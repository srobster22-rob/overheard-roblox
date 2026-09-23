--!strict
-- A full headless session with bot players and an event trace, for PLAYTEST
-- rounds. Run from the project root:
--     lune run tools/playtest [persona] [rounds] [seed] [gate]
--
-- The world is tools/sim.luau: the REAL server modules in the server's order
-- within a beat, shared with tools/play.luau so there is one copy of it. This
-- file is only the bots' script: what they say, where they run, when.
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

local Sim = require("./sim")

local persona = process.args[1] or "firsttimer"
local wantRounds = tonumber(process.args[2]) or 7
local seed = tonumber(process.args[3]) or 11

local Round, Config, Layout, Escape = Sim.Round, Sim.Config, Sim.Layout, Sim.Escape
local NAMES = Sim.NAMES

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

-- R138: how long each group takes to react once the outside call rings, and
-- how long the run to the lobby takes: 93 studs from the middle of the board
-- room or the archive, 123 from a far corner, so 6 to 8 s at Roblox's default
-- walk of 16 studs/s. The bots take 7. First-timers stand around asking what
-- the ringing means.
local RUN_AFTER: { [string]: number } = { firsttimer = 10, returning = 3, quiet = 6 }
local RUN_TRAVEL_SECONDS = 7

local sim = Sim.new(seed)
local swaps, codeIndex, redSeen = 0, {} :: { [string]: number }, {} :: { [string]: boolean }
local function codewordFor(concept: string): string
	local i = codeIndex[concept] or FIRST_CODEWORD[concept] or 1
	codeIndex[concept] = i
	return CODEWORDS[(i - 1) % #CODEWORDS + 1]
end
-- The group notices it came for their codeword, and coins another.
sim.onUnderstood = function(concept: string, confidence: number)
	if confidence < 1 or persona ~= "firsttimer" then
		redSeen[concept] = true
	end
end

local function panel()
	local rows = {}
	for _, c in sim.operator:snapshot() do
		if c.heat >= 0.3 then
			table.insert(
				rows,
				`{c.phrase} {math.floor(c.heat * 100)}%{if c.heat >= Config.ActThreshold then "!" else ""}`
			)
		end
	end
	table.sort(rows)
	sim:trace(`   lexicon panel ({#sim.operator:snapshot()} rows), warm ones: {table.concat(rows, ", ")}`)
end

local function freeActor(objective): number?
	local room = Layout.stationRoom(objective.id)
	local fallback: number? = nil
	for _, id in sim.present do
		if id ~= objective.holder and not objective.seenBy[id] and not sim.line:isConnected(id) then
			if sim.roomOf[id] == room then
				return id
			end
			fallback = fallback or id
		end
	end
	return fallback
end

sim:trace(`persona: {persona}.`)
sim:begin()

local played = 0
while played < wantRounds do
	played += 1
	sim:trace(`===== ROUND {played} =====`)
	for _, objective in sim.board.list do
		if not sim.round:isPlaying() then
			break
		end
		sim:tick(12)
		local holder = objective.holder
		local actor = freeActor(objective)
		if holder == nil or actor == nil or not sim.round:isPlaying() then
			sim:trace(`   nobody free can work the {objective.id} line`)
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
				swaps += 1
				sim:trace(
					`   (the group drops its old word for the {objective.id} line and coins "{codewordFor(concept)}")`
				)
			end
			word = codewordFor(concept)
		end
		if sim.line:isConnected(holder) then
			sim:trace(`   ({NAMES[holder]} is on the line but can still talk)`)
		end
		local room = Layout.stationRoom(objective.id)
		if sim.roomOf[actor] ~= room then
			sim:trace(`   {NAMES[actor]} runs to the {room} room`)
			sim:move(actor, room)
			sim:tick(8)
		end
		sim:say(holder, `{NAMES[actor]} its the {word} {objective.answer}`)
		if persona ~= "quiet" then
			sim:tick(4)
			sim:say(actor, "which one again")
			sim:say(holder, `the {word} {objective.answer} go`)
		end
		sim:tick(2)
		if not sim.round:isPlaying() then
			break
		end
		if sim.line:isConnected(actor) then
			sim:trace(`   {NAMES[actor]} was taken before reaching the station`)
			continue
		end
		local result = sim:submit(actor, objective.id, objective.answer)
		if result.ok then
			panel()
		else
			sim:trace(`   {NAMES[actor]} is refused: {tostring(result.reason)}`)
		end
	end
	-- R138: the last line opened the way out. The group hears the call, reacts,
	-- runs, and the round is won only if everyone free gets into the lobby.
	if sim.round:isPlaying() and sim.escape:isOpen() then
		sim:tickUntilOver(RUN_AFTER[persona] or 6)
		if sim.round:isPlaying() then
			local runners = {}
			for _, id in sim.present do
				if not sim.line:isConnected(id) then
					table.insert(runners, NAMES[id])
				end
			end
			sim:trace(`   {table.concat(runners, ", ")} run for the {Escape.ROOM}`)
			sim:tickUntilOver(RUN_TRAVEL_SECONDS)
			for _, id in sim.present do
				if not sim.line:isConnected(id) then
					sim.roomOf[id] = Escape.ROOM
				end
			end
			sim:place()
			sim:tickUntilOver(60)
		end
	end
	sim:nextRound()
end

local red = 0
for _, c in sim.operator:snapshot() do
	if c.heat >= Config.ActThreshold then
		red += 1
	end
end
local stats = sim.stats
print("")
print(
	`SUMMARY persona={persona} rounds={played} won={stats.won} lost={stats.lost} captures={stats.captures} understood={stats.understood} supervisorCalls={stats.calls} codewordSwaps={swaps} redAtEnd={red} minutes={string.format(
		"%.1f",
		sim.now / 60
	)}`
)
if process.args[4] == "gate" and stats.won == 0 then
	print(`GATE: the bots won none of {played} rounds`)
	process.exit(1)
end
