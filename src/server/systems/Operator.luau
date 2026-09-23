--!strict
-- The Operator: the listener, and the thing that learns.
--
-- Two responsibilities, and it is worth keeping them straight:
--   1. COMPREHENSION - did that utterance convey a secret right now?
--   2. ACQUISITION   - which unfamiliar phrase is starting to mean something?
--
-- (2) is the game. A monster that only did (1) would be a keyword filter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Lexicon = require(ReplicatedStorage.Shared.Lexicon)
local Heuristic = require(script.Parent.Heuristic)

type Secret = Types.Secret
type Coinage = Types.Coinage
type Utterance = Types.Utterance
type Understanding = Types.Understanding

type Observation = {
	terms: { string },
	at: number,
	speaker: Player,
}

local Operator = {}
Operator.__index = Operator

export type Operator = typeof(setmetatable(
	{} :: {
		secrets: { Secret },
		lexicon: { Coinage },
		observations: { Observation },
		-- Coinages credited since the last round boundary; see `coolRound`.
		creditedSinceBoundary: { [Coinage]: boolean },
		-- Every credit each meaning of a phrase has had, by phrase then concept;
		-- see `contrast`. Unlike heat it does not cool.
		evidence: { [string]: { [string]: number } },
		backend: Types.ComprehensionBackend,
		-- Each concept's live code right now, asked for at the moment something
		-- is said, so a code re-dealt or re-rolled is never heard stale.
		liveCodes: (() -> { [string]: string })?,
		-- `heard` is what moved it, when that is the server's own text (Types).
		onUnderstood: (concept: string, payload: string, confidence: number, heard: string?) -> ()?,
		onBurned: (coinage: Coinage) -> ()?,
		-- The live code for `concept` was said aloud.
		onCodeHeard: (concept: string) -> ()?,
	},
	Operator
))

function Operator.new(secrets: { Secret }): Operator
	return setmetatable({
		secrets = secrets,
		lexicon = {},
		observations = {},
		creditedSinceBoundary = {},
		evidence = {},
		backend = Heuristic :: any,
		liveCodes = nil,
		onUnderstood = nil,
		onBurned = nil,
		onCodeHeard = nil,
	}, Operator)
end

-- Feed it something a player said. Safe to call on every chat message.
function Operator.hear(self: Operator, utterance: Utterance)
	-- EVERY concept the utterance conveyed, not just the strongest. Taking the
	-- best one meant "the jack is right by the fuse" gave away `jack_number` and
	-- left `breaker` free, because both words are plain language and only one
	-- could be reported. Either alone was understood; the combination hid one.
	local codes = if self.liveCodes then self.liveCodes() else nil
	local conveyed = (self.backend :: any).conveyed(utterance, self.secrets, self.lexicon, codes)

	for _, understanding in conveyed do
		if understanding.concept == nil or understanding.confidence < Config.ActThreshold then
			continue
		end
		local payload = ""
		for _, secret in self.secrets do
			if secret.concept == understanding.concept then
				payload = secret.payload
				break
			end
		end
		if self.onUnderstood then
			(self.onUnderstood :: any)(understanding.concept, payload, understanding.confidence, understanding.heard)
		end
		if understanding.byCode and self.onCodeHeard then
			(self.onCodeHeard :: any)(understanding.concept)
		end
	end

	-- Remember the unfamiliar words for a little while. If the players turn out
	-- to have been coordinating about a concept, we credit these retroactively.
	--
	-- Recorded ONCE per utterance, outside the loop above: a sentence conveying
	-- two concepts still offered its novel terms once, and crediting them twice
	-- would inflate every coinage minted from it.
	local novel = (self.backend :: any).novelTerms(utterance, self.secrets)
	if #novel > 0 then
		table.insert(self.observations, {
			terms = novel,
			at = utterance.at,
			speaker = utterance.speaker,
		})
	end
end

-- An exact match wins; otherwise an existing coinage that is the SAME PHRASE
-- by reading (R87). Without the second pass, a group alternating "blue wire"
-- and "blue wires" minted two coinages, each at half the heat, and the reader
-- -- which already treats them as one phrase -- took the weaker 0.50, under
-- the act threshold: varying the plural kept a codeword unlearned for free, and
-- the Lexicon panel showed the same word twice. The first-minted spelling is
-- kept, so the panel's row does not change its name under the players.
local function findCoinage(self: Operator, phrase: string, concept: string): Coinage?
	for _, c in self.lexicon do
		if c.phrase == phrase and c.concept == concept then
			return c
		end
	end
	for _, c in self.lexicon do
		if c.concept == concept and Lexicon.samePhrase(c.phrase, phrase) then
			return c
		end
	end
	return nil
end

