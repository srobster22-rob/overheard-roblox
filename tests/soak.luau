--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: state that only accumulates.
--
-- R46, R47 and R48 were each found by simulating a session by hand, and none of
-- them was visible to any rule-level test in this suite:
--   R46  the Operator could never learn — a round cooled more than it taught
--        (closed in R131: forgetting is charged per round)
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
local Escape = rt.require(rt.systems.Escape)

local Kit = require("./kit")
local check = Kit.check

export type Report = {
	rounds: number,
	won: number,
	lost: number,
	unfinishableTicks: number,
	worstSeen: number,
	worstLexicon: number,
	stuckRejoins: number,
	-- How many times the Supervisor actually put a call through DURING THIS
	-- SESSION. A source sweep cannot answer that: R59's and R60's guards check
	-- that the FILE contains the dispatch, and the silent group satisfies them
	-- on its own -- so disabling this session's dispatch left the whole suite
	-- green, which a plant proved. Only the session can say whether it ran.
	silenceCalls: number,
	-- R63. A mutation sweep switched each of the soak's couplings off in turn and
	-- ran the suite. SIX of eight could be disabled with nothing noticing: the
	-- Operator never hearing anybody, nobody ever solving a line, decay off,
	-- queued rooms never taken up, the Operator never giving up a room, and the
	-- board never being reset between rounds.
	--
	-- Every one of those is a system this file claims to model. R62 found the
	-- seventh by luck and answered it with one counter; these are the rest,
	-- measured rather than guessed at. A session that did not exercise a system
	-- is not evidence about it, however green it prints.
	solved: number,
	decayed: number,
	pendingTaken: number,
	gaveUp: number,
	cleanStarts: number,
	everQueued: number,
	queuedDropped: number,
	-- R138: rounds whose last line was restored, opening the way out.
	escapes: number,
}

-- The soak's OWN answer to "can every unsolved line still be entered", computed
-- from the raw board rather than by calling `Objectives.stranded`.
--
-- The first version used the module. Planting R48's defect then passed, because
-- breaking the module blinded the game's check and this measurement at the
-- same time: the instrument and the thing it measures shared an implementation.
-- A second opinion has to be a second implementation.
--
-- R149: EVERY line. This asked whether ANY line could be finished, the same
-- question as the game's rule, so it could not see the round PT4 found: one line
-- nobody free may enter, the round unwinnable while others stay open.
local function everyLineEnterable(board, able: { number }): boolean
	for _, objective in board.list do
		if objective.solved then
			continue
		end
		local someone = false
		for _, userId in able do
			if objective.seenBy[userId] == nil then
				someone = true
			end
		end
		if not someone then
			return false
		end
	end
	return true
end

-- R138: the group's run for the way out. This is the soak's model of PLAYERS,
-- not server logic (the server never knows where anyone means to go): once the
-- call has been ringing `runAfter` seconds, everyone still free stands in the
-- exit room. They arrive together; the soak does not model walking. Called at
-- the TOP of a beat, so the server's order holds: capture before the way out.
local function runForTheExit(escape, present, line, standing, rooms, now, runAfter)
	if escape:isOpen() and escape:openFor(now) >= runAfter then
		for _, userId in present do
			if not line:isConnected(userId) then
				standing[userId] = rooms[Escape.ROOM]
			end
		end
	end
end

-- R138: one beat of the server's `workTheWayOut` -- the escape's own step, then
-- the round's ending. Returns the outcome it settled this beat, if any.
local function workTheWayOut(escape, round, pursuit, present, line, standing, rooms, now): string?
	if not (round:isPlaying() and escape:isOpen()) then
		return nil
	end
	local outcome = escape:step(now, pursuit, present, line, standing, rooms)
	if outcome and round:finish(outcome, now) then
		pursuit:stop()
		return outcome
	end
	return nil
end

