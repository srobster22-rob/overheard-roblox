--!strict
-- THE NUMBERS EVERYONE KNOWS (DECISIONS D15).
--
-- A group that cannot say its codes plainly reaches for riddles built from
-- public facts: "a deck of cards minus one", "days in february", "heinz
-- ketchup", "fingers on one hand, then days in a week". What beats the
-- Operator is shared context it was never present for (GAME.md), and a fact
-- every caller has ever said is not that. This module holds those facts as
-- data and rewrites a line with each one said as its number, so the plain
-- number reader (Lexicon.numbersIn) can do the arithmetic: "a deck of cards
-- minus one" becomes "52 minus one", which reads as 51.
--
--   * A fact is a phrase and its number. A unit ("dozen", "weeks", "quarters")
--     multiplies the number before it: "two dozen" is 24, "three quarters" 75.
--   * "seven sevens" and "seven squared" multiply, "double 43" and "twice a
--     dozen" double, "half of seventy four" and "half a deck" halve, and a
--     digit said "twice" or "double" is said twice ("double seven" is 77).
--   * A private fact ("how old my cousin is", "Bo's jersey") is in nobody's
--     registry, and stays safe.
-- Pure: tokenises with Lexicon, so it runs headlessly.

local Lexicon = require(script.Parent.Lexicon)

local Facts = {}

export type Fact = { says: { string }, value: number, unit: boolean? }

-- Every fact, as players say it: lower case, apostrophes dropped ("jordans").
-- The longest phrase that matches wins, so "the lucky one" is 7 and not 7 1.
-- A phrase must be one nobody says in passing: "the score", "an hour", "a hand"
-- and "lucky" are everyday chat, so they are not here, and a unit ("dozen",
-- "weeks") counts only after a number ("two dozen"). tests/facts.luau reads a
-- list of everyday lines that must read as nothing.
Facts.KNOWN = {
	-- Time.
	{ says = { "days in a week", "days of the week" }, value = 7 },
	{ says = { "week", "weeks" }, value = 7, unit = true },
	{ says = { "a fortnight" }, value = 14 },
	{ says = { "hours in a day" }, value = 24 },
	{ says = { "minutes in an hour", "seconds in a minute" }, value = 60 },
	{ says = { "months in a year" }, value = 12 },
	{ says = { "weeks in a year" }, value = 52 },
	{ says = { "days in january", "days in march", "days in may", "days in july" }, value = 31 },
	{ says = { "days in august", "days in october", "days in december" }, value = 31 },
	{ says = { "days in april", "days in june", "days in september", "days in november" }, value = 30 },
	{ says = { "days in february" }, value = 28 },
	{ says = { "decade", "decades" }, value = 10, unit = true },
	{ says = { "century", "centuries" }, value = 100, unit = true },
	-- Counting words.
	{ says = { "a dozen", "dozen", "dozens" }, value = 12, unit = true },
	{ says = { "a bakers dozen", "bakers dozen" }, value = 13 },
	{ says = { "a score", "score" }, value = 20, unit = true },
	{ says = { "a gross" }, value = 144 },
	{ says = { "a hundred", "hundred" }, value = 100, unit = true },
	{ says = { "a pair", "pair", "pairs" }, value = 2, unit = true },
	-- Money, in cents.
	{ says = { "a dollar", "dollar", "dollars" }, value = 100, unit = true },
	{ says = { "quarter", "quarters" }, value = 25, unit = true },
	{ says = { "a dime", "dime", "dimes" }, value = 10, unit = true },
	{ says = { "a nickel", "nickel", "nickels" }, value = 5, unit = true },
	{ says = { "a penny", "penny", "pennies" }, value = 1, unit = true },
	-- Cards, games and teams.
	{ says = { "a deck of cards", "a full deck", "a deck", "a pack of cards", "cards in a deck" }, value = 52 },
	{ says = { "blackjack" }, value = 21 },
	{ says = { "players on a soccer team", "a soccer team", "a football team" }, value = 11 },
	{ says = { "a basketball team", "players on a basketball team" }, value = 5 },
	{
		says = { "sides on a dice", "the biggest dice number", "biggest dice number", "the biggest number on a dice" },
		value = 6,
	},
	-- Bodies and animals.
	{ says = { "fingers on one hand", "fingers on a hand", "a high five", "another high five" }, value = 5 },
	{ says = { "legs on a dog", "a dogs legs", "dog legs", "legs a dog has" }, value = 4 },
	{ says = { "legs on a spider", "spider legs", "legs on an octopus", "octopus legs" }, value = 8 },
	-- Things everyone has counted.
	{ says = { "letters in the alphabet", "the alphabet" }, value = 26 },
	{ says = { "states in america", "us states", "how many states" }, value = 50 },
	{ says = { "keys on a piano", "piano keys" }, value = 88 },
	{ says = { "colours in a rainbow", "colors in a rainbow", "the seven seas" }, value = 7 },
	{ says = { "planets in the solar system" }, value = 8 },
	-- Numbers with a name.
	{ says = { "the answer to life the universe and everything", "the answer to life" }, value = 42 },
	{ says = { "heinz", "heinz ketchup" }, value = 57 },
	{ says = { "the lucky number", "the lucky one", "lucky number", "a lucky number" }, value = 7 },
	{ says = { "old enough to run for president", "to run for president" }, value = 35 },
	{ says = { "the unlucky number", "unlucky number" }, value = 13 },
	{ says = { "the loneliest number" }, value = 1 },
	{ says = { "the nice number", "the funny number" }, value = 69 },
	{ says = { "sweet sixteen" }, value = 16 },
	{ says = { "a quinceanera" }, value = 15 },
	{ says = { "the age you can vote", "the voting age", "old enough to vote" }, value = 18 },
	{ says = { "the drinking age", "old enough to drink" }, value = 21 },
	{ says = { "jordans jersey", "michael jordans jersey", "jordans number" }, value = 23 },
} :: { Fact }

