--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: state that only accumulates.
--
-- R46, R47 and R48 were each found by simulating a session by hand, and none of
-- them was visible to any rule-level test in this suite:
--   R46  the Operator can never learn — two credits a round against four needed
--   R47  five joins and no line can be patched by anybody
--   R48  three captures and the round ends neither way, forever
-- All three are the same family: `seenBy` grew, `held` grew, heat only fell,
-- and none had a path back. A rule read in isolation looks right every time.
--
-- So this drives the whole server loop the way `init.server` drives it — rounds
-- cycling, players joining and leaving, chatter, giveaways, captures, patching
-- — and asserts the invariants those three rounds established, every tick.
--
-- IT IS WIRED LIKE THE SERVER OR IT IS NOT EVIDENCE. The first draft called
-- `board:submit` directly and so never ran `board.onSolved`, where the server
-- calls `operator:credit`; the Lexicon stayed empty for 1500 simulated seconds
-- and it looked like a finding. It was the harness.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Objectives = rt.require(rt.systems.Objectives)
local Connected = rt.require(rt.systems.Connected)
local Lifecycle = rt.require(rt.systems.Lifecycle)
local Operator = rt.require(rt.systems.Operator)
local Pursuit = rt.require(rt.systems.Pursuit)
local Round = rt.require(rt.systems.Round)
local Supervisor = rt.require(rt.systems.Supervisor)
local Silence = rt.require(rt.shared.Silence)
local Layout = rt.require(rt.shared.Layout)
local Config = rt.require(rt.shared.Config)

local failures = 0
local checks = 0
local function check(name: string, condition: boolean)
	checks += 1
	if not condition then
		failures += 1
		print(`  FAIL  {name}`)
	else
		print(`  ok    {name}`)
	end
end

export type Report = {
	rounds: number,
	won: number,
	lost: number,
	unfinishableTicks: number,
	worstSeen: number,
	worstLexicon: number,
	stuckRejoins: number,
}

-- The soak's OWN answer to "can anybody still finish anything", computed from
-- the raw board rather than by calling `Objectives.anyFinishable`.
--
-- The first version used the module. Planting R48's defect then passed, because
-- breaking `anyFinishable` blinded the game's check and this measurement at the
-- same time: the instrument and the thing it measures shared an implementation.
-- A second opinion has to be a second implementation.
local function anybodyCouldFinish(board, able: { number }): boolean
	for _, objective in board.list do
		if objective.solved then
			continue
		end
		for _, userId in able do
			if objective.seenBy[userId] == nil then
				return true
			end
		end
	end
	return false
end

-- `rejoinEvery` models the thing R47 tripped over: one player with a bad
-- connection, whose every return fires `PlayerAdded` and re-deals the board.
-- `takeAllButOne` is R48's shape: the Operator takes everyone in the room,
-- and R23 made that everyone. A gentler soak never strands a line at all, so it
-- cannot exercise the stranded-loss rule -- the first version of this file
-- passed with that rule deleted, for exactly that reason.
-- SEEDS. `Round.dealSecrets` shuffles with `math.random`, and nothing seeded
-- it, so every run of this file was a different game. Measured on identical
-- code, three runs of the harsh soak stranded 6, 7 and 13 rounds.
--
-- That is worse than a model wired wrong. A wired-wrong model gives you the same
-- wrong answer every time and can be caught; a seedless one gives a different
-- answer every time and lets you keep the run that agrees with you. R60's
-- headline table -- 7 stranded by array index, 10 by `reachedInRoom`, 15 once it
-- also stopped on a loss -- was three single runs of a simulation whose spread
-- on unchanged code is 6 to 13. The fix was right; the numbers arguing for it
-- were not measurements.
--
-- So every scenario runs across all of these, and the checks below are made
-- against the WORST and the TOTAL rather than against one session.
local SEEDS = { 1, 7, 19, 42, 101, 2024, 31337 }

