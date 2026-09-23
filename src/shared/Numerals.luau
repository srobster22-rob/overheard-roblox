--!strict
-- WORDS A GROUP USES AS NUMBERS (R147).
--
-- PT4's three blind groups beat the listener by round 2 with a number SCHEME:
-- "five dozen minus two", "sixty take away the usual", "three quarters". The
-- Operator reads digits, number words and simple sums (Lexicon.numbersIn), but
-- a word only the group had given a value to was never a number to it. And the
-- learner credits words toward STATIONS, where a scheme word used for every
-- station cancels out (R143).
--
-- This module does the arithmetic and nothing else:
--   * `explain` takes one line said before a code was entered, and the code,
--     and finds the one word the line needs to equal it: "five dozen minus
--     two" before 58 means dozen = 12.
--   * `read` evaluates a line with the words already learned: with dozen = 12,
--     "six dozen and five" is 77.
-- The Operator keeps the evidence and decides when a value is understood
-- (Operator.creditCode).
--
-- Deliberately narrow, so that a solved value is rarely a coincidence:
--   * a phrase is made only of numbers, "a", "an", "the", the operators below,
--     and words; any other word (a stopword, a short word) ends it;
--   * a phrase has at most one unknown: one word, or two side by side
--     ("jordans jersey");
--   * the unknown must stand with a number or a learned word in the same
--     phrase: "a quarter" alone is not evidence, "three quarters" is;
--   * a value is a whole number from 1 to 99, and a line that two phrases
--     explain differently explains nothing.
-- Pure: tokenises with Lexicon, so it runs headlessly.

local Lexicon = require(script.Parent.Lexicon)

local Numerals = {}

Numerals.LOWEST, Numerals.HIGHEST = 1, 99

local ADDS: { [string]: boolean } = { plus = true, ["and"] = true, add = true, added = true }
local SUBTRACTS: { [string]: boolean } = { minus = true, without = true }
-- "7 more than 40", "2 less than two dozen": the part after "than" is the base.
local COMPARED: { [string]: number } = { more = 1, less = -1, fewer = -1 }
local ARTICLES: { [string]: boolean } = { a = true, an = true }

-- A phrase is at most this many words long in its unknown ("jordans jersey").
local MOST_WORDS = 2

type Token = { kind: string, value: number?, word: string?, key: string? }

-- The key a word is learned under: its stem, so "quarter" and "quarters" are
-- one word to the Operator. Operators are matched on the word as typed
-- ("minus" stems to "minu").
function Numerals.key(words: { string }): string
	local stems = {}
	for _, word in words do
		table.insert(stems, Lexicon.stem(word))
	end
	return table.concat(stems, " ")
end

local function classify(word: string, nextWord: string?, known: { [string]: number }): Token
	local number = Lexicon.wholeNumber(word)
	if number ~= nil then
		return { kind = "number", value = number }
	end
	if ADDS[word] then
		return { kind = "add" }
	end
	if SUBTRACTS[word] then
		return { kind = "subtract" }
	end
	if word == "take" and nextWord == "away" then
		return { kind = "take" }
	end
	if word == "times" then
		return { kind = "times" }
	end
	if COMPARED[word] and nextWord == "than" then
		return { kind = "compare", value = COMPARED[word] }
	end
	if word == "than" or word == "away" then
		return { kind = "glue" }
	end
	if ARTICLES[word] then
		return { kind = "article" }
	end
	if word == "the" then
		return { kind = "skip" }
	end
	if Lexicon.isStopword(word) or #word < 3 or not string.match(word, "^%a+$") then
		return { kind = "break" }
	end
	local key = Numerals.key({ word })
	if known[key] ~= nil then
		return { kind = "known", value = known[key], word = word, key = key }
	end
	return { kind = "word", word = word, key = key }
end

-- A phrase ends on a number or a word: "four dozen and" before "cy do it" is
-- "four dozen", and "and four dozen" is too.
local ENDS: { [string]: boolean } = { number = true, word = true, known = true }
local STARTS: { [string]: boolean } = { number = true, word = true, known = true, article = true }

