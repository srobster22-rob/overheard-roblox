--!strict
-- The comprehension backend that works TODAY, with no API access.
--
-- It answers one question per utterance: did this convey a secret, and if not,
-- which unfamiliar words were used near it? The second half is what makes the
-- Operator able to learn, and it is the more important half.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lexicon = require(ReplicatedStorage.Shared.Lexicon)
local Types = require(ReplicatedStorage.Shared.Types)

type Secret = Types.Secret
type Coinage = Types.Coinage
type Utterance = Types.Utterance
type Understanding = Types.Understanding

-- A coinage at or above this heat is treated as plain language.
local BURNED_AT = 1.0

local Heuristic = {}
Heuristic.name = "heuristic"

local function matchesAny(stems: { string }, joined: string, candidates: { string }): boolean
	for _, candidate in candidates do
		local candidateStems = Lexicon.stemAll(Lexicon.tokenize(candidate))
		if #candidateStems == 0 then
			continue
		end
		if #candidateStems == 1 then
			if Lexicon.contains(stems, candidateStems[1]) then
				return true
			end
		else
			-- Multi-word term: require the whole phrase, in order.
			if string.find(joined, table.concat(candidateStems, " "), 1, true) then
				return true
			end
		end
	end
	return false
end

function Heuristic.understand(utterance: Utterance, secrets: { Secret }, lexicon: { Coinage }): Understanding
	local words = Lexicon.tokenize(utterance.text)
	local stems = Lexicon.stemAll(words)
	local joined = table.concat(stems, " ")

	local best: Understanding = {
		concept = nil,
		confidence = 0,
		novelTerms = {},
		source = Heuristic.name,
	}

	for _, secret in secrets do
		local confidence = 0

		-- Plain language is always understood.
		if matchesAny(stems, joined, secret.plain) then
			confidence = 1
		end

		-- A coinage is understood in proportion to how well it has been learned.
		for _, coinage in lexicon do
			if coinage.concept ~= secret.concept then
				continue
			end
			if matchesAny(stems, joined, { coinage.phrase }) then
				local learned = math.clamp(coinage.heat / BURNED_AT, 0, 1)
				confidence = math.max(confidence, learned)
			end
		end

		if confidence > best.confidence then
			best = {
				concept = secret.concept,
				confidence = confidence,
				novelTerms = {},
				source = Heuristic.name,
			}
		end
	end

	-- Everything contentful that is NOT already plain language for some secret
	-- is a candidate coinage. The Operator does not understand these yet, but it
	-- notices that they were said.
	local plainStems: { [string]: boolean } = {}
	for _, secret in secrets do
		for _, term in secret.plain do
			for _, s in Lexicon.stemAll(Lexicon.tokenize(term)) do
				plainStems[s] = true
			end
		end
	end

	local novel: { string } = {}
	local seen: { [string]: boolean } = {}
	local function offer(term: string)
		if not seen[term] then
			seen[term] = true
			table.insert(novel, term)
		end
	end

	for _, s in stems do
		if not Lexicon.isStopword(s) and not plainStems[s] and #s > 2 then
			offer(s)
		end
	end
	-- Two-word phrases carry most player coinages ("blue one", "jake spot").
	for _, gram in Lexicon.ngrams(stems, 2) do
		local a, b = string.match(gram, "^(%S+) (%S+)$")
		if a and b and not (Lexicon.isStopword(a) and Lexicon.isStopword(b)) then
			if not plainStems[a] and not plainStems[b] then
				offer(gram)
			end
		end
	end

	best.novelTerms = novel
	return best
end

return Heuristic
