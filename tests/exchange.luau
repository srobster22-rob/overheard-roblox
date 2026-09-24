--!strict
-- The server's game flow (systems/Exchange), run on a fake host. Run: lune run tests/exchange
--
-- What this file guards: what the server does with a submission, a prompt, a
-- player joining or leaving, chat, and each beat of its clock; what it says and
-- to whom; how a round ends and the next begins. The host is fake: players the
-- test places, remotes that record what was sent, and a clock the test steps.
-- The Operator's walk (Presence's job on a live server) is stepped by the test.

local Harness = require("./harness")
local Kit = require("./kit")
local check = Kit.check

local rt = Harness.build()
local Exchange = rt.require(rt.systems.Exchange)
local Round = rt.require(rt.systems.Round)
local Escape = rt.require(rt.systems.Escape)
local Layout = rt.require(rt.shared.Layout)
local Config = rt.require(rt.shared.Config)
local Guard = rt.require(rt.shared.Guard)
local Silence = rt.require(rt.shared.Silence)

math.randomseed(154)

local REMOTES =
	{ "Heard", "LexiconUpdated", "Objectives", "OpenBoard", "Silence", "Rejected", "Connected", "Phase", "Holding" }
-- Remotes that carry one player's own information, and so must never be broadcast.
local PRIVATE = { "Rejected", "OpenBoard", "Silence", "Connected", "Objectives" }

local STATION: { [string]: any } = {}
local STATION_AT: { [string]: any } = {}
for _, station in Round.STATIONS do
	STATION[station.id] = station
	STATION_AT[station.id] = Layout.stationPoint(station.id)
end
local ROOMS = Layout.rooms()
local POST = Layout.operatorPost()
local TICK = Config.TickSeconds

type Sent = { to: any, args: { any } }

local function recorder(): any
	local remote = { sent = {} :: { Sent } }
	function remote.FireClient(self: any, player: any, ...: any)
		table.insert(self.sent, { to = player.UserId, args = { ... } })
	end
	function remote.FireAllClients(self: any, ...: any)
		table.insert(self.sent, { to = "all", args = { ... } })
	end
	return remote
end

local PASS_THROUGH = {
	FilterStringAsync = function(_self: any, text: string, _authorId: number): any
		return {
			GetNonChatStringForBroadcastAsync = function(_result: any): string
				return text
			end,
		}
	end,
}

local worlds: { any } = {}

