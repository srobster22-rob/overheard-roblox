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

-- Does `joined` contain `phrase` as WHOLE words?
--
-- `joined` is stems separated by single spaces, so surrounding both sides with
-- one space turns "is a substring of" into "is a run of whole words". Without
-- the padding, `string.find` matched inside a longer token in both directions:
-- the phrase's last word could be a prefix of a token ("the blue" understood
-- inside "check the bluetooth") and its first word could be a suffix of one
-- ("one blue" inside "someone blue"). Both were probed at confidence 1.0, on
-- bigrams the Operator mints from ordinary sentences, so a player speaking
-- normally moved the monster for a phrase they never said.
local function containsWords(joined: string, phrase: string): boolean
	return string.find(` {joined} `, ` {phrase} `, 1, true) ~= nil
end

-- `alreadyStemmed` exists because the two call sites pass different things.
-- `secret.plain` holds RAW words an author typed, which must be stemmed here.
-- `coinage.phrase` is ALREADY a stem — it came out of this file's own
-- novel-term extraction, which stores stems.
--
-- Stemming the second one a second time is a real defect, not a redundancy,
-- because `Lexicon.stem` is not idempotent: `gathering -> gather -> gath`, and
-- any `-ing` word whose stem then ends in `-er` does the same. "everyone to the
-- gathering spot", said six times and credited, mints `the gather` and
-- `gather spot` at heat 1.00 — and both then scored 0.00 against the exact
-- sentence that minted them.
--
-- That is the worst possible failure for this game specifically. The Lexicon
-- panel is the instrument players read to decide what is still safe to say, and
-- it was showing those two at 100% burned. A group abandons a codeword that
-- still works because the panel says the Operator learned it.
--
-- Fixed here rather than in `Lexicon.stem`: `gather -> gath` is the `er` rule
-- working as written, and telling "gather" from "gath"+"er" needs real
-- morphology. The bug is the DOUBLE stemming, not the stemmer.
local function matchesAny(stems: { string }, joined: string, candidates: { string }, alreadyStemmed: boolean?): boolean
	for _, candidate in candidates do
		local candidateStems = if alreadyStemmed
			then Lexicon.tokenize(candidate)
			else Lexicon.stemAll(Lexicon.tokenize(candidate))
		if #candidateStems == 0 then
			continue
		end
		if #candidateStems == 1 then
			if Lexicon.contains(stems, candidateStems[1]) then
				return true
			end
		else
			-- Multi-word term: require the whole phrase, in order, on word
			-- boundaries. Single-word terms go through `Lexicon.contains`,
			-- which compares whole stems and was never affected.
			if containsWords(joined, table.concat(candidateStems, " ")) then
				return true
			end
		end
	end
	return false
end

-- EVERY concept the utterance conveys, strongest first.
--
-- `understand` below reports only the strongest, and reporting one was a real
-- hole in "plain speech is always punished": "the jack is right by the fuse"
-- carries plain giveaways for TWO concepts, and the Operator registered
-- `jack_number` and nothing else. Either word alone is understood, so it was
-- the COMBINATION that hid one -- a group that noticed could bury every
-- dangerous word inside a sentence giving away something already lost.
function Heuristic.conveyed(utterance: Utterance, secrets: { Secret }, lexicon: { Coinage }): { Understanding }
	local words = Lexicon.tokenize(utterance.text)
	local stems = Lexicon.stemAll(words)
	local joined = table.concat(stems, " ")

	local found: { Understanding } = {}

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
			-- Already a stem; see `alreadyStemmed` above.
			if matchesAny(stems, joined, { coinage.phrase }, true) then
				local learned = math.clamp(coinage.heat / BURNED_AT, 0, 1)
				confidence = math.max(confidence, learned)
			end
		end

		if confidence > 0 then
			table.insert(found, {
				concept = secret.concept,
				confidence = confidence,
				novelTerms = {},
				source = Heuristic.name,
			})
		end
	end

	-- Strongest first, and ties broken by concept name so the order is stable
	-- rather than dependent on how the pool happened to be shuffled.
	table.sort(found, function(a, b)
		if a.confidence ~= b.confidence then
			return a.confidence > b.confidence
		end
		return (a.concept or "") < (b.concept or "")
	end)

	return found
end

-- The novel terms an utterance offered. Computed once per utterance, never once
-- per concept: crediting them twice would inflate every coinage's heat.
function Heuristic.novelTerms(utterance: Utterance, secrets: { Secret }): { string }
	local words = Lexicon.tokenize(utterance.text)
	local stems = Lexicon.stemAll(words)

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

	return novel
end

-- The single strongest reading, kept because most callers and every existing
-- test ask "what did that convey", singular.
function Heuristic.understand(utterance: Utterance, secrets: { Secret }, lexicon: { Coinage }): Understanding
	local all = Heuristic.conveyed(utterance, secrets, lexicon)
	local best: Understanding = all[1]
		or {
			concept = nil,
			confidence = 0,
			novelTerms = {},
			source = Heuristic.name,
		}
	best.novelTerms = Heuristic.novelTerms(utterance, secrets)
	return best
end

return Heuristic
