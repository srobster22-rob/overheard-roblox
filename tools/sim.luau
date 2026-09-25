--!strict
-- A headless OVERHEARD server: the real modules, wired the way init.server
-- wires them and stepped in the server's order within a beat, on a clock the
-- caller advances. Two drivers share it, so there is one copy of the beat:
--   tools/playtest.luau  scripted bot groups (the trace the log quotes)
--   tools/play.luau      a session a person or an agent writes, replayed
-- Chat is heard only while a round is live, a code is taken only at the
-- station the player stands at, and a solve credits the Operator and opens the
-- way out: the server's handlers, in the same order. `view` is one player's
-- screen: their panel, the Lexicon, the silence clock, the hum.

local Harness = require("../tests/harness")

local rt = Harness.build()
local Objectives = rt.require(rt.systems.Objectives)
local Connected = rt.require(rt.systems.Connected)
local Lifecycle = rt.require(rt.systems.Lifecycle)
local Operator = rt.require(rt.systems.Operator)
local Pursuit = rt.require(rt.systems.Pursuit)
local Round = rt.require(rt.systems.Round)
local Supervisor = rt.require(rt.systems.Supervisor)
local Escape = rt.require(rt.systems.Escape)
local Layout = rt.require(rt.shared.Layout)
local Config = rt.require(rt.shared.Config)
local Readout = rt.require(rt.shared.Readout)
local Silence = rt.require(rt.shared.Silence)
local Guard = rt.require(rt.shared.Guard)

local Sim = {}
Sim.__index = Sim

-- What the drivers need to read, without building a second harness.
Sim.Round = Round
Sim.Config = Config
Sim.Layout = Layout
Sim.Escape = Escape
Sim.Guard = Guard
Sim.NAMES = { [1] = "Ana", [2] = "Bo", [3] = "Cy", [4] = "Dee" }
-- Where the group stands when a round begins: two in each work room.
Sim.START = { [1] = "board", [2] = "board", [3] = "archive", [4] = "archive" }

function Sim.new(seed: number): any
	math.randomseed(seed)
	local rooms = Layout.rooms()
	local secrets = Round.dealSecrets(Round.secretsPerRound())
	local self = setmetatable({
		now = 0,
		seed = seed,
		rooms = rooms,
		secrets = secrets,
		board = Objectives.new(),
		line = Connected.new(),
		round = Lifecycle.new(),
		operator = Operator.new(secrets),
		pursuit = Pursuit.new(rooms, Layout.operatorPost(), Layout.route),
		supervisor = Supervisor.new(),
		escape = Escape.new(),
		present = { 1, 2, 3, 4 },
		standing = {},
		roomOf = table.clone(Sim.START),
		stats = { won = 0, lost = 0, captures = 0, understood = 0, calls = 0, codesHeard = 0, rangThrough = 0 },
		-- A driver's own reaction to being understood (the bots notice red).
		onUnderstood = nil :: ((concept: string, confidence: number) -> ())?,
	}, Sim)
	for _, station in Round.STATIONS do
		self.board:add(station.id, station.concept, station.prompt)
	end
	self.operator.liveCodes = Guard.wrap("sim.liveCodes", function()
		return self.board:liveCodes()
	end)
	self.operator.seenCodes = Guard.wrap("sim.seenCodes", function(userId: number)
		return self.board:codesSeenBy(userId)
	end)
	self.operator.names = Guard.wrap("sim.names", function()
		local names: { [string]: boolean } = {}
		for _, id in self.present do
			names[string.lower(Sim.NAMES[id])] = true
		end
		return names
	end)
	self.operator.onUnderstood = Guard.wrap(
		"sim.onUnderstood",
		function(concept: string, payload: string, confidence: number, heard: string?)
			self.stats.understood += 1
			local _, onItsWay = self.pursuit:sendTo(payload)
			self:trace(
				`   >> THE OPERATOR UNDERSTOOD '{concept}' ({math.floor(confidence * 100)}%) and {if onItsWay
					then "is walking to"
					else "queues"} the {payload} room. "{Round.readBack(heard)}"`
			)
			if self.onUnderstood then
				self.onUnderstood(concept, confidence)
			end
		end
	)
	self.operator.onCodeHeard = Guard.wrap("sim.onCodeHeard", function(concept: string)
		local line = self.board:reroll(concept)
		if line then
			self.stats.codesHeard += 1
			self:trace(`   >> the {line.id} code was heard, so it is spent: its holder has a new one.`)
		end
	end)
	self.operator.onBurned = Guard.wrap("sim.onBurned", function(coinage)
		self:trace(`   >> BURNED: "{coinage.phrase}" now means {coinage.concept}. "{Round.LINES.connecting}"`)
	end)
	-- R147: the server's `onCounted`, as the trace reads it.
	self.operator.onCounted = Guard.wrap("sim.onCounted", function(key: string, value: number)
		self:trace(`   >> it counts "{key}" as {value} now. "{Round.LINES.counted}"`)
	end)
	self.operator.onMethod = Guard.wrap("sim.onMethod", function(kind: string, way: string, says: string)
		local said = (Round.LINES :: { [string]: string })[says]
		if kind == "noting" then
			self:trace(`   >> it is writing down how you pass codes ({way}). "{said}"`)
		else
			self:trace(`   >> it reads codes passed this way now: {way}. "{said}"`)
		end
	end)
	self.operator.onKnown = Guard.wrap("sim.onKnown", function(_concept: string)
		self:trace(`   >> it knows that number. "{Round.LINES.known}"`)
	end)
	self.operator.onLettered = Guard.wrap("sim.onLettered", function()
		self:trace(`   >> it reads the group's letters now. "{Round.LINES.lettered}"`)
	end)
	self:place()
	return self