-- One server, on a fake host.
local function world(textService: any?): any
	local w: any = { now = 100, roster = {}, remotes = {} }
	for _, name in REMOTES do
		w.remotes[name] = recorder()
	end
	w.flow = Exchange.build({
		Players = {
			GetPlayers = function(_self: any)
				return table.clone(w.roster)
			end,
			GetPlayerByUserId = function(_self: any, id: number): any
				for _, p in w.roster do
					if p.UserId == id then
						return p
					end
				end
				return nil
			end,
		},
		TextService = textService or PASS_THROUGH,
		remotes = w.remotes,
		built = { rooms = ROOMS, stationAt = STATION_AT, operatorStart = POST },
		spawnTask = function(work: () -> ())
			work()
		end,
		deferTask = function(work: () -> ())
			work()
		end,
		clock = function(): number
			return w.now
		end,
	})

	-- A player joins, standing at `point`.
	function w.join(id: number, name: string, point: any): any
		local root = { Position = { X = point.x, Z = point.z } }
		local p = {
			UserId = id,
			Name = name,
			Character = {
				FindFirstChild = function(_self: any, child: string): any
					return if child == "HumanoidRootPart" then root else nil
				end,
			},
			stand = function(at: any)
				root.Position = { X = at.x, Z = at.z }
			end,
		}
		table.insert(w.roster, p)
		w.flow.playerAdded(p)
		return p
	end
	-- A player leaves. Roblox still lists them while PlayerRemoving runs.
	function w.leave(p: any)
		w.flow.playerRemoving(p)
		local i = table.find(w.roster, p)
		if i then
			table.remove(w.roster, i)
		end
	end
	function w.player(id: number): any
		for _, p in w.roster do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	function w.sent(remote: string, to: any): { Sent }
		local out = {}
		for _, s in w.remotes[remote].sent do
			if to == nil or s.to == to then
				table.insert(out, s)
			end
		end
		return out
	end
	-- How many times `line` was said on Heard to `to`.
	function w.said(line: string, to: any): number
		local n = 0
		for _, s in w.sent("Heard", to) do
			if s.args[1] == line then
				n += 1
			end
		end
		return n
	end
	function w.last(remote: string, to: any): Sent?
		local list = w.sent(remote, to)
		return list[#list]
	end
	-- `seconds` of the server: the Operator's walk (Presence) and the beat.
	function w.run(seconds: number)
		for _ = 1, math.floor(seconds / TICK + 0.5) do
			w.now += TICK
			w.flow.pursuit:step(TICK)
			w.flow.beat()
		end
	end
	function w.runUntil(done: () -> boolean, maxSeconds: number): boolean
		local waited = 0
		while not done() and waited < maxSeconds do
			w.run(TICK)
			waited += TICK
		end
		return done()
	end
	-- A joined player, free, who has not seen that line's code (so may enter it).
	function w.enterer(stationId: string, except: number?): any
		local line = w.flow.board:get(stationId)
		for _, p in w.roster do
			if p.UserId ~= except and not line.seenBy[p.UserId] and not w.flow.line:isConnected(p.UserId) then
				return p
			end
		end
		return nil
	end
	-- Restore a line the honest way: walk up, open the keypad, enter the code.
	function w.restore(stationId: string): any
		local p = w.enterer(stationId)
		p.stand(STATION_AT[stationId])
		w.flow.openStation(p, STATION[stationId])
		w.now += 1
		w.flow.submit(p, stationId, w.flow.board:get(stationId).answer)
		return p
	end
	table.insert(worlds, w)
	return w
end

local function fourPlayers(w: any): { any }
	return {
		w.join(1, "Ana", ROOMS.board),
		w.join(2, "Bo", ROOMS.board),
		w.join(3, "Cy", ROOMS.archive),
		w.join(4, "Dee", ROOMS.archive),
	}
end

local function wrongCode(answer: string): string
	return if answer == "11" then "12" else "11"
end

local function arrived(w: any): () -> boolean
	return function()
		return w.flow.pursuit.state == "arrived"
	end
end

-- A spy on one of the flow's objects: keeps every call's arguments.
local function spy(object: any, method: string): { calls: { { any } } }
	local real = object[method]
	local record = { calls = {} }
	object[method] = function(self: any, ...: any)
		table.insert(record.calls, { ... })
		return real(self, ...)
	end
	return record
end

--------------------------------------------------------------------------------
print("the flow builds on a fake host, and players join")
do
	local w = world()
	check("(guard) the flow builds", w.flow ~= nil and w.flow.beat ~= nil)
	local players = fourPlayers(w)
	local everyone = true
	for _, p in players do
		everyone = everyone and #w.sent("Objectives", p.UserId) > 0
	end
	check("every player who joins is sent their own panel", everyone)
	local held = true
	for _, station in Round.STATIONS do
		local holder = w.flow.board:get(station.id).holder
		held = held and holder ~= nil and holder >= 1 and holder <= 4
	end
	check("every line is dealt to a player who is here", held)
	local asked, live = w.flow.operator.liveCodes(), w.flow.board:liveCodes()
	local same = next(live) ~= nil
	for concept, code in live do
		same = same and asked[concept] == code
	end
	check("the Operator is asked for exactly the board's live codes", same)
	check("the Operator is given the route through the building", w.flow.pursuit.routeFor == Layout.route)
end

--------------------------------------------------------------------------------
print("")
print("prompts")
do
	local w = world()
	local players = fourPlayers(w)
	local greeted = w.said(Round.LINES.greeting, 1)
	local panels = #w.sent("Objectives", 1)
	w.flow.readerPrompt(players[1])
	check("the card index greets that player, and only that player", w.said(Round.LINES.greeting, 1) == greeted + 1)
	check("...and shows them their own panel", #w.sent("Objectives", 1) == panels + 1)
	w.flow.openStation(players[3], STATION.breaker)
	check("a station prompt seats the player at that keypad, on the server", w.flow.desk:openedBy(3) == "breaker")
	local opened = w.last("OpenBoard", 3)
	check(
		"...and opens that keypad on that player's screen",
		opened ~= nil and opened.args[1] == "breaker" and opened.args[2] == STATION.breaker.actionText
	)
	w.flow.openStation(players[3], STATION.board)
	check("reaching a second station gives up the first", w.flow.desk:openedBy(3) == "board")
end

--------------------------------------------------------------------------------
print("")
print("a submission")
do
	local w = world()
	fourPlayers(w)
	local line = w.flow.board:get("breaker")
	local p = w.enterer("breaker")
	local quiet = #w.sent("Rejected", p.UserId) + w.said(Round.LINES.busy, p.UserId)
	w.flow.submit(p, 5, "42")
	w.flow.submit(p, "breaker", {})
	w.flow.submit(p, string.rep("b", 500), "42")
	check(
		"a malformed submission is dropped before anything else",
		#w.sent("Rejected", p.UserId) + w.said(Round.LINES.busy, p.UserId) == quiet and not line.solved
	)

	p.stand(STATION_AT.breaker)
	w.now += 1
	w.flow.submit(p, "breaker", line.answer)
	local refused = w.last("Rejected", p.UserId)
	check(
		"a code at a keypad the player never opened is refused on their own channel",
		refused ~= nil and refused.args[1] == "breaker" and not line.solved
	)
	check("...and the Operator tells that player the line is busy", w.said(Round.LINES.busy, p.UserId) == 1)

	w.flow.openStation(p, STATION.breaker)
	p.stand(ROOMS.board)
	w.now += 1
	local notes = #w.sent("Rejected", p.UserId)
	w.flow.submit(p, "breaker", line.answer)
	check(
		"a player who walked away from the keypad is refused (where they stand, not a remembered prompt)",
		#w.sent("Rejected", p.UserId) == notes + 1 and not line.solved
	)
	check("...without being accused aloud", w.said(Round.LINES.busy, p.UserId) == 1)
	check("...and the refusal does not count as a miss", line.misses[p.UserId] == nil)

	p.stand(STATION_AT.breaker)
	w.now += 1
	w.flow.submit(p, "breaker", wrongCode(line.answer))
	local dead = w.last("Rejected", p.UserId)
	check(
		"a wrong code is refused on that player's own channel",
		dead ~= nil and dead.args[1] == "breaker" and dead.args[2] == "that line is dead"
	)
	check("...and the Operator says the line is busy to that player alone", w.said(Round.LINES.busy, p.UserId) == 2)
	check("...not to everyone", w.said(Round.LINES.busy, "all") == 0)
	local before = #w.sent("Rejected", p.UserId)
	w.flow.submit(p, "breaker", wrongCode(line.answer))
	check("a second submission inside the cooldown is dropped", #w.sent("Rejected", p.UserId) == before)

	w.now += 1
	w.flow.submit(p, "breaker", wrongCode(line.answer))
	check(
		"past the free wrong dial, a wrong code rings through to everyone",
		w.said(Round.LINES.wrongParty, "all") == 1
	)
	check(
		"...and the Operator walks to that station's room",
		w.flow.pursuit.targetName == Layout.stationRoom("breaker")
	)
	w.now += 1
	w.flow.submit(p, "breaker", wrongCode(line.answer))
	local jammed = w.last("Rejected", p.UserId)
	check(
		"the third miss jams the line for that player",
		jammed ~= nil and string.find(jammed.args[2], "jammed", 1, true) ~= nil
	)
	w.now += 1
	w.flow.submit(p, "breaker", line.answer)
	check("...and the right code waits out the jam (the board is given the clock)", not line.solved)
	w.now += Config.LockoutSeconds
	w.flow.submit(p, "breaker", line.answer)
	check("once the jam has passed, the right code restores the line", line.solved)

	local other = w.enterer("breaker", p.UserId)
	other.stand(STATION_AT.breaker)
	w.flow.openStation(other, STATION.breaker)
	w.now += 1
	local accused = w.said(Round.LINES.busy, other.UserId)
	w.flow.submit(other, "breaker", line.answer)
	local note = w.last("Rejected", other.UserId)
	check("a code for a line already restored gets the keypad note", note ~= nil and note.args[2] == "already restored")
	check("...but no accusation", w.said(Round.LINES.busy, other.UserId) == accused)

	w.flow.round:finish("lost", w.now)
	local board = w.flow.board:get("board")
	local late = w.enterer("board")
	late.stand(STATION_AT.board)
	w.flow.openStation(late, STATION.board)
	w.now += 1
	w.flow.submit(late, "board", board.answer)
	check("a finished round takes no more answers", not board.solved)
end

--------------------------------------------------------------------------------
print("")
print("a restore teaches the Operator")
do
	local w = world()
	fourPlayers(w)
	local credit = spy(w.flow.operator, "credit")
	local creditCode = spy(w.flow.operator, "creditCode")
	local line = w.flow.board:get("board")
	local answer, holder = line.answer, line.holder
	w.restore("board")
	check("(guard) the line is restored", line.solved)
	check(
		"a restore credits the Operator once, with the line's concept and the time",
		#credit.calls == 1 and credit.calls[1][1] == line.concept and credit.calls[1][2] == w.now
	)
	check(
		"...and teaches the counting learner what the code was said as, from its holder",
		#creditCode.calls == 1
			and creditCode.calls[1][1] == answer
			and creditCode.calls[1][2] == w.now
			and creditCode.calls[1][3] == holder
	)
	local pushed = true
	for id = 1, 4 do
		pushed = pushed and #w.sent("Objectives", id) >= 2
	end
	check("...and every panel is pushed", pushed)
	check("a line that is not the last leaves the round going", w.flow.round:isPlaying())
	check("...and the way out shut", not w.flow.escape:isOpen())
end

--------------------------------------------------------------------------------
print("")
print("the last line opens the way out, and getting out wins")
do
	local w = world()
	local players = fourPlayers(w)
	w.restore("board")
	w.restore("breaker")
	w.restore("latch")
	check("the last line opens the way out", w.flow.escape:isOpen())
	check("...rings, said to everyone", w.said(Round.LINES.ringing, "all") == 1)
	check("...and does not end the round by itself", w.flow.round:isPlaying())
	w.run(Config.CallRingSeconds + TICK)
	check("once the call has rung the Operator is sent for the way out", w.flow.pursuit.targetName == Escape.ROOM)
	for _, p in players do
		p.stand(ROOMS.lobby)
	end
	w.run(TICK * 2)
	check("everyone free in the lobby wins the round", w.flow.round.outcome == "won")
	check("...said with its own line", w.said(Round.LINES.completed, "all") == 1)
	check(
		"...and winning, being found and losing are three different lines",
		Round.LINES.completed ~= Round.LINES.taken
			and Round.LINES.completed ~= Round.LINES.lost
			and Round.LINES.taken ~= Round.LINES.lost
	)
end

--------------------------------------------------------------------------------
do
	-- The call rings and the Operator reaches the lobby first; then they walk in.
	local w = world()
	local players = fourPlayers(w)
	w.restore("board")
	w.restore("breaker")
	w.restore("latch")
	check(
		"(guard) it reaches the lobby before anyone",
		w.runUntil(function()
			return w.flow.pursuit.state == "arrived" and w.flow.pursuit.targetName == Escape.ROOM
		end, 90)
	)
	for _, p in players do
		p.stand(ROOMS.lobby)
	end
	w.run(TICK)
	check(
		"the Operator waiting in the lobby takes whoever walks in, rather than letting them out",
		w.flow.line:count() == 4
	)
	check("...so the round is lost, not won", w.flow.round.outcome == "lost")
end

print("")
print("being taken, and the loss")
do
	local w = world()
	local players = fourPlayers(w)
	w.flow.pursuit:sendTo("board")
	check("(guard) the Operator reaches the board room", w.runUntil(arrived(w), 60))
	check("arriving is announced to everyone", w.said(Round.LINES.taken, "all") >= 1)
	check("everyone in that room is taken", w.flow.line:isConnected(1) and w.flow.line:isConnected(2))
	check("...and nobody outside it", not w.flow.line:isConnected(3) and not w.flow.line:isConnected(4))
	check(
		"each is told privately that they are on the line",
		w.said(Round.LINES.onTheLine, 1) == 1
			and w.said(Round.LINES.onTheLine, 2) == 1
			and w.said(Round.LINES.onTheLine, 3) == 0
	)
	local switched = w.last("Connected", 1)
	check("...and their screen switched to 'on the line'", switched ~= nil and switched.args[1] == true)
	check("a taken player is no longer chased for silence", w.flow.supervisor:quietFor(1, w.now) == nil)
	players[3].stand(ROOMS.board)
	w.run(TICK)
	check("a player who walks in while it waits is taken on the next beat", w.flow.line:isConnected(3))
end
do
	local w = world()
	local players = fourPlayers(w)
	for _, p in players do
		w.flow.line:connect(p.UserId, w.now)
	end
	w.run(TICK)
	check("everyone taken ends the round, lost", w.flow.round.outcome == "lost")
	check("...said once, with the loss's own line", w.said(Round.LINES.lost, "all") == 1)
	local phase = w.last("Phase", "all")
	check(
		"...the phase is pushed to everyone",
		phase ~= nil and phase.args[1].playing == false and phase.args[1].outcome == "lost"
	)
	check("...and the Operator stops", w.flow.pursuit.state == "idle")
	w.run(TICK * 4)
	check("a round already over is not ended again", w.said(Round.LINES.lost, "all") == 1)
end
do
	-- A line nobody free may enter: its holder is the only one left.
	local w = world()
	fourPlayers(w)
	local holder = w.flow.board:get("latch").holder
	for id = 1, 4 do
		if id ~= holder then
			w.flow.line:connect(id, w.now)
		end
	end
	w.run(TICK)
	check("a round nobody free can finish is lost on the beat", w.flow.round.outcome == "lost")
end
do
	-- It waits in a room; the round ends; somebody walks in.
	local w = world()
	local players = fourPlayers(w)
	players[1].stand(ROOMS.archive)
	players[2].stand(ROOMS.archive)
	w.flow.pursuit:sendTo("board")
	check("(guard) it waits in an empty board room", w.runUntil(arrived(w), 60) and w.flow.line:count() == 0)
	w.flow.round:finish("lost", w.now)
	players[1].stand(ROOMS.board)
	w.run(TICK)
	check("a finished round is not a hunting ground: nobody is taken", not w.flow.line:isConnected(1))
end

--------------------------------------------------------------------------------
print("")
print("the beat")
do
	local w = world()
	for _, p in fourPlayers(w) do
		p.stand(ROOMS.archive)
	end
	w.flow.pursuit:sendTo("lobby")
	w.runUntil(function()
		return w.flow.pursuit.state == "approaching" or w.flow.pursuit.state == "closing"
	end, 60)
	w.flow.pursuit:sendTo("board") -- heard while it closes on the lobby: queued
	check("(guard) it waits in the empty lobby", w.runUntil(arrived(w), 60) and w.flow.pursuit.targetName == "lobby")
	w.run(Config.LingerSeconds + 1)
	check(
		"left waiting in an empty room, it gives the room up after the linger, and says so",
		w.said(Round.LINES.givingUp, "all") == 1
	)
	local after = w.last("Holding", "all")
	check(
		"...and the panel stops saying it waits there (the beat tells it last)",
		after ~= nil and after.args[1] == nil
	)
	check(
		"a room it heard about while busy is taken up once it is idle",
		w.runUntil(function()
			return w.flow.pursuit.targetName == "board"
		end, 60)
	)
end
do
	local w = world()
	local players = fourPlayers(w)
	local cool = spy(w.flow.operator, "coolRound")
	w.run(10)
	check("the Operator does not forget on the clock within a round", #cool.calls == 0)
	for _, p in players do
		w.flow.line:connect(p.UserId, w.now)
	end
	w.run(TICK)
	check("(guard) the round is over", w.flow.round:isOver())
	local greetings = w.said(Round.LINES.greeting, "all")
	w.run(Config.IntermissionSeconds + TICK * 2)
	check("after the intermission the next round begins", w.flow.round.number == 2 and w.flow.round:isPlaying())
	check(
		"...the Operator forgets once, as the round begins",
		#cool.calls == 1 and cool.calls[1][1] == Config.CoolPerRound
	)
	check("...it is sent back to its post", w.flow.pursuit.position.x == POST.x and w.flow.pursuit.position.z == POST.z)
	check("...nobody is on the line", w.flow.line:count() == 0)
	local released = true
	for _, p in players do
		local last = w.last("Connected", p.UserId)
		released = released and last ~= nil and last.args[1] == false
	end
	check("...everyone's screen says they are off the line", released)
	local fresh = true
	for _, station in Round.STATIONS do
		local line = w.flow.board:get(station.id)
		fresh = fresh and not line.solved and line.holder ~= nil
	end
	check("...the board is dealt again, nothing restored", fresh)
	check("...and the greeting is said", w.said(Round.LINES.greeting, "all") == greetings + 1)
end
do
	local w = world()
	local players = fourPlayers(w)
	w.flow.openStation(players[1], STATION.board)
	for _, p in players do
		w.flow.line:connect(p.UserId, w.now)
	end
	w.run(TICK + Config.IntermissionSeconds + TICK * 2)
	check("a new round leaves no keypad open", w.flow.desk:openedBy(1) == nil)
end

--------------------------------------------------------------------------------
do
	local w = world()
	local players = fourPlayers(w)
	w.flow.hearChat(players[1], "the purple lantern")
	w.restore("board")
	w.restore("breaker")
	w.restore("latch")
	check("(guard) the way out is open", w.flow.escape:isOpen())
	w.flow.hearChat(players[2], "the green umbrella")
	for _, p in players do
		w.flow.line:connect(p.UserId, w.now)
	end
	w.run(TICK + Config.IntermissionSeconds + TICK * 2)
	check("(guard) a new round began", w.flow.round.number == 2)
	check("a new round shuts the way out again", not w.flow.escape:isOpen())
	check("...restarts everyone's silence clock", (w.flow.supervisor:quietFor(1, w.now) :: number) < 1)
	check("...and forgets what it overheard last round", #w.flow.operator.observations == 0)
end

print("")
print("chat")
do
	local w = world()
	local players = fourPlayers(w)
	local hears = spy(w.flow.operator, "hear")
	local credits = spy(w.flow.operator, "credit")
	local creditCodes = spy(w.flow.operator, "creditCode")
	w.flow.readerPrompt(players[1])
	w.flow.openStation(players[3], STATION.board)
	w.now += 1
	w.flow.submit(players[3], "board", "00")
	w.run(2)
	check("nothing but chat feeds the Operator", #hears.calls == 0)
	check(
		"nothing but a restore credits it (prompts, a wrong code, the beat)",
		#credits.calls == 0 and #creditCodes.calls == 0
	)
	w.now += 1
	w.flow.hearChat(players[1], "the jack on the switchboard")
	check("chat feeds it", #hears.calls == 1)
	check("...and plain talk about a station sends it there", w.flow.pursuit.targetName == "board")
	check("...saying it understood, to everyone", #w.sent("Heard", "all") > 0)
	check("speaking resets that player's silence clock", w.flow.supervisor:quietFor(1, w.now) == 0)
	w.flow.round:finish("lost", w.now)
	w.flow.hearChat(players[2], "the breaker in the archive")
	check("while no round is being played it is not listening", #hears.calls == 1)
end

--------------------------------------------------------------------------------
print("")
print("silence")
do
	local w = world()
	local players = fourPlayers(w)
	local pushes = 0
	local lastBand = nil
	local rightWords = true
	for _ = 1, math.floor((Config.SpeakEvery - 1) / TICK) do
		for i = 2, 4 do
			w.flow.hearChat(players[i], "ok")
		end
		w.run(TICK)
		local told = w.sent("Silence", 1)
		if #told > pushes then
			pushes = #told
			local s = told[#told]
			local quiet = w.flow.supervisor:quietFor(1, w.now) :: number
			local band = s.args[1]
			rightWords = rightWords
				and band ~= lastBand
				and s.args[2] == Silence.pressure(quiet)
				and s.args[3] == Silence.note(band)
				and s.args[4] == Silence.secondsLeft(quiet)
			lastBand = band
		end
	end
	check(`a quiet player is told their own silence ({pushes} pushes)`, pushes >= 2)
	check("...only when its band changes, in Shared.Silence's words, fill and time left", rightWords)
	check("...and it is never broadcast", #w.sent("Silence", "all") == 0)
	w.run(4)
	check(
		"a player silent past the deadline has their line put through, said once",
		w.said(Round.LINES.traced, "all") == 1
	)
	check("...and the Operator is sent to their room", w.flow.pursuit.targetName == "board")
end

--------------------------------------------------------------------------------
print("")
print("codes said aloud")
do
	local w = world()
	fourPlayers(w)
	local line = w.flow.board:get("board")
	local code = line.answer
	local panels = #w.sent("Objectives", line.holder)
	w.flow.hearChat(w.player(line.holder), `mine is {code}`)
	check("a code said aloud is spent: the line gets a new code", line.answer ~= code)
	check("...the holder's panel is pushed with it", #w.sent("Objectives", line.holder) > panels)
	check("...and the Operator reads it back to everyone, in digits", w.said(Round.readBack(code), "all") == 1)
end

--------------------------------------------------------------------------------
print("")
print("where the Operator is waiting")
do
	local w = world()
	fourPlayers(w)
	local joined = #w.sent("Holding", "all")
	w.run(2)
	check("nothing is sent while nothing changes", #w.sent("Holding", "all") == joined)
	w.flow.pursuit:sendTo("board")
	w.runUntil(arrived(w), 60)
	w.run(TICK)
	local s = w.last("Holding", "all")
	local expected = Round.holding(w.flow.pursuit.state, w.flow.pursuit.targetName, Escape.ROOM)
	check(
		"where it waits is sent to everyone, from its own state",
		#w.sent("Holding", "all") > joined
			and expected ~= nil
			and s ~= nil
			and s.args[1] ~= nil
			and s.args[1].label == expected.label
			and s.args[1].wayOut == expected.wayOut
	)
	local count = #w.sent("Holding", "all")
	w.run(1)
	check("...and not again while it waits", #w.sent("Holding", "all") == count)
	w.join(5, "Eve", ROOMS.lobby)
	check("...but told again to a player who joins", #w.sent("Holding", "all") == count + 1)
end

--------------------------------------------------------------------------------
print("")
print("the Lexicon panel shows only filtered words")
do
	local masked = {
		FilterStringAsync = function(_self: any, text: string, _authorId: number): any
			if string.find(text, "cursed", 1, true) then
				error("the filter service is down")
			end
			return {
				GetNonChatStringForBroadcastAsync = function(_result: any): string
					if string.find(text, "blank", 1, true) then
						return ""
					end
					return string.rep("#", #text)
				end,
			}
		end,
	}
	local w = world(masked)
	fourPlayers(w)
	local line = w.flow.board:get("board")
	local holder = w.player(line.holder)
	w.flow.hearChat(holder, "the blue kettle")
	w.flow.hearChat(holder, "a cursed teapot")
	w.flow.hearChat(holder, "a blank page")
	w.restore("board")
	local sent = w.last("LexiconUpdated", "all")
	local rows = if sent then sent.args[1] else {}
	check(`(guard) the panel was sent after a restore ({#rows} rows)`, #rows > 0)
	local clean, labelled = true, true
	for _, row in rows do
		clean = clean
			and row.phrase ~= ""
			and not string.find(row.phrase, "kettle", 1, true)
			and not string.find(row.phrase, "teapot", 1, true)
			and not string.find(row.phrase, "page", 1, true)
		labelled = labelled and row.leadsTo ~= nil
	end
	check("no phrase reaches the panel unfiltered, failed or blanked", clean)
	check("...and every row says where its word leads", labelled)
	check(
		"the panel is only ever sent to everyone at once",
		#w.remotes.LexiconUpdated.sent == #w.sent("LexiconUpdated", "all")
	)
end

--------------------------------------------------------------------------------
print("")
print("a player leaving")
do
	local w = world()
	fourPlayers(w)
	local boardHolder = w.flow.board:get("board").holder
	local jammer = w.enterer("latch", boardHolder)
	jammer.stand(STATION_AT.latch)
	w.flow.openStation(jammer, STATION.latch)
	local latch = w.flow.board:get("latch")
	for _ = 1, 3 do
		w.now += 1
		w.flow.submit(jammer, "latch", wrongCode(latch.answer))
	end
	check("(guard) the jammer jammed the latch", latch.jammedUntil[jammer.UserId] ~= nil)

	local leaver = w.player(boardHolder)
	w.flow.openStation(leaver, STATION.board)
	w.flow.line:connect(leaver.UserId, w.now)
	w.leave(leaver)
	check("a player who leaves is forgotten by the supervisor", w.flow.supervisor:quietFor(leaver.UserId, w.now) == nil)
	check("...by the line", not w.flow.line:isConnected(leaver.UserId))
	check("...and by the desk", w.flow.desk:openedBy(leaver.UserId) == nil)
	local board = w.flow.board:get("board")
	check(
		"their unrestored line goes to someone still here",
		board.holder ~= leaver.UserId and w.player(board.holder) ~= nil
	)
	w.leave(jammer)
	w.join(jammer.UserId, jammer.Name, STATION_AT.latch)
	check("a jam is not shed by leaving and coming back", latch.jammedUntil[jammer.UserId] ~= nil)
end

--------------------------------------------------------------------------------
print("")
print("what may be broadcast")
local private = true
local broadcastPhase = false
for _, w in worlds do
	for _, name in PRIVATE do
		private = private and #w.sent(name, "all") == 0
	end
	broadcastPhase = broadcastPhase or #w.sent("Phase", "all") > 0
end
check(`a player's own remotes are never broadcast ({table.concat(PRIVATE, ", ")})`, private)
check("(control) Phase really is broadcast, so the sweep is not vacuous", broadcastPhase)

print("")
local failures = Guard.failures()
check(`nothing the flow ran threw ({#failures})`, #failures == 0)
for _, f in failures do
	print(`  [{f.tag}] {f.message}`)
end

Kit.finish()
