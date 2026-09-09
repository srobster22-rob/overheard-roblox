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
local function soak(ticks: number, rejoinEvery: number, takeAllButOne: boolean): Report
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
			local caught = if takeAllButOne then #present - 1 else math.max(1, #present // 2)
			for i = 1, caught do
				line:connect(present[i], now)
			end
			local able = ableNow()
			local stranded = #present > 0 and not board:allSolved() and not board:anyFinishable(able)
			if (line:allTaken(present) or stranded) and round:finish("lost", now) then
				report.lost += 1
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
					table.remove(present, 1)
				end
			end
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

print("a server's whole life")
local long = soak(6000, 0, false)
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
print("one player with a bad connection")
-- R47's exact shape: every return fires PlayerAdded and re-deals the board.
local churny = soak(6000, 25, false)
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
local harsh = soak(6000, 0, true)
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
