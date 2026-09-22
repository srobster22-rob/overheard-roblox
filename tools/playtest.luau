--!strict
-- A full headless session with bot players and an event trace, for PLAYTEST
-- rounds (AGENT_LOOP v2). Run from the project root:
--     lune run tools/playtest [persona] [rounds] [seed] [gate]
--
-- It drives the REAL server modules the way `init.server` does, in the
-- server's order within a beat (see `tick`), and prints what a player would see
-- and hear, in order. tests/wiring.luau holds it to the server's escape step.
-- It is a reading instrument, not a test. The one exception is `gate`, which
-- test.cmd passes: then it exits non-zero if the bots won no round at all, so
-- an escape nobody can win fails the ship gate rather than printing quietly.
--
-- Personas are how the bots TALK, because talking is the game:
--   firsttimer  says the plain word in round 1, then coins a codeword and keeps
--               using it until the Operator shows up for it
--   returning   starts with a codeword, swaps it the moment the panel shows red
--   quiet       one mention per solve and one player who never speaks

local process = require("@lune/process")

local Harness = require("../tests/harness")

local rt = Harness.build()
local Objectives = rt.require(rt.systems.Objectives)
local Connected = rt.require(rt.systems.Connected)
local Lifecycle = rt.require(rt.systems.Lifecycle)
local Operator = rt.require(rt.systems.Operator)
local Pursuit = rt.require(rt.systems.Pursuit)
local Round = rt.require(rt.systems.Round)
local Supervisor = rt.require(rt.systems.Supervisor)
local Layout = rt.require(rt.shared.Layout)
local Config = rt.require(rt.shared.Config)
local Escape = rt.require(rt.systems.Escape)

local persona = process.args[1] or "firsttimer"
local wantRounds = tonumber(process.args[2]) or 7
local seed = tonumber(process.args[3]) or 11
math.randomseed(seed)

local NAMES = { [1] = "Ana", [2] = "Bo", [3] = "Cy", [4] = "Dee" }
local CODEWORDS = {
	"blue kettle",
	"tin whistle",
	"red anchor",
	"green ladder",
	"old saddle",
	"grey heron",
	"paper moon",
	"brass owl",
	"cold toast",
}
-- Each line starts on its own codeword and steps by the number of lines, so two
-- lines never share one.
local FIRST_CODEWORD: { [string]: number } = {}
for index, station in Round.STATIONS do
	FIRST_CODEWORD[station.concept] = index
end
local CODEWORD_STRIDE = #Round.STATIONS
local PLAIN = { jack_number = "jack", breaker = "breaker", exit = "exit" }

local now = 0
local function trace(text: string)
	print(string.format("[%6.1fs] %s", now, text))
end

local rooms = Layout.rooms()
local secrets = Round.dealSecrets(Round.secretsPerRound())
local board = Objectives.new()
for _, station in Round.STATIONS do
	board:add(station.id, station.concept, station.prompt)
end
local line = Connected.new()
local round = Lifecycle.new()
local operator = Operator.new(secrets)
local pursuit = Pursuit.new(rooms, Layout.operatorPost(), Layout.route)
local supervisor = Supervisor.new()
local escape = Escape.new()

-- R138: how long each group takes to react once the outside call rings, and
-- how long the run to the lobby takes: 93 studs from the middle of the board
-- room or the archive, 123 from a far corner, so 6 to 8 s at Roblox's default
-- walk of 16 studs/s. The bots take 7. First-timers stand around asking what
-- the ringing means.
local RUN_AFTER: { [string]: number } = { firsttimer = 10, returning = 3, quiet = 6 }
local RUN_TRAVEL_SECONDS = 7

local present = { 1, 2, 3, 4 }
local standing: { [number]: any } = {}
local roomOf: { [number]: string } = { [1] = "board", [2] = "board", [3] = "archive", [4] = "archive" }
local function place()
	for _, id in present do
		standing[id] = rooms[roomOf[id]]
	end
end
place()

