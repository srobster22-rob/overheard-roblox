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
	-- How many rounds a codeword lasts is set by how heat is FORGOTTEN
	-- (`CoolPerRound` below), not by this dial.
	--
	-- Low enough that plain speech is always punished. Comprehension is a HARD
	-- threshold: a coinage at or above this heat is understood every single time
	-- and one below it never is. There is no gamble anywhere in the code.
	--
	-- Left deterministic on purpose. The Lexicon panel is built on it -- red
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
	-- ten. Four is only the best case; do not plan around it.
	HeatPerCredit = 0.25,

	-- Forgetting. Every coinage loses this much heat ONCE PER ROUND, when the next
	-- round begins: the owner's rule (OWNER.md).
	--
	-- Per round, not per second. A per-second rate cools a codeword by more than
	-- one credit can add over a round, so heat never carries from one round to
	-- the next: a codeword either never burns or burns in the round it was
	-- coined. Measured on a simulated session through the real Operator, no
	-- per-second rate gives GAME.md's "works for four rounds and then doesn't"
	-- at more than one round pace (0.0025/s: 2 rounds at a solve every 30s, 4 at
	-- 60s, never at 120s). Charged per round, 0.32 gives 4 rounds at a solve
	-- every 15, 30, 60 and 120 seconds, with ordinary chat left alone.
	--
	-- What that number assumes, so nobody retunes it blind: the holder says the
	-- codeword about twice shortly before the solve, worth 0.40 heat a round at
	-- `HeatPerCredit` 0.25. The band for 4 rounds is 0.30 < CoolPerRound <= 0.333
	-- (0.30 gives 3, 0.34 gives 5). One mention a solve (0.225) never burns; a
	-- third as the button is pressed (0.65) burns in the first round.
	--
	-- A word that is already understood AND was credited again this round is
	-- exempt (`Operator.coolRound`, DECISIONS D3), or red never bites: each
	-- round's cooling takes a word in use back under the threshold before it is
	-- said again, so the panel shows it red for rounds before the Operator
	-- first comes.
	--
	-- Known cost: a word the group retires is safe again after one whole round
	-- unused, not some seconds later mid-round. Anything it cools to zero leaves
	-- the register (`Operator.cool`), which is what keeps the panel small.
	--
	-- STILL NOT RECONCILED, and the owner's: GAME.md wants the Lexicon to persist
	-- per group and cool over real days. That needs the unbuilt DataStore work and
	-- the owner's answer on what counts as the same group (OWNER.md).
	CoolPerRound = 0.32,

	-- The server clock. Capture is asked every tick, because occupancy is a
	-- continuous fact: an Operator that took only whoever was in the room at
	-- the instant it arrived would then stand there harmless.
	TickSeconds = 0.25,

	-- How long the Operator stands in the room it understood before losing
	-- interest. It captures the whole time it stands there, so with no limit one
	-- plain word would park it on top of an objective for good and the round
	-- could only end in a loss. The number is a balance question filed for the
	-- owner; that there must BE one is not.
	LingerSeconds = 20,

	-- THE CALL (DECISIONS D6). When the last line is restored the outside call
	-- rings for this long with the street door shut; then the door opens and the
	-- Operator is sent for the lobby, where the door is. The round is won when
	-- everyone still free stands in the lobby. Measured (tests/escape.luau's
	-- race): the Operator reaches the lobby about 16 s after the ring starts from
	-- its post, 23 s from a room, and the longest run to the lobby, from a far
	-- corner of the board room or the archive, is 123 studs: under 8 s at
	-- Roblox's walking 16 studs/s. So a group that runs at once has about 8 s in
	-- hand, and one that talks longer than that walks into it. A tuning dial, set
	-- without a Studio playtest.
	CallRingSeconds = 10,
	-- How long after the door opens the round is settled anyway: won if anyone
	-- still free got out, lost if nobody did. Without it one player who never
	-- comes holds the round open for good. Long enough to wait the Operator out:
	-- it stays LingerSeconds once it gets there, and even when it set off from a
	-- room it has left with more than that run to spare (the same race).
	EscapeSeconds = 45,

	-- Breath between rounds.
	IntermissionSeconds = 8,

	-- How the Operator moves, and when it goes quiet. Dials here rather than
	-- literals inside `Pursuit.new`, so the invariant that matters -- that every
	-- approach STARTS outside the silence radius, so players always hear it
	-- coming -- is asserted against the real numbers (tests/layout.luau).
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
	-- A wrong code a player enters is free this many times in a round; every
	-- one after that rings through, and the Operator walks to that station's
	-- room. With the deal shuffled, a code alone does not say which station it
	-- is for, and trying it at each station in turn must be a gamble rather
	-- than a protocol. One, so a single typo costs nothing.
	FreeWrongDials = 1,

	-- How close you must be to a station to submit at it, checked at SUBMIT
	-- time. It must be WIDER than `PromptReach` below, so a player standing
	-- where the game let them open the keypad is never refused by a stud of
	-- drift. If the prompt reached further than this, a player could open a
	-- keypad at a distance where every answer is refused, and be told "you are
	-- not at that station" while standing exactly where the game let them open
	-- it.
	StationReach = 14,

	-- How close you must be for a station's prompt to appear at all. Strictly
	-- smaller than `StationReach`; `tests/config.luau` holds them in that order.
	PromptReach = 10,

	-- THE SUPERVISOR (GAME.md entity #4): how long a player may go without
	-- saying anything before a call is put through to them.
	--
	-- Without it, silence is the winning strategy and the monster is opt-in: a
	-- group that never speaks gives the Operator nothing to hear, so it never
	-- leaves its post.
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
	-- somebody who has already been punished: an event that should announce
	-- itself once, announcing itself continuously.
	SupervisorCooldown = 25,

	-- How wide a Roblox character is, near enough. Used to keep the corridor's
	-- WALLS inside the span its doorways can pass: a player walking the corridor
	-- must never be somewhere the door will not let them through.
	PlayerWidth = 4,

	-- There is no reach dial: capture is the ROOM itself (see
	-- Connected.reachedInRoom). A reach radius cannot fit a square room: the
	-- smallest circle containing it also covers 9.94 studs of corridor outside
	-- every wall, so a player who got out of the door would still be taken.

	-- Rooms the Operator can be sent to. World.build must return a position for
	-- every one of these, and every secret payload must name one of them.
	-- tests/round.luau enforces the second half of that.
	Rooms = { "board", "archive", "lobby" },

	-- Dials for systems that are not built yet. Nothing reads these, and the
	-- config test does not require anything to. Move a key up into the table
	-- above in the same commit that first reads it.
	Planned = {
		RoundLength = 600, -- seconds (round flow)
		PlayersPerRound = 4,
	},
}

return Config