end

function Sim.trace(self: any, text: string)
	print(string.format("[%6.1fs] %s", self.now, text))
end

function Sim.place(self: any)
	for _, id in self.present do
		self.standing[id] = self.rooms[self.roomOf[id]]
	end
end

-- The first round: deal the lines and start everyone's silence clock.
function Sim.begin(self: any)
	self:trace(`seed {self.seed}. Secrets it listens for: {#self.secrets}. "{Round.LINES.greeting}"`)
	self.board:deal(self.present)
	for _, id in self.present do
		self.supervisor:watch(id, self.now)
	end
end

-- A chat message. The server's `hearChat`: both listeners, only while a round
-- is being played.
function Sim.say(self: any, id: number, text: string)
	self:trace(`{Sim.NAMES[id]}: "{text}"`)
	if not self.round:isPlaying() then
		return
	end
	self.supervisor:hear(id, self.now)
	self.operator:hear({ speaker = { UserId = id } :: any, text = text, at = self.now })
end

function Sim.move(self: any, id: number, room: string)
	assert(self.rooms[room], `no room called '{room}'`)
	self.roomOf[id] = room
	self:place()
end

-- Roblox's default walk, studs per second.
Sim.WALK = 16

-- Where a walking player is between rooms: the corridor junction, which no
-- room contains, so nobody walking can be taken there.
Sim.CORRIDOR = "corridor"

-- How long a player takes to walk from the middle of one room to another: the
-- corridor route the Operator also takes, at a walk.
function Sim.walkSeconds(self: any, from: string, to: string): number
	local a, b = self.rooms[from], self.rooms[to]
	local studs, at = 0, a
	for _, turn in Layout.route(a, b) do
		studs += math.sqrt((turn.x - at.x) ^ 2 + (turn.z - at.z) ^ 2)
		at = turn
	end
	studs += math.sqrt((b.x - at.x) ^ 2 + (b.z - at.z) ^ 2)
	return studs / Sim.WALK
end

