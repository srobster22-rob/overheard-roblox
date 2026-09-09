--!strict
-- Tuning values for OVERHEARD. Everything here is a dial we will move during
-- playtesting; nothing here should be a secret from the client.

local Config = {
	GameName = "OVERHEARD",

	-- Round
	RoundLength = 600, -- seconds
	PlayersPerRound = 4,

	-- Comprehension. How sure the Operator must be before it acts.
	-- Low enough that plain speech is always punished, high enough that a
	-- half-learned coinage is a gamble rather than a certainty.
	ActThreshold = 0.6,

	-- Acquisition. How far back the Operator will look when crediting an
	-- unfamiliar phrase for a concept the players just acted on.
	CreditWindow = 20, -- seconds

	-- How much heat one credited sighting adds, at maximum recency.
	-- 0.25 means roughly four uses burns a term - fast enough that players feel
	-- the decay inside a single session, slow enough to be worth coining.
	HeatPerCredit = 0.25,

	-- How much every term cools between rounds.
	CoolPerRound = 0.1,

	-- Rooms the Operator can be sent to. World.build must return a position for
	-- every one of these, and every secret payload must name one of them.
	-- tests/round.luau enforces the second half of that.
	Rooms = { "board", "archive" },
}

return Config
