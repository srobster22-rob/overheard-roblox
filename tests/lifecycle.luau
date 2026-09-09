--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: a game that cannot be played twice.
--
-- Until R29 there was no round lifecycle at all. `allSolved()` fired the win
-- line and returned; `allTaken()` fired the loss line and stopped the Operator.
-- Nothing reset anything. So a WIN left the monster hunting — you finished the
-- board and were then taken by something that had no idea the round was over —
-- and either ending left the server a dead lobby with the objectives still
-- solved and the connected still connected.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Lifecycle = rt.require(rt.systems.Lifecycle)
type Lifecycle_Round = Lifecycle.Round
local Objectives = rt.require(rt.systems.Objectives)
local Connected = rt.require(rt.systems.Connected)

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

print("a round starts playable")
local round = Lifecycle.new()
check("it begins in play", round:isPlaying())
check("and is not over", round:isOver() == false)
check("it is round one", round.number == 1)
check("a round still being played cannot restart", round:restart() == false)
check("nor is it ready to", round:readyToRestart(1000, 0) == false)

print("")
print("ending it is a transition, and only happens once")
-- Both endings are checked on a repeating tick: `allSolved` stays true forever
-- once the board is done, and `allTaken` stays true while everyone is caught.
-- Without the once-only guarantee the server announces the ending four times a
-- second, which is the shape of the bug this returns `false` to prevent.
check("finishing reports the transition", round:finish("won", 100) == true)
check("it is over", round:isOver() and round:isPlaying() == false)
check("the outcome is recorded", round.outcome == "won")
check("finishing again reports nothing", round:finish("won", 101) == false)
check("even with a different outcome", round:finish("lost", 102) == false)
check("and the first outcome stands", round.outcome == "won")

print("")
print("the intermission is waited out")
check("not ready immediately", round:readyToRestart(100, 8) == false)
check("not ready part way", round:readyToRestart(107.9, 8) == false)
check("ready exactly on time", round:readyToRestart(108, 8) == true)
check("and after", round:readyToRestart(200, 8) == true)

print("")
print("restarting")
check("restarting works once the round is over", round:restart() == true)
check("it is playable again", round:isPlaying())
check("the outcome is cleared", round.outcome == nil)
check("the round number advances", round.number == 2)
check("restarting again is refused", round:restart() == false)
check("and it is not ready to restart mid-play", round:readyToRestart(9999, 0) == false)

print("")
print("what a new round resets, and what it must NOT")
-- The lexicon surviving between rounds is the retention mechanic GAME.md is
-- built on. Resetting it would make every round a first round with strangers.
local board = Objectives.new()
local objective = board:add("board", "jack_number", "jack %s")
objective.holder = 1
local firstAnswer = objective.answer
board:submit("board", 2, firstAnswer, 0)
check("(guard) the board was finished", board:allSolved())

board:reset()
check("a new round is unsolved", board:allSolved() == false)
check("and has no holder until it is dealt", objective.holder == nil)

-- Fresh answers, or a group could retype last round's numbers.
local changed = false
for _ = 1, 40 do
	board:reset()
	if objective.answer ~= firstAnswer then
		changed = true
		break
	end
end
check("the answers are re-rolled, not reused", changed)

local line = Connected.new()
line:connect(1, 0)
line:connect(2, 0)
check("(guard) players were on the line", line:count() == 2)
line:clear()
check("a new round takes everyone off the line", line:count() == 0)
check("and they are not still connected", line:isConnected(1) == false)

print("")
print("per-round state does not cross the boundary")

-- R31. `beginRound` reset the board, the line and the Operator's position, and
-- nothing else. Two things crossed:

local Station = rt.require(rt.systems.Station)
local Operator = rt.require(rt.systems.Operator)
local Config = rt.require(rt.shared.Config)

-- 1. Where each player is standing. R12 added this gate so the SERVER owns it;
--    surviving the boundary handed every player one free station.
local desk = Station.new()
desk:open(1, "breaker")
check("(guard) walking up to a station opens it", desk:accepts(1, "breaker"))
desk:clear()
check("a new round forgets where everyone was standing", desk:accepts(1, "breaker") == false)
check("...for every station, not just the one", desk:accepts(1, "board") == false)
check("...and for every player", desk:accepts(2, "breaker") == false)

