--!strict
-- Text utilities shared by the comprehension backends.
--
-- Deliberately dumb and deterministic: the heuristic backend must be
-- explainable, because when a player says "that should NOT have burned" we
-- need to be able to say exactly why it did.

local Lexicon = {}

-- Words that carry no concept and must never be treated as a coinage.
-- If "the" could burn, every phrase would burn.
local STOPWORDS: { [string]: boolean } = {}
for _, w in
	{
		"the",
		"a",
		"an",
		"is",
		"it",
		"in",
		"on",
		"at",
		"to",
		"of",
		"and",
		"or",
		"but",
		"i",
		"you",
		"we",
		"they",
		"he",
		"she",
		"me",
		"my",
		"your",
		"our",
		"go",
		"get",
		"got",
		"do",
		"did",
		"was",
		"were",
		"be",
		"are",
		"am",
		"this",
		"that",
		"there",
		"here",
		"where",
		"what",
		"who",
		"how",
		"now",
		"ok",
		"okay",
		"yeah",
		"yes",
		"no",
		"not",
		"guys",
		"wait",
		"hold",
		"come",
		"see",
		"look",
		"know",
		"think",
		"like",
		"just",
		"can",
		"will",
		"one",
		"for",
		"with",
		"its",
		"im",
		"has",
		"have",
	}
do
	STOPWORDS[w] = true
end

function Lexicon.isStopword(word: string): boolean
	return STOPWORDS[word] == true
end

-- Lowercase, strip punctuation, split on whitespace.
-- Digits players type in place of letters. Applied ONLY to a token that
-- mixes letters and digits, so an all-digit token -- which is how every
-- ANSWER in this game is written -- is never rewritten.
local LEET: { [string]: string } = {
	["0"] = "o",
	["1"] = "i",
	["3"] = "e",
	["4"] = "a",
	["5"] = "s",
	["7"] = "t",
}

local function unleet(word: string): string
	if not (string.find(word, "%a") and string.find(word, "%d")) then
		return word
	end
	return (string.gsub(word, "%d", function(d: string): string
		return LEET[d] or d
	end))
end

-- A letter held for three or more characters ("jackkk", "exiiit") collapses to
-- one. Real spellings never repeat a letter three times, so this cannot damage
-- an ordinary word; a genuine double stretched out ("doooor") collapses to
-- "dor" and is missed, as it would be without this.
--
-- Walked by hand rather than done with a pattern: Lua applies quantifiers only
-- to single character classes, never to a back-reference, so "(%a)%1%1+" reads
-- its "+" as a literal plus sign and matches nothing.
local function unstretch(word: string): string
	local out: { string } = {}
	local i = 1
	while i <= #word do
		local ch = string.sub(word, i, i)
		local j = i
		while j < #word and string.sub(word, j + 1, j + 1) == ch do
			j += 1
		end
		local run = j - i + 1
		if run >= 3 and string.match(ch, "%a") then
			table.insert(out, ch)
		else
			table.insert(out, string.sub(word, i, j))
		end
		i = j + 1
	end
	return table.concat(out)
end

