--!strict
-- The comprehension backend: word matching, with no API access.
--
-- It answers one question per utterance: did this convey a secret, and if not,
-- which unfamiliar words were used near it? The second half is what makes the
-- Operator able to learn, and it is the more important half.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lexicon = require(ReplicatedStorage.Shared.Lexicon)
local Numerals = require(ReplicatedStorage.Shared.Numerals)
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
-- the padding, `string.find` matches inside a longer token in both directions:
-- the phrase's last word can be a prefix of a token ("the blue" understood
-- inside "check the bluetooth") and its first word a suffix of one ("one blue"
-- inside "someone blue"). The Operator mints such bigrams from ordinary
-- sentences, so a player speaking normally would move the monster, at full
-- confidence, for a phrase they never said.
local function containsWords(joined: string, phrase: string): boolean
	return string.find(` {joined} `, ` {phrase} `, 1, true) ~= nil
end

-- One definition of "the same word", shared with the learner.
local sameWord = Lexicon.sameWord

-- Does `words` contain `phrase` as a run of ADJACENT, IN-ORDER whole words,
-- each allowed to meet its counterpart on a shared reading? Positional, so the
-- whole-word rule (see `containsWords`) holds by construction: a phrase word can
-- only ever be compared with one whole token, never with part of a longer one.
local function sequenceMeets(words: { string }, phrase: { string }): boolean
	if #phrase == 0 or #phrase > #words then
		return false
	end
	for start = 1, #words - #phrase + 1 do
		local all = true
		for k = 1, #phrase do
			if not sameWord(words[start + k - 1], phrase[k]) then
				all = false
				break
			end
		end
		if all then
			return true
		end
	end
	return false
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
-- `gather spot` at heat 1.00 — and stemmed again, both would score 0.00
-- against the exact sentence that minted them.
--
-- That is the worst possible failure for this game specifically. The Lexicon
-- panel is the instrument players read to decide what is still safe to say, and
-- it would show those two at 100% burned. A group abandons a codeword that
-- still works because the panel says the Operator learned it.
--
-- Handled here rather than in `Lexicon.stem`: `gather -> gath` is the `er` rule
-- working as written, and telling "gather" from "gath"+"er" needs real
-- morphology. The danger is the DOUBLE stemming, not the stemmer.
--
-- `glued` holds the stems of every two and three ADJACENT tokens run together
-- ("ja ck" -> "jack", "out side" -> "outside"), because a word split into
-- chunks arrives as tokens that each match nothing. Consulted for SINGLE-word
-- terms only; multi-word phrases still need their words in order on word
-- boundaries, and gluing must never be able to satisfy that.
--
-- Returns the candidate that matched, so the Operator can say which word moved
-- it, or nil.
local function matchesAny(
	stems: { string },
	joined: string,
	candidates: { string },
	alreadyStemmed: boolean?,
	glued: { string }?
): string?
	for _, candidate in candidates do
		local candidateStems = if alreadyStemmed
			then Lexicon.tokenize(candidate)
			else Lexicon.stemAll(Lexicon.tokenize(candidate))
		if #candidateStems == 0 then
			continue
		end
		if #candidateStems == 1 then
			-- Every reading of the term against every reading of the
			-- utterance (the caller passes the utterance side already widened).
			for _, reading in Lexicon.readings(candidateStems[1]) do
				if Lexicon.contains(stems, reading) then
					return candidate
				end
				if glued and Lexicon.contains(glued, reading) then
					return candidate
				end
			end
		else
			-- Multi-word term: require the whole phrase, in order, on word
			-- boundaries. Single-word terms go through `Lexicon.contains`,
			-- which compares whole stems.
			if containsWords(joined, table.concat(candidateStems, " ")) then
				return candidate
			end
			-- The same rule -- whole words, adjacent, in order -- but each
			-- word may meet its counterpart on any shared reading, so a burned
			-- "blue wire" still hears "the blue wires". The exact check above
			-- stays first; this only adds matches.
			if sequenceMeets(string.split(joined, " "), candidateStems) then
				return candidate
			end
		end
	end
	return nil
end

