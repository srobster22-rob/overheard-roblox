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

-- A BURNED COINAGE MUST MATCH THE SENTENCE THAT MINTED IT -------------------
--
-- Coinages are stored ALREADY STEMMED, and `matchesAny` used to stem every
-- candidate again. `Lexicon.stem` is not idempotent — `gathering -> gather ->
-- gath` — so a coinage minted from any `-ing` word whose stem ends in `-er`
-- could never match anything, while the Lexicon panel showed it at 100% burned.
-- Players read that panel to decide what is still safe to say, so it was
-- telling them to abandon codewords that still worked.
--
-- The round trip is the assertion: mint through the real Operator, then feed
-- the SAME sentence back. Anything a coinage was born from, it must recognise.

print("")
print("a burned coinage matches the sentence that minted it")

local Operator = rt.require(rt.systems.Operator)

local MINTED = "everyone to the gathering spot"
local roundTripSecrets = { { concept = "exit", plain = { "exit", "stair" }, payload = "archive" } }
local op = Operator.new(roundTripSecrets)
local speaker = { UserId = 1 } :: any
for i = 1, 6 do
	op:hear({ speaker = speaker, text = MINTED, at = i })
	op:credit("exit", i + 0.5)
end

local burned = {}
for _, coinage in op:snapshot() do
	if coinage.heat >= 1 and string.find(coinage.phrase, " ", 1, true) then
		table.insert(burned, coinage)
	end