-- RESPELLINGS ARE NOT SHARED CONTEXT. Tokens are split on anything outside
-- [%a%d'], so without the joining below "j.a.c.k", "j-a-c-k" and "j a c k"
-- arrive as four one-letter tokens, and "j4ck" as a token matching nothing.
-- GAME.md is explicit that what defeats the Operator is "shared context it
-- was never present for" -- a stranger spacing a word out on their first
-- round is not that, and once one player finds it the whole mechanic is
-- optional.
--
-- Normalised HERE, in the one function every reader goes through, so plain
-- matching, coinages and novel terms all see the same word.
--
-- `splitCodes` gives a SECOND reading, in which a code glued to a word is two
-- tokens ("door48", "48door", "x47"): as one token the word in it matches
-- nothing, so a station could be named unheard by leaving out the space. It
-- is not the only reading, because "ex17" is "exit" respelled, not "ex" and
-- 17: split alone, it costs the respelling rule above 18 of 56 plain words.
function Lexicon.tokenize(text: string, splitCodes: boolean?): { string }
	-- `@` and `$` stand in for `a` and `s` ("j@ck", "bre$k"), but the token
	-- class below treats them as separators, so "j@ck" would arrive as "j" and
	-- "ck". Rewritten only where they touch a letter, so "@bob" or "$5" are not
	-- turned into words.
	local lowered = string.lower(text)
	lowered = string.gsub(lowered, "(%a)@", "%1a")
	lowered = string.gsub(lowered, "@(%a)", "a%1")
	lowered = string.gsub(lowered, "(%a)%$", "%1s")
	lowered = string.gsub(lowered, "%$(%a)", "s%1")

	local raw: { string } = {}
	for piece in string.gmatch(lowered, "[%a%d']+") do
		local word = string.gsub(piece, "'", "")
		-- Only a run of two or more digits at either END is split off: digits
		-- inside a word are a respelling ("d00r"), and a single trailing digit
		-- is left to the leet table.
		local front, codeAfter, codeBefore, back
		if splitCodes then
			front, codeAfter = string.match(word, "^(%a[%a%d]*%a)(%d%d+)$")
			if front == nil then
				front, codeAfter = string.match(word, "^(%a)(%d%d+)$")
			end
			codeBefore, back = string.match(word, "^(%d%d+)(%a[%a%d]*%a)$")
			if codeBefore == nil then
				codeBefore, back = string.match(word, "^(%d%d+)(%a)$")
			end
		end
		if front and codeAfter then
			table.insert(raw, front)
			table.insert(raw, codeAfter)
		elseif codeBefore and back then
			table.insert(raw, codeBefore)
			table.insert(raw, back)
		elseif #word > 0 then
			table.insert(raw, word)
		end
	end

	local out: { string } = {}
	local i = 1
	while i <= #raw do
		-- A run of three or more single letters is one word spelled out. Two
		-- is left alone: "u r" and "i a" are ordinary chat, not a spelling.
		--
		-- A run may include LEET digits ("j 4 c k"), so a respelling does not
		-- break it. It must still hold at least two real letters, so an answer
		-- spelled out digit by digit ("4 2") is never joined and never
		-- un-leeted.
		local j = i
		local letters = 0
		while j <= #raw and (string.match(raw[j], "^%a$") or LEET[raw[j]] ~= nil) do
			if string.match(raw[j], "^%a$") then
				letters += 1
			end
			j += 1
		end
		if j - i >= 3 and letters >= 2 then
			table.insert(out, unstretch(unleet(table.concat(raw, "", i, j - 1))))
			i = j
		else
			table.insert(out, unstretch(unleet(raw[i])))
			i += 1
		end
	end
	return out
end

-- Crude suffix stemmer. Enough to make "keys" match "key" without pulling in a
-- dependency. Only strips when a reasonable stem remains.
--
-- A STOPWORD IS RETURNED UNCHANGED, and that guard belongs here rather than at
-- the call sites. `Heuristic.understand` gates novel terms with
-- `isStopword(stem)`, not `isStopword(word)`, so any stopword that stems into a
-- non-stopword walks straight through the gate. Unguarded, `this -> thi` and
-- `guys -> guy` are both long enough to clear the `#s > 2` filter: "guys the
-- wire is over here" burns `guy`, and then "hey guys" moves the monster on a
-- phrase nobody coined, with nothing in the panel to explain why. It also
-- defeats the both-words-are-stopwords bigram rejection, since `guy` reads as
-- contentful.
--
-- Guarding inside `stem` protects every consumer at once, and keeps the
-- promise the stopword table above makes: if "the" could burn, every phrase
-- would burn.
function Lexicon.stem(word: string): string
	if STOPWORDS[word] then
		return word
	end
	for _, suffix in { "ing", "ers", "er", "es", "s" } do
		-- A word ending in "ss" is not a plural: "fuss", "boss", "address".
		-- Stripping its last s would make "fuss" and "fuses" the same stem (so
		-- "don't make a fuss" would send the Operator to the breaker), and make
		-- "address" disagree with "addresses".
		if suffix == "s" and string.sub(word, -2) == "ss" then
			continue
		end
		if #word > #suffix + 2 and string.sub(word, -#suffix) == suffix then
			return string.sub(word, 1, #word - #suffix)
		end
	end
	return word
end

-- Every reasonable reading of an already-stemmed word, for SINGLE-word
-- matching only.
--
-- `stem` strips one suffix, and English does not say which one: `fuses` is
-- `fuse`+s or `fus`+es, exactly as `buses` is `bus`+es. The suffix order gives
-- `fuses -> fus` against `fuse -> fuse`, so on the stem alone every plain word
-- ending in e is free to say in the plural or with -ing: "the fuses", "the
-- names", "leaving now", "escaping". Any SINGLE rule is wrong one way (try `s`
-- before `es` and `boxes` and `buses` break instead).
--
-- So there is no single rule. A match is accepted if ANY reading of the word
-- agrees with any reading of the term, so a new reading can only add matches,
-- never remove one; the cost is a wider net, measured in the tests rather than
-- assumed. The readings: the stem itself, and the stem without a trailing `e`
-- (`fuse`, `leave` -> `fus`, `leav`, meeting `fuses`, `leaving`).
--
-- And the stem stemmed once more, for chained suffixes: `numbering -> number`
-- meets `number -> numb`, `powering -> power` meets `power -> pow`, `listings ->
-- listing` meets `listing -> list`. Without it those inflections stop matching.
local function computeReadings(stemmed: string): { string }
	local out = { stemmed }
	if #stemmed > 3 and string.sub(stemmed, -1) == "e" then
		table.insert(out, string.sub(stemmed, 1, -2))
	end
	local again = Lexicon.stem(stemmed)
	if again ~= stemmed then
		table.insert(out, again)
	end
	-- The "-ves" plurals. "leaves" stems to "leav", "knives" to "kniv";
	-- reading the v as f meets "leaf" and "knif" (knife). Only where English
	-- actually does this -- after l (wolves, shelves, halves), after i (knives,
	-- wives, lives), or after two vowels (leaves, loaves, thieves) -- because a
	-- bare "wav" read as "waf" would make "waves" the word "wafer".
	if #stemmed >= 3 and string.sub(stemmed, -1) == "v" then
		local before = string.sub(stemmed, -2, -2)
		local pair = string.sub(stemmed, -3, -2)
		if before == "l" or before == "i" or string.match(pair, "^[aeiou][aeiou]$") then
			table.insert(out, string.sub(stemmed, 1, -2) .. "f")
		end
	end
	-- Past tense and doubled consonants. `stem` never strips -ed and never
	-- undoes "running -> runn", so without these readings "stopped", "wired",
	-- "digging", "hurried" and "batteries" are different words from their
	-- roots. Readings, not `stem`, because stems are what LexiconSave stores:
	-- changing `stem` would orphan every saved coinage.
	local base = table.clone(out)
	if #stemmed > 4 and string.sub(stemmed, -2) == "ed" then
		table.insert(base, string.sub(stemmed, 1, -3)) -- stopped -> stopp, hurried -> hurri
		table.insert(base, string.sub(stemmed, 1, -2)) -- wired -> wire
		-- And stem what is left, as the root itself was stemmed: "number" stems
		-- to "numb" and "power" to "pow", so otherwise "numbered" and "powered"
		-- miss the plain words they are.
		table.insert(base, Lexicon.stem(string.sub(stemmed, 1, -3)))
	end
	for _, r in base do
		if not table.find(out, r) then
			table.insert(out, r)
		end
		local last = string.sub(r, -1)
		-- runn -> run, stopp -> stop; only the letters English doubles before a
		-- suffix, so "shell" and "fill" keep their own spelling.
		if #r >= 4 and string.sub(r, -2, -2) == last and string.find("bdgmnprt", last, 1, true) then
			table.insert(out, string.sub(r, 1, -2))
		end
		-- tri -> try, batteri -> battery, hurri -> hurry
		if #r >= 3 and last == "i" then
			table.insert(out, string.sub(r, 1, -2) .. "y")
		end
	end
	return out
end

-- Readings are a pure function of the stem, and they cost enough that
-- recomputing them makes a worst-case chat line (200 characters, a full
-- 200-coinage lexicon) take about 120 ms in Heuristic.conveyed -- seven server
-- frames of hitch every time someone talks. Cached, frozen so no caller can
-- corrupt a shared entry, and capped: chat vocabulary is open-ended, so a long
-- server would otherwise grow it forever.
local READINGS_CAP = 4096
local readingsCache: { [string]: { string } } = {}
local readingsCached = 0

function Lexicon.readings(stemmed: string): { string }
	local hit = readingsCache[stemmed]
	if hit then
		return hit
	end
	if readingsCached >= READINGS_CAP then
		readingsCache = {}
		readingsCached = 0
	end
	local out = table.freeze(computeReadings(stemmed))
	readingsCache[stemmed] = out
	readingsCached += 1
	return out
end

-- Do two stems share any reading? The ONE definition of "the same word",
-- used by the matcher (Heuristic) and the learner (Operator) alike. If only
-- the matcher used it, a group alternating "blue wire" and "blue wires" would
-- be understood as one phrase but learned as two, each half-heated.
function Lexicon.sameWord(a: string, b: string): boolean
	if a == b then
		return true
	end
	for _, x in Lexicon.readings(a) do
		for _, y in Lexicon.readings(b) do
			if x == y then
				return true
			end
		end
	end
	return false
end

-- Are two already-stemmed phrases the same phrase: same length, and each word
-- the same word, in order?
function Lexicon.samePhrase(a: string, b: string): boolean
	if a == b then
		return true
	end
	local aw, bw = string.split(a, " "), string.split(b, " ")
	if #aw ~= #bw then
		return false
	end
	for i = 1, #aw do
		if not Lexicon.sameWord(aw[i], bw[i]) then
			return false
		end
	end
	return true
end

function Lexicon.stemAll(words: { string }): { string }
	local out: { string } = {}
	for _, w in words do
		table.insert(out, Lexicon.stem(w))
	end
	return out
end

-- Contiguous n-grams, used to spot multi-word coinages like "the blue one".
function Lexicon.ngrams(words: { string }, n: number): { string }
	local out: { string } = {}
	for i = 1, #words - n + 1 do
		local parts = table.create(n)
		for j = 0, n - 1 do
			parts[j + 1] = words[i + j]
		end
		table.insert(out, table.concat(parts, " "))
	end
	return out
end

function Lexicon.contains(haystack: { string }, needle: string): boolean
	for _, v in haystack do
		if v == needle then
			return true
		end
	end
	return false
end

-- THE CODE HAS TO BE SAID. A live code is a secret like a station's word, so
-- it is heard in the forms a person types two digits in without needing any
-- context: digits ("47", "047"), digits apart ("4 7", "4-7", "4 then 7"),
-- digits glued to a word or a number word ("door47", "x47", "four7"), number
-- words ("four seven", "forty seven", "fortyseven", "fourseven", "forty 7",
-- "40 7"), a teen ("fifteen"), a simple sum ("40 plus 7", "40 and 7", "50-3",
-- "6x8", "7 more than 40", "60 take away 13") and a code turned round ("74
-- backwards", "the reverse of 7 4"). What it cannot read is a number only the
-- group knows: "Bo's age plus 34" is safe until the Operator learns who Bo is,
-- and it never will.

-- How each digit is said: DIGIT_WORDS[d + 1] is digit d. The Operator reads a
-- code back with these (Round.readBack), so hearing and speaking share them.
Lexicon.DIGIT_WORDS = { "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" }
local UNIT_WORDS: { [string]: number } = {}
for index, word in Lexicon.DIGIT_WORDS do
	UNIT_WORDS[word] = index - 1
end
local TEEN_WORDS: { [string]: number } = {
	ten = 10,
	eleven = 11,
	twelve = 12,
	thirteen = 13,
	fourteen = 14,
	fifteen = 15,
	sixteen = 16,
	seventeen = 17,
	eighteen = 18,
	nineteen = 19,
}
local TENS_WORDS: { [string]: number } = {
	twenty = 20,
	thirty = 30,
	forty = 40,
	fourty = 40,
	fifty = 50,
	sixty = 60,
	seventy = 70,
	eighty = 80,
	ninety = 90,
}
local function add(a: number, b: number): number
	return a + b
end
local function subtract(a: number, b: number): number
	return a - b
end
local OPERATIONS: { [string]: (number, number) -> number } = {
	plus = add,
	add = add,
	["and"] = add,
	minus = subtract,
	times = function(a: number, b: number): number
		return a * b
	end,
}
-- "7 more than 40", "3 less than 50": the number after "than" is the base.
local COMPARED: { [string]: (number, number) -> number } = {
	more = function(a: number, base: number): number
		return base + a
	end,
	less = function(a: number, base: number): number
		return base - a
	end,
	fewer = function(a: number, base: number): number
		return base - a
	end,
}
local TURNED_ROUND: { [string]: boolean } = {
	backwards = true,
	backward = true,
	reversed = true,
	reverse = true,
	flipped = true,
}

-- At most this many words may stand between two digits that are still read as
-- one number: "4 then 7" is 47, and so is "4 and then a 7". Wider than that
-- the digits are too far apart to be one thought in a chat line.
Lexicon.DIGIT_GAP = 3

-- A single digit, written or spelled: "4" or "four".
local function oneDigit(word: string): string?
	if string.match(word, "^%d$") then
		return word
	end
	local value = UNIT_WORDS[word]
	return if value ~= nil then tostring(value) else nil
end

-- A whole number one token can stand for: "47", "fifteen", "forty",
-- "fortyseven", "fourseven".
local function wholeNumber(word: string): number?
	if string.match(word, "^%d+$") then
		return tonumber(word)
	end
	local value = UNIT_WORDS[word] or TEEN_WORDS[word] or TENS_WORDS[word]
	if value ~= nil then
		return value
	end
	for tensWord, tens in TENS_WORDS do
		local rest = string.match(word, "^" .. tensWord .. "(%a+)$")
		local unit = rest and UNIT_WORDS[rest]
		if unit and unit > 0 then
			return tens + unit
		end
	end
	for unitWord, first in UNIT_WORDS do
		local rest = string.match(word, "^" .. unitWord .. "(%a+)$")
		local second = rest and UNIT_WORDS[rest]
		if first > 0 and second ~= nil then
			return first * 10 + second
		end
	end
	return nil
end
-- Numerals reads a group's number words with the same whole numbers
-- (DECISIONS D11).
Lexicon.wholeNumber = wholeNumber

-- Every number one reading of a line holds, added to `found`.
local function readNumbers(words: { string }, found: { [string]: boolean })
	for i, word in words do
		if string.match(word, "^%d+$") then
			found[word] = true
			-- "047" is 47: a leading zero is padding, not another number.
			found[tostring(tonumber(word))] = true
		else
			local value = wholeNumber(word)
			if value ~= nil then
				found[tostring(value)] = true
			end
		end

		-- Tens and then a digit: "forty seven", "forty 7", "40 7".
		local tens = TENS_WORDS[word]
		if tens == nil and string.match(word, "^[2-9]0$") then
			tens = tonumber(word)
		end
		local unit = if words[i + 1] then oneDigit(words[i + 1]) else nil
		if tens and unit and unit ~= "0" then
			found[tostring(tens + (tonumber(unit) :: number))] = true
		end

		-- Two digits in order, a few words apart at most.
		local first = oneDigit(word)
		if first then
			for gap = 1, Lexicon.DIGIT_GAP + 1 do
				local later = words[i + gap]
				local second = if later then oneDigit(later) else nil
				if second then
					found[first .. second] = true
					break
				end
			end
		end

		-- A simple sum between two numbers: "40 plus 7", "40 and 7".
		local operation = OPERATIONS[word]
		if operation and i > 1 and i < #words then
			local a, b = wholeNumber(words[i - 1]), wholeNumber(words[i + 1])
			if a ~= nil and b ~= nil then
				found[tostring(operation(a, b))] = true
			end
		end
		-- "60 take away 13".
		if word == "away" and words[i - 1] == "take" and i > 2 and i < #words then
			local a, b = wholeNumber(words[i - 2]), wholeNumber(words[i + 1])
			if a ~= nil and b ~= nil then
				found[tostring(a - b)] = true
			end
		end
		-- "7 more than 40".
		local compared = COMPARED[word]
		if compared and i > 1 and words[i + 1] == "than" and words[i + 2] then
			local a, base = wholeNumber(words[i - 1]), wholeNumber(words[i + 2])
			if a ~= nil and base ~= nil then
				found[tostring(compared(a, base))] = true
			end
		end
	end
end

-- Every number `text` can be read as, as digit strings. Symbols the word
-- tokenizer drops are spelled out first, so "40+7" and "50-3" keep their
-- operators.
function Lexicon.numbersIn(text: string): { [string]: boolean }
	local spelled = string.lower(text)
	spelled = string.gsub(spelled, "%+", " plus ")
	spelled = string.gsub(spelled, "%*", " times ")
	spelled = string.gsub(spelled, "(%d)%s*x%s*(%d)", "%1 times %2")
	spelled = string.gsub(spelled, "(%d)%s*%-%s*(%d)", "%1 minus %2")

	-- Read twice: as typed, so a respelled number word ("f0rty") still reads,
	-- and with every letter pulled apart from every digit, so a code glued to
	-- a word or to a number word ("door47", "x47", "four7") reads too.
	local apart = string.gsub(string.gsub(spelled, "(%a)(%d)", "%1 %2"), "(%d)(%a)", "%1 %2")
	local found: { [string]: boolean } = {}
	local turned = false
	for _, reading in { spelled, apart } do
		local words = Lexicon.tokenize(reading)
		readNumbers(words, found)
		for _, word in words do
			turned = turned or TURNED_ROUND[word] == true
		end
	end

	-- Turned round anywhere in the line: every two-digit number in it is read
	-- the other way too ("74 backwards", "the reverse of 7 4").
	if turned then
		local reversed: { string } = {}
		for number in found do
			if string.match(number, "^%d%d$") then
				table.insert(reversed, string.reverse(number))
			end
		end
		for _, number in reversed do
			found[number] = true
		end
	end
	return found
end

return Lexicon
