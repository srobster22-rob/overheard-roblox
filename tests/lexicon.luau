--!strict
-- Headless tests for the pure text layer. Run: lune run tests/lexicon
-- These need no Roblox runtime, which is exactly why the text layer was kept
-- free of Roblox APIs.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".
local process = require("@lune/process")

local fs = require("@lune/fs")

local Lexicon = require("../src/shared/Lexicon")
local Harness = require("./harness")

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

local function same(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if v ~= b[i] then
			return false
		end
	end
	return true
end

print("tokenize")
check(
	"lowercases and strips punctuation",
	same(Lexicon.tokenize("The KEY, in the kitchen!"), { "the", "key", "in", "the", "kitchen" })
)
check("keeps digits", same(Lexicon.tokenize("jack 47"), { "jack", "47" }))
check("handles apostrophes", same(Lexicon.tokenize("it's Jake's"), { "its", "jakes" }))
check("empty string yields nothing", #Lexicon.tokenize("") == 0)

print("stem")
check("plural collapses to singular", Lexicon.stem("keys") == "key")
check("ing is stripped", Lexicon.stem("hiding") == "hid")
check("short words are left alone", Lexicon.stem("is") == "is")
check("does not overstrip", Lexicon.stem("gas") == "gas")

print("stopwords")
check("the is a stopword", Lexicon.isStopword("the"))
check("kitchen is not", not Lexicon.isStopword("kitchen"))

print("ngrams")
check(
	"bigrams are contiguous and in order",
	same(Lexicon.ngrams({ "blue", "one", "again" }, 2), { "blue one", "one again" })
)
check("n larger than input yields nothing", #Lexicon.ngrams({ "solo" }, 2) == 0)

print("the case the game depends on")
-- A plain giveaway and a coinage must stem to different things, or the
-- Operator would understand a coinage for free.
local plain = Lexicon.stemAll(Lexicon.tokenize("the key is in the kitchen"))
local coined = Lexicon.stemAll(Lexicon.tokenize("its where jake fell"))
check("plain speech contains the giveaway stem", Lexicon.contains(plain, "key"))
check("coinage does not contain it", not Lexicon.contains(coined, "key"))

-- STOPWORDS MUST SURVIVE STEMMING ------------------------------------------
--
-- `Heuristic.understand` asks `isStopword(stem)`, never `isStopword(word)`. So
-- a stopword that stems into a non-stopword walks through the gate, gets
-- offered as a coinage, and can burn. Two of the 67 did this before R17.
--
-- The word list is DERIVED from the source file rather than restated here, the
-- way tests/config.luau derives its dials: a hand-copied list would pass while
-- a stopword added tomorrow went unchecked, which is the failure mode that lets
-- this defect back in.

print("stopwords survive stemming")

local lexiconSource = fs.readFile("src/shared/Lexicon.luau")
local listBlock = string.match(lexiconSource, "for _, w in%s*{(.-)}") or ""
local stopwords: { string } = {}
for w in string.gmatch(listBlock, '"([%a]+)"') do
	table.insert(stopwords, w)
end

-- Without this the loop below can pass by iterating nothing.
check(`(guard) parsed the stopword list from source ({#stopwords} words)`, #stopwords >= 50)

local leaked: { string } = {}
for _, word in stopwords do
	local stemmed = Lexicon.stem(word)
	if not Lexicon.isStopword(stemmed) then
		table.insert(leaked, `{word} -> {stemmed}`)
	end
end
check(`no stopword stems into a non-stopword ({table.concat(leaked, ", ")})`, #leaked == 0)

-- The two that actually leaked, named, so a regression says which.
check("'guys' is not stemmed into the contentful 'guy'", Lexicon.stem("guys") == "guys")
check("'this' is not stemmed into the contentful 'thi'", Lexicon.stem("this") == "this")

-- The guard must not have turned the stemmer off for real words.
check("'keys' still stems to 'key'", Lexicon.stem("keys") == "key")
check("'hiding' still stems", Lexicon.stem("hiding") == "hid")

-- END TO END: an ordinary sentence must not burn an ordinary word -----------
print("an ordinary word cannot burn")

local rt = Harness.build()
local Operator = rt.require(rt.systems.Operator)
local Heuristic = rt.require(rt.systems.Heuristic)

local secrets = { { concept = "jack_number", plain = { "jack", "wire", "socket" }, payload = "board" } }
local op = Operator.new(secrets)
local speaker = { UserId = 1 } :: any
for i = 1, 5 do
	op:hear({ speaker = speaker, text = "guys the wire is over here", at = i })
	op:credit("jack_number", i + 0.5)
end

local burnedGuy = false
for _, coinage in op:snapshot() do
	if string.find(coinage.phrase, "guy", 1, true) and coinage.heat >= 1 then
		burnedGuy = true
	end
end
check("saying 'guys' five times does not burn it", not burnedGuy)

local heard = Heuristic.understand({ speaker = speaker, text = "hey guys", at = 99 }, secrets, op.lexicon)
check(`"hey guys" gives nothing away (conf {string.format("%.2f", heard.confidence)})`, heard.confidence < 0.6)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