-- 2. Novel terms waiting to be credited. CreditWindow (20s) is longer than the
--    intermission (8s), so a phrase said just before a round ended was credited
--    by a success in the NEXT one: 6 coinages minted across the boundary.
check(
	`(guard) the window really is longer than the intermission ({Config.CreditWindow} > {Config.IntermissionSeconds})`,
	Config.CreditWindow > Config.IntermissionSeconds
)

local secrets = { { concept = "exit", plain = { "exit" }, payload = "archive" } }
local speaker = { UserId = 1 } :: any

local leaky = Operator.new(secrets)
leaky:hear({ speaker = speaker, text = "meet me at the purple lantern", at = 100 })
leaky:credit("exit", 112)
check("(guard) a same-window success does credit it", #leaky:snapshot() > 0)

local clean = Operator.new(secrets)
clean:hear({ speaker = speaker, text = "meet me at the purple lantern", at = 100 })
clean:forgetObservations()
clean:credit("exit", 112)
check("a phrase from last round is not credited by this round's success", #clean:snapshot() == 0)

-- And the thing that must NOT be forgotten: the Lexicon itself. Carrying a
-- group's vocabulary between rounds is the retention mechanic.
local kept = Operator.new(secrets)
for i = 1, 6 do
	kept:hear({ speaker = speaker, text = "head for the purple lantern", at = i })
	kept:credit("exit", i + 0.5)
end
local before = #kept:snapshot()
check(`(guard) the group coined something ({before})`, before > 0)
kept:forgetObservations()
check("forgetting observations does not wipe the Lexicon", #kept:snapshot() == before)

print("")
print("a finished round is not listened to either")

-- R32. R29 gated CAPTURE on the round being live and nothing else, so during
-- the intermission a plain giveaway still made the Operator announce itself and
-- walk audibly at a room it could take nobody in. The whole game rests on the
-- hum meaning something; a hum that sometimes means nothing is worse than none.
--
-- Modelled against the real Operator, Pursuit and Lifecycle, wired the way the
-- server wires them, because `init.server` cannot be loaded headlessly.

local Pursuit = rt.require(rt.systems.Pursuit)
local Layout = rt.require(rt.shared.Layout)
local RoundModule = rt.require(rt.systems.Round)

local hunted = { board = Layout.boardCentre(), archive = Layout.archiveCentre() }
local dealt = RoundModule.dealSecrets(3)

-- The plain giveaway for a room that exists, taken from the real pool.
local giveaway: string? = nil
for _, secret in dealt do
	if secret.payload == "board" then
		giveaway = secret.plain[1]
	end
end
check("(guard) the real pool gave us a plain term for the board room", giveaway ~= nil)

local function serverLike(live: Lifecycle_Round)
	local op = Operator.new(dealt)
	local chase = Pursuit.new(hunted, Layout.operatorPost())
	local broadcasts = 0
	op.onUnderstood = function(_concept: string, payload: string)
		broadcasts += 1
		chase:sendTo(payload)
	end
	-- THE GATE, exactly as the server states it.
	local function feed(text: string, at: number)
		if not live:isPlaying() then
			return
		end
		op:hear({ speaker = { UserId = 1 } :: any, text = text, at = at })
	end
	return feed, chase, function()
		return broadcasts
	end
end

local playing = Lifecycle.new()
local feedLive, chaseLive, countLive = serverLike(playing)
feedLive(`patch the {giveaway}`, 1)
check("(control) while the round is live it DOES hunt", chaseLive.targetName == "board")
check("(control) and it announces", countLive() > 0)
check("(control) and you hear it", chaseLive:isAudible())

local finished = Lifecycle.new()
finished:finish("won", 100)
local feedOver, chaseOver, countOver = serverLike(finished)
feedOver(`patch the {giveaway}`, 101)
check("a finished round does not start a hunt", chaseOver.targetName == nil)
check("...and says nothing to anyone", countOver() == 0)
check("...and stays silent", chaseOver:isAudible() == false)
check("...and does not move", chaseOver.state == "idle")

-- And it starts listening again once the next round begins.
finished:restart()
feedOver(`patch the {giveaway}`, 200)
check("the next round is listened to again", chaseOver.targetName == "board")

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