-- A WORD USED BEFORE EVERY RESTORE MEANS NOTHING IN PARTICULAR. Crediting a
-- phrase toward one concept takes the same heat off that phrase's other
-- meanings -- unless the Operator has more evidence for the other meaning.
-- Evidence is every credit a meaning has ever had here, and it does not cool,
-- so it says which station a word has been used for MOST.
--   * Filler said as often before one station's restore as before another's
--     ("say", "mine", "then") cancels itself out instead of being filed for
--     whichever station was restored first.
--   * A word said MORE before one station is that station's word, filler or
--     not: three mentions before the first restore still file it at once (the
--     rate the owner's R46 answer documents), and it moves to another station
--     only once said at least as often before that one.
--   * The cost: a group that recites ALL its codewords before every restore,
--     equally often, teaches none of them. Each is filler by this rule.
--   * A group's nickname keeps its heat when it is also mentioned before
--     another station's restore ("piano done, now the tuba"). R143's first
--     version debited it anyway: a nickname said twice before its own station
--     and once before another never burned, and saying a codeword once near
--     another restore was a free way to stop it being learned.
-- A tie is a debit: filler said twice before every restore ties every time.
-- No rate changes: `HeatPerCredit` and `CoolPerRound` are what the owner's R46
-- answer was measured with.
local function evidenceFor(self: Operator, c: Coinage): number
	local byConcept = self.evidence[c.phrase]
	-- A meaning with no record counts what it holds. Every credit records one,
	-- so today only a coinage made some other way (LexiconSave, not yet wired)
	-- could lack it.
	return if byConcept and byConcept[c.concept] then byConcept[c.concept] else c.heat
end

local function contrast(self: Operator, credited: Coinage, amount: number)
	local byConcept = self.evidence[credited.phrase] or {}
	byConcept[credited.concept] = (byConcept[credited.concept] or 0) + amount
	self.evidence[credited.phrase] = byConcept
	local mine = byConcept[credited.concept]
	for i = #self.lexicon, 1, -1 do
		local other = self.lexicon[i]
		if
			other ~= credited
			and other.concept ~= credited.concept
			and Lexicon.samePhrase(other.phrase, credited.phrase)
			and evidenceFor(self, other) <= mine
		then
			other.heat = math.max(0, other.heat - amount)
			if other.heat <= 0 then
				table.remove(self.lexicon, i)
			end
		end
	end
end

-- A word cooled out of every meaning is forgotten whole, its evidence with it
-- (R14: the Operator keeps no file on a word it no longer knows). A meaning
-- debited to nothing keeps its evidence while the word has another meaning.
local function forgetLostWords(self: Operator)
	local known: { [string]: boolean } = {}
	for _, c in self.lexicon do
		known[c.phrase] = true
	end
	for phrase in self.evidence do
		if not known[phrase] then
			self.evidence[phrase] = nil
		end
	end
end

-- Called when players demonstrably ACTED on a concept (patched the right jack,
-- opened the right door). Anything unfamiliar said shortly before that is now
-- suspected of meaning it.
--
-- This is the acquisition rule, and it is deliberately behavioural rather than
-- linguistic: the Operator learns from consequences, not from grammar. That is
-- why it cannot be fooled by simply using a weird word - the word has to
-- actually precede the group succeeding.
--
-- An utterance is credited to at most ONE concept: what you said just before
-- the lights came back on taught the Operator about the lights, not about
-- everything else the group happened to finish in the same twenty seconds.
-- Observations are therefore CONSUMED here. While only one objective existed
-- this was unobservable; with two stations, solving both inside the credit
-- window would otherwise burn every word said beforehand twice, into two
-- different concepts, at double speed.
function Operator.credit(self: Operator, concept: string, now: number)
	local gained: { [Coinage]: number } = {}
	local credited: { Coinage } = {}
	for _, obs in self.observations do
		local age = now - obs.at
		if age > Config.CreditWindow then
			continue -- too old to be related; drop it
		end

		-- Recency weighting: something said one second before the action is far
		-- more suspicious than something said fifteen seconds before.
		local recency = 1 - (age / Config.CreditWindow)

		for _, term in obs.terms do
			local coinage = findCoinage(self, term, concept)
			if not coinage then
				coinage = {
					phrase = term,
					concept = concept,
					heat = 0,
					sightings = 0,
					coinedBy = obs.speaker.UserId,
				}
				table.insert(self.lexicon, coinage :: Coinage)
			end

			local c = coinage :: Coinage
			local wasBurned = c.heat >= 1
			local credit = Config.HeatPerCredit * recency
			self.creditedSinceBoundary[c] = true
			c.sightings += 1
			c.heat = math.clamp(c.heat + credit, 0, 1)
			if gained[c] == nil then
				table.insert(credited, c)
			end
			gained[c] = (gained[c] or 0) + credit

			if not wasBurned and c.heat >= 1 and self.onBurned then
				(self.onBurned :: any)(c)
			end
		end
	end

	-- Weighed once the whole window is counted, so a word said twice before
	-- this restore has both sightings as evidence whichever came first.
	for _, c in credited do
		contrast(self, c, gained[c])
	end

	-- Everything in the window was just spent on `concept`; everything outside
	-- it was too old to matter. Either way nothing survives this call.
	self.observations = {}
end

-- Drop novel terms that are still waiting to be credited. Called when a round
-- ends: `CreditWindow` is 20 seconds against an 8-second intermission, so a
-- phrase said just before one round finished was being credited by a success in
-- the NEXT one -- six coinages minted across the boundary in the R31 probe.
--
-- The acquisition rule is "the group said it and then succeeded". Crediting
-- across a reset turns that into "said last round, succeeded this one", which
-- is a different claim and not a true one. The LEXICON itself is untouched:
-- burned terms carry over on purpose, and that is the retention mechanic.
function Operator.forgetObservations(self: Operator)
	self.observations = {}
end

-- Terms cool off. It forgets, a little, which is what keeps a long-running
-- group from being permanently mute. Returns whether anything actually moved,
-- so callers can avoid replicating an unchanged lexicon.
--
-- A TERM THAT REACHES ZERO IS DROPPED, not left sitting at zero. Until R14 it
-- was left, and "it forgets" was only ever true of the heat, never of the
-- register:
--
--   * `snapshot` ships every dead entry to every client on every change, and
--     `renderLexicon` draws every entry it is given with no heat floor. So the
--     one panel that tells a player what the Operator has picked up listed
--     words at "0%" -- words it does not know at all, and by this module's own
--     rule cannot act on -- in the same list, in the same shape, as the words
--     that will get them killed. What the player could SEE and what the server
--     believed had come apart.
--   * `Heuristic.understand` walks the whole register once per secret per
--     utterance, re-tokenising and re-stemming each phrase, so dead entries are
--     paid for on every line of chat forever.
--   * And the register only grows. One 230-character message -- inside
--     Roblox's chat cap -- offers 79 candidate terms, and one solve inside the
--     credit window writes all 79 in. Nothing removed them, so a single long
--     message permanently enlarged the panel and the per-utterance scan.
--
-- Dropping at zero is observationally neutral for COMPREHENSION, which is why
-- it is safe: `understand` scores a coinage as `heat / BURNED_AT` and only
-- takes it `if confidence > best.confidence` starting from 0, so a zero-heat
-- coinage can never be the concept it picks. `tests/operator.luau` asserts that
-- directly rather than leaving it as an argument. What DOES change is that a
-- phrase which comes back after being fully forgotten comes back fresh, with
-- `sightings` at 1 and a new `coinedBy`. That is the correct reading of
-- forgetting: the Operator is not keeping a file on a word it no longer knows.
--
-- Removal is NOT conditional on the heat having moved this tick. A term already
-- resting at zero cools to zero, so an "only if it changed" test would leave
-- exactly the entries this is meant to clear.
function Operator.cool(self: Operator, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local changed = false
	-- Backwards: `table.remove` shifts everything after the index.
	for i = #self.lexicon, 1, -1 do
		local c = self.lexicon[i]
		local cooled = math.max(0, c.heat - amount)
		if cooled ~= c.heat then
			c.heat = cooled
			changed = true
		end
		if c.heat <= 0 then
			table.remove(self.lexicon, i)
			changed = true
		end
	end
	forgetLostWords(self)
	return changed
end

-- The round boundary's forgetting (R134). Everything cools by `amount` EXCEPT a
-- coinage that is already understood and was credited again since the last
-- boundary: a word the group is still succeeding with stays understood.
--
-- R131 cooled everything, and the first playtests (PT1, PT2) showed what that
-- cost: a codeword crossed the threshold at the solve in its fourth round, was
-- cooled back under it seconds later at the restart, and so was safe every time
-- it was actually SAID. The panel showed red from round 4; the Operator first
-- came for the word in round 9. Red has to mean it is coming.
--
-- A word the group retires is not credited, so it cools like anything else and
-- is safe again after a round of disuse. That is still the way back.
function Operator.coolRound(self: Operator, amount: number): boolean
	if amount <= 0 then
		self.creditedSinceBoundary = {}
		return false
	end
	local changed = false
	for i = #self.lexicon, 1, -1 do
		local c = self.lexicon[i]
		if self.creditedSinceBoundary[c] and c.heat >= Config.ActThreshold then
			continue
		end
		local cooled = math.max(0, c.heat - amount)
		if cooled ~= c.heat then
			c.heat = cooled
			changed = true
		end
		if c.heat <= 0 then
			table.remove(self.lexicon, i)
			changed = true
		end
	end
	self.creditedSinceBoundary = {}
	forgetLostWords(self)
	return changed
end

-- `Operator.decay` (per-second forgetting on the server's clock) was DELETED in
-- R131 with `Config.CoolPerSecond`. The server now calls `cool` once per round
-- with `Config.CoolPerRound`; leaving `decay` exported would have kept a second
-- clock one call away from cooling everything twice.

-- What the client needs to render the Lexicon panel.
function Operator.snapshot(self: Operator): { Coinage }
	local out: { Coinage } = {}
	for _, c in self.lexicon do
		table.insert(out, {
			phrase = c.phrase,
			concept = c.concept,
			heat = c.heat,
			sightings = c.sightings,
			coinedBy = c.coinedBy,
		})
	end
	return out
end

return Operator
