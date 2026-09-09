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

-- A fixed clock. `submit` takes the time so the jam is testable without
-- sleeping; nothing here advances it unless a check is about the jam.
local T0 = 1000

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
local selfSolve = board:submit("board", HOLDER, jack.answer, T0)
check("the holder cannot solve their own objective", selfSolve.ok == false)
check("and it stays unsolved", jack.solved == false)

print("submission")
check("a wrong value fails", board:submit("board", ACTOR, "00", T0).ok == false)
check("wrong value does not leak the answer", board:submit("board", ACTOR, "00", T0).reason == "that line is dead")

local solvedBy: number? = nil
board.onSolved = function(_objective, actor: number)
	solvedBy = actor
end
local good = board:submit("board", ACTOR, jack.answer, T0)
check("a different player with the right value solves it", good.ok == true)
check("onSolved reports the actor", solvedBy == ACTOR)
check("board reports all solved", board:allSolved() == true)

print("idempotence")
check("re-submitting a solved objective is refused", board:submit("board", THIRD, jack.answer, T0).ok == false)

print("input cleaning")
local b2 = Objectives.new()
local o2 = b2:add("second", "breaker", "p")
o2.holder = HOLDER
o2.answer = "47"
check("punctuation and spaces are ignored", b2:submit("second", ACTOR, " 4-7 ", T0).ok == true)

-- GUESSING. The reason these exist: `holder ~= actor` was the only thing
-- standing between a player and a solved line, and the answer is two digits.
-- 90 values, median 45 guesses, 0.75s per attempt at the remote's rate limit
-- is about 34 seconds of holding Enter -- a whole objective cleared without
-- anyone speaking, in a game whose only premise is that you have to speak.
print("guessing is not a strategy")
local bJam = Objectives.new()
local jamLine = bJam:add("board", "jack_number", "p")
local otherLine = bJam:add("breaker", "breaker", "p")
jamLine.holder = HOLDER
otherLine.holder = HOLDER
jamLine.answer = "47"
otherLine.answer = "58"

check("the first wrong answer is just wrong", bJam:submit("board", ACTOR, "11", T0).reason == "that line is dead")
check("the second is too", bJam:submit("board", ACTOR, "12", T0).reason == "that line is dead")
local third = bJam:submit("board", ACTOR, "13", T0)
check("the third wrong answer jams the line", third.reason == "that line is jammed - wait 20s")
check("and it is still not solved", jamLine.solved == false)

-- The point of the jam: it beats the RIGHT answer too, or a guesser simply
-- keeps going and the jam is decoration.
local duringJam = bJam:submit("board", ACTOR, jamLine.answer, T0 + 5)
check("a jammed player is refused even with the right answer", duringJam.ok == false)
check("and the line stays unsolved while jammed", jamLine.solved == false)
-- ...and the refusal must not become an oracle: same reply either way, so a
-- jammed player cannot tell a right guess from a wrong one by the wording.
check(
	"the jammed reply does not say whether the value was right",
	duringJam.reason == bJam:submit("board", ACTOR, "99", T0 + 5).reason
)
check("the countdown shrinks as the jam runs down", bJam:submit("board", ACTOR, "99", T0 + 15).reason == "that line is jammed - wait 5s")

-- Per (line, actor), so one guesser cannot lock the game for anyone else.
check("another player is not jammed", bJam:submit("board", THIRD, "11", T0 + 5).reason == "that line is dead")
check("and the same player is not jammed on the other line", bJam:submit("breaker", ACTOR, "11", T0 + 5).reason == "that line is dead")

-- Escalation. The second jam is twice the first, which is what turns guessing
-- from slow into pointless.
check("the jam expires", bJam:submit("board", ACTOR, "14", T0 + 21).reason == "that line is dead")
check("the fifth wrong answer is just wrong", bJam:submit("board", ACTOR, "15", T0 + 22).reason == "that line is dead")
check(
	"the second jam is twice as long as the first",
	bJam:submit("board", ACTOR, "16", T0 + 23).reason == "that line is jammed - wait 40s"
)

-- An honest actor who was TOLD the number is never punished for fumbling it.
local bHonest = Objectives.new()
local honest = bHonest:add("board", "jack_number", "p")
honest.holder = HOLDER
honest.answer = "47"
bHonest:submit("board", ACTOR, "11", T0)
bHonest:submit("board", ACTOR, "12", T0)
check("two typos then the right answer still solves it", bHonest:submit("board", ACTOR, "47", T0).ok == true)
check("and the right answer wipes the miss count", honest.misses[ACTOR] == nil)

