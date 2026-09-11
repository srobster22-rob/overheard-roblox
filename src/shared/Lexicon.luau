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
-- "dor" and is still missed, which is no worse than before.
--
-- Walked by hand rather than done with a pattern: Lua applies quantifiers only
-- to single character classes, never to a back-reference, so "(%a)%1%1+" reads
-- its "+" as a literal plus sign and matched nothing. The first version of
-- this function was exactly that, and the probe caught it at 0 of 5.
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

-- R83. RESPELLINGS ARE NOT SHARED CONTEXT. Tokens are split on anything
-- outside [%a%d'], so "j.a.c.k", "j-a-c-k" and "j a c k" all arrived as four
-- one-letter tokens, and "j4ck" as a token matching nothing. Measured against
-- the real Heuristic: 0 of 30 respelled giveaways understood, across every
-- secret in the pool. GAME.md is explicit that what defeats the Operator is
-- "shared context it was never present for" -- a stranger spacing a word out
-- on their first round is not that, and once one player finds it the whole
-- mechanic is optional.
--
-- Normalised HERE, in the one function every reader goes through, so plain
-- matching, coinages and novel terms all see the same word.
function Lexicon.tokenize(text: string): { string }
	-- R84. `@` and `$` stand in for `a` and `s` ("j@ck", "bre$k"), but the
	-- token class below treats them as separators, so "j@ck" arrived as "j" and
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
		if #word > 0 then
			table.insert(raw, word)
		end
	end

	local out: { string } = {}
	local i = 1
	while i <= #raw do
		-- A run of three or more single letters is one word spelled out. Two
		-- is left alone: "u r" and "i a" are ordinary chat, not a spelling.
		--
		-- R84: a run may include a single LEET digit ("j 4 c k"), which R83's
		-- letters-only run broke on. It must still hold at least two real
		-- letters, so an answer spelled out digit by digit ("4 2") is never
		-- joined and never un-leeted.
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
-- non-stopword walks straight through the gate. Two of the 67 did:
-- `this -> thi` and `guys -> guy`, both long enough to clear the `#s > 2`
-- filter. Five utterances of "guys the wire is over here" plus one credit burnt
-- `guy` and `guy the` to heat 1.00, after which "hey guys" gave the group away
-- at confidence 1.00 — the monster moving on a phrase nobody coined, with
-- nothing in the panel to explain why. It also silently disabled the
-- both-words-are-stopwords bigram rejection, since `guy` then read as
-- contentful.
--
-- Guarding inside `stem` protects every consumer at once instead of the one
-- that happened to be caught, and keeps the promise the stopword table above
-- makes: if "the" could burn, every phrase would burn.
function Lexicon.stem(word: string): string
	if STOPWORDS[word] then
		return word
	end
	for _, suffix in { "ing", "ers", "er", "es", "s" } do
		-- A word ending in "ss" is not a plural: "fuss", "boss", "address".
		-- Stripping its last s made "fuss" and "fuses" the same stem, and made
		-- "address" disagree with "addresses". R85 found both measuring
		-- paraphrase: "don't make a fuss" moved the Operator to the breaker.
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
-- R85, and R17's filed "stemming pair" item 2. `stem` strips one suffix, and
-- English does not say which one: `fuses` is `fuse`+s or `fus`+es, exactly as
-- `buses` is `bus`+es. The current order gives `fuses -> fus` against
-- `fuse -> fuse`, so every plain word ending in e was free to say in the plural
-- or with -ing: "the fuses", "the names", "leaving now", "escaping". R17 filed
-- it because any SINGLE rule is wrong one way (try `s` before `es` and `boxes`
-- and `buses` break instead).
--
-- It never needed a single rule. A match is accepted if ANY reading of the
-- word agrees with any reading of the term, so nothing that matched before can
-- stop matching; the cost is a wider net, measured in the tests rather than
-- assumed. The readings: the stem itself, and the stem without a trailing `e`
-- (`fuse`, `leave` -> `fus`, `leav`, meeting `fuses`, `leaving`).
--
-- And the stem stemmed once more, for chained suffixes: `numbering -> number`
-- meets `number -> numb`, `powering -> power` meets `power -> pow`, `listings ->
-- listing` meets `listing -> list`. The first version of this round dropped
-- that reading while fixing the "ss" bug, took inflections from 70 of 70 to 59,
-- and was put back once the probe showed what it had been doing.
function Lexicon.readings(stemmed: string): { string }
	local out = { stemmed }
	if #stemmed > 3 and string.sub(stemmed, -1) == "e" then
		table.insert(out, string.sub(stemmed, 1, -2))
	end
	local again = Lexicon.stem(stemmed)
	if again ~= stemmed then
		table.insert(out, again)
	end
	-- R89: the "-ves" plurals. "leaves" stems to "leav", "knives" to "kniv";
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
	return out
end

-- Do two stems share any reading? The ONE definition of "the same word",
-- used by the matcher (Heuristic) and the learner (Operator) alike. R87: when
-- only the matcher knew it, a group alternating "blue wire" and "blue wires"
-- was understood as one phrase but learned as two, each half-heated.
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

return Lexicon
