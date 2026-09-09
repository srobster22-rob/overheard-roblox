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
function Lexicon.tokenize(text: string): { string }
	local out: { string } = {}
	for raw in string.gmatch(string.lower(text), "[%a%d']+") do
		local word = string.gsub(raw, "'", "")
		if #word > 0 then
			table.insert(out, word)
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
		if #word > #suffix + 2 and string.sub(word, -#suffix) == suffix then
			return string.sub(word, 1, #word - #suffix)
		end
	end
	return word
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