-- Number words that multiply as plurals ("seven sevens"), and a digit's word.
local PLURAL: { [string]: string } = {
	twos = "two",
	threes = "three",
	fours = "four",
	fives = "five",
	sixes = "six",
	sevens = "seven",
	eights = "eight",
	nines = "nine",
	tens = "ten",
}

-- Every phrase, longest first, as its words.
local PHRASES: { { words: { string }, fact: Fact } } = {}
for _, fact in Facts.KNOWN do
	for _, said in fact.says do
		local words: { string } = {}
		for word in string.gmatch(said, "%S+") do
			table.insert(words, word)
		end
		table.insert(PHRASES, { words = words, fact = fact })
	end
end
table.sort(PHRASES, function(a, b)
	return #a.words > #b.words
end)

-- The words of a line, lower case. Symbols are spelled out as the number
-- reader spells them ("12*2" is "12 times 2", "52-1" is "52 minus 1"), and a
-- hyphenated number is two words ("twenty-one").
local function tokens(text: string): { string }
	local spelled = string.lower((string.gsub(text, "'", "")))
	spelled = string.gsub(spelled, "%*", " times ")
	spelled = string.gsub(spelled, "%+", " plus ")
	spelled = string.gsub(spelled, "(%d)%s*%-%s*(%d)", "%1 minus %2")
	spelled = string.gsub(spelled, "%s%-%s", " minus ")
	local out: { string } = {}
	for word in string.gmatch(spelled, "[%w]+") do
		table.insert(out, word)
	end
	return out
end

-- A product small enough to be a number people say: a code is two digits,
-- and a product in the thousands is no riddle (nor written in scientific
-- notation, whose exponent would read as a code).
local LARGEST = 9999
local function bounded(n: number): number?
	return if n >= 0 and n <= LARGEST and n == math.floor(n) then n else nil
end

-- The whole number a token stands for, if it is one: "47", "seven".
local function numberOf(token: string?): number?
	if token == nil then
		return nil
	elseif string.match(token, "^%d+$") then
		return tonumber(token)
	end
	return Lexicon.wholeNumber(token)
end

-- The whole number said at `words[i]`, and how many words say it: "74",
-- "seventy four" (a tens word, then a digit), "seven".
local function numberAt(words: { string }, i: number): (number?, number)
	local first = numberOf(words[i])
	local second = numberOf(words[i + 1])
	if first and first >= 20 and first % 10 == 0 and first < 100 and second and second > 0 and second < 10 then
		return first + second, 2
	end
	return first, 1
end

-- The fact phrase that starts at `words[i]`, longest first.
local function phraseAt(words: { string }, i: number): { words: { string }, fact: Fact }?
	for _, phrase in PHRASES do
		local fits = true
		for k, word in phrase.words do
			if words[i + k - 1] ~= word then
				fits = false
				break
			end
		end
		if fits then
			return phrase
		end
	end
	return nil
