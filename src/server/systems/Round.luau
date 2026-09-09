--!strict
-- Round flow and the objectives.
--
-- Design rule for every objective: ONE player can see the answer, ANOTHER must
-- act on it, and they are never in the same room. That is what makes players
-- audible. An objective a single player can solve alone is a bug in this game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

type Secret = Types.Secret

local Round = {}

-- The seed pool. `plain` is everything the Operator already understands for
-- that concept; players must get the idea across without any of it.
-- `payload` MUST name a room that World.build actually returns, or Pursuit
-- refuses the move and understanding has no visible effect. Only `board` and
-- `archive` exist today; add rooms before adding payloads.
local SECRET_POOL: { Secret } = {
	{
		concept = "jack_number",
		plain = { "jack", "number", "socket", "port", "plug", "board", "switchboard" },
		payload = "board",
	},
	{
		concept = "breaker",
		plain = { "breaker", "fuse", "fusebox", "power", "electric", "switch", "lever" },
		-- The Operator goes where the thing IS. The breaker panel is in the
		-- records room, so understanding "breaker" sends it there — which is
		-- also the room the reader is standing in.
		payload = "archive",
	},
	{
		concept = "exit",
		plain = { "exit", "door", "out", "outside", "street", "leave", "escape", "stair" },
		payload = "archive",
	},
	{
		concept = "directory",
		plain = { "directory", "address", "book", "listing", "ledger", "name" },
		payload = "archive",
	},
	{
		concept = "hiding",
		plain = { "hide", "hiding", "closet", "locker", "cabinet", "under", "behind" },
		payload = "archive",
	},
}

-- THE STATIONS. A physical place an objective can be solved, and the concept
-- players have to get across to solve it.
--
-- This table is the source of truth for a round. The secrets dealt to the
-- Operator are DERIVED from it (see `dealSecrets`), because the two used to be
-- independent: `init.server` hardcoded one objective while `pickSecrets`
-- shuffled 3 of 5 secrets, so 39.6% of servers ran an objective whose concept
-- the Operator was not listening for at all. Saying the answer out loud was
-- free, and the monster never moved for the one thing players had to discuss.
-- Never add a station without a secret whose `concept` matches; never add an
-- objective without a station (R2's rule). `tests/round.luau` enforces both.
export type Station = {
	id: string,
	concept: Types.ConceptId,
	-- Shown to the holder only. Takes the answer via string.format.
	prompt: string,
	-- The ProximityPrompt verb at the physical station.
	actionText: string,
}

local STATIONS: { Station } = {
	{
		id = "board",
		concept = "jack_number",
		prompt = "Line is out. Patch it to jack %s.",
		actionText = "Patch",
	},
	{
		id = "breaker",
		concept = "breaker",
		prompt = "Breaker %s tripped. Someone has to throw it.",
		actionText = "Throw",
	},
}

Round.STATIONS = STATIONS

-- What the Operator is listening for this round. Every station's concept is
-- guaranteed in; `count` is a FLOOR that ambient extras are shuffled up to, not
-- a cap that can squeeze a station's concept out.
function Round.dealSecrets(count: number): { Secret }
	local byConcept: { [string]: Secret } = {}
	for _, secret in SECRET_POOL do
		byConcept[secret.concept] = secret
	end

	local out: { Secret } = {}
	local taken: { [string]: boolean } = {}
	for _, station in STATIONS do
		local secret = byConcept[station.concept]
		if not secret then
			error(`station '{station.id}' wants concept '{station.concept}', which no secret carries`)
		end
		table.insert(out, secret)
		taken[station.concept] = true
	end

	-- Then ambient secrets: things it understands that no objective needs, so
	-- the safe vocabulary is not simply "everything except two words".
	local rest: { Secret } = {}
	for _, secret in SECRET_POOL do
		if not taken[secret.concept] then
			table.insert(rest, secret)
		end
	end
	for i = #rest, 2, -1 do
		local j = math.random(i)
		rest[i], rest[j] = rest[j], rest[i]
	end
	for _, secret in rest do
		if #out >= count then
			break
		end
		table.insert(out, secret)
	end
	return out
end

-- `Round.pickSecrets` was DELETED in R12 after five rounds on the carried list.
-- It shuffled 3 of 5 secrets with no regard for the stations, which is the exact
-- selection that ran an objective the Operator was not listening for on 39.6% of
-- servers (R5). `dealSecrets` replaced it; nothing in `src/` had called it since,
-- but it stayed exported, so it was one call away from re-creating that defect.
-- Dead AND loaded. If a shuffled selection is ever wanted again, it must still
-- seat every station's concept first.

-- The Operator's whole vocabulary of spoken lines. It is never threatening.
-- Politeness is the instrument.
Round.LINES = {
	greeting = "Number, please.",
	understood = "I have that party for you.",
	connecting = "I'm connecting you now.",
	busy = "That line is busy.",
	-- It reached the room it understood. Said to everyone, because everyone
	-- needs to know it is here.
	taken = "Go ahead, caller.",
	-- The round is WON. This used to be `taken` as well: the monster arriving in
	-- your room and the group finishing the board fired the same string, and once
	-- R10 dropped `detail` from the client's `onHeard` there was nothing left to
	-- tell them apart. Two opposite events, one sentence. Kept in register --
	-- every line here is real switchboard phrasing, and the operator's sign-off
	-- for a call that went through is exactly this.
	completed = "Your call has been completed.",
}

return Round