-- EVERY concept the utterance conveys, strongest first.
--
-- `understand` below reports only the strongest, and reporting one is a hole in
-- "plain speech is always punished": "the jack is right by the fuse" carries
-- plain giveaways for TWO concepts. Either word alone is understood, so if only
-- one is reported, the COMBINATION hides the other -- a group that noticed
-- could bury every dangerous word inside a sentence giving away something
-- already lost.
--
-- `codes` is each concept's live code, if the round has dealt one: saying it in
-- any form `Lexicon.numbersIn` reads is plain language for that concept. So is
-- saying it with a word the group uses as a number, once `known` holds it
-- (Operator.knownValues, Numerals.read).
function Heuristic.conveyed(
	utterance: Utterance,
	secrets: { Secret },
	lexicon: { Coinage },
	codes: { [string]: string }?,
	known: { [string]: number }?,
	letters: { [string]: number }?
): { Understanding }
	local words = Lexicon.tokenize(utterance.text)
	local stems = Lexicon.stemAll(words)
	local joined = table.concat(stems, " ")

	local glued: { string } = {}
	for i = 1, #words - 1 do
		for span = 2, 3 do
			if i + span - 1 <= #words then
				local whole = table.concat(words, "", i, i + span - 1)
				if #whole >= 3 then
					table.insert(glued, Lexicon.stem(whole))
				end
			end
		end
	end

	-- The utterance side of `Lexicon.readings`, for single-word matching.
	-- `joined` (multi-word phrases) is deliberately left exact.
	local function widen(list: { string }): { string }
		local wide: { string } = {}
		for _, s in list do
			for _, reading in Lexicon.readings(s) do
				table.insert(wide, reading)
			end
		end
		return wide
	end
	local wideStems = widen(stems)
	local wideGlued = widen(glued)
	-- A code glued to a word ("door48") is read a second way, split in two,
	-- so the word in it is heard too. Single words only: phrases and the
	-- gluing above stay on the line as typed, where "ex17" is still "exit".
	for _, reading in widen(Lexicon.stemAll(Lexicon.tokenize(utterance.text, true))) do
		table.insert(wideStems, reading)
	end

	local found: { Understanding } = {}
	local numbers = if codes then Lexicon.numbersIn(utterance.text) else {}
	if codes and known then
		for number in Numerals.read(utterance.text, known) do
			numbers[number] = true
		end
	end
	-- And spelled with the group's letters, once those are understood.
	if codes and letters then
		for number in Numerals.readLetters(utterance.text, letters) do
			numbers[number] = true
		end
	end

	for _, secret in secrets do
		local confidence = 0
		local heard: string? = nil
		local byCode = false

		-- Plain language is always understood.
		local plainWord = matchesAny(wideStems, joined, secret.plain, false, wideGlued)
		if plainWord then
			confidence = 1
			heard = plainWord
		end

		-- And so is the code, however it is written.
		local code = if codes then codes[secret.concept] else nil
		if code and numbers[code] then
			confidence = 1
			heard = code
			byCode = true
		end

		-- A coinage is understood in proportion to how well it has been learned.
		for _, coinage in lexicon do
			if coinage.concept ~= secret.concept then
				continue
			end
			-- Already a stem; see `alreadyStemmed` above.
			if matchesAny(wideStems, joined, { coinage.phrase }, true, wideGlued) then
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
				heard = heard,
				byCode = byCode,
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
	--
	-- A MULTI-word plain term is plain as a phrase, not word by word. Putting
	-- each of its words in this set would mean "line", "phone", "take" and
	-- "cover" (from "phone line" and "take cover") could never be learned, so a
	-- codeword built on any of them, like "the red line", could never burn. Only
	-- the phrase itself is kept out, by the same-phrase rule the matcher uses.
	local plainStems: { [string]: boolean } = {}
	local plainPhrases: { string } = {}
	for _, secret in secrets do
		for _, term in secret.plain do
			local termStems = Lexicon.stemAll(Lexicon.tokenize(term))
			if #termStems == 1 then
				plainStems[termStems[1]] = true
			elseif #termStems > 1 then
				table.insert(plainPhrases, table.concat(termStems, " "))
			end
		end
	end
	local function isPlainPhrase(gram: string): boolean
		for _, phrase in plainPhrases do
			if Lexicon.samePhrase(gram, phrase) then
				return true
			end
		end
		return false
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
			if not plainStems[a] and not plainStems[b] and not isPlainPhrase(gram) then
				offer(gram)
			end
		end
	end

	return novel
end

-- The single strongest reading, for the callers and tests that ask "what did
-- that convey", singular.
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