-- The holder hammering their own line must never earn a jam: they are refused
-- by the invariant before a guess is ever counted, so they cannot lock the
-- line against the person who is allowed to solve it.
local bHolder = Objectives.new()
local holderLine = bHolder:add("board", "jack_number", "p")
holderLine.holder = HOLDER
holderLine.answer = "47"
for _ = 1, 9 do
	bHolder:submit("board", HOLDER, "11", T0)
end
check("the holder's own attempts are not counted as guesses", holderLine.misses[HOLDER] == nil)
check(
	"so the holder cannot jam their own line",
	bHolder:submit("board", HOLDER, "11", T0).reason == "someone else has to patch this"
)

-- The whole claim, simulated: a guesser who waits out every jam and never
-- speaks. Before this change 45 wrong answers cost 45 * 0.75 = 33.75 seconds.
local bBrute = Objectives.new()
local target = bBrute:add("board", "jack_number", "p")
target.holder = HOLDER
target.answer = "47"
local elapsed = 0
local iterations = 0
while (target.misses[ACTOR] or 0) < 45 and iterations < 1000 do
	iterations += 1
	local before = target.misses[ACTOR] or 0
	bBrute:submit("board", ACTOR, "11", elapsed)
	if (target.misses[ACTOR] or 0) == before then
		-- Refused as jammed and not counted. Wait exactly as long as told.
		elapsed = target.jammedUntil[ACTOR]
	else
		elapsed += 0.75
	end
end
check("the brute-force simulation terminated", (target.misses[ACTOR] or 0) == 45)
check(`45 guesses now costs over half an hour, not 34 seconds (got {math.floor(elapsed)}s)`, elapsed > 1800)

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
check("the re-dealt line is solvable by another present player", b4:submit("breaker", other, orphan.answer, T0).ok == true)

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

-- Same shape of guard for the jam: the module can refuse every guess and the
-- keypad still be free if the ONE call site forgets to pass a clock. `now` is a
-- required parameter, but Luau's type error is not a test failure, and a nil
-- `now` only explodes on the first comparison -- i.e. after a jam is set, in
-- production, and never in the happy path anyone would notice.
local submitCall = string.match(serverSource, "board:submit%b()")
check("init.server calls board:submit", submitCall ~= nil)
check(
	"and passes it a clock, or nothing can ever be jammed",
	submitCall ~= nil and string.find(submitCall :: string, "now", 1, true) ~= nil
)

-- The jam must survive a rejoin. R10 corrected R9 on this and found the game
-- was better than believed: UserId is stable and the Board lives for the life of
-- the SERVER, so a guesser cannot reconnect their way out. R10 then filed
-- `misses`/`jammedUntil` as a leak because `PlayerRemoving` does not clear them
-- -- and R12 started writing that cleanup before realising it is the SAME two
-- lines, and removing them hands the guesser exactly the escape R9 closed.
-- Asserted so the leak can never be "tidied up" without this going red.
print("")
print("a jam is not shed by reconnecting")
local bRejoin = Objectives.new()
local rejoinLine = bRejoin:add("board", "jack_number", "p")
bRejoin:add("breaker", "breaker", "p")
rejoinLine.holder = HOLDER
rejoinLine.answer = "47"
for _ = 1, 3 do
	bRejoin:submit("board", ACTOR, "11", T0)
end
check("the guesser is jammed to begin with", (rejoinLine.jammedUntil[ACTOR] or 0) > T0)
-- Everything PlayerRemoving actually does to this board today: nothing.
check(
	"Objectives exposes no per-player forget that PlayerRemoving could call",
	(Objectives :: any).forgetPlayer == nil
)
check(
	"the jam is still in force after a departure",
	bRejoin:submit("board", ACTOR, rejoinLine.answer, T0 + 1).ok == false
)
check("and the line is still unsolved", rejoinLine.solved == false)
check(
	"the miss count did not reset either",
	(rejoinLine.misses[ACTOR] or 0) == 3
)
local removingCode = removingBody or ""
check(
	"PlayerRemoving does not clear the jam tables",
	string.find(removingCode, "misses", 1, true) == nil
		and string.find(removingCode, "jammedUntil", 1, true) == nil
)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
