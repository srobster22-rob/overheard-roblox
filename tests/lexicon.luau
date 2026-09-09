--!strict
-- Headless tests for the pure text layer. Run: lune run tests/lexicon
-- These need no Roblox runtime, which is exactly why the text layer was kept
-- free of Roblox APIs.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".
local process = require("@lune/process")

local Lexicon = require("../src/shared/Lexicon")

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

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
