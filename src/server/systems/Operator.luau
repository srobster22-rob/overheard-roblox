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
		backend: Types.ComprehensionBackend,
		onUnderstood: (concept: string, payload: string, confidence: number) -> ()?,
		onBurned: (coinage: Coinage) -> ()?,
	},
	Operator
))

function Operator.new(secrets: { Secret }): Operator
	return setmetatable({
		secrets = secrets,
		lexicon = {},
		observations = {},
		backend = Heuristic :: any,
		onUnderstood = nil,
		onBurned = nil,
	}, Operator)
end

-- Feed it something a player said. Safe to call on every chat message.
function Operator.hear(self: Operator, utterance: Utterance)
	local understanding = self.backend.understand(utterance, self.secrets, self.lexicon)

	if understanding.concept and understanding.confidence >= Config.ActThreshold then
		local payload = ""
		for _, secret in self.secrets do
			if secret.concept == understanding.concept then
				payload = secret.payload
				break
			end
		end
		if self.onUnderstood then
			(self.onUnderstood :: any)(understanding.concept, payload, understanding.confidence)
		end
	end

	-- Remember the unfamiliar words for a little while. If the players turn out
	-- to have been coordinating about a concept, we credit these retroactively.
	if #understanding.novelTerms > 0 then
		table.insert(self.observations, {
			terms = understanding.novelTerms,
			at = utterance.at,
			speaker = utterance.speaker,
		})
	end
end

local function findCoinage(self: Operator, phrase: string, concept: string): Coinage?
	for _, c in self.lexicon do
		if c.phrase == phrase and c.concept == concept then
			return c
		end
	end
	return nil
end

-- Called when players demonstrably ACTED on a concept (patched the right jack,
-- opened the right door). Anything unfamiliar said shortly before that is now
-- suspected of meaning it.
--
-- This is the acquisition rule, and it is deliberately behavioural rather than
-- linguistic: the Operator learns from consequences, not from grammar. That is
-- why it cannot be fooled by simply using a weird word - the word has to
-- actually precede the group succeeding.
function Operator.credit(self: Operator, concept: string, now: number)
	local kept: { Observation } = {}

	for _, obs in self.observations do
		local age = now - obs.at
		if age > Config.CreditWindow then
			continue -- too old to be related; drop it
		end
		kept[#kept + 1] = obs

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
			c.sightings += 1
			c.heat = math.clamp(c.heat + Config.HeatPerCredit * recency, 0, 1)

			if not wasBurned and c.heat >= 1 and self.onBurned then
				(self.onBurned :: any)(c)
			end
		end
	end

	self.observations = kept
end

-- Terms cool off between rounds. It forgets, a little, which is what keeps a
-- long-running group from being permanently mute.
function Operator.cool(self: Operator, amount: number)
	for _, c in self.lexicon do
		c.heat = math.max(0, c.heat - amount)
	end
end

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
