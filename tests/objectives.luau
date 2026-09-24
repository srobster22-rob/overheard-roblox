--!strict
-- The invariant tests. If any of these regress, the game is broken even if it
-- still runs: players would stop needing to talk to each other.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".

local fs = require("@lune/fs")

local Harness = require("./harness")
local stripNonCode = require("./luaucode").stripNonCode

local rt = Harness.build()
local Objectives = rt.require(rt.systems.Objectives)
local Round = rt.require(rt.systems.Round)
-- The jam sweep steps the miss counter to the lockout boundary; reading the
-- dial rather than hardcoding 3 keeps it honest if the tuning changes.
local Config = rt.require(rt.shared.Config)

local Kit = require("./kit")
local check = Kit.check

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
check(
	"the countdown shrinks as the jam runs down",
	bJam:submit("board", ACTOR, "99", T0 + 15).reason == "that line is jammed - wait 5s"
)

-- Per (line, actor), so one guesser cannot lock the game for anyone else.
check("another player is not jammed", bJam:submit("board", THIRD, "11", T0 + 5).reason == "that line is dead")
check(
	"and the same player is not jammed on the other line",
	bJam:submit("breaker", ACTOR, "11", T0 + 5).reason == "that line is dead"
)

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

-- R144 (PT3): every refusal said "patch", so the Cutoff told a player somebody
-- else had to patch it. Each station refuses in its own prompt's verb.
do
	local RoundModule = rt.require(rt.systems.Round)
	local ownVerb, otherVerb = 0, 0
	for _, station in RoundModule.STATIONS do
		local board = Objectives.new()
		local line = board:add(station.id, station.concept, "p")
		line.holder = HOLDER
		line.answer = "47"
		line.seenBy[ACTOR] = true
		local verb = string.lower(station.actionText)
		for _, reason in
			{ board:submit(station.id, HOLDER, "47", T0).reason, board:submit(station.id, ACTOR, "47", T0).reason }
		do
			if string.find(reason, ` {verb} `, 1, true) then
				ownVerb += 1
			end
			for _, other in RoundModule.STATIONS do
				local theirs = string.lower(other.actionText)
				if theirs ~= verb and string.find(reason, ` {theirs} `, 1, true) then
					otherVerb += 1
				end
			end
		end
	end
	check(
		`each station's two refusals name its own verb ({ownVerb} of {2 * #RoundModule.STATIONS})`,
		ownVerb == 2 * #RoundModule.STATIONS
	)
	check(`...and never another station's ({otherVerb})`, otherVerb == 0)
end

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
check(
	"the re-dealt line is solvable by another present player",
	b4:submit("breaker", other, orphan.answer, T0).ok == true
)

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
local serverSource = stripNonCode(require("./sources").server())
local removingBody = string.match(serverSource, "local function playerRemoving%(.-\nend")
check("the server has a PlayerRemoving handler", removingBody ~= nil)
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
check("the server calls board:submit", submitCall ~= nil)
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
check("Objectives exposes no per-player forget that PlayerRemoving could call", (Objectives :: any).forgetPlayer == nil)
check(
	"the jam is still in force after a departure",
	bRejoin:submit("board", ACTOR, rejoinLine.answer, T0 + 1).ok == false
)
check("and the line is still unsolved", rejoinLine.solved == false)
check("the miss count did not reset either", (rejoinLine.misses[ACTOR] or 0) == 3)
local removingCode = removingBody or ""
check(
	"PlayerRemoving does not clear the jam tables",
	string.find(removingCode, "misses", 1, true) == nil and string.find(removingCode, "jammedUntil", 1, true) == nil
)

