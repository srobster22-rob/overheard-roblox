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
	-- R46 found no codeword could reach this in normal play; R131 closed that by
	-- changing how heat is FORGOTTEN (`CoolPerRound` below), not this dial.
	-- Measured then: lowering the threshold only switches a codeword between
	-- "never understood" and "understood in the round it was coined".
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

	-- Forgetting. Every coinage loses this much heat ONCE PER ROUND, when the next
	-- round begins. R131, the owner's answer to R46.
	--
	-- Until R131 heat bled off per second (`CoolPerSecond = 0.01`), and a round
	-- cooled a codeword by more than one credit could add, so heat never carried
	-- from one round to the next: a codeword either never burned or burned in the
	-- round it was coined. Measured on a simulated session through the real
	-- Operator, no per-second rate gave GAME.md's "works for four rounds and then
	-- doesn't" at more than one round pace (0.0025/s: 2 rounds at a solve every
	-- 30s, 4 at 60s, never at 120s). Charged per round, 0.32 gives 4 rounds at a
	-- solve every 15, 30, 60 and 120 seconds, with ordinary chat left alone.
	--
	-- What that number assumes, so nobody retunes it blind: the holder says the
	-- codeword about twice shortly before the solve, worth 0.40 heat a round at
	-- `HeatPerCredit` 0.25. The band for 4 rounds is 0.30 < CoolPerRound <= 0.333
	-- (0.30 gives 3, 0.34 gives 5). One mention a solve (0.225) never burns; a
	-- third as the button is pressed (0.65) burns in the first round.
	--
	-- R134: a word that is already understood AND was credited again this round
	-- is exempt (`Operator.coolRound`), or red never bites: the first playtests
	-- saw the panel red in round 4 and the Operator first come in round 9.
	--
	-- Known cost: a word the group retires is safe again after one whole round
	-- unused, not some seconds later mid-round. Anything it cools to zero leaves
	-- the register (`Operator.cool`), which is what keeps the panel small.
	--
	-- STILL NOT RECONCILED, and the owner's: GAME.md wants the Lexicon to persist
	-- per group and cool over real days. That needs the unbuilt DataStore work and
	-- an answer to R73 (what counts as the same group).
	CoolPerRound = 0.32,

	-- The server clock. Capture is asked every tick, because occupancy is a
	-- continuous fact: before R24 the Operator took whoever was in the room at
	-- the one instant it arrived, then stood there permanently harmless.
	TickSeconds = 0.25,

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

	-- THE SUPERVISOR (GAME.md entity #4): how long a player may go without
	-- saying anything before a call is put through to them.
	--
	-- Until this existed, silence was the winning strategy and the monster was
	-- opt-in: four silent players won 20 rounds in 600 simulated seconds with
	-- zero captures and the Operator never once leaving its post, against 16
	-- rounds and 96 captures for a group that talked.
	--
	-- 45s is long enough that you are not typing constantly and short enough
	-- that you cannot sit out an objective. It is the dial most likely to be
	-- wrong; it is here, alone, so it can be moved.
	SpeakEvery = 45,
	-- When the Supervisor starts warning that player. The gap between the two
	-- is the time they have to react, and a warning without that gap is not a
	-- warning -- `Silence.warningLeadSeconds` exists so a test can say so.
	SpeakWarning = 30,
	-- After a call goes through, that player is not called again for this long,
	-- however quiet they stay. Without it the Supervisor fires every tick at
	-- somebody who has already been punished -- the mistake R11 and R24 each
	-- had to unpick, an event that should announce itself once announcing
	-- itself continuously.
	SupervisorCooldown = 25,

	-- How wide a Roblox character is, near enough. Used to keep the corridor's
	-- WALLS inside the span its doorways can pass: a player walking the corridor
	-- must never be somewhere the door will not let them through.
	PlayerWidth = 4,

	-- There is no OperatorReach dial any more. R21 made it a radius derived from
	-- the room; R23 found that the smallest circle containing a square also
	-- covers 9.94 studs of corridor outside every wall, so a player who got out
	-- of the door was still taken. Capture is now the ROOM itself -- see
	-- Connected.reachedInRoom -- and a radius nobody enforces is worse than none.

	-- Rooms the Operator can be sent to. World.build must return a position for
	-- every one of these, and every secret payload must name one of them.
	-- tests/round.luau enforces the second half of that.
	Rooms = { "board", "archive", "lobby" },

	-- Dials for systems that are not built yet. Nothing reads these, and the
	-- config test does not require anything to. Move a key up into the table
	-- above in the same commit that first reads it.
	Planned = {
		RoundLength = 600, -- seconds (R9, round flow)
		PlayersPerRound = 4, -- (R9)
	},
}

return Config