-- The phrases in a line: runs of tokens between the words that end them. A
-- sentence's punctuation ends one too ("eight dozen plus two. dont say it"):
-- the tokenizer drops it, so the line is split on it first.
local function phrases(text: string, known: { [string]: number }): { { Token } }
	local words: { string } = {}
	local stops: { [number]: boolean } = {}
	for sentence in string.gmatch(text, "[^%.,!%?;:]+") do
		for _, word in Lexicon.tokenize(sentence) do
			table.insert(words, word)
		end
		stops[#words] = true
	end
	local out: { { Token } } = {}
	local current: { Token } = {}
	local function finish()
		while #current > 0 and not ENDS[current[#current].kind] do
			table.remove(current)
		end
		while #current > 0 and not STARTS[current[1].kind] do
			table.remove(current, 1)
		end
		if #current > 0 then
			table.insert(out, current)
		end
		current = {}
	end
	for i, word in words do
		local token = classify(word, words[i + 1], known)
		if token.kind == "break" then
			finish()
		elseif token.kind ~= "skip" then
			-- A number straight after a word starts a new phrase: in "toaster.
			-- five dozen minus two" the station's nickname is not in the sum.
			local last = current[#current]
			if token.kind == "number" and last and (last.kind == "word" or last.kind == "known") then
				finish()
			end
			table.insert(current, token)
		end
		if stops[i] then
			finish()
		end
	end
	finish()
	return out
end

-- A phrase as a * X + b, with X its one unknown (nil when it has none).
export type Linear = {
	a: number,
	b: number,
	unknown: string?,
	-- The unknown as typed, for the wall.
	said: string?,
	-- It has a number or a learned word in it: an unknown alone is no evidence.
	grounded: boolean,
	-- The one learned word it used, when it used exactly one.
	usedKnown: string?,
	usedCount: number,
}

-- A sum of terms: [number | a | an] [word or learned word, up to two], joined by
-- plus/and/add/minus/without/take away, with "times" between a number and a word.
local function sum(tokens: { Token }): Linear?
	local out: Linear = { a = 0, b = 0, grounded = false, usedCount = 0 }
	local sign = 1
	local coefficient: number? = nil
	local words: { Token } = {}
	local open = false

	local function close(): boolean
		if not open then
			return true
		end
		local c = coefficient or 1
		if #words == 0 then
			out.b += sign * c
		elseif #words > MOST_WORDS then
			return false
		else
			local allKnown = true
			for _, t in words do
				allKnown = allKnown and t.kind == "known"
			end
			if #words == 1 and allKnown then
				out.b += sign * c * (words[1].value :: number)
				out.grounded = true
				out.usedKnown = words[1].key
				out.usedCount += 1
			else
				local keys, said = {}, {}
				for _, t in words do
					table.insert(keys, t.key :: string)
					table.insert(said, t.word :: string)
				end
				local key = table.concat(keys, " ")
				if out.unknown ~= nil and out.unknown ~= key then
					return false
				end
				out.unknown = key
				out.said = table.concat(said, " ")
				out.a += sign * c
			end
		end
		coefficient, words, open = nil, {}, false
		return true
	end

	local i = 1
	while i <= #tokens do
		local t = tokens[i]
		if t.kind == "number" then
			out.grounded = true
			if #words > 0 then
				-- A number after a word starts nothing the grammar knows.
				return nil
			end
			local value = t.value :: number
			if coefficient ~= nil then
				-- "forty seven": tens and then a digit.
				if coefficient % 10 == 0 and coefficient >= 20 and coefficient <= 90 and value >= 1 and value <= 9 then
					coefficient += value
				else
					return nil
				end
			else
				coefficient = value
			end
			open = true
		elseif t.kind == "article" then
			if coefficient ~= nil or #words > 0 then
				return nil
			end
			coefficient = 1
			open = true
		elseif t.kind == "word" or t.kind == "known" then
			table.insert(words, t)
			open = true
		elseif t.kind == "times" then
			-- "5 times dozen": the number before is the coefficient.
			if coefficient == nil or #words > 0 then
				return nil
			end
		elseif t.kind == "add" or t.kind == "subtract" or t.kind == "take" then
			if not open or not close() then
				return nil
			end
			sign = if t.kind == "add" then 1 else -1
		elseif t.kind == "glue" then
			-- "away" after "take" and "than" after a comparison are read with them.
			if not (i > 1 and (tokens[i - 1].kind == "take" or tokens[i - 1].kind == "compare")) then
				return nil
			end
		else
			return nil
		end
		i += 1
	end
	if not open or not close() then
		return nil
	end
	return out
end

local function parse(tokens: { Token }): Linear?
	-- "2 less than two dozen": the part after "than" is the base.
	for i, t in tokens do
		if t.kind == "compare" then
			local left = sum(table.move(tokens, 1, i - 1, 1, {}))
			local right = sum(table.move(tokens, i + 2, #tokens, 1, {}))
			if left == nil or right == nil then
				return nil
			end
			if left.unknown and right.unknown and left.unknown ~= right.unknown then
				return nil
			end
			local sign = t.value :: number
			return {
				a = right.a + sign * left.a,
				b = right.b + sign * left.b,
				unknown = right.unknown or left.unknown,
				said = right.said or left.said,
				grounded = left.grounded or right.grounded,
				usedKnown = if left.usedCount + right.usedCount == 1 then right.usedKnown or left.usedKnown else nil,
				usedCount = left.usedCount + right.usedCount,
			}
		end
	end
	return sum(tokens)
end

-- Chatter after the sum: "five dozen minus two pls". A trailing run of plain
-- words after the phrase's last number or learned word is dropped, and what is
-- left is read instead. nil when there is no such run.
local function withoutChatter(tokens: { Token }): { Token }?
	local last = 0
	for i, t in tokens do
		if t.kind == "number" or t.kind == "known" then
			last = i
		end
	end
	if last == 0 or last == #tokens then
		return nil
	end
	for i = last + 1, #tokens do
		if tokens[i].kind ~= "word" then
			return nil
		end
	end
	return table.move(tokens, 1, last, 1, {})
end

export type Explanation = {
	-- The word's key (its stem) and the word as it was typed.
	key: string,
	said: string,
	value: number,
	-- A learned word the line used and confirmed, rather than a new unknown.
	confirmed: boolean,
}

-- The one word `text` needs to equal `code`, and its value; or a learned word
-- the line used to say exactly `code`. nil when no phrase explains it, or two
-- explain it differently.
function Numerals.explain(text: string, code: number, known: { [string]: number }): Explanation?
	local found: Explanation? = nil
	for _, tokens in phrases(text, known) do
		local linear = parse(tokens)
		if linear == nil then
			local trimmed = withoutChatter(tokens)
			linear = if trimmed then parse(trimmed) else nil
		end
		local this: Explanation? = nil
		if linear and linear.grounded then
			if linear.unknown and linear.a ~= 0 then
				local value = (code - linear.b) / linear.a
				if value == math.floor(value) and value >= Numerals.LOWEST and value <= Numerals.HIGHEST then
					this = {
						key = linear.unknown :: string,
						said = linear.said :: string,
						value = value,
						confirmed = false,
					}
				end
			elseif linear.unknown == nil and linear.usedKnown and linear.b == code then
				local key = linear.usedKnown :: string
				this = { key = key, said = key, value = known[key], confirmed = true }
			end
		end
		if this then
			if found and (found.key ~= this.key or found.value ~= this.value) then
				return nil
			end
			found = this
		end
	end
	return found
end

-- Every whole number `text` says with the learned words, as digit strings. A
-- phrase with no learned word in it is left to Lexicon.numbersIn.
function Numerals.read(text: string, known: { [string]: number }): { [string]: boolean }
	local found: { [string]: boolean } = {}
	if next(known) == nil then
		return found
	end
	for _, tokens in phrases(text, known) do
		local linear = parse(tokens)
		if linear == nil or linear.unknown ~= nil then
			local trimmed = withoutChatter(tokens)
			linear = if trimmed then parse(trimmed) else linear
		end
		if linear and linear.unknown == nil and linear.usedCount > 0 then
			local value = linear.b
			if value == math.floor(value) and value >= 0 and value <= Numerals.HIGHEST then
				found[tostring(value)] = true
			end
		end
	end
	return found
end

return Numerals