end
-- Without this the loop below can pass by iterating nothing.
check(`(guard) the sentence minted burned multi-word coinages ({#burned})`, #burned >= 2)

local dead = {}
for _, coinage in burned do
	-- Each one ALONE, so a unigram from the same sentence cannot carry it.
	local seen = Heuristic.understand({ speaker = speaker, text = MINTED, at = 99 }, roundTripSecrets, { coinage })
	if seen.confidence < 1 then
		table.insert(dead, coinage.phrase)
	end
end
check(`every burned coinage recognises its own sentence ({table.concat(dead, ", ")})`, #dead == 0)

-- The two that were actually dead, named, so a regression says which.
local function aloneMatches(phrase: string): number
	local coinage = { phrase = phrase, concept = "exit", heat = 1, sightings = 9 }
	return Heuristic.understand({ speaker = speaker, text = MINTED, at = 99 }, roundTripSecrets, { coinage }).confidence
end
check("'gather spot' matches 'the gathering spot'", aloneMatches("gather spot") == 1)
check("'the gather' matches it too", aloneMatches("the gather") == 1)

-- And the fix must not have made coinages match everything: a stored stem is
-- still compared on word boundaries, not as a substring (R15's defect).
check("a burned coinage still does not match an unrelated sentence", aloneMatches("purple lantern") == 0)
local wide = { phrase = "gather spot", concept = "exit", heat = 1, sightings = 9 }
local unrelated = Heuristic.understand(
	{ speaker = speaker, text = "the gathering place", at = 99 },
	roundTripSecrets,
	{ wide }
)
check("...nor a sentence missing half the phrase", unrelated.confidence == 0)

print("")
print("every giveaway in a sentence is heard, not just the loudest")

-- R40. `understand` returned ONE reading, so a sentence carrying plain
-- giveaways for two concepts gave away one and left the other free:
-- "the jack is right by the fuse" registered `jack_number` and nothing else,
-- while either word alone was understood. The combination hid one, and
-- Config's own comment says plain speech is ALWAYS punished.

local Operator = rt.require(rt.systems.Operator)

-- SEEDED. `Round.dealSecrets` shuffles with `math.random`, and an unseeded test
-- is a different test every run: `tests/soak.luau` stranded 6, 7 and 13 rounds
-- on three runs of identical code, and two log entries argued from single runs
-- of it. Nothing in THIS file's assertions depends on the shuffle today, which
-- is exactly why it would go unnoticed the day one does.
math.randomseed(11)

-- Two concepts from the real pool, so this cannot drift from what the game deals.
local pool = Round.dealSecrets(5)
local first, second
for _, secret in pool do
	if secret.concept == "jack_number" then
		first = secret
	elseif secret.concept == "breaker" then
		second = secret
	end
end
check("(guard) both concepts are in the real pool", first ~= nil and second ~= nil)

if first and second then
	local both = { first, second }
	local sentence = `the {first.plain[1]} is right by the {second.plain[2]}`

	-- Each alone, as a control: if these fail the sentence proves nothing.
	local aloneA = Heuristic.conveyed(utterance(`the {first.plain[1]}`), both, {})
	local aloneB = Heuristic.conveyed(utterance(`the {second.plain[2]}`), both, {})
	check("(control) the first word alone is understood", #aloneA == 1 and aloneA[1].concept == first.concept)
	check("(control) the second word alone is understood", #aloneB == 1 and aloneB[1].concept == second.concept)

	local together = Heuristic.conveyed(utterance(sentence), both, {})
	check(`both giveaways in one sentence are reported ({#together})`, #together == 2)

	local seen: { [string]: boolean } = {}
	for _, item in together do
		seen[item.concept :: string] = true
	end
	check("...the first among them", seen[first.concept] == true)
	check("...and the second", seen[second.concept] == true)
	check("both at full confidence, since both are plain", together[1].confidence == 1 and together[2].confidence == 1)

	-- Order is stable, so the Operator's first destination is not decided by how
	-- the pool happened to be shuffled.
	local again = Heuristic.conveyed(utterance(sentence), { second, first }, {})
	check("the reading order does not depend on the pool's order", again[1].concept == together[1].concept)

	-- R65. The check above only ever compares two EQUAL confidences (both are
	-- plain giveaways, both are 1), so it can only prove the TIE-BREAK and
	-- cannot tell "strongest first" from "weakest first" or from no rule at
	-- all. A mutation sweep flipped `a.confidence > b.confidence` to `<` and
	-- nothing here noticed. This gives the two DIFFERENT confidences: one plain
	-- (1) and one from a half-learned coinage (0.5), and asserts which comes
	-- first by name rather than by position alone.
	local halfLearned = {
		phrase = "the gizmo",
		concept = second.concept,
		heat = 0.5,
		sightings = 3,
		coinedBy = 0,
	}
	local mixedSentence = `the {first.plain[1]} and the gizmo`
	local mixed = Heuristic.conveyed(utterance(mixedSentence), both, { halfLearned })
	check(`(guard) both are reported ({#mixed})`, #mixed == 2)
	check("(guard) the plain giveaway is at full confidence", mixed[1].confidence == 1 or mixed[2].confidence == 1)
	check(
		"(guard) the coinage is at PARTIAL confidence, not full or zero",
		(mixed[1].confidence > 0 and mixed[1].confidence < 1) or (mixed[2].confidence > 0 and mixed[2].confidence < 1)
	)
	check("the stronger (plain) giveaway sorts first", mixed[1].concept == first.concept and mixed[1].confidence == 1)
	check(
		"...and the weaker (half-learned) one is second",
		mixed[2].concept == second.concept and mixed[2].confidence < 1
	)

	-- And the Operator ACTS on both: the first moves it, the second queues
	-- behind it under R36's commitment rule.
	local fired: { string } = {}
	local op = Operator.new(both)
	op.onUnderstood = function(concept: string)
		table.insert(fired, concept)
	end
	op:hear(utterance(sentence))
	check(`the Operator is told about both ({#fired})`, #fired == 2)

	-- The novel terms must still be counted ONCE, or a sentence conveying two
	-- concepts would credit its coinages twice and inflate their heat.
	local counting = Operator.new(both)
	counting:hear(utterance(`the {first.plain[1]} is by the {second.plain[2]} near the purple lantern`))
	check("(guard) the sentence offered novel terms", #counting.observations == 1)
	check("novel terms are recorded once per utterance, not once per concept", #counting.observations == 1)
end

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
