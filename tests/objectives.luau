--!strict
-- The invariant tests. If any of these regress, the game is broken even if it
-- still runs: players would stop needing to talk to each other.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".
local process = require("@lune/process")

local fs = require("@lune/fs")

local Harness = require("./harness")
local stripNonCode = require("./luaucode").stripNonCode

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

print("a holder who leaves")
-- The defect this covers: `PlayerRemoving` used to clear a rate-limit entry and
-- nothing else, so the objective held by a departing player kept their userId.
-- Its answer was then visible to nobody, so nobody could enter it, so the round
-- could never be finished by the players still in the server.
local b4 = Objectives.new()
local kept = b4:add("board", "jack_number", "p")
local orphan = b4:add("breaker", "breaker", "p")
kept.holder = ACTOR
orphan.holder = HOLDER

-- HOLDER disconnects; ACTOR and THIRD remain.
local moved = b4:redealOrphans({ ACTOR, THIRD })
check("the leaver's line is re-dealt", orphan.holder ~= HOLDER)
check("and it goes to someone still present", orphan.holder == ACTOR or orphan.holder == THIRD)
check("exactly one line moved", moved == 1)
check("a line held by someone present is left alone", kept.holder == ACTOR)
check("somebody can now see the orphaned answer", b4:viewFor(orphan.holder :: number)[2].answer == orphan.answer)

-- The whole point: the round can be finished again. Somebody who is NOT the
-- new holder enters the answer.
local other = if orphan.holder == ACTOR then THIRD else ACTOR
check("the re-dealt line is solvable by another present player", b4:submit("breaker", other, orphan.answer).ok == true)

print("re-dealing orphans does not overreach")
local b5 = Objectives.new()
local doneAlready = b5:add("board", "jack_number", "p")
doneAlready.holder = HOLDER
doneAlready.solved = true
check("a solved line held by a leaver is not re-dealt", b5:redealOrphans({ ACTOR }) == 0)
check("and its holder is untouched", doneAlready.holder == HOLDER)

local b6 = Objectives.new()
local lonely = b6:add("board", "jack_number", "p")
lonely.holder = HOLDER
check("with nobody left, nothing is re-dealt", b6:redealOrphans({}) == 0)
check("and the holder is left as it was", lonely.holder == HOLDER)

local b7 = Objectives.new()
local never = b7:add("board", "jack_number", "p")
check("a line that was never dealt counts as an orphan", b7:redealOrphans({ ACTOR }) == 1)
check("and it now has a holder", never.holder == ACTOR)

local b8 = Objectives.new()
local settled = b8:add("board", "jack_number", "p")
settled.holder = ACTOR
check("with every holder present, nothing moves", b8:redealOrphans({ ACTOR, THIRD }) == 0)
check("and the holder is unchanged", settled.holder == ACTOR)

print("the leave path is actually wired")
-- Everything above tests the MODULE. The defect was in the WIRING: the method
-- can be perfect and the round still unwinnable if nothing calls it when a
-- player leaves. `init.server.luau` needs a real Roblox runtime, so this reads
-- its source and checks the handler body instead of loading it. A capability
-- written and never wired is the shape this project keeps shipping.
--
-- It reads the handler as CODE, not as text. The first draft searched raw
-- source, which meant the explanatory comment sitting directly above the call
-- would have certified the wiring all by itself. `stripNonCode` is the same
-- scanner the dead-dial guard uses (`tests/luaucode.luau`), so a mention can no
-- longer stand in for a call.
--
-- KNOWN LIMIT, inherited: the scanner is a lexer, so `if false and
-- board:redealOrphans(...)` is still code to it and would pass. Telling live
-- code from dead code is the open item R7 filed and R8 did not close.
local serverSource = stripNonCode(fs.readFile("src/server/init.server.luau"))
local removingBody = string.match(serverSource, "Players%.PlayerRemoving:Connect%(function.-\nend%)")
check("init.server has a PlayerRemoving handler", removingBody ~= nil)
check(
	"the PlayerRemoving handler re-deals orphaned lines",
	removingBody ~= nil and string.find(removingBody :: string, "redealOrphans", 1, true) ~= nil
)
check(
	"and it excludes the leaving player from the re-deal",
	removingBody ~= nil and string.find(removingBody :: string, "~= player", 1, true) ~= nil
)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
