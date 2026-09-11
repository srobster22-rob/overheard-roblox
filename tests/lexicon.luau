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

print("")
print("respellings are tokenized as the word they spell")

-- R83. A giveaway spelled out ("j a c k", "j.a.c.k", "j-a-c-k"), leeted
-- ("j4ck") or stretched ("jackkk") reached the Operator as tokens that matched
-- nothing: 0 of 30 understood across the whole pool. GAME.md says only shared
-- context defeats it, and a respelling is not that.
local function toks(text: string): string
	return table.concat(Lexicon.tokenize(text), "|")
end
check("spaced letters rejoin", toks("the j a c k") == "the|jack")
check("dotted letters rejoin", toks("the j.a.c.k") == "the|jack")
check("dashed letters rejoin", toks("the j-a-c-k") == "the|jack")
check("leet unscrambles a token that mixes letters and digits", toks("j4ck") == "jack")
check("a letter held three times collapses", toks("jackkk") == "jack")

-- What must NOT change.
check("an all-digit token -- every answer in this game -- is left alone", toks("jack 42 07 777") == "jack|42|07|777")
check("two single letters are ordinary chat, not a spelling", toks("u r right") == "u|r|right")
check("a real double letter survives", toks("door street book") == "door|street|book")
check(
	"(control) an ordinary sentence tokenizes exactly as before",
	toks("meet me by the purple lantern") == "meet|me|by|the|purple|lantern"
)

print("")
print("mixed respellings tokenize as the word they spell")

-- R84: a leet digit inside a spelled-out run, and @ / $ standing in for letters.
check("a leet digit inside a spelled-out run is joined", toks("the j 4 c k") == "the|jack")
check("...dotted too", toks("the j.4.c.k") == "the|jack")
check("@ touching a letter reads as a", toks("the j@ck") == "the|jack")
check("$ touching a letter reads as s", toks("bre$k") == "bresk")
-- What must NOT change: an answer spelled out digit by digit has no letters,
-- so it is never joined into a word or un-leeted.
-- Every digit here is a LEET digit, so the run genuinely reaches the letters
-- rule. The first version used "4 2 7" -- 2 is not in the table, the run broke
-- before the rule was reached, and a plant removing the rule passed.
check("an answer spelled out digit by digit is left alone", toks("type 4 3 7") == "type|4|3|7")
check("a lone @ or $ is not turned into a letter", toks("look @ it for $ 5") == "look|it|for|5")

print("")
print("a word ending in ss is not a plural")

-- R85: stripping the last s off "fuss" made it the same stem as "fuses", and
-- "don't make a fuss" moved the Operator to the breaker.
check("fuss keeps its ss", Lexicon.stem("fuss") == "fuss")
check("address keeps its ss", Lexicon.stem("address") == "address")
check("...and addresses still stems to it", Lexicon.stem("addresses") == "address")
check("(control) an ordinary plural still loses its s", Lexicon.stem("doors") == "door")
check("(control) fuses still stems as before", Lexicon.stem("fuses") == "fus")

print("")
print("readings reconcile a word with its own inflections")
local function meets(a: string, b: string): boolean
	for _, x in Lexicon.readings(Lexicon.stem(a)) do
		for _, y in Lexicon.readings(Lexicon.stem(b)) do
			if x == y then
				return true
			end
		end
	end
	return false
end
for _, pair in
	{
		{ "fuse", "fuses" },
		{ "name", "names" },
		{ "leave", "leaving" },
		{ "escape", "escaping" },
		{ "number", "numbering" },
		{ "listing", "listings" },
	}
do
	check(`'{pair[1]}' and '{pair[2]}' share a reading`, meets(pair[1], pair[2]))
end
check("(control) fuse and fuss do not", not meets("fuse", "fuss"))
check("(control) box and boxes still do", meets("box", "boxes"))

print("")
print("one definition of the same phrase")

check("samePhrase: singular and plural are the same phrase", Lexicon.samePhrase("blue wire", "blue wir"))
check("samePhrase: identical phrases are", Lexicon.samePhrase("blue wire", "blue wire"))
check("(control) a different word is not", not Lexicon.samePhrase("blue wire", "blue box"))
check("(control) a different length is not", not Lexicon.samePhrase("blue wire", "blue"))
check("(control) order matters", not Lexicon.samePhrase("blue wire", "wire blue"))
check("(control) fuse and fuss are still different words", not Lexicon.sameWord("fuse", "fuss"))