-- FAULT, AND TWO PLAYERS ACTING AT ONCE ------------------------------------
--
-- The fourth shape of the multiplayer seam: ordering. Everything above asks
-- "does A's action land in B's slot"; this asks "what if A and B act at once".
-- Luau is single-threaded and none of these handlers yield, so the interleaving
-- is at the granularity of whole events -- which is exactly enough to lose a
-- race, because two players standing at one keypad who were both told the same
-- number will both press Enter.
--
-- `not ok` is not the same as "you did something wrong", and until R13 the
-- server had no way to tell them apart, so it fired the Operator's "That line
-- is busy." at whichever of the two lost the frame.
print("")
print("fault: whose doing was the refusal")

-- Stated here, deliberately NOT derived from the module, so this table and the
-- code have to agree rather than the test reading its own answer off the thing
-- it is checking.
local FAULT_BRANCHES: { { name: string, fault: boolean, run: () -> any } } = {}
local function branch(name: string, fault: boolean, run: () -> any)
	table.insert(FAULT_BRANCHES, { name = name, fault = fault, run = run })
end

local function freshBoard(): (any, any)
	local b = Objectives.new()
	local line = b:add("board", "jack_number", "Patch line to jack %s")
	line.holder = HOLDER
	line.answer = "47"
	return b, line
end

branch("no such objective", true, function()
	local b = freshBoard()
	return b:submit("nowhere", ACTOR, "47", T0)
end)
branch("already restored", false, function()
	local b, line = freshBoard()
	line.solved = true
	return b:submit("board", ACTOR, "47", T0)
end)
branch("the holder tries their own line", true, function()
	local b = freshBoard()
	return b:submit("board", HOLDER, "47", T0)
end)
branch("a wrong answer", true, function()
	local b = freshBoard()
	return b:submit("board", ACTOR, "11", T0)
end)
branch("the miss that trips the jam", true, function()
	local b = freshBoard()
	for _ = 1, Config.GuessesBeforeLockout - 1 do
		b:submit("board", ACTOR, "11", T0)
	end
	return b:submit("board", ACTOR, "11", T0)
end)
branch("a submit while jammed", true, function()
	local b = freshBoard()
	for _ = 1, Config.GuessesBeforeLockout do
		b:submit("board", ACTOR, "11", T0)
	end
	return b:submit("board", ACTOR, "11", T0)
end)
branch("the right answer", false, function()
	local b = freshBoard()
	return b:submit("board", ACTOR, "47", T0)
end)
branch("a code that was overheard and replaced", false, function()
	local b = freshBoard()
	b:reroll("jack_number")
	return b:submit("board", ACTOR, "47", T0)
end)

local sawFault, sawBlameless = false, false
for _, case in FAULT_BRANCHES do
	local result = case.run()
	check(`{case.name}: fault is {tostring(case.fault)}`, result.fault == case.fault)
	if result.fault then
		sawFault = true
	else
		sawBlameless = true
	end
