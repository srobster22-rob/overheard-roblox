--!strict
-- Headless tests for the comprehension backend. Run: lune run tests/heuristic
--
-- THE CLASS OF BUG THIS FILE GUARDS: the Operator understanding a phrase the
-- player did not say, because the matcher looked for a substring instead of
-- words. Until R15 a burned multi-word coinage matched anywhere inside the
-- utterance's joined stems, so "check the bluetooth" conveyed the coinage
-- "the blue" at confidence 1.0 and the monster moved. The panel gives the
-- player no way to see why, which is what makes it worse than a miss.
--
-- Why this file did not exist before R15: `Heuristic` decides what the monster
-- understood and had no test that counts a check. `tests/lexicon.luau` covers
-- the text layer under it and `tests/operator.luau` covers acquisition above
-- it; the decision in between was unguarded for fourteen rounds.
--
-- Everything here goes through `Heuristic.understand`, the function the game
-- actually calls, rather than an exported helper -- a private matcher tested
-- directly can be correct while the caller stops using it.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Heuristic = rt.require(rt.systems.Heuristic)
local Round = rt.require(rt.systems.Round)

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

-- One secret, taken from the real pool rather than invented, so a change to
-- `plain` cannot leave this file testing a concept the game no longer deals.
local CONCEPT = "jack_number"
local secrets = {}
for _, s in Round.dealSecrets(5) do
	if s.concept == CONCEPT then
		table.insert(secrets, s)
	end
end
check("the real secret pool still carries the concept under test (guard)", #secrets == 1)

local fakePlayer = { UserId = 1, Name = "A" } :: any
local function utterance(text: string)
	return { speaker = fakePlayer, text = text, at = 0 } :: any
end
local function coinage(phrase: string, heat: number)
	return { phrase = phrase, concept = CONCEPT, heat = heat, sightings = 4, coinedBy = 1 } :: any
end

local function confidenceFor(text: string, phrase: string): number
	return Heuristic.understand(utterance(text), secrets, { coinage(phrase, 1.0) }).confidence
end

print("a burned coinage is understood when it is actually said")
-- The keep side. A boundary rule that rejected these would be worse than the
-- bug: the coinage the group worked for would stop working.
check("said exactly", confidenceFor("the blue one", "blue one") == 1)
check("said mid-sentence", confidenceFor("go stand by the blue one now", "blue one") == 1)
check("said at the very start", confidenceFor("blue one is what i meant", "blue one") == 1)
check("said at the very end", confidenceFor("i mean the blue one", "blue one") == 1)
check("through the stemmer, plural for singular", confidenceFor("the blue ones", "blue one") == 1)
check("a stopword-bearing bigram still works", confidenceFor("check the blue please", "the blue") == 1)

print("but NOT inside a longer word")
-- Each of these was probed at confidence 1.00 before R15.
check("the phrase's tail is a prefix of a longer token", confidenceFor("the blue oneself", "blue one") == 0)
check("and again, on a real English word", confidenceFor("check the bluetooth", "the blue") == 0)
-- Deliberately NOT "the board is finest": `board` is plain language for this
-- concept, so that sentence is understood for a legitimate reason and the
-- check would pass with the bug still in place.
check("and again", confidenceFor("the wire is finest", "is fine") == 0)
check("the phrase's head is a suffix of a longer token", confidenceFor("someone blue", "one blue") == 0)
check("both ends at once", confidenceFor("someone blueness", "one blue") == 0)
check("a real one a group would hit", confidenceFor("the big redhead", "big red") == 0)

print("the words must still be adjacent and in order")
check("out of order does not match", confidenceFor("one blue", "blue one") == 0)
check("split by another word does not match", confidenceFor("the blue big one", "blue one") == 0)

print("degenerate coinages convey nothing")
-- Probed in R15's shortlist item 4: a phrase that stems to nothing must not
-- match everything. `matchesAny` skips an empty stem list; this holds it there.
check("an empty phrase", confidenceFor("hello there friend", "") == 0)
check("a phrase with no word characters", confidenceFor("hello there friend", "!!") == 0)
check("a single stopword", confidenceFor("hello there friend", "the") == 0)

print("heat still scales confidence, and zero heat conveys nothing")
-- The neutrality claim R14's removal rests on, asserted here with a hot
-- control beside it so it cannot pass vacuously.
check("a half-heated coinage is understood by half", confidenceFor("the blue one", "blue one") == 1)
local half = Heuristic.understand(utterance("the blue one"), secrets, { coinage("blue one", 0.5) })
check("a coinage at heat 0.5 lands at confidence 0.5", half.confidence == 0.5)
local cold = Heuristic.understand(utterance("the blue one"), secrets, { coinage("blue one", 0) })
check("a coinage at heat 0 conveys nothing", cold.confidence == 0 and cold.concept == nil)

print("plain language is unaffected")
-- Single-word plain terms go through `Lexicon.contains`, which compares whole
-- stems, so the boundary bug never touched them. Asserted rather than assumed,
-- because the fix edits the function both paths share.
local plain = Heuristic.understand(utterance("patch the jack"), secrets, {})
check("a plain giveaway is understood", plain.confidence == 1 and plain.concept == CONCEPT)
local nearPlain = Heuristic.understand(utterance("bring the jackhammer"), secrets, {})
check("a longer word containing a plain term is not", nearPlain.confidence == 0)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