print("")
print("-ves plurals are the same word")

for _, pair in
	{ { "leaf", "leaves" }, { "knife", "knives" }, { "wolf", "wolves" }, { "shelf", "shelves" }, { "half", "halves" } }
do
	check(`'{pair[2]}' is the same word as '{pair[1]}'`, Lexicon.sameWord(Lexicon.stem(pair[1]), Lexicon.stem(pair[2])))
end
check("(control) 'waves' is not 'wafer'", not Lexicon.sameWord(Lexicon.stem("waves"), Lexicon.stem("wafer")))
check(
	"(control) 'doves' is not 'dofe'-anything: 'dove' stays 'dove'",
	Lexicon.sameWord(Lexicon.stem("dove"), Lexicon.stem("doves"))
)
check("(control) 'gloves' is still 'glove'", Lexicon.sameWord(Lexicon.stem("glove"), Lexicon.stem("gloves")))

print("")
print("past tense and doubled consonants are the same word")

for _, pair in
	{
		{ "run", "running" },
		{ "stop", "stopped" },
		{ "plan", "planning" },
		{ "wire", "wired" },
		{ "hurry", "hurried" },
		{ "battery", "batteries" },
		{ "dig", "digging" },
		{ "fuse", "fused" },
		{ "try", "tries" },
		{ "shut", "shutting" },
	}
do
	check(`'{pair[2]}' is the same word as '{pair[1]}'`, Lexicon.sameWord(Lexicon.stem(pair[1]), Lexicon.stem(pair[2])))
end
check(
	"(control) 'red' is not 're'-anything: 'red' is not 'ready'",
	not Lexicon.sameWord(Lexicon.stem("red"), Lexicon.stem("ready"))
)
check("(control) 'shelled' is not 'shed'", not Lexicon.sameWord(Lexicon.stem("shelled"), Lexicon.stem("shed")))
check("(control) 'filled' is not 'fired'", not Lexicon.sameWord(Lexicon.stem("filled"), Lexicon.stem("fired")))
check(
	"(control) 'filled' is not 'file' (l is never undoubled)",
	not Lexicon.sameWord(Lexicon.stem("filled"), Lexicon.stem("file"))
)
check(
	"'numbered' is the same word as 'number' (R92)",
	Lexicon.sameWord(Lexicon.stem("number"), Lexicon.stem("numbered"))
)
check("'powered' is the same word as 'power' (R92)", Lexicon.sameWord(Lexicon.stem("power"), Lexicon.stem("powered")))
check("(control) 'speed' is not 'spy'", not Lexicon.sameWord(Lexicon.stem("speed"), Lexicon.stem("spy")))

print("")
print("readings are cached, frozen and bounded")

-- R95. Uncached readings made a worst-case chat line cost 120.8 ms.
local first = Lexicon.readings("stopped")
check("a repeated reading is the SAME table (cached)", Lexicon.readings("stopped") == first)
check("a cached reading is frozen", table.isfrozen(first))
for i = 1, 5000 do
	Lexicon.readings(`filler{i}`)
end
check("after the cap resets, readings are still right", Lexicon.sameWord("stop", "stopped"))
check("(control) and still distinct", not Lexicon.sameWord("stop", "step"))

print("")
print("Lexicon mutation sweep (R101)")

-- Each check below is a mutant that passed the whole suite before R101.
check("'and' is a stopword", Lexicon.isStopword("and"))
check("'or' is a stopword", Lexicon.isStopword("or"))
check("a lone apostrophe is not a token", #Lexicon.tokenize("' '") == 0)
check("(control) an apostrophe inside a word is dropped, the word kept", Lexicon.tokenize("it's")[1] == "its")
local spelled = Lexicon.tokenize("o u t")
check(`exactly three spelled-out letters join ({table.concat(spelled, ",")})`, #spelled == 1 and spelled[1] == "out")
check(
	"'lives' is the same word as 'life' (a 3-letter -v stem)",
	Lexicon.sameWord(Lexicon.stem("life"), Lexicon.stem("lives"))
)
check("(control) 'shell' is not 'shelf'", not Lexicon.sameWord(Lexicon.stem("shell"), Lexicon.stem("shelf")))

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