end
-- Guards. A `fault` hardwired to either constant satisfies half the sweep, and
-- a sweep that never reaches a branch proves nothing about it.
check("the sweep saw a refusal that WAS the actor's fault (guard)", sawFault)
check("the sweep saw an outcome that was NOT (guard)", sawBlameless)
check(`the sweep covered every branch it claims (guard, {#FAULT_BRANCHES})`, #FAULT_BRANCHES == 8)

-- Completeness, read out of the module rather than trusted. If a future round
-- adds an eighth exit from `submit` and gives it a `fault` but no test, this
-- count disagrees with the table above and says so.
local objectivesCode = stripNonCode(fs.readFile("src/server/systems/Objectives.luau"))
local faultSites = select(2, string.gsub(objectivesCode, "fault = ", ""))
check(
	`submit sets fault on exactly as many exits as this file enumerates ({faultSites})`,
	faultSites == #FAULT_BRANCHES
)

-- The race itself ----------------------------------------------------------
print("")
print("two players entering the same number in the same tick")

local raceBoard, raceLine = freshBoard()
local first = raceBoard:submit("board", ACTOR, "47", T0)
local second = raceBoard:submit("board", THIRD, "47", T0)
check("the first correct answer solves the line", first.ok == true)
check("the second correct answer does not", second.ok == false)
check("but the second player is NOT at fault", second.fault == false)
check("and takes no miss for it", raceLine.misses[THIRD] == nil)
check("and is not jammed for it", raceLine.jammedUntil[THIRD] == nil)
check("the line stays solved", raceLine.solved == true)

-- Order-independence. Whichever of the two lands first, neither player who
-- entered the RIGHT number is ever told it was their doing. Swept over both
-- orders rather than asserted once, because the whole defect was that only one
-- of the two orders was ever exercised.
local racers = { ACTOR, THIRD }
for i = 1, 2 do
	local a, b = racers[i], racers[3 - i]
	local rb, rl = freshBoard()
	local ra = rb:submit("board", a, "47", T0)
	local rbres = rb:submit("board", b, "47", T0)
	check(`order {i}: exactly one of the two solved it`, (ra.ok and not rbres.ok) == true)
	check(`order {i}: neither correct answer is blamed`, ra.fault == false and rbres.fault == false)
	check(`order {i}: no misses recorded against either`, rl.misses[a] == nil and rl.misses[b] == nil)
end

-- A wrong answer arriving after somebody else has solved the line is still not
-- a miss, because the line is gone. The refusal is blameless for the same
-- reason, and must not be counted against a player who was simply mid-typo when
-- their friend finished.
local lateBoard, lateLine = freshBoard()
lateBoard:submit("board", ACTOR, "47", T0)
local late = lateBoard:submit("board", THIRD, "11", T0)
check("a wrong answer arriving after the solve is blameless too", late.fault == false)
check("and costs the late player no miss", lateLine.misses[THIRD] == nil)

print("")
print("having SEEN an answer disqualifies you, whoever holds it now")

-- R38. `submit` refused only the CURRENT holder. `PlayerAdded` re-deals the
-- whole board, so a join moved the line off the player who had just read the
-- number out — and the keypad then accepted it from them. `ok=true,
-- solved=true`, in two of three probe runs. The invariant this game is built on
-- is "the player who can SEE an answer may never be the player who ENTERS it",
-- and it was written as "is not the current holder", which is a different claim.

local joinBoard = Objectives.new()
local joinLine = joinBoard:add("board", "jack_number", "jack %s")

-- Deal to exactly one player so the reader is known, then re-deal to somebody
-- else, which is what a join does.
joinBoard:deal({ 7 })
check("(guard) player 7 was dealt the line", joinLine.holder == 7)
check("(guard) and is recorded as having seen it", joinLine.seenBy[7] == true)
local answer = joinLine.answer

joinLine.holder = 8
check("(guard) the line has moved to somebody else", joinLine.holder == 8)

local reader = joinBoard:submit("board", 7, answer, 1)
check("the player who read it cannot enter it", reader.ok == false)
check("...and is told why, not left guessing", reader.reason ~= nil and #(reader.reason :: string) > 0)
check("...and the line is not solved", joinLine.solved == false)

-- A wrong answer from a disqualified player must not cost them a jam either:
-- they are refused for who they are, not for what they typed.
check("...and it costs them no miss", (joinLine.misses[7] or 0) == 0)

-- The keep side. Somebody who never saw it can still solve it, or the fix has
-- simply broken the game.
local fresh = joinBoard:submit("board", 9, answer, 2)
check("a player who never saw the answer can still patch it", fresh.ok == true)
check("...and the line is solved", joinLine.solved == true)

-- Every player a re-deal has shown the line to accumulates, rather than the set
-- being overwritten by the latest holder.
local many = Objectives.new()
local manyLine = many:add("board", "jack_number", "jack %s")
many:deal({ 1 })
manyLine.solved = false
many:deal({ 2 })
manyLine.solved = false
many:deal({ 3 })
check("(guard) three players have been dealt it in turn", manyLine.holder == 3)
local seen = 0
for _ in manyLine.seenBy do
	seen += 1
end
check(`every reader is remembered, not just the last ({seen})`, seen == 3)
check("the first reader is still disqualified", many:submit("board", 1, manyLine.answer, 3).ok == false)
check("and the second", many:submit("board", 2, manyLine.answer, 4).ok == false)

-- And it is per ROUND: a new round re-rolls the answer, so last round's readers
-- are strangers to it again.
many:reset()
many:deal({ 4 })
check("(guard) a new round dealt it to somebody", manyLine.holder == 4)
check("last round's reader is no longer disqualified", many:submit("board", 1, manyLine.answer, 5).ok == true)

print("")
print("no number of re-deals can make a line unpatchable")

-- R47, and this is R38's own defect. That round made having SEEN an answer
-- disqualify you, which closed a real hole: a join used to move the line off the
-- reader and let them type in the number they had just read out.
--
-- But `PlayerAdded` re-deals the whole board, so every join burned one more
-- reader per line. Simulated over four players with one of them rejoining:
--
--   deal 1  seenBy board=1 breaker=1   0 stuck
--   deal 4  seenBy board=3 breaker=3   0 stuck
--   deal 5  seenBy board=4 breaker=4   2 STUCK
--
-- At that point four players are in the server and nobody can patch anything.
-- `allSolved` can never become true, so the round never ends, so `reset` never
-- runs, so `seenBy` is never cleared. Permanent.
--
-- Five joins in a round is ordinary: one player with a bad connection does it.

local function freshBoard()
	local board = Objectives.new()
	for _, station in Round.STATIONS do
		board:add(station.id, station.concept, station.prompt)
	end
	return board
end

local function unpatchable(board, present: { number }): number
	local count = 0
	for _, objective in board.list do
		if objective.solved then
			continue
		end
		local ableSomebody = false
		for _, userId in present do
			if not objective.seenBy[userId] then
				ableSomebody = true
				break
			end
		end
		if not ableSomebody then
			count += 1
		end
	end
	return count
end

local roster = { 1, 2, 3, 4 }
local churned = freshBoard()
check(`(guard) the board has lines to deal ({#churned.list})`, #churned.list >= 2)

for _ = 1, 30 do
	churned:deal(roster)
end
check(
	`thirty re-deals leave every line patchable ({unpatchable(churned, roster)} stuck)`,
	unpatchable(churned, roster) == 0
)

-- The mechanism: the seen set stops growing once somebody has read the line,
-- because a re-deal prefers a reader who has already seen it.
for _, objective in churned.list do
	local seen = 0
	for _ in objective.seenBy do
		seen += 1
	end
	check(`'{objective.id}' burned exactly one reader, not one per deal ({seen})`, seen == 1)
end

-- And R38's rule still holds: whoever HAS seen it still cannot patch it.
local guarded = freshBoard()
guarded:deal(roster)
for _, objective in guarded.list do
	local reader = objective.holder :: number
	check(`(guard) '{objective.id}' has a reader`, reader ~= nil)
	check(
		`the reader of '{objective.id}' still cannot patch it`,
		guarded:submit(objective.id, reader, objective.answer, 1).ok == false
	)

	local other: number? = nil
	for _, userId in roster do
		if userId ~= reader then
			other = userId
			break
		end
	end
	check(`(guard) somebody else is present for '{objective.id}'`, other ~= nil)
	if other then
		check(
			`somebody who never saw '{objective.id}' still can`,
			guarded:submit(objective.id, other, objective.answer, 2).ok == true
		)
	end
end

-- A growing server must not reintroduce it either: joins add unseen players,
-- and the preference must not start handing lines to them instead.
local growing = freshBoard()
local present = { 1, 2 }
for join = 3, 10 do
	growing:deal(present)
	table.insert(present, join)
end
growing:deal(present)
check(
	`a server that grew to {#present} still has every line patchable ({unpatchable(growing, present)} stuck)`,
	unpatchable(growing, present) == 0
)

print("")
print("a round nobody can finish is recognised as lost")

-- R48. R23 made the Operator take everyone in a room at once and R16 made being
-- connected cost you the ability to act. Three of four caught in one arrival
-- leaves a survivor who is ALWAYS the reader of one of the two lines, so that
-- line can be patched by nobody: `allSolved` unreachable. And `allTaken` needs
-- the survivor caught too, which they can avoid. The round ended neither way
-- and ran forever -- there is no timer, `RoundLength` is still unread.

local stranding = Objectives.new()
for _, station in Round.STATIONS do
	stranding:add(station.id, station.concept, station.prompt)
end
local four = { 1, 2, 3, 4 }
stranding:deal(four)
check(`(guard) the board dealt its lines ({#stranding.list})`, #stranding.list >= 2)
check("with everybody able, no line is stranded", stranding:stranded(four) == nil)

-- Everyone except one reader is taken.
local strandedReader = stranding.list[1].holder :: number
local onlyReaderLeft = { strandedReader }
check("a survivor who has read a line strands it", stranding:stranded(onlyReaderLeft) == stranding.list[1])

-- R149, PT4's shape: the survivor can still enter the OTHER lines, and the round
-- is lost anyway, because the way out needs every line restored.
check(
	"(guard) the survivor has not read another line",
	stranding.list[2].seenBy[strandedReader] == nil and not stranding.list[2].solved
)
check(
	"one line nobody free may enter strands the round, however many others they could",
	stranding:stranded(onlyReaderLeft) ~= nil
)
-- ...and restoring those others changes nothing: the held line is still there.
stranding.list[2].solved = true
check("...with the others restored too", stranding:stranded(onlyReaderLeft) == stranding.list[1])
stranding.list[2].solved = false

-- The exact shape the probe found: one line, its reader the only one able.
local single = Objectives.new()
local onlyLine = single:add("board", "jack_number", "jack %s")
single:deal({ 7 })
check(`(guard) player 7 read it`, onlyLine.seenBy[7] == true)
check("nobody able who has not read it strands it", single:stranded({ 7 }) == onlyLine)
check("...but somebody who never read it can enter it", single:stranded({ 7, 8 }) == nil)
check("an empty room can enter nothing", single:stranded({}) == onlyLine)

-- A solved board strands nothing: there is nothing left to enter because it is
-- restored. The win (the way out) is checked first anyway.
local won = Objectives.new()
local wonLine = won:add("board", "jack_number", "jack %s")
won:deal({ 1 })
won:submit("board", 2, wonLine.answer, 1)
check("(guard) the board is finished", won:allSolved())
check("a finished board strands no line", won:stranded({ 1 }) == nil)
check("...which is why the win is checked first", won:allSolved() == true)

print("")
print("every refusal is a refusal (R98 mutation sweep)")

-- R98. A scripted sweep flipped `ok = false` to `ok = true` on four refusal
-- paths and the whole suite passed. The server only sends the keypad note when
-- `not result.ok`, so any of those flips makes the keypad silently swallow the
-- attempt: no "that line is dead", no jam countdown.
do
	local b = Objectives.new()
	local line = b:add("board", "jack_number", "Patch line to jack %s")
	b:deal({ HOLDER })
	line.holder = HOLDER
	line.seenBy = { [HOLDER] = true }
	local refusals = {
		["no such objective"] = b:submit("nowhere", ACTOR, "00", T0),
		["the holder"] = b:submit("board", HOLDER, line.answer, T0),
	}
	line.seenBy = {}
	refusals["the holder, unseen"] = b:submit("board", HOLDER, line.answer, T0)
	local wrong = if line.answer == "00" then "11" else "00"
	for n = 1, Config.GuessesBeforeLockout do
		refusals[`wrong answer {n}`] = b:submit("board", ACTOR, wrong, T0)
	end
	refusals["while jammed"] = b:submit("board", ACTOR, line.answer, T0 + 0.5)
	for name, result in refusals do
		check(`refusal '{name}' is not ok ({result.reason})`, result.ok == false and result.reason ~= nil)
	end
	check(
		"(guard) the jam really was reached",
		string.find(refusals["while jammed"].reason or "", "jammed", 1, true) ~= nil
	)
	b:submit("board", THIRD, line.answer, T0)
	local late = b:submit("board", ACTOR, line.answer, T0 + 999)
	check("refusal 'already restored' is not ok", late.ok == false and late.reason == "already restored")
end

print("")
print("a re-dealt line counts as seen by whoever it was re-dealt to")

-- R98. `redealOrphans` marking `seenBy[to]` was untested: without it, a player
-- handed an orphaned line reads the number, leaves, rejoins after it has been
-- re-dealt again, and enters the number they were shown -- solving a line alone.
do
	local b = Objectives.new()
	local line = b:add("board", "jack_number", "Patch line to jack %s")
	b:deal({ HOLDER })
	b:redealOrphans({ ACTOR }) -- the holder left; ACTOR is shown the number
	check("(guard) the orphan went to the player present", line.holder == ACTOR)
	b:redealOrphans({ THIRD }) -- ACTOR left too
	check("(guard) and moved on when they left", line.holder == THIRD)
	local back = b:submit("board", ACTOR, line.answer, T0) -- ACTOR rejoins
	check("the player it was re-dealt to cannot enter it", back.ok == false and line.solved == false)
end

print("")
print("an empty board is not a won round")
check("allSolved is false with no objectives", Objectives.new():allSolved() == false)

print("")
print("who may enter a code, RUN rather than grepped (R114)")

do
	local Station = rt.require(rt.systems.Station)
	local Layout = rt.require(rt.shared.Layout)
	local at = { x = 0, z = 0 }
	local near = { x = 1, z = 0 }
	local far = { x = Config.StationReach + 5, z = 0 }
	local desk = Station.new()
	desk:open(1, "board")
	local function gate(playing, onLine, standing, stationAt, who: number?)
		return desk:gate(who or 1, "board", playing, onLine, standing, stationAt)
	end
	check("(guard) near really is within reach", Layout.within(at, near, Config.StationReach))
	check("a player at the keypad they opened may enter", gate(true, false, near, at) == nil)
	local over = gate(false, false, near, at)
	check("a finished round refuses", over ~= nil and over.reason == "the round is over" and not over.busy)
	local caught = gate(true, true, near, at)
	check("a player on the line refuses", caught ~= nil and caught.reason == "you are on the line" and not caught.busy)
	local away = gate(true, false, far, at)
	check(
		"a player out of reach refuses, quietly",
		away ~= nil and away.reason == "you are not at that station" and not away.busy
	)
	local bodiless = gate(true, false, nil, at)
	check("a player with no body refuses", bodiless ~= nil and bodiless.reason == "you are not at that station")
	local probe = gate(true, false, near, at, 2)
	check(
		"a keypad never opened refuses AND the Operator says busy",
		probe ~= nil and probe.busy == true and probe.reason == "you are not at that station"
	)
	local order = gate(false, true, far, at, 2)
	check("the round being over is said first", order ~= nil and order.reason == "the round is over")
end

print("")
print("the Submit cooldown (R116)")
do
	local Station = rt.require(rt.systems.Station)
	local desk = Station.new()
	local t = 100
	check("a first submission is paced through", desk:tryPace(1, t))
	check("a second inside the cooldown is refused", not desk:tryPace(1, t + Station.SUBMIT_COOLDOWN / 2))
	check("(control) another player is not held up by it", desk:tryPace(2, t + 0.1))
	check("after the cooldown it goes through", desk:tryPace(1, t + Station.SUBMIT_COOLDOWN))
	desk:forget(1)
	check(
		"a player who left and came back is not still cooling down",
		desk:tryPace(1, t + Station.SUBMIT_COOLDOWN + 0.1)
	)
end

Kit.finish()
