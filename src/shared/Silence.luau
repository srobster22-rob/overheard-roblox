--!strict
-- What a player's SILENCE means, in one place.
--
-- The Operator hunts by meaning, so until now the optimal way to play was to
-- say nothing at all. Measured over 600 simulated seconds with four players:
--
--   a group that talks    16 rounds won, 96 captures, the Operator active for
--                         2120 of 2400 ticks
--   a group that is silent  20 rounds won, 0 captures, the Operator NEVER LEFT
--                           ITS POST
--
-- Silence was not merely safer, it won MORE rounds and the monster was never
-- switched on. Two people on a voice call outside the game could pass every
-- answer and play an unopposed fetch quest. `GAME.md` has the answer in the
-- roster: entity #4, the Supervisor, "punishes silence -- you must keep
-- talking. Inverts everything: babble continuously, convey nothing."
--
-- This is that rule as a pure function. The tension it creates is the design's:
-- everything you say to satisfy the Supervisor is still heard by the Operator,
-- so you must talk constantly and mean nothing.
--
-- The band above the threshold is deliberately NOT a gradient, for the reason
-- `Heat` says it: above it there is no "partly" -- the call goes through. A ramp
-- there would keep implying headroom that does not exist.

local Config = require(script.Parent.Config)

local Silence = {}

export type Band = "clear" | "warned" | "overdue"

-- How close this player is to being called, 0..1. Reaches 1 exactly at the
-- moment the call goes through, so a panel drawing it never has to know the
-- dial.
function Silence.pressure(quietFor: number): number
	if Config.SpeakEvery <= 0 then
		return 1
	end
	return math.clamp(quietFor / Config.SpeakEvery, 0, 1)
end

-- The one fact the rest of the game acts on.
function Silence.isOverdue(quietFor: number): boolean
	return quietFor >= Config.SpeakEvery
end

function Silence.band(quietFor: number): Band
	if Silence.isOverdue(quietFor) then
		return "overdue"
	elseif quietFor >= Config.SpeakWarning then
		return "warned"
	end
	return "clear"
end

-- What the player is shown, per band. The panel draws `pressure` as a bar and
-- this beside it, so the rule is legible before it fires rather than after.
--
-- `CLAUDE.md`: the monster must be legible, or the scare reads as unfair. A
-- monster that takes you on a timer you cannot see is the exact case that rule
-- is about.
--
-- The three notes are deliberately different lengths and different in kind --
-- a state, a prod, and a verdict -- so a player catching the panel out of the
-- corner of an eye can tell them apart without reading.
local NOTES: { [Band]: string } = {
	clear = "your line is open",
	warned = "say something",
	overdue = "SILENT LINE - TRACED",
}

Silence.NOTES = NOTES

function Silence.note(band: Band): string
	return NOTES[band]
end

-- How full the bar is NOW, given what the last push said and how long ago it
-- arrived.
--
-- R56 pushed the clock on band change rather than per tick -- 4 replications in
-- 600 ticks instead of 1,200, which is the right call. But the bar was drawn
-- from the pressure sent at that instant, so it showed three positions in a
-- whole countdown and sat perfectly still for 29.5 of the 45 seconds. A bar that
-- does not move for two-thirds of the wait says nothing about time passing, and
-- the first thing it says is that you are already out of time.
--
-- The client can fill in the gap itself without knowing a single dial: the push
-- carries how full the bar is and how many seconds are left, and those two give
-- the rate. That keeps the thresholds here, beside the numbers they come from,
-- which is what the client's own comment already claimed.
--
-- `secondsLeft <= 0` holds at full rather than dividing by it: the deadline has
-- passed, and there is no "more than overdue".
function Silence.fill(pressureAtPush: number, secondsLeft: number, elapsed: number): number
	local from = math.clamp(pressureAtPush, 0, 1)
	if secondsLeft <= 0 or from >= 1 then
		return 1
	end
	local rate = (1 - from) / secondsLeft
	return math.clamp(from + rate * math.max(0, elapsed), 0, 1)
end

-- How long this player has before the call goes through.
function Silence.secondsLeft(quietFor: number): number
	return math.max(0, Config.SpeakEvery - quietFor)
end

-- The warning has to arrive with time left to do something about it, or it is
-- not a warning. Read by tests against the real dials rather than trusted.
function Silence.warningLeadSeconds(): number
	return Config.SpeakEvery - Config.SpeakWarning
end

return Silence