end

-- The number at `words[i]`, said plainly or as a fact, after an article if
-- there is one ("a dozen", "the alphabet", "seventy four"), and how many words
-- say it.
local ARTICLES: { [string]: boolean } = { a = true, an = true, the = true, of = true }
local function valueAt(words: { string }, i: number): (number?, number)
	for skip = 0, 2 do
		local phrase = phraseAt(words, i + skip)
		if phrase then
			return phrase.fact.value, skip + #phrase.words
		end
		local whole, count = numberAt(words, i + skip)
		if whole then
			return whole, skip + count
		end
		if not ARTICLES[words[i + skip] or ""] then
			break
		end
	end
	return nil, 0
end

-- The line, with each fact said as its number. Products and halves are worked
-- out here ("five dozen" is 60), because the number reader takes one sum at a
-- time: "five dozen minus two" reaches it as "60 minus two".
function Facts.rewrite(text: string): string
	local words = tokens(text)
	local out: { string } = {}
	-- The number just written, to multiply ("two dozen") or repeat ("7 twice").
	local function last(): number?
		return numberOf(out[#out])
	end
	local i = 1
	while i <= #words do
		local phrase = phraseAt(words, i)
		local word = words[i]
		if phrase and phrase.fact.unit and #phrase.words == 1 then
			-- "two dozen": the number before a unit multiplies it. A unit alone is
			-- a word ("dozens of them", "the score").
			local product = if last() then bounded((last() :: number) * phrase.fact.value) else nil
			if product then
				out[#out] = tostring(product)
			else
				table.insert(out, word)
			end
			i += 1
		elseif phrase then
			table.insert(out, tostring(phrase.fact.value))
			i += #phrase.words
		elseif PLURAL[word] and last() and bounded((last() :: number) * (numberOf(PLURAL[word]) :: number)) then
			-- "seven sevens"
			out[#out] = tostring(bounded((last() :: number) * (numberOf(PLURAL[word]) :: number)))
			i += 1
		elseif word == "squared" and last() and bounded((last() :: number) ^ 2) then
			out[#out] = tostring(bounded((last() :: number) ^ 2))
			i += 1
		elseif word == "half" or word == "double" or word == "twice" then
			-- "half of seventy four", "half a deck", "double 43", "twice a dozen".
			-- A digit doubled is said twice ("double seven" is 77), as on a phone.
			local whole, count = valueAt(words, i + 1)
			if whole == nil or (word == "half" and whole % 2 ~= 0) or not bounded(whole * 2) then
				-- "a dozen twice", "7 twice": the number before it.
				local before = last()
				if word == "twice" and before and bounded(before * 2) then
					out[#out] = if before < 10 then `{before} {before}` else tostring(before * 2)
				else
					table.insert(out, word)
				end
				i += 1
			elseif word == "half" then
				table.insert(out, tostring(whole // 2))
				i += 1 + count
			else
				table.insert(out, if whole < 10 then `{whole} {whole}` else tostring(whole * 2))
				i += 1 + count
			end
		elseif
			word == "two"
			and words[i + 1] == "times"
			and not numberOf(words[i + 2])
			and out[#out]
			and string.match(out[#out], "^%d$")
		then
			-- "the lucky one two times": the digit said twice.
			table.insert(out, out[#out])
			i += 2
		else
			-- "sixty three" as one number, so a sum after a fact reads it whole:
			-- "a dollar minus sixty three cents" is 37, not 40.
			local whole, count = numberAt(words, i)
			table.insert(out, if count == 2 then tostring(whole) else word)
			i += count
		end
	end
	return table.concat(out, " ")
end

-- The numbers a line holds only through a fact: what the plain reader finds
-- in the rewritten line and not in the line as said.
function Facts.read(text: string): { [string]: boolean }
	local plain = Lexicon.numbersIn(text)
	local found: { [string]: boolean } = {}
	-- One sentence at a time: "we need 4. a pair of us go left" is no 42, and
	-- "i have 2. dozens of them" no 24.
	for sentence in string.gmatch(text, "[^%.!%?;]+") do
		for number in Lexicon.numbersIn(Facts.rewrite(sentence)) do
			if not plain[number] then
				found[number] = true
			end
		end
	end
	return found
end

return Facts