-- Players walking to a room together, the way they do live. Each is out of its
-- room once it reaches the doorway (half a room from the middle, 1.5 s), in the
-- corridor for the walk, and in the new room once through its door. The clock
-- runs until the last of them is through. A player taken before reaching the
-- doorway stays where they were taken. Returns who set off.
--
-- Until R140's playtest this tool moved a walker only when the whole walk was
-- over, so a player who left the moment the Operator was called was still
-- counted in the room 7 s later, and PT3 reported "no escape once it is called".
-- Live, they are out of the room in 1.5 s.
function Sim.walk(self: any, ids: { number }, room: string): { number }
	assert(self.rooms[room], `no room called '{room}'`)
	local doorway = Layout.halfRoom() / Sim.WALK
	local plan, last, walking = {}, 0, {}
	for _, id in ids do
		local from = self.roomOf[id]
		if from ~= room and not self.line:isConnected(id) then
			local through = self:walkSeconds(from, room) - doorway
			table.insert(plan, { id = id, out = false, arrived = false, through = through })
			table.insert(walking, id)
			last = math.max(last, through)
		end
	end
	local elapsed = 0
	while elapsed < last - 1e-9 do
		self:tick(Config.TickSeconds)
		elapsed += Config.TickSeconds
		for _, step in plan do
			if not step.out and self.line:isConnected(step.id) then
				step.arrived = true
			elseif not step.out and elapsed >= doorway - 1e-9 then
				step.out = true
				self.roomOf[step.id] = Sim.CORRIDOR
				self.standing[step.id] = Layout.junction()
			elseif step.out and not step.arrived and elapsed >= step.through - 1e-9 then
				step.arrived = true
				self.roomOf[step.id] = room
				self.standing[step.id] = self.rooms[room]
			end
		end
	end
	return walking
end

