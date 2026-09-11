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
local Lexicon = rt.require(rt.shared.Lexicon)

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

print("")
print("a repeated word is offered once, not once per repetition")

-- R69. A mutation sweep removed novelTerms' de-dup (`if not seen[term] then`)
-- and NOTHING in the whole suite noticed, even though it changes real game
-- balance: `Operator.credit` iterates `obs.terms` and adds
-- `Config.HeatPerCredit` for EVERY entry, so a duplicate term in the returned
-- list burns that coinage twice as fast for one utterance that merely repeats
-- a word -- silently doubling the learning rate R4's own dial is tuned around.
local repeatedWord = Heuristic.novelTerms(utterance("the gizmo and the gizmo again"), {})
local gizmoCount = 0
for _, term in repeatedWord do
	if term == "gizmo" then
		gizmoCount += 1
	end
end
check(`(guard) the repeated word was offered at all ({gizmoCount})`, gizmoCount > 0)
check("...but only once, however many times it was said", gizmoCount == 1)

local repeatedPhrase = Heuristic.novelTerms(utterance("the blue one the blue one"), {})
local phraseCount = 0
for _, term in repeatedPhrase do
	if term == "blue one" then
		phraseCount += 1
	end
end
check("a repeated TWO-WORD phrase is also offered once", phraseCount == 1)

-- The property that actually matters: crediting a repeated word must not
-- out-burn a word said once, for the same eventual solve.
local pool = Round.dealSecrets(5)
local secret = pool[1]
local opOnce = Operator.new({ secret })
opOnce:hear({ speaker = { UserId = 1 } :: any, text = "the gizmo", at = 0 })
opOnce:credit(secret.concept, 1)

local opTwice = Operator.new({ secret })
opTwice:hear({ speaker = { UserId = 1 } :: any, text = "the gizmo and the gizmo", at = 0 })
opTwice:credit(secret.concept, 1)

local function heatFor(op: any, phrase: string): number
	for _, c in op:snapshot() do
		if c.phrase == phrase then
			return c.heat
		end
	end
	return 0
end
check(
	`saying "gizmo" twice in one sentence heats it no faster than saying it once ({heatFor(opOnce, "gizmo")} vs {heatFor(
		opTwice,
		"gizmo"
	)})`,
	heatFor(opOnce, "gizmo") == heatFor(opTwice, "gizmo")
)

print("")
print("a respelled giveaway is still a giveaway")

-- R83, measured against the real reader. Before: 0 of 30. Reversal ("kcaj") is
-- deliberately NOT normalised -- whether a word two players agree to read
-- backwards is shared context is filed as a design question -- so it is kept
-- here as a (recorded) row, not asserted either way.
local respellPool = Round.dealSecrets(99)
local respelled = { spaced = 0, dotted = 0, dashed = 0, leet = 0, stretched = 0 }
local offered = 0
for _, secret in respellPool do
	local w = secret.plain[1]
	offered += 1
	local forms = {
		spaced = table.concat(string.split(w, ""), " "),
		dotted = table.concat(string.split(w, ""), "."),
		dashed = table.concat(string.split(w, ""), "-"),
		leet = (string.gsub(string.gsub(string.gsub(w, "a", "4"), "e", "3"), "o", "0")),
		stretched = (string.gsub(w, "(%a)$", "%1%1%1")),
	}
	for kind, text in forms do
		if #Heuristic.conveyed(utterance(`it's the {text}`), { secret }, {}) > 0 then
			respelled[kind] += 1
		end
	end
end
check(`(guard) every secret in the pool was respelled ({offered})`, offered >= 5)
for _, kind in { "spaced", "dotted", "dashed", "leet", "stretched" } do
	check(`a {kind} giveaway is understood ({respelled[kind]} of {offered})`, respelled[kind] == offered)
end

-- The fix must not make the Operator hear things nobody said.
local ordinaryChat = {
	"i think u r right about that",
	"a b testing is fun",
	"gg wp",
	"the answer is 42",
	"room 404 is empty",
	"go 2 the left",
	"lol ok",
	"i am so tired",
	"wait for me",
	"ha ha ha",
	"hmmm let me think",
	"its 3am",
	"l8r",
	"what is up",
	"b4 we go",
}
local falseHits: { string } = {}
for _, text in ordinaryChat do
	if #Heuristic.conveyed(utterance(text), respellPool, {}) > 0 then
		table.insert(falseHits, text)
	end