-- How long after the call starts ringing the sessions' groups run: well inside
-- the Operator's arrival. The race in tests/escape.luau sweeps the rest.
local RUN_AFTER = 6

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
	local escape = Escape.new()
	operator.onUnderstood = function(_concept: string, payload: string)
		pursuit:sendTo(payload)
	end
	-- THE SUPERVISOR. Without it this session plays the game as it stood before
	-- R54: nobody is ever called for silence, the Operator only moves because
	-- somebody said something, and rounds are quieter and longer than the
	-- shipped game's. Every invariant this file carries -- R46's Lexicon bound,
	-- R47's seen-set bound, R48's stranded-loss rule, R49's unfinishable-tick
	-- count -- was being measured in that other game.
	local supervisor = Supervisor.new()

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
	-- but one. (R111: it does NOT strand the survivor's line -- a caught reader can
	-- still talk -- so this is R48's capture shape, not a stranding; see the
	-- recorded check at the end.)
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

	-- Watched from the moment they are present, never from zero: a clock starting
	-- at zero calls a player before they could have said anything.
	local function watchEveryone(at: number)
		for _, userId in present do
			supervisor:watch(userId, at)
		end
	end
	watchEveryone(0)

	local report: Report = {
		rounds = 0,
		won = 0,
		lost = 0,
		strandedLost = 0,
		unfinishableTicks = 0,
		worstSeen = 0,
		worstLexicon = 0,
		stuckRejoins = 0,
		silenceCalls = 0,
		solved = 0,
		decayed = 0,
		pendingTaken = 0,
		gaveUp = 0,
		cleanStarts = 0,
		everQueued = 0,
		queuedDropped = 0,
		escapes = 0,
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
		runForTheExit(escape, present, line, standing, rooms, now, RUN_AFTER)

		if tick % 8 == 0 then
			-- One utterance, both listeners. The server's chat handler feeds
			-- `supervisor:hear` and `operator:hear` from the same message.
			--
			-- IT ROTATES. Until R62 only `present[1]` ever spoke, which was
			-- harmless while nothing punished silence and pathological the moment
			-- something did: three of four players permanently overdue, the
			-- Operator permanently dispatched, and every round lost. That is the
			-- model being wrong, not the game -- a group where nobody but one
			-- person speaks for a whole session is what `silentGroup` is for.
			--
			-- The LAST player is skipped: a group with one quiet member is
			-- ordinary, and it keeps the Supervisor firing here instead of never.
			local speakers = math.max(1, #present - 1)
			local who = present[(tick // 8) % speakers + 1]
			supervisor:hear(who, now)
			operator:hear({ speaker = { UserId = who } :: any, text = "meet me by the purple lantern", at = now })
		end
		if tick % 40 == 0 then
			supervisor:hear(present[1], now)
			operator:hear({
				speaker = { UserId = present[1] } :: any,
				text = `check the {secrets[1].plain[1]}`,
				at = now,
			})
		end

		-- R110: the server's own dispatch, not a copy of it.
		if round:isPlaying() then
			if supervisor:putThrough(pursuit, rooms, Config.Rooms, standing, now) then
				report.silenceCalls += 1
			end
		end

		pursuit:step(Config.TickSeconds)
		-- `takePending` returns whether it promoted a queued room, so the count is
		-- the module's own answer rather than an inference from its fields.
		if pursuit:takePending() then
			report.pendingTaken += 1
		end
		if pursuit.pending ~= nil then
			report.everQueued += 1
		end

		if round:isPlaying() and pursuit.state == "arrived" then
			-- R112: the server's own capture (connect AND forget), not a copy.
			line:takeInRoom(pursuit.position, standing, Layout.halfRoom(), now, supervisor)
			-- R111: the server's own loss rule, not a copy (this one had drifted:
			-- it lacked the line:count() > 0 clause).
			local allTakenNow = line:allTaken(present)
			if Lifecycle.nobodyCanWin(present, board, line) and round:finish("lost", now) then
				report.lost += 1
				if not allTakenNow then
					report.strandedLost += 1
				end
				-- The server stops it hunting once there is nobody left to hunt;
				-- leaving it travelling would keep the hum going over a finished
				-- round. The soak cannot hear a hum, but it must not model a
				-- monster still walking through an intermission either.
				if pursuit.pending ~= nil then
					report.queuedDropped += 1
				end
				pursuit:stop()
			end
		end

		-- The server asks on every beat now, not only on arrival (R49).
		if round:isPlaying() then
			-- R111: the server's own loss rule, not a copy.
			local allTakenNow = line:allTaken(present)
			if Lifecycle.nobodyCanWin(present, board, line) and round:finish("lost", now) then
				report.lost += 1
				if not allTakenNow then
					report.strandedLost += 1
				end
			end
		end

		if pursuit:shouldLeave(Config.LingerSeconds) then
			pursuit:withdrawTo(Layout.operatorPost())
			report.gaveUp += 1
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
							report.solved += 1
						end
						break
					end
				end
			end
			-- R138: the last line opens the way out; the beat below settles it.
			if board:allSolved() and escape:open(now) then
				report.escapes += 1
			end
		end
		local settled = workTheWayOut(escape, round, pursuit, present, line, standing, rooms, now)
		if settled == "won" then
			report.won += 1
		elseif settled == "lost" then
			report.lost += 1
		end

		-- A player rejoining. Every return re-deals the whole board.
		if rejoinEvery > 0 and tick % rejoinEvery == 0 then
			-- The deal is unconditional, because `PlayerAdded` is: the server
			-- re-deals whatever the phase.
			board:deal(present)
			-- The MEASUREMENT is not. "Nobody can finish anything" is the normal,
			-- correct state of a round that is already over -- everyone is still
			-- on the line and the board is not reset until the restart -- so
			-- counting it during an intermission counts the game working.
			--
			-- This was invisible until R62 put the Supervisor in this session and
			-- losses became common: the count went from 0 to 28 with no change to
			-- any rule, which is what a measurement that was never gated looks
			-- like when the thing it forgot to exclude starts happening.
			if round:isPlaying() and not everyLineEnterable(board, ableNow()) and not board:allSolved() then
				report.stuckRejoins += 1
			end
		end

		if round:readyToRestart(now, Config.IntermissionSeconds) and round:restart() then
			report.rounds += 1
			board:reset()
			-- The restart must hand the next round an unsolved board. Counted as a
			-- property rather than trusted: `board:reset()` could be deleted and
			-- the suite noticed nothing.
			local anySolved = false
			for _, objective in board.list do
				if objective.solved then
					anySolved = true
				end
			end
			if not anySolved then
				report.cleanStarts += 1
			end
			line:clear()
			escape:reset()
			operator:forgetObservations()
			-- R131: the server forgets once per round, here, not on a clock.
			if operator:coolRound(Config.CoolPerRound) then
				report.decayed += 1
			end
			if pursuit.pending ~= nil then
				report.queuedDropped += 1
			end
			pursuit:sendHome(Layout.operatorPost())
			-- R31's boundary. Without it a player quiet through the intermission
			-- is called in the first seconds of the new round.
			supervisor:reset(now)
			if report.rounds % 3 == 0 then
				table.insert(present, nextId)
				nextId += 1
				if #present > 6 then
					local gone = table.remove(present, 1)
					if gone then
						standing[gone] = nil
						supervisor:forget(gone)
					end
				end
			end
			-- Somebody who joined has to stand somewhere, or they are never in any
			-- room and cannot be caught at all -- which would quietly turn the
			-- harsh soak into the gentle one as the server filled up.
			placeEveryone()
			watchEveryone(now)
			board:deal(present)
		end

		for _, objective in board.list do
			local seen = 0
			for _ in objective.seenBy do
				seen += 1
			end
			report.worstSeen = math.max(report.worstSeen, seen)
		end
		report.worstLexicon = math.max(report.worstLexicon, #operator:snapshot())

		if round:isPlaying() and not board:allSolved() and not everyLineEnterable(board, ableNow()) then
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
		strandedLost = 0,
		unfinishableTicks = 0,
		worstSeen = 0,
		worstLexicon = 0,
		stuckRejoins = 0,
		silenceCalls = 0,
		solved = 0,
		decayed = 0,
		pendingTaken = 0,
		gaveUp = 0,
		cleanStarts = 0,
		everQueued = 0,
		queuedDropped = 0,
		escapes = 0,
	}
	for _, seed in SEEDS do
		local one = soak(ticks, rejoinEvery, takeAllButOne, seed)
		total.rounds += one.rounds
		total.won += one.won
		total.lost += one.lost
		total.strandedLost += one.strandedLost
		total.stuckRejoins += one.stuckRejoins
		total.silenceCalls += one.silenceCalls
		total.solved += one.solved
		total.decayed += one.decayed
		total.pendingTaken += one.pendingTaken
		total.gaveUp += one.gaveUp
		total.cleanStarts += one.cleanStarts
		total.everQueued += one.everQueued
		total.queuedDropped += one.queuedDropped
		total.escapes += one.escapes
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

-- (control) the seed must actually reach the randomness, or the replay check
-- above passes for the wrong reason -- by nothing being random at all.
--
-- Asked of the DEAL rather than of the report. R62 put the Supervisor in this
-- session and its outcomes became uniform enough that two seeds produced
-- identical summaries: the old control compared reports and started failing
-- while the seeding was perfectly correct. A control has to probe the thing the
-- seed governs, which is the shuffle.
local function firstSecrets(seed: number): string
	math.randomseed(seed)
	local dealt = Round.dealSecrets(Round.secretsPerRound())
	local names: { string } = {}
	for _, secret in dealt do
		table.insert(names, `{secret.concept}:{secret.payload}`)
	end
	return table.concat(names, "|")
end
-- Swept, not asked of one pair. The deal fixes every station's secret and
-- shuffles only ONE ambient secret out of the rest (R137: two candidates), so
-- any two seeds coincide about one time in two -- and the first version of this
-- control drew such a pair (4242 and 99) and failed while the seeding was
-- perfectly correct.
local dealtA = firstSecrets(4242)
check(`(guard) a deal produces something ({dealtA})`, #dealtA > 0)
local distinct: { [string]: boolean } = {}
for _, seed in SEEDS do
	distinct[firstSecrets(seed)] = true
end
local shapes = 0
for _ in distinct do
	shapes += 1
end
check(`(control) different seeds deal different games ({shapes} across {#SEEDS} seeds)`, shapes > 1)
check("...and the same seed deals the same game", firstSecrets(4242) == dealtA)

print("a server's whole life")
local long = acrossSeeds(1200, 0, false)
check(`(guard) the soak actually played rounds ({long.rounds})`, long.rounds >= 5)
check(`(guard) and players were caught in them ({long.won} won, {long.lost} lost)`, long.won + long.lost >= 5)

-- R62. The Supervisor has to actually run in THIS session, not merely exist in
-- the file. Before this round the main soak had none at all, so R46's Lexicon
-- bound, R47's seen-set bound, R48's stranded-loss rule and R49's
-- unfinishable-tick count were every one of them measured in the pre-R54 game.
check(`the Supervisor runs in a normal session ({long.silenceCalls} calls)`, long.silenceCalls > 0)

-- R63. Each of these was switched off in a mutation sweep and NOTHING in the
-- suite noticed. A session that did not exercise a system is not evidence about
-- it, however green it prints.
-- Checked by its EFFECT, not by a tally at the call site.
--
-- The first version of this counted `operator:hear` calls, and the mutation
-- sweep caught it out live: with BOTH hear calls gutted, `the Operator hears
-- people (1050 utterances)` still passed, because a counter next to a call
-- measures the call SITE and increments whether or not the call does anything.
-- A check that cannot fail when the thing it names is broken is worse than no
-- check -- R48, R49, R55 and R62 are all that same mistake -- so the tally is
-- gone and the Lexicon answers instead. It only grows if something was really
-- heard and really understood.
check(`the Operator is heard and learns ({long.worstLexicon} coinages at the high-water mark)`, long.worstLexicon > 0)
check(`lines actually get solved ({long.solved})`, long.solved > 0)
check(`heat is actually forgotten ({long.decayed} round starts changed the Lexicon)`, long.decayed > 0)
check(`(measured) rooms were queued behind a busy Operator ({long.everQueued} ticks)`, long.everQueued >= 0)
-- MEASURED, NOT ASSERTED. `takePending` works -- `tests/pursuit.luau` drives it
-- busy, queued, arrived, withdrawn, idle and watches it promote -- but across
-- seven whole sessions it promoted NOTHING, while rooms sat queued for hundreds
-- of ticks. They are thrown away instead: `stop()` on a loss and `sendHome()` on
-- a restart both clear `pending`, and with the Supervisor in, rounds end long
-- before the Operator is ever idle with something waiting.
--
-- So a room somebody gave away is silently never visited. Whether that is right
-- -- a finished round should probably forget its queue -- is the owner's call,
-- and a test demanding either answer would be making it. See LOOP_LOG R63.
check(`(recorded, see R63) queued rooms taken up ({long.pendingTaken})`, long.pendingTaken >= 0)
check(`(recorded, see R63) queued rooms thrown away instead ({long.queuedDropped})`, long.queuedDropped >= 0)
check(`(guard) the queue really does fill up ({long.everQueued} ticks with a room waiting)`, long.everQueued > 0)
check(`the Operator gives rooms up ({long.gaveUp} times)`, long.gaveUp > 0)
-- R138: a normal session reaches the way out, or none of it is evidence.
check(`(guard) sessions reach the way out ({long.escapes} escapes)`, long.escapes > 0)
check(`...and escapes are won ({long.won} won of {long.escapes})`, long.won > 0)
check(
	`every restart hands over a clean board ({long.cleanStarts} of {long.rounds})`,
	long.rounds > 0 and long.cleanStarts == long.rounds
)

-- R48: a live round must always be finishable by somebody, or it ends.
check(`no live round is ever unfinishable ({long.unfinishableTicks} ticks)`, long.unfinishableTicks == 0)

-- R47: the seen set must not grow with the size of the server.
check(`the seen set stays bounded ({long.worstSeen} readers per line)`, long.worstSeen <= 2)

-- R46's gap was closed in R131 (forgetting is per round now), so coinages can
-- burn; the register must still stay bounded, because every round start cools
-- it and drops what reaches zero.
check(`the Lexicon never runs away ({long.worstLexicon})`, long.worstLexicon < 200)

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
	local function homePositions(): { [number]: { x: number, z: number } }
		return {
			[1] = Layout.spawn(),
			[2] = rooms.board,
			[3] = rooms.board,
			[4] = rooms.archive,
		}
	end
	-- R138: the escape moves everyone to the lobby, so each round starts again
	-- from these places.
	local standing = homePositions()

	local won, calls, unreachable, announced = 0, 0, 0, 0
	local everMoved = false
	local roundsPlayed, playingTicks, thisRound, longestRound = 0, 0, 0, 0

	for tick = 1, ticks do
		now += Config.TickSeconds
		runForTheExit(escape, present, line, standing, rooms, now, RUN_AFTER)

		-- Nobody says anything, ever. `operator:hear` is never called.
		--
		-- The dispatch is the server's, in miniature: everyone stands in a room,
		-- so the longest-quiet player's room is where it is sent.
		if round:isPlaying() then
			-- The corridor measurement (R54): overdue players standing where no
			-- room can serve them. Counted beside the call, not by copying it.
			for _, userId in supervisor:overdue(now) do
				local at = standing[userId]
				if at then
					local inRoom = false
					for _, name in Config.Rooms do
						if rooms[name] and Layout.inRoom(rooms[name], at) then
							inRoom = true
						end
					end
					if not inRoom then
						unreachable += 1
					end
				end
			end
			-- R110: the server's own dispatch, not a copy of it.
			local called, announce = supervisor:putThrough(pursuit, rooms, Config.Rooms, standing, now)
			if called then
				calls += 1
				if announce then
					announced += 1
				end
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
			if board:allSolved() then
				escape:open(now)
			end
		end
		if workTheWayOut(escape, round, pursuit, present, line, standing, rooms, now) == "won" then
			won += 1
		end

		if round:readyToRestart(now, Config.IntermissionSeconds) and round:restart() then
			board:reset()
			line:clear()
			escape:reset()
			standing = homePositions()
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
-- R111: this guard was named "it really did strand people", but it counted
-- every loss. Measured then: 0 of 28 harsh losses were strandings with anyone
-- still free, because the rule wanted the survivor to have seen EVERY unsolved
-- line, which this model never produces. Planting `nobodyCanWin`'s stranded
-- clause to `false` left this file green.
-- R149: one line nobody free may enter is enough (the way out needs them all),
-- and R48's survivor always holds one. Measured: 31 of 34, and the same seven
-- sessions play 58 rounds instead of 28, because a stranded round no longer runs
-- on until the last player is taken. So this is a guard again: without
-- strandings this file could not see the rule.
check(`(guard) the harsh soak loses rounds ({harsh.lost})`, harsh.lost >= 1)
check(
	`(guard) the harsh soak strands rounds with someone still free ({harsh.strandedLost} of {harsh.lost})`,
	harsh.strandedLost > 0
)
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

print("")
print("a caught player is no longer chased for silence")

-- R67. A caught player cannot act -- Objectives.submit refuses anyone
-- isConnected -- and nothing releases them again inside a round, so there is no
-- more silence left to punish once they are on the line. Nothing joined capture
-- to the Supervisor's clock, so it kept chasing them anyway.
--
-- Measured before the fix: one player alone in a room, already caught from
-- tick one, against another player alone elsewhere, genuinely silent. Over
-- 8,000 ticks the Operator was dispatched to the CAUGHT player 76 times and to
-- the silent one 75 -- not starvation (the per-player cooldown forces
-- alternation), but roughly HALF of every dispatch, and every audible "putting
-- you through", spent on someone who could not possibly benefit from it.
local function chaseScenario(forgetOnCapture: boolean): (number, number)
	local rooms = Layout.rooms()
	local pursuit = Pursuit.new(rooms, Layout.operatorPost(), Layout.route)
	local supervisor = Supervisor.new()
	local line = Connected.new()
	local standing = { [1] = rooms.board, [2] = rooms.archive }

	local now = 0
	supervisor:watch(1, now)
	supervisor:watch(2, now)
	line:connect(1, now) -- player 1 starts already caught
	if forgetOnCapture then
		supervisor:forget(1)
	end

	local toBoard, toArchive = 0, 0
	for _ = 1, 8000 do
		now += Config.TickSeconds
		for _, userId in supervisor:overdue(now) do
			local at = standing[userId]
			if not at then
				continue
			end
			local found = false
			for name, centre in rooms do
				if Layout.inRoom(centre, at) then
					found = true
					local _, onItsWay = pursuit:sendTo(name)
					if onItsWay then
						supervisor:called(userId, now)
						if name == "board" then
							toBoard += 1
						else
							toArchive += 1
						end
					end
					break
				end
			end
			if found then
				break
			end
		end
		pursuit:step(Config.TickSeconds)
		pursuit:takePending()
		if pursuit:shouldLeave(Config.LingerSeconds) then
			pursuit:withdrawTo(Layout.operatorPost())
		end
	end
	return toBoard, toArchive
end

local beforeBoard, beforeArchive = chaseScenario(false)
check(`(guard) the unfixed shape wastes real dispatches on the caught player ({beforeBoard})`, beforeBoard > 10)
check(`(control) ...roughly evenly with the genuinely silent player ({beforeArchive})`, beforeArchive > 10)

local afterBoard, afterArchive = chaseScenario(true)
check(`forgetting on capture stops the wasted dispatches ({afterBoard} to the caught player)`, afterBoard == 0)
check(`...and every dispatch instead reaches the silent player ({afterArchive})`, afterArchive > 0)

Kit.finish()
