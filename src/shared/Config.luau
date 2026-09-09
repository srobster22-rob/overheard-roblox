--!strict
-- Tuning values for OVERHEARD. Everything here is a dial we will move during
-- playtesting; nothing here should be a secret from the client.

-- Every key at the TOP LEVEL of this table must be read somewhere in `src/`.
-- A dial that nothing reads is a promise the game does not keep, so dials for
-- systems that do not exist yet live under `Planned` instead, where they are
-- visibly not live. `tests/config.luau` derives that check from this file.

local Config = {
	GameName = "OVERHEARD",

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

	-- Forgetting. Heat bleeds off in REAL TIME, not per round, so a phrase the
	-- group stops using becomes safe to say again without waiting for a round
	-- boundary (there is no round flow yet — see R9). At 0.01/s a term burned
	-- to 1.0 falls back under ActThreshold after 40s of disuse and is fully
	-- cold after 100s. This is what keeps a long-running group from ending up
	-- unable to say anything at all.
	CoolPerSecond = 0.01,

	-- Rooms the Operator can be sent to. World.build must return a position for
	-- every one of these, and every secret payload must name one of them.
	-- tests/round.luau enforces the second half of that.
	Rooms = { "board", "archive" },

	-- Dials for systems that are not built yet. Nothing reads these, and the
	-- config test does not require anything to. Move a key up into the table
	-- above in the same commit that first reads it.
	Planned = {
		RoundLength = 600, -- seconds (R9, round flow)
		PlayersPerRound = 4, -- (R9)
	},
}

return Config