end
check(`ordinary chat is not mistaken for a giveaway ({#falseHits} of {#ordinaryChat})`, #falseHits == 0)
if #falseHits > 0 then
	print(`        misheard: {table.concat(falseHits, " / ")}`)
end

print("")
print("a word split into chunks is still the word")

-- R84: "ja ck", "j a ck", "j4 ck" arrived as tokens that each matched nothing.
-- Adjacent tokens are glued for SINGLE-word terms only.
local chunkPool = Round.dealSecrets(99)
local jackSecret
for _, secret in chunkPool do
	if secret.concept == "jack_number" then
		jackSecret = secret
	end
end
check("(guard) the jack secret is in the pool", jackSecret ~= nil)
if jackSecret then
	for _, text in { "the ja ck", "the j a ck", "the j4 ck", "the j 4 c k", "the j@ck" } do
		check(`'{text}' is understood`, #Heuristic.conveyed(utterance(text), { jackSecret }, {}) > 0)
	end
end

-- Gluing must never let two words satisfy a MULTI-word coinage out of order,
-- or turn ordinary neighbours into a giveaway nobody said.
local gluedChat = {
	"come on guys hurry",
	"no way thats crazy",
	"can you hear me",
	"where are you",
	"run run run",
	"is anyone there",
	"the code is 4 2",
	"type 7 3",
	"on my way",
	"be right back",
	"a sub way",
	"in side the room",
	"no body move",
	"the red one",
	"go go go",
	"my mic is broken",
	"email me @ home",
	"that costs $5",
	"look @ that",
	"the a b c song",
	"x y z",
}
local gluedHits: { string } = {}
for _, text in gluedChat do
	if #Heuristic.conveyed(utterance(text), chunkPool, {}) > 0 then
		table.insert(gluedHits, text)
	end
end
check(`gluing neighbours adds no false giveaways ({#gluedHits} of {#gluedChat})`, #gluedHits == 0)
if #gluedHits > 0 then
	print(`        misheard: {table.concat(gluedHits, " / ")}`)
end

-- (control) R15's rule still holds with gluing on: a burned two-word coinage is
-- not understood inside a longer word.
local blue = {
	phrase = "the blue",
	concept = jackSecret and jackSecret.concept or "jack_number",
	heat = 1,
	sightings = 9,
	coinedBy = 1,
}
check(
	"(control) 'check the bluetooth' still does not match the coinage 'the blue'",
	#Heuristic.conveyed(utterance("check the bluetooth"), { jackSecret }, { blue }) == 0
)
check(
	"(control) ...while 'the blue' itself still does",
	#Heuristic.conveyed(utterance("it is the blue one"), { jackSecret }, { blue }) > 0
)

print("")
print("a plain word is understood in its own inflections")

-- R85, and item 2 of R17's filed "stemming pair". Every plain word ending in e
-- stemmed differently from its own plural and -ing form, so "the fuses", "the
-- names", "leaving now" and "escaping" were free to say. R17 filed it because
-- any single suffix rule is wrong one way; matching on ANY reading of the word
-- needs no single rule. Derived from the live pool, so a new plain word is
-- covered the day it is added.
local inflPool = Round.dealSecrets(99)
local inflected, understoodInfl = 0, 0
local missedInfl: { string } = {}
for _, secret in inflPool do
	for _, w in secret.plain do
		local plural = if string.match(w, "[sxz]$") or string.match(w, "[cs]h$") then w .. "es" else w .. "s"
		for _, form in { plural } do
			inflected += 1
			if #Heuristic.conveyed(utterance(`the {form}`), { secret }, {}) > 0 then
				understoodInfl += 1
			else
				table.insert(missedInfl, form)
			end
		end
	end
end
check(`(guard) every plain word was inflected ({inflected})`, inflected >= 30)
check(`every plain word is understood in the plural ({understoodInfl} of {inflected})`, understoodInfl == inflected)
if #missedInfl > 0 then
	print(`        missed: {table.concat(missedInfl, ", ")}`)
end
for _, text in { "leaving now", "they are escaping", "the numbering", "check the fuses", "read the names" } do
	check(`'{text}' is understood`, #Heuristic.conveyed(utterance(text), inflPool, {}) > 0)
end

-- The wider net must not hear words that only LOOK like a plain word.
local lookalikes = {
	"dont make a fuss",
	"thats the boss",
	"pass it",
	"no fuss",
	"the glasses",
	"i miss you",
	"less talking",
	"the buses are late",
	"open the boxes",
	"my notes say so",
}
local misheard: { string } = {}
for _, text in lookalikes do
	if #Heuristic.conveyed(utterance(text), inflPool, {}) > 0 then
		table.insert(misheard, text)
	end
end
check(`lookalike words are not giveaways ({#misheard} of {#lookalikes})`, #misheard == 0)
if #misheard > 0 then
	print(`        misheard: {table.concat(misheard, " / ")}`)
end

print("")
print("a burned coinage is still heard in the plural")

-- R86, and item 3 of R17's filed "stemming pair". Multi-word coinages were
-- matched as exact joined stems, so a group's own "blue wire" at heat 1.0
-- stopped working the moment somebody said "blue wires" -- while the Lexicon
-- panel still showed it burned. Minted the way the game mints them: as stems.
local coinPool = Round.dealSecrets(99)
local coinSecret = coinPool[1]
local function minted(words: string)
	return {
		phrase = table.concat(Lexicon.stemAll(Lexicon.tokenize(words)), " "),
		concept = coinSecret.concept,
		heat = 1,
		sightings = 9,
		coinedBy = 1,
	}
end
local function heardAs(text: string, coin): number
	local r = Heuristic.conveyed(utterance(text), { coinSecret }, { coin })
	return if #r > 0 then r[1].confidence else 0
end
for _, case in
	{
		{ "blue wire", "the blue wires" },
		{ "blue wire", "blue wires please" },
		{ "fuse closet", "the fuses closet" },
		{ "gathering spot", "gather spot" },
	}
do
	check(`coinage '{case[1]}' is heard in '{case[2]}'`, heardAs(case[2], minted(case[1])) == 1)
end

-- R15's rule must survive: whole words, adjacent, in order.
local blue = minted("the blue")
check("(control) 'check the bluetooth' is not 'the blue'", heardAs("check the bluetooth", blue) == 0)
check("(control) 'someone blue' is not 'one blue'", heardAs("someone blue", minted("one blue")) == 0)
check("(control) 'the big redhead' is not 'big red'", heardAs("the big redhead", minted("big red")) == 0)
check("the words must be in order: 'wire blue' is not 'blue wire'", heardAs("the wire blue", minted("blue wire")) == 0)
check("...and adjacent: 'blue and wire' is not 'blue wire'", heardAs("blue and wire", minted("blue wire")) == 0)
check("(control) the exact phrase still is", heardAs("the blue wire", minted("blue wire")) == 1)

print("")
print("a codeword said both ways is learned as one")

-- R87. Matching treated "blue wire" and "blue wires" as one phrase (R86), but
-- learning looked coinages up by exact text, so alternating the two minted two
-- rows at 0.50 each -- under the act threshold -- where four uses of either
-- spelling reach 1.00. Varying the plural kept a codeword unlearned for free.
local learnPool = Round.dealSecrets(99)
local learnSecret = learnPool[1]
local function learnFrom(lines: { string })
	local op = Operator.new({ learnSecret })
	for t, line in lines do
		op:hear({ speaker = { UserId = 1 } :: any, text = line, at = t })
		op:credit(learnSecret.concept, t)
	end
	return op:snapshot()
end
local function rowsFor(snapshot, needle: string)
	local found = {}
	for _, c in snapshot do
		if c.phrase == needle or Lexicon.samePhrase(c.phrase, needle) then
			table.insert(found, c)
		end
	end
	return found
end
local mixedLearn = learnFrom({ "the blue wire", "the blue wires", "the blue wire", "the blue wires" })
local mixedRows = rowsFor(mixedLearn, "blue wire")
check(`alternating singular and plural leaves ONE row ({#mixedRows})`, #mixedRows == 1)
check(
	`...burned as fully as saying it one way ({mixedRows[1] and mixedRows[1].heat or 0})`,
	mixedRows[1] ~= nil and mixedRows[1].heat == 1
)
check("...under the spelling first said", mixedRows[1] ~= nil and mixedRows[1].phrase == "blue wire")

-- (control) genuinely different codewords must stay separate.
local twoCodes = learnFrom({ "the blue wire", "the blue box", "the blue wire", "the blue box" })
check(
	"(control) 'blue wire' and 'blue box' stay two rows",
	#rowsFor(twoCodes, "blue wire") == 1 and #rowsFor(twoCodes, "blue box") == 1
)

-- R88. R87's plant C survived: nothing checked that a phrase meaning one
-- secret is not merged into a same-sounding coinage for ANOTHER secret. Two
-- secrets, "blue wire" credited to the first, "blue wires" to the second.
local crossA, crossB = learnPool[1], learnPool[2]
local crossOp = Operator.new({ crossA, crossB })
crossOp:hear({ speaker = { UserId = 1 } :: any, text = "the blue wire", at = 1 })
crossOp:credit(crossA.concept, 1)
crossOp:hear({ speaker = { UserId = 1 } :: any, text = "the blue wires", at = 2 })
crossOp:credit(crossB.concept, 2)
local crossConcepts = {}
for _, c in rowsFor(crossOp:snapshot(), "blue wire") do
	crossConcepts[c.concept] = true
end
check(
	"a plural naming a DIFFERENT secret is its own coinage",
	crossConcepts[crossA.concept] == true and crossConcepts[crossB.concept] == true
)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