local function soak(ticks: number, rejoinEvery: number, takeAllButOne: boolean, seed: number): Report
	math.randomseed(seed)
	local rooms = { board = Layout.boardCentre(), archive = Layout.archiveCentre() }
	local secrets = Round.dealSecrets(3)

	local board = Objectives.new()
	for _, station in Round.STATIONS do
		board:add(station.id, station.concept, station.prompt)
	end
	local line = Connected.new()
	local round = Lifecycle.new()
	local operator = Operator.new(secrets)
	local pursuit = Pursuit.new(rooms, Layout.operatorPost())
	operator.onUnderstood = function(_concept: string, payload: string)
		pursuit:sendTo(payload)
	end

	local present = { 1, 2, 3, 4 }
	local nextId = 5
	board:deal(present)

	-- WHERE everybody is standing, because the server catches people by asking
	-- `Connected.reachedInRoom` which players are inside the room the Operator
	-- arrived in. The soak used to take the first N entries of `present`, so the
	-- Operator's position did not enter into it and R23 -- "it takes the ROOM,
	-- not a circle around it" -- was never exercised here.
	--
	-- `takeAllButOne` used to be an index trick. It is now a PLACE: everybody but
	-- the last player stands in the board room, so one arrival takes all of them
	-- and strands whatever line the survivor is holding. That is R48's shape,
	-- produced by where people are rather than by arithmetic on an array.
	local standing: { [number]: { x: number, z: number } } = {}
	local function placeEveryone()
		for index, userId in present do
			if takeAllButOne then
				standing[userId] = if index == #present then rooms.archive else rooms.board
			else
				standing[userId] = if index % 2 == 0 then rooms.archive else rooms.board
			end
		end
	end
	placeEveryone()

	local report: Report = {
		rounds = 0,
		won = 0,
		lost = 0,
		unfinishableTicks = 0,
		worstSeen = 0,
		worstLexicon = 0,
		stuckRejoins = 0,
	}
	local now = 0

	local function ableNow(): { number }
		local able: { number } = {}
		for _, userId in present do
			if not line:isConnected(userId) then
				table.insert(able, userId)
			end
		end
		return able
	end

	for tick = 1, ticks do
		now += Config.TickSeconds

		if tick % 8 == 0 then
			operator:hear({ speaker = { UserId = present[1] } :: any, text = "meet me by the purple lantern", at = now })
		end
		if tick % 40 == 0 then
			operator:hear({
				speaker = { UserId = present[1] } :: any,
				text = `check the {secrets[1].plain[1]}`,
				at = now,
			})
		end

		pursuit:step(Config.TickSeconds)
		pursuit:takePending()

		if round:isPlaying() and pursuit.state == "arrived" then
			-- `takeWhoeverIsHere`, as the server runs it.
			for _, userId in line:reachedInRoom(pursuit.position, standing, Layout.halfRoom()) do
				line:connect(userId, now)
			end
			local able = ableNow()
			local stranded = #present > 0 and not board:allSolved() and not board:anyFinishable(able)
			if (line:allTaken(present) or stranded) and round:finish("lost", now) then
				report.lost += 1
				-- The server stops it hunting once there is nobody left to hunt;
				-- leaving it travelling would keep the hum going over a finished
				-- round. The soak cannot hear a hum, but it must not model a
				-- monster still walking through an intermission either.
				pursuit:stop()
			end
		end

		-- The server asks on every beat now, not only on arrival (R49).
		if round:isPlaying() then
			local able = ableNow()
			local strandedNow = #present > 0
				and not board:allSolved()
				and line:count() > 0
				and not board:anyFinishable(able)
			if (line:allTaken(present) or strandedNow) and round:finish("lost", now) then
				report.lost += 1
			end
		end

		if pursuit:shouldLeave(Config.LingerSeconds) then
			pursuit:withdrawTo(Layout.operatorPost())
		end

		if round:isPlaying() and tick % 260 == 0 then
			for _, objective in board.list do
				if objective.solved then
					continue
				end
				for _, userId in present do
					if not line:isConnected(userId) and not objective.seenBy[userId] then
						-- Through submit, and then the credit `board.onSolved` does.
						if board:submit(objective.id, userId, objective.answer, now).ok then
							operator:credit(objective.concept, now)
						end
						break
					end
				end
			end
			if board:allSolved() and round:finish("won", now) then
				report.won += 1
			end
		end

		-- A player rejoining. Every return re-deals the whole board.
		if rejoinEvery > 0 and tick % rejoinEvery == 0 then
			board:deal(present)
			if not anybodyCouldFinish(board, ableNow()) and not board:allSolved() then
				report.stuckRejoins += 1
			end
		end

		if round:readyToRestart(now, Config.IntermissionSeconds) and round:restart() then
			report.rounds += 1
			board:reset()
			line:clear()
			operator:forgetObservations()
			pursuit:sendHome(Layout.operatorPost())
			if report.rounds % 3 == 0 then
				table.insert(present, nextId)
				nextId += 1
				if #present > 6 then
					local gone = table.remove(present, 1)
					if gone then
						standing[gone] = nil
					end
				end
			end
			-- Somebody who joined has to stand somewhere, or they are never in any
			-- room and cannot be caught at all -- which would quietly turn the
			-- harsh soak into the gentle one as the server filled up.
			placeEveryone()
			board:deal(present)
		end

		operator:decay(now)

		for _, objective in board.list do
			local seen = 0
			for _ in objective.seenBy do
				seen += 1
			end
			report.worstSeen = math.max(report.worstSeen, seen)
		end
		report.worstLexicon = math.max(report.worstLexicon, #operator:snapshot())

		if round:isPlaying() and not board:allSolved() and not anybodyCouldFinish(board, ableNow()) then
			report.unfinishableTicks += 1
		end
	end

	return report
end

-- Every seed, folded into one report by taking the WORST of each measure. An
-- invariant that holds on six seeds and breaks on the seventh is broken.
local function acrossSeeds(ticks: number, rejoinEvery: number, takeAllButOne: boolean): Report
	local total: Report = {
		rounds = 0,
		won = 0,
		lost = 0,
		unfinishableTicks = 0,
		worstSeen = 0,
		worstLexicon = 0,
		stuckRejoins = 0,
	}
	for _, seed in SEEDS do
		local one = soak(ticks, rejoinEvery, takeAllButOne, seed)
		total.rounds += one.rounds
		total.won += one.won
		total.lost += one.lost
		total.stuckRejoins += one.stuckRejoins
		-- These three are failures, so they ACCUMULATE rather than average: one
		-- bad seed must not be diluted by six good ones.
		total.unfinishableTicks += one.unfinishableTicks
		total.worstSeen = math.max(total.worstSeen, one.worstSeen)
		total.worstLexicon = math.max(total.worstLexicon, one.worstLexicon)
	end
	return total
end

print("the same seed is the same session")

-- The seed line is a claim; this is the check. Two runs of one scenario at one
-- seed must agree in every field. Without it, `math.randomseed` could be
-- deleted, or a second source of randomness added, and the file would go back
-- to reporting a different game every run while still looking seeded.
local twiceA = soak(600, 0, true, 4242)
local twiceB = soak(600, 0, true, 4242)
local differed: { string } = {}
for field, value in twiceA :: any do
	if (twiceB :: any)[field] ~= value then
		table.insert(differed, `{field} {value} vs {(twiceB :: any)[field]}`)
	end
end
check(`(guard) the sample session did something ({twiceA.rounds} rounds)`, twiceA.rounds > 0)
check(`the same seed replays exactly ({#differed} fields differed)`, #differed == 0)
if #differed > 0 then
	print(`        {table.concat(differed, ", ")}`)
end

-- (control) a DIFFERENT seed must produce a different session, or the seed is
-- being ignored and the check above passes for the wrong reason.
local other = soak(600, 0, true, 99)
local anyDifference = false
for field, value in twiceA :: any do
	if (other :: any)[field] ~= value then
		anyDifference = true
	end
end
check("(control) a different seed is a different session", anyDifference)

print("a server's whole life")
local long = acrossSeeds(1200, 0, false)
check(`(guard) the soak actually played rounds ({long.rounds})`, long.rounds >= 5)
check(`(guard) and players were caught in them ({long.won} won, {long.lost} lost)`, long.won + long.lost >= 5)

-- R48: a live round must always be finishable by somebody, or it ends.
check(`no live round is ever unfinishable ({long.unfinishableTicks} ticks)`, long.unfinishableTicks == 0)

-- R47: the seen set must not grow with the size of the server.
check(`the seen set stays bounded ({long.worstSeen} readers per line)`, long.worstSeen <= 2)

-- R46 is a FILED gap, not a fixed one, so it is recorded rather than asserted
-- as correct: nothing burns, and the Lexicon stays small because of it.
check(`(recorded, see R46) the Lexicon never runs away ({long.worstLexicon})`, long.worstLexicon < 200)

print("")
print("a group that never says a word in-game")

-- R54's finding, kept as an invariant rather than as a number in a log entry.
--
-- Before the Supervisor existed, four silent players won 20 rounds in 600
-- simulated seconds, took ZERO captures, and the Operator never left its post.
-- Silence was not merely safe, it won MORE than talking did (20 to 16), and a
-- group on a voice call outside Roblox could pass every answer and play an
-- unopposed fetch quest against a statue.
--
-- No rule-level test could see it: every rule was right on its own. The defect
-- was in what they left out.
local function silentGroup(ticks: number, seed: number): (number, number, boolean)
	math.randomseed(seed)
	local rooms = { board = Layout.boardCentre(), archive = Layout.archiveCentre() }
	local secrets = Round.dealSecrets(3)
	local board = Objectives.new()
	for _, station in Round.STATIONS do
		board:add(station.id, station.concept, station.prompt)
	end
	local line = Connected.new()
	local round = Lifecycle.new()
	local operator = Operator.new(secrets)
	local pursuit = Pursuit.new(rooms, Layout.operatorPost())
	local supervisor = Supervisor.new()
	operator.onUnderstood = function(_concept: string, payload: string)
		pursuit:sendTo(payload)
	end

	local present = { 1, 2, 3, 4 }
	local now = 0
	for _, userId in present do
		supervisor:watch(userId, now)
	end
	board:deal(present)

	-- WHERE each player is standing. The shipped dispatch reads a position and
	-- finds the room containing it; without this the soak was choosing a room by
	-- `userId % #Config.Rooms`, which is not the game.
	--
	-- One of them stands in the corridor on purpose. That is the case the
	-- dispatch cannot serve -- filed in R54 as an owner question, and a soak that
	-- never puts anybody there would report a call rate the game cannot reach.
	-- The corridor player is id 1 deliberately. Nobody here ever speaks, so every
	-- clock runs out together and `overdue` breaks the tie by id -- put them last
	-- and the dispatch serves somebody in a room first and never reaches them, so
	-- the corridor case would go unexercised while looking fine.
	local standing: { [number]: { x: number, z: number } } = {
		[1] = Layout.spawn(),
		[2] = rooms.board,
		[3] = rooms.board,
		[4] = rooms.archive,
	}

	local won, calls, unreachable, announced = 0, 0, 0, 0
	local everMoved = false
	local roundsPlayed, playingTicks, thisRound, longestRound = 0, 0, 0, 0

	for tick = 1, ticks do
		now += Config.TickSeconds

		-- Nobody says anything, ever. `operator:hear` is never called.
		--
		-- The dispatch is the server's, in miniature: everyone stands in a room,
		-- so the longest-quiet player's room is where it is sent.
		if round:isPlaying() then
			-- `putThroughTheSilentLine`, as the server runs it: longest-quiet
			-- first, the room the player is actually standing in, and nothing
			-- forgiven unless the call really goes through (R55).
			for _, userId in supervisor:overdue(now) do
				local at = standing[userId]
				if not at then
					continue
				end
				local found = false
				for _, name in Config.Rooms do
					local centre = rooms[name]
					if centre and Layout.inRoom(centre, at) then
						found = true
						-- `alreadyComing` is the server's second gate: a trip
						-- already under way answers this silence, so the player
						-- is forgiven but nothing new is announced (R55).
						local alreadyComing = pursuit.targetName == name
						local _, onItsWay = pursuit:sendTo(name)
						if onItsWay then
							supervisor:called(userId, now)
							calls += 1
							if not alreadyComing then
								announced += 1
							end
						end
						break
					end
				end
				if found then
					break
				end
				-- In the corridor: no room to send anything to, so this player's
				-- silence goes unanswered and the next overdue player is tried.
				unreachable += 1
			end
		end

		if round:isPlaying() then
			playingTicks += 1
			thisRound += Config.TickSeconds
			longestRound = math.max(longestRound, thisRound)
		else
			thisRound = 0
		end

		pursuit:step(Config.TickSeconds)
		pursuit:takePending()
		if pursuit.state ~= "idle" then
			everMoved = true
		end

		if round:isPlaying() and pursuit.state == "arrived" then
			for _, userId in present do
				line:connect(userId, now)
			end
			if line:allTaken(present) then
				round:finish("lost", now)
			end
		end
		if pursuit:shouldLeave(Config.LingerSeconds) then
			pursuit:withdrawTo(Layout.operatorPost())
		end

		if round:isPlaying() and tick % 260 == 0 then
			for _, objective in board.list do
				if objective.solved then
					continue
				end
				for _, userId in present do
					if not line:isConnected(userId) and not objective.seenBy[userId] then
						if board:submit(objective.id, userId, objective.answer, now).ok then
							operator:credit(objective.concept, now)
						end
						break
					end
				end
			end
			if board:allSolved() and round:finish("won", now) then
				won += 1
			end
		end

		if round:readyToRestart(now, Config.IntermissionSeconds) and round:restart() then
			board:reset()
			line:clear()
			pursuit:sendHome(Layout.operatorPost())
			supervisor:reset(now)
			roundsPlayed += 1
			board:deal(present)
		end
	end

	return won, calls, everMoved, longestRound, roundsPlayed, unreachable, announced
end

local TICKS = 2400 -- 600 simulated seconds, the length that was measured
local _silentWins, calls, moved, longestRound, roundsPlayed, unreachable, announced = silentGroup(TICKS, SEEDS[1])
check(`(guard) the silent run was long enough to matter ({TICKS} ticks)`, TICKS >= 2400)
check(`silence is called out ({calls} calls in {TICKS} ticks)`, calls > 0)
check("the Operator no longer stands still through a silent session", moved)

-- The rate matters as much as the fact. A call every few minutes is not
-- pressure; the deadline says roughly one per player per `SpeakEvery`.
-- A DEADLINE LONGER THAN A ROUND NEVER FIRES. The first version of this block
-- modelled a 30-second round against a 45-second `SpeakEvery` and recorded zero
-- calls -- a dead dial of exactly the kind R6 built its guard for, and invisible
-- to every rule-level test because the rule itself is right.
check(`(guard) rounds were played to measure ({roundsPlayed})`, roundsPlayed >= 3)
check(
	`the deadline is reachable inside a round ({Config.SpeakEvery}s < {string.format("%.0f", longestRound)}s)`,
	Config.SpeakEvery < longestRound
)
-- ...and the warning lands with its lead time still inside the round, or the
-- player is told to speak up at the same moment they are called.
check(
	`...and the warning lands before it, in time ({Config.SpeakWarning}s + {Silence.warningLeadSeconds()}s lead)`,
	Config.SpeakWarning + Silence.warningLeadSeconds() <= longestRound
)

-- The rate matters as much as the fact: one call in ten minutes is not pressure.
-- The floor is what the deadline and the cooldown together imply for a single
-- player, which four players should clear several times over.
local floorCalls = math.floor((TICKS * Config.TickSeconds) / (Config.SpeakEvery + Config.SupervisorCooldown))
check(`...and often enough to be pressure ({calls} >= {floorCalls})`, calls >= floorCalls)

-- R54 filed "the corridor is a place to hide from the Supervisor" as an owner
-- question. This is that question with a number on it: how often a silent player
-- standing in the corridor was reached for and could not be served. It is
-- RECORDED, not asserted to be zero -- whether the corridor should be a refuge
-- is the owner's call, and a test that demanded either answer would be making it.
check(`(recorded, see R54) the corridor cannot be served ({unreachable} attempts)`, unreachable >= 0)
check(`(guard) ...and somebody really did stand there ({unreachable})`, unreachable > 0)

-- R55: every announcement must be a call that really went through, and a trip
-- already under way must not be announced twice. Measured here rather than
-- trusted, because R55 found 116 of 117 announcements were about calls that
-- were never placed.
check(`no silence is announced that was not also a call ({announced} of {calls})`, announced <= calls)
check(`(guard) ...and announcements do happen ({announced})`, announced > 0)

print("")
print("one player with a bad connection")
-- R47's exact shape: every return fires PlayerAdded and re-deals the board.
local churny = acrossSeeds(1200, 25, false)
check(`(guard) it kept playing through the churn ({churny.rounds} rounds)`, churny.rounds >= 5)
check(`rejoining never strands the board ({churny.stuckRejoins} times)`, churny.stuckRejoins == 0)
check(`...and no round is left unfinishable ({churny.unfinishableTicks} ticks)`, churny.unfinishableTicks == 0)
check(`...and the seen set still stays bounded ({churny.worstSeen})`, churny.worstSeen <= 2)

print("")
print("the Operator takes everyone but one")
-- R48's shape. The survivor is always the reader of one of the lines, so that
-- line can be patched by nobody and the round must be DECLARED lost rather than
-- left running. Counted with the soak's own judge, so deleting the game's rule
-- shows up here instead of blinding the measurement.
--
-- A gentler soak cannot exercise this at all: with half the group caught the
-- team still wins every round, nothing is ever stranded, and the first version
-- of this file passed with the stranded-loss rule deleted for that reason.
local harsh = acrossSeeds(1200, 0, true)
check(`(guard) the harsh soak played rounds ({harsh.rounds})`, harsh.rounds >= 3)
check(`(guard) and it really did strand people ({harsh.lost} rounds lost)`, harsh.lost >= 1)
-- At most ONE tick of lag per stranded round: the capture strands it, and the
-- next beat of the server clock ends it. That is the granularity of asking on a
-- tick, not slack in the rule -- which is why the bound is expressed in rounds
-- lost rather than as a number somebody picked.
--
-- Before R49 this check ran only when the Operator ARRIVED, and the same soak
-- measured 134 ticks: about half a minute of a stranded round still running
-- after it had walked away, because nothing looked again until it came back.
check(
	`a stranded round ends within a tick ({harsh.unfinishableTicks} ticks over {harsh.lost} lost rounds)`,
	harsh.unfinishableTicks <= harsh.lost
)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