-- A code entered at a station. Taken only from a player standing in that
-- station's room (the server's desk gate); a solve credits the Operator and,
-- for the last line, starts the outside call (the server's `board.onSolved`).
function Sim.submit(self: any, id: number, stationId: string, value: string): any
	if self.roomOf[id] ~= Layout.stationRoom(stationId) then
		return { ok = false, reason = "not at that station" }
	end
	local objective = self.board:get(stationId)
	local result = self.board:submit(stationId, id, value, self.now)
	if result.ringsThrough then
		self.stats.rangThrough += 1
		local _, onItsWay = self.pursuit:sendTo(Layout.stationRoom(stationId))
		self:trace(
			`   >> a wrong code rang through. "{Round.LINES.wrongParty}" It {if onItsWay
				then "is walking to"
				else "queues"} the {Layout.stationRoom(stationId)} room.`
		)
	end
	if result.ok then
		self.operator:credit(objective.concept, self.now, objective.holder, id)
		self.operator:creditCode(objective.answer, self.now, objective.holder)
		self:trace(`   {Sim.NAMES[id]} restores the {stationId} line.`)
		if self.board:allSolved() and self.escape:open(self.now) then
			self:trace(`   every line is through. "{Round.LINES.ringing}"`)
		end
	end
	return result
end

-- The server's beat, `seconds` of it: the Operator's walk (Heartbeat there),
-- capture, the loss, the silent line, the way out, a queued room, the linger.
function Sim.tick(self: any, seconds: number)
	local steps = math.floor(seconds / Config.TickSeconds)
	for _ = 1, steps do
		self.now += Config.TickSeconds
		if not self.round:isPlaying() then
			continue
		end
		Guard.run("sim.beat", Sim.beat, self)
	end
end

-- One beat of a round being played, in the server's order.
function Sim.beat(self: any)
	local pursuit, line = self.pursuit, self.line
	local before = pursuit.state
	pursuit:step(Config.TickSeconds)
	if pursuit.state == "arrived" and before ~= "arrived" then
		local where = Round.holding(pursuit.state, pursuit.targetName, Escape.ROOM)
		local note = if where and where.label then ` It is waiting by the {where.label}.` else ""
		self:trace(`   >> it has ARRIVED. "{Round.LINES.taken}"{note}`)
	end
	if pursuit.state == "arrived" then
		local had = line:count()
		line:takeInRoom(pursuit.position, self.standing, Layout.halfRoom(), self.now, self.supervisor)
		if line:count() > had then
			self.stats.captures += line:count() - had
			local taken = {}
			for _, id in self.present do
				if line:isConnected(id) then
					table.insert(taken, Sim.NAMES[id])
				end
			end
			self:trace(`   >> "{Round.LINES.onTheLine}" On the line now: {table.concat(taken, ", ")}`)
		end
	end
	if Lifecycle.nobodyCanWin(self.present, self.board, line) and self.round:finish("lost", self.now) then
		self.stats.lost += 1
		pursuit:stop()
		self:trace(`   ROUND LOST. "{Round.LINES.lost}"`)
	end
	if self.round:isPlaying() then
		local called, announce = self.supervisor:putThrough(pursuit, self.rooms, Config.Rooms, self.standing, self.now)
		if called then
			self.stats.calls += 1
			if announce then
				self:trace(`   >> THE SUPERVISOR put a call through to a silent player. "{Round.LINES.traced}"`)
			end
		end
	end
	if self.round:isPlaying() and self.escape:isOpen() then
		local outcome, sent = self.escape:step(self.now, pursuit, self.present, line, self.standing, self.rooms)
		if sent then
			self:trace(`   >> the call has rung. The door is open and it is coming for the {Escape.ROOM}.`)
		end
		if outcome and self.round:finish(outcome, self.now) then
			pursuit:stop()
			local out, free = 0, 0
			for _, id in self.present do
				if not line:isConnected(id) then
					free += 1
					out += if self.roomOf[id] == Escape.ROOM then 1 else 0
				end
			end
			if outcome == "won" then
				self.stats.won += 1
				self:trace(`   ROUND WON: {out} of {free} still free got out. "{Round.LINES.completed}"`)
			else
				self.stats.lost += 1
				self:trace(`   ROUND LOST: the door was open {Config.EscapeSeconds}s and nobody got out.`)
			end
		end
	end
	pursuit:takePending()
	if pursuit:shouldLeave(Config.LingerSeconds) then
		pursuit:withdrawTo(Layout.operatorPost())
		self:trace(`   >> it gives the room up. "{Round.LINES.givingUp}"`)
	end
end

-- Tick until the round is over, or `seconds` pass.
function Sim.tickUntilOver(self: any, seconds: number)
	local waited = 0
	while self.round:isPlaying() and waited < seconds do
		self:tick(Config.TickSeconds)
		waited += Config.TickSeconds
	end
end

-- The intermission, then the next round, set up the way `beginRound` does. A
-- round still being played is counted as a stall (a loss) first.
function Sim.nextRound(self: any)
	if self.round:isPlaying() then
		self.round:finish("lost", self.now)
		self.stats.lost += 1
		self:trace("   the round stalls out (counted as lost)")
	end
	self.now += Config.IntermissionSeconds
	if self.round:readyToRestart(self.now, Config.IntermissionSeconds) and self.round:restart() then
		self.board:reset()
		self.line:clear()
		self.escape:reset()
		self.operator:forgetObservations()
		self.operator:coolRound(Config.CoolPerRound)
		self.pursuit:sendHome(Layout.operatorPost())
		self.supervisor:reset(self.now)
		self.roomOf = table.clone(Sim.START)
		self:place()
		for _, id in self.present do
			self.supervisor:watch(id, self.now)
		end
		self.board:deal(self.present)
	end
end

-- One player's screen, as text: what the client would show them right now.
function Sim.view(self: any, id: number): { string }
	local out: { string } = {}
	local roundText = if self.round:isPlaying()
		then `round {self.round.number}, being played`
		else Readout.roundOver(self.round.outcome, self.round.number).title
	table.insert(out, `{Sim.NAMES[id]}, in the {self.roomOf[id]} room. {roundText}.`)
	if self.line:isConnected(id) then
		table.insert(out, "  You are ON THE LINE: you can still talk, but you cannot act.")
	end
	local holding = Round.holding(self.pursuit.state, self.pursuit.targetName, Escape.ROOM)
	for _, row in Readout.lineRows(self.board:viewFor(id), holding) do
		table.insert(out, `  panel: {row.text}`)
	end
	local band = self.supervisor:band(id, self.now)
	if band then
		table.insert(out, `  silence: {Silence.note(band)}`)
	end
	table.insert(out, `  the hum: {if self.pursuit:isAudible() then "you can hear it" else "silence"}`)
	return out
end

-- The Lexicon panel, which everyone sees.
function Sim.lexicon(self: any): { string }
	local out: { string } = {}
	local rows = Round.wallRows(self.operator:snapshot(), self.operator:countingRows(), self.operator:methodRows())
	for _, row in Readout.lexiconRows(rows) do
		table.insert(out, row.text)
	end
	return out
end

-- Whatever the guard caught in this run, printed; true if anything was. A
-- driver that ends with a failure recorded fails, because a callback that threw
-- shows in the trace only as a line that is missing.
function Sim.reportFailures(): boolean
	local recorded = Guard.failures()
	for _, failure in recorded do
		print(`GUARD: [{failure.tag}] {failure.message}`)
		print(failure.traceback)
	end
	return #recorded > 0
end

return Sim
