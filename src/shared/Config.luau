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
	--
	-- NOTHING CURRENTLY REACHES THIS. R46 measured it: burning a coinage takes
	-- four credited uses, a round supplies two, and heat is cold after 100s. The
	-- threshold is fine; the gap is between what the game credits and what
	-- burning costs. See LOOP_LOG R46 before retuning this dial to chase it.
	--
	-- Low enough that plain speech is always punished. This used to add "high
	-- enough that a half-learned coinage is a gamble rather than a certainty",
	-- which was never true: comprehension is a HARD threshold, so a coinage at
	-- or above this heat is understood every single time and one below it never
	-- is. There is no gamble anywhere in the code.
	--
	-- Left deterministic on purpose. R20 built the Lexicon panel on it -- red
	-- above the threshold, no gradient, and the row says "understood" as a fact
	-- -- so making comprehension random would make that panel lie. Whether the
	-- game WANTS the gamble is an owner's call, not a comment's.
	ActThreshold = 0.6,

	-- Acquisition. How far back the Operator will look when crediting an
	-- unfamiliar phrase for a concept the players just acted on.
	CreditWindow = 20, -- seconds

	-- How much heat one credited sighting adds, AT MAXIMUM RECENCY. The credit is
	-- weighted by how soon success followed the phrase, so the uses needed to
	-- burn a term depend on that gap. Measured against the real Operator: 4 uses
	-- when success is instant, 5 at a one-second gap, 6 at five seconds, 8 at
	-- ten. This said "roughly four uses", which is only the best case — and it
	-- is the number a reader would plan around.
	HeatPerCredit = 0.25,

	-- Forgetting. Heat bleeds off in REAL TIME, not per round, so a phrase the
	-- group stops using becomes safe to say again without waiting for a round
	-- boundary. At 0.01/s a term burned to 1.0 sits EXACTLY on ActThreshold after
	-- 40s of disuse — still understood, since the test is `>=` — and is under it
	-- a second later, fully cold after 100s. Measured in `tests/lifecycle.luau`,
	-- not divided here: this comment said "falls back under ActThreshold after
	-- 40s", and the boundary second is precisely the sort of thing prose gets
	-- wrong. This is what keeps a long-running group from ending up mute.
	--
	-- (The parenthetical here used to read "there is no round flow yet — see
	-- R9". R29 built it: rounds now end, wait out an intermission and begin
	-- again. A stale note like that is worse than none — it sends the next
	-- reader off to build something that already exists.)
	--
	-- NOT RECONCILED, and left for the owner: GAME.md says burned terms "cool
	-- slowly over real days", which would need about 0.0000116 — some 860x
	-- slower than this. At the rate above nothing accumulates across a session,
	-- so the escalation GAME.md is built on (a coinage that works for several
	-- rounds and then one night does not) cannot happen. Cooling over days also
	-- needs the Lexicon to outlive the server, which is the unbuilt DataStore
	-- work. Both are balance and scope calls, not defects to fix unilaterally.
	CoolPerSecond = 0.01,

	-- The server clock. Capture is asked every tick, because occupancy is a
	-- continuous fact: before R24 the Operator took whoever was in the room at
	-- the one instant it arrived, then stood there permanently harmless.
	TickSeconds = 0.25,
	-- Decay keeps its own slower beat. It is time-based, so ticking it faster
	-- would be correct but would replicate the whole lexicon four times a second.
	DecaySeconds = 1,

	-- How long the Operator stands in the room it understood before losing
	-- interest. Until R25 the answer was FOREVER, and since R24 it captures the
	-- whole time it is standing there -- so one plain word parked it on top of an
	-- objective permanently and the round could only end in a loss.
	-- The number is a balance question filed for the owner; that there must BE
	-- one is not.
	LingerSeconds = 20,

	-- Breath between rounds. Until R29 there was no next round at all: both
	-- endings fired a line and left the server a dead lobby, and a WIN did not
	-- even stop the Operator hunting.
	IntermissionSeconds = 8,

	-- How the Operator moves, and when it goes quiet. These lived as literals
	-- inside `Pursuit.new` until R27, which meant the invariant that matters --
	-- that every approach STARTS outside the silence radius, so players always
	-- hear it coming -- could not be asserted against the real number.
	PursuitSpeed = 9,
	-- Inside this distance from its target it stops making noise. The silence is
	-- the tell; it is the whole scare.
	SilenceRadius = 26,
	-- Close enough to count as arrived.
	ArriveRadius = 4,

	-- Guessing. The answer is two digits -- 90 possibilities -- and the submit
	-- remote is rate-limited to one attempt every 0.75s, so a player alone at a
	-- keypad brute-forces a line in about 34 seconds without anyone ever
	-- speaking. That defeats the only invariant this game has. So a wrong
	-- answer jams the line for the player who gave it, escalating: the n-th jam
	-- that player earns on that line lasts n * LockoutSeconds. Three honest
	-- typos in a row cost 20 seconds; guessing your way to the median 45 wrong
	-- answers costs about 40 minutes, which is not a strategy any more.
	GuessesBeforeLockout = 3,
	LockoutSeconds = 20,

	-- How close you must be to a station to submit at it, checked at SUBMIT
	-- time. It must be WIDER than `PromptReach` below, so a player standing
	-- where the game let them open the keypad is never refused by a stud of
	-- drift. That relationship used to be a sentence in this comment about a
	-- bare `10` in World.luau, with nothing between them: if the prompt distance
	-- were raised past this, a player could open a keypad at a distance where
	-- every answer is refused, and be told "you are not at that station" while
	-- standing exactly where the game let them open it.
	StationReach = 14,

	-- How close you must be for a station's prompt to appear at all. Strictly
	-- smaller than `StationReach`; `tests/config.luau` holds them in that order.
	PromptReach = 10,

	-- There is no OperatorReach dial any more. R21 made it a radius derived from
	-- the room; R23 found that the smallest circle containing a square also
	-- covers 9.94 studs of corridor outside every wall, so a player who got out
	-- of the door was still taken. Capture is now the ROOM itself -- see
	-- Connected.reachedInRoom -- and a radius nobody enforces is worse than none.

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