local stats = { won = 0, lost = 0, captures = 0, understood = 0, calls = 0, red = 0, swaps = 0 }
local codeIndex: { [string]: number } = {}
local redSeen: { [string]: boolean } = {}
local function codewordFor(concept: string): string
	local i = codeIndex[concept] or FIRST_CODEWORD[concept] or 1
	codeIndex[concept] = i
	return CODEWORDS[(i - 1) % #CODEWORDS + 1]
end

operator.onUnderstood = function(concept: string, payload: string, confidence: number)
	stats.understood += 1
	local _, onItsWay = pursuit:sendTo(payload)
	trace(
		`   >> THE OPERATOR UNDERSTOOD '{concept}' ({math.floor(confidence * 100)}%) and {if onItsWay
			then "is walking to"
			else "queues"} the {payload} room`
	)
	-- The group notices it came for their codeword, and coins another.
	if confidence < 1 or persona ~= "firsttimer" then
		redSeen[concept] = true
	end
end
operator.onBurned = function(coinage)
	trace(`   >> BURNED: "{coinage.phrase}" now means {coinage.concept}. "{Round.LINES.connecting}"`)
end

local function say(who: number, text: string)
	trace(`{NAMES[who]}: "{text}"`)
	supervisor:hear(who, now)
	operator:hear({ speaker = { UserId = who } :: any, text = text, at = now })
end

local function panel()
	local rows = {}
	for _, c in operator:snapshot() do
		if c.heat >= 0.3 then
			table.insert(
				rows,
				`{c.phrase} {math.floor(c.heat * 100)}%{if c.heat >= Config.ActThreshold then "!" else ""}`
			)
		end
	end
	table.sort(rows)
	trace(`   lexicon panel ({#operator:snapshot()} rows), warm ones: {table.concat(rows, ", ")}`)
end

local function tick(seconds: number)
	local steps = math.floor(seconds / Config.TickSeconds)
	for _ = 1, steps do
		now += Config.TickSeconds
		if not round:isPlaying() then
			continue
		end
		-- The server's order within a beat: capture, the loss, the silent line,
		-- the way out, a queued room, the linger. (The Operator's own walk runs
		-- on Heartbeat there; here it goes first.)
		local before = pursuit.state
		pursuit:step(Config.TickSeconds)
		if pursuit.state == "arrived" and before ~= "arrived" then
			trace(`   >> it has ARRIVED. "{Round.LINES.taken}"`)
		end
		if pursuit.state == "arrived" then
			local had = line:count()
			line:takeInRoom(pursuit.position, standing, Layout.halfRoom(), now, supervisor)
			if line:count() > had then
				stats.captures += line:count() - had
				local taken = {}
				for _, id in present do
					if line:isConnected(id) then
						table.insert(taken, NAMES[id])
					end
				end
				trace(`   >> "{Round.LINES.onTheLine}" On the line now: {table.concat(taken, ", ")}`)
			end
		end
		if Lifecycle.nobodyCanWin(present, board, line) and round:finish("lost", now) then
			stats.lost += 1
			pursuit:stop()
			trace(`   ROUND LOST. "{Round.LINES.lost}"`)
		end
		if round:isPlaying() then
			local called, announce = supervisor:putThrough(pursuit, rooms, Config.Rooms, standing, now)
			if called then
				stats.calls += 1
				if announce then
					trace(`   >> THE SUPERVISOR put a call through to a silent player. "{Round.LINES.traced}"`)
				end
			end
		end
		-- R138: the server's way out, one beat of the same `Escape.step`.
		if round:isPlaying() and escape:isOpen() then
			local outcome, sent = escape:step(now, pursuit, present, line, standing, rooms)
			if sent then
				trace(`   >> the call has rung. The door is open and it is coming for the {Escape.ROOM}.`)
			end
			if outcome and round:finish(outcome, now) then
				pursuit:stop()
				local out, free = 0, 0
				for _, id in present do
					if not line:isConnected(id) then
						free += 1
						out += if roomOf[id] == Escape.ROOM then 1 else 0
					end
				end
				if outcome == "won" then
					stats.won += 1
					trace(`   ROUND WON: {out} of {free} still free got out. "{Round.LINES.completed}"`)
				else
					stats.lost += 1
					trace(`   ROUND LOST: the door was open {Config.EscapeSeconds}s and nobody got out.`)
				end
			end
		end
		pursuit:takePending()
		if pursuit:shouldLeave(Config.LingerSeconds) then
			pursuit:withdrawTo(Layout.operatorPost())
			trace(`   >> it gives the room up. "{Round.LINES.givingUp}"`)
		end
	end
end

-- Tick until the round is over, or `seconds` pass.
local function tickUntilOver(seconds: number)
	local waited = 0
	while round:isPlaying() and waited < seconds do
		tick(Config.TickSeconds)
		waited += Config.TickSeconds
	end
end

local function freeActor(objective): number?
	local room = Layout.stationRoom(objective.id)
	local fallback: number? = nil
	for _, id in present do
		if id ~= objective.holder and not objective.seenBy[id] and not line:isConnected(id) then
			if roomOf[id] == room then
				return id
			end
			fallback = fallback or id
		end
	end
	return fallback
end

trace(`persona: {persona}, seed {seed}. Secrets it listens for: {#secrets}. "{Round.LINES.greeting}"`)
board:deal(present)
for _, id in present do
	supervisor:watch(id, now)
end

local played = 0
while played < wantRounds do
	played += 1
	trace(`===== ROUND {played} =====`)
	for _, objective in board.list do
		if not round:isPlaying() then
			break
		end
		tick(12)
		local holder = objective.holder
		local actor = freeActor(objective)
		if holder == nil or actor == nil or not round:isPlaying() then
			trace(`   nobody free can work the {objective.id} line`)
			continue
		end
		local concept = objective.concept
		local word: string
		if persona == "firsttimer" and played == 1 then
			word = PLAIN[concept] or concept
		else
			if redSeen[concept] then
				redSeen[concept] = false
				codeIndex[concept] = (codeIndex[concept] or FIRST_CODEWORD[concept] or 1) + CODEWORD_STRIDE
				stats.swaps += 1
				trace(
					`   (the group drops its old word for the {objective.id} line and coins "{codewordFor(concept)}")`
				)
			end
			word = codewordFor(concept)
		end
		if line:isConnected(holder) then
			trace(`   ({NAMES[holder]} is on the line but can still talk)`)
		end
		if roomOf[actor] ~= Layout.stationRoom(objective.id) then
			trace(`   {NAMES[actor]} runs to the {Layout.stationRoom(objective.id)} room`)
			roomOf[actor] = Layout.stationRoom(objective.id)
			place()
			tick(8)
		end
		say(holder, `{NAMES[actor]} its the {word} {objective.answer}`)
		if persona ~= "quiet" then
			tick(4)
			say(actor, "which one again")
			say(holder, `the {word} {objective.answer} go`)
		end
		tick(2)
		if not round:isPlaying() then
			break
		end
		if line:isConnected(actor) then
			trace(`   {NAMES[actor]} was taken before reaching the station`)
			continue
		end
		local result = board:submit(objective.id, actor, objective.answer, now)
		if result.ok then
			operator:credit(objective.concept, now)
			trace(`   {NAMES[actor]} restores the {objective.id} line.`)
			panel()
		else
			trace(`   {NAMES[actor]} is refused: {tostring(result.reason)}`)
		end
	end
	-- R138: the last line opens the way out. The group hears the call, reacts,
	-- runs, and the round is won only if everyone free gets into the lobby.
	if round:isPlaying() and board:allSolved() and escape:open(now) then
		trace(`   every line is through. "{Round.LINES.ringing}"`)
		tickUntilOver(RUN_AFTER[persona] or 6)
		if round:isPlaying() then
			local runners = {}
			for _, id in present do
				if not line:isConnected(id) then
					table.insert(runners, NAMES[id])
				end
			end
			trace(`   {table.concat(runners, ", ")} run for the {Escape.ROOM}`)
			tickUntilOver(RUN_TRAVEL_SECONDS)
			for _, id in present do
				if not line:isConnected(id) then
					roomOf[id] = Escape.ROOM
				end
			end
			place()
			tickUntilOver(60)
		end
	end
	if round:isPlaying() then
		round:finish("lost", now)
		stats.lost += 1
		trace("   the round stalls out (counted as lost)")
	end
	now += Config.IntermissionSeconds
	if round:readyToRestart(now, Config.IntermissionSeconds) and round:restart() then
		board:reset()
		line:clear()
		escape:reset()
		operator:forgetObservations()
		operator:coolRound(Config.CoolPerRound)
		pursuit:sendHome(Layout.operatorPost())
		supervisor:reset(now)
		roomOf = { [1] = "board", [2] = "board", [3] = "archive", [4] = "archive" }
		place()
		for _, id in present do
			supervisor:watch(id, now)
		end
		board:deal(present)
	end
end

for _, c in operator:snapshot() do
	if c.heat >= Config.ActThreshold then
		stats.red += 1
	end
end
print("")
print(
	`SUMMARY persona={persona} rounds={played} won={stats.won} lost={stats.lost} captures={stats.captures} understood={stats.understood} supervisorCalls={stats.calls} codewordSwaps={stats.swaps} redAtEnd={stats.red} minutes={string.format(
		"%.1f",
		now / 60
	)}`
)
if process.args[4] == "gate" and stats.won == 0 then
	print(`GATE: the bots won none of {played} rounds`)
	process.exit(1)
end
