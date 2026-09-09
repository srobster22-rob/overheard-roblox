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

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
