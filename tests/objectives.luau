--!strict
-- The invariant tests. If any of these regress, the game is broken even if it
-- still runs: players would stop needing to talk to each other.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".
local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Objectives = rt.require(rt.systems.Objectives)

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

local HOLDER = 100
local ACTOR = 200
local THIRD = 300

local board = Objectives.new()
local jack = board:add("board", "jack_number", "Patch line to jack %s")
board:deal({ HOLDER })
-- Force a known holder for determinism.
jack.holder = HOLDER

print("visibility")
local holderView = board:viewFor(HOLDER)[1]
local otherView = board:viewFor(ACTOR)[1]
check("holder sees the answer", holderView.answer == jack.answer)
check("holder is marked as holding", holderView.holding == true)
check("everyone else sees no answer", otherView.answer == nil)
check("everyone else sees no prompt", otherView.prompt == nil)
check("everyone else still sees the objective exists", otherView.id == "board")

print("the invariant")
local selfSolve = board:submit("board", HOLDER, jack.answer)
check("the holder cannot solve their own objective", selfSolve.ok == false)
check("and it stays unsolved", jack.solved == false)

print("submission")
check("a wrong value fails", board:submit("board", ACTOR, "00").ok == false)
check("wrong value does not leak the answer", board:submit("board", ACTOR, "00").reason == "that line is dead")

local solvedBy: number? = nil
board.onSolved = function(_objective, actor: number)
	solvedBy = actor
end
local good = board:submit("board", ACTOR, jack.answer)
check("a different player with the right value solves it", good.ok == true)
check("onSolved reports the actor", solvedBy == ACTOR)
check("board reports all solved", board:allSolved() == true)

print("idempotence")
check("re-submitting a solved objective is refused", board:submit("board", THIRD, jack.answer).ok == false)

print("input cleaning")
local b2 = Objectives.new()
local o2 = b2:add("second", "breaker", "p")
o2.holder = HOLDER
o2.answer = "47"
check("punctuation and spaces are ignored", b2:submit("second", ACTOR, " 4-7 ").ok == true)

print("dealing")
local b3 = Objectives.new()
b3:add("a", "exit", "p")
b3:add("b", "breaker", "p")
b3:add("c", "directory", "p")
b3:deal({ 1, 2, 3 })
local holders: { [number]: boolean } = {}
for _, o in b3.list do
	holders[o.holder :: number] = true
end
local distinct = 0
for _ in holders do
	distinct += 1
end
check("three objectives across three players use every player", distinct == 3)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
