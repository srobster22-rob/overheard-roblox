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
local SECRET_POOL: { Secret } = {
	{
		concept = "jack_number",
		plain = { "jack", "number", "socket", "port", "plug", "board", "switchboard" },
		payload = "board",
	},
	{
		concept = "breaker",
		plain = { "breaker", "fuse", "fusebox", "power", "electric", "switch", "lever" },
		payload = "basement",
	},
	{
		concept = "exit",
		plain = { "exit", "door", "out", "outside", "street", "leave", "escape", "stair" },
		payload = "lobby",
	},
	{
		concept = "directory",
		plain = { "directory", "address", "book", "listing", "ledger", "name" },
		payload = "archive",
	},
	{
		concept = "hiding",
		plain = { "hide", "hiding", "closet", "locker", "cabinet", "under", "behind" },
		payload = "hunt",
	},
}

function Round.pickSecrets(count: number): { Secret }
	local pool = table.clone(SECRET_POOL)
	-- Fisher-Yates, so the same three concepts do not come up every round.
	for i = #pool, 2, -1 do
		local j = math.random(i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local out: { Secret } = {}
	for i = 1, math.min(count, #pool) do
		table.insert(out, pool[i])
	end
	return out
end

-- The Operator's whole vocabulary of spoken lines. It is never threatening.
-- Politeness is the instrument.
Round.LINES = {
	greeting = "Number, please.",
	understood = "I have that party for you.",
	connecting = "I'm connecting you now.",
	busy = "That line is busy.",
	taken = "Go ahead, caller.",
}

return Round
