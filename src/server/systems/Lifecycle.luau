--!strict
-- Whether a round is being played, and what to do when it stops.
--
-- Until R29 there was no such thing. `allSolved()` fired the win line and
-- returned; `allTaken()` fired the loss line and stopped the Operator. Nothing
-- reset anything, so:
--   * after a WIN the Operator kept hunting — you finished the board and were
--     then taken by a monster that had no idea the round was over
--   * after either ending the objectives stayed solved and the connected stayed
--     connected, and the server was a dead lobby
-- The game was playable exactly once, which meant everything else built for it
-- was reachable exactly once.
--
-- Pure and clockless: it is TOLD the time, so the intermission stays a dial and
-- this module stays headlessly testable.

export type Outcome = "won" | "lost"
export type Phase = "playing" | "over"

local Lifecycle = {}
Lifecycle.__index = Lifecycle

export type Round = typeof(setmetatable(
	{} :: {
		phase: Phase,
		outcome: Outcome?,
		endedAt: number?,
		-- How many rounds have been played on this server. The Lexicon is
		-- deliberately NOT reset between them; a group's shared vocabulary
		-- carrying over is the whole point of it.
		number: number,
	},
	Lifecycle
))

function Lifecycle.new(): Round
	return setmetatable({
		phase = "playing" :: Phase,
		outcome = nil,
		endedAt = nil,
		number = 1,
	}, Lifecycle)
end

function Lifecycle.isPlaying(self: Round): boolean
	return self.phase == "playing"
end

function Lifecycle.isOver(self: Round): boolean
	return self.phase == "over"
end

-- Ends the round. Returns true only on the transition, so callers can announce
-- exactly once.
--
-- Idempotent because both endings are checked on a repeating tick: `allSolved`
-- stays true forever once the board is finished, and `allTaken` stays true
-- while everyone is connected. Without this the server would re-announce the
-- ending four times a second.
function Lifecycle.finish(self: Round, outcome: Outcome, now: number): boolean
	if self.phase == "over" then
		return false
	end
	self.phase = "over"
	self.outcome = outcome
	self.endedAt = now
	return true
end

function Lifecycle.readyToRestart(self: Round, now: number, after: number): boolean
	local endedAt = self.endedAt
	if self.phase ~= "over" or endedAt == nil then
		return false
	end
	return now - endedAt >= after
end

-- Begins the next round. Returns false if the round was still being played, so
-- a stray call cannot wipe a board mid-game.
function Lifecycle.restart(self: Round): boolean
	if self.phase ~= "over" then
		return false
	end
	self.phase = "playing"
	self.outcome = nil
	self.endedAt = nil
	self.number += 1
	return true
end

-- Has the group lost? Everyone present taken, OR nobody left able to finish
-- anything (R48/R49; see the caller in init.server). `board` is an Objectives
-- board and `line` a Connected line -- both pure, so this runs headlessly.
-- `line:count() > 0` keeps a solo server from losing instantly and looping: a
-- board nobody can finish with NOBODY connected is the dealing problem (the
-- owner's filed solo question), not a round that play has stranded.
function Lifecycle.nobodyCanWin(present: { number }, board: any, line: any): boolean
	if #present == 0 or board:allSolved() then
		return false
	end
	if line:allTaken(present) then
		return true
	end

	local able: { number } = {}
	for _, userId in present do
		if not line:isConnected(userId) then
			table.insert(able, userId)
		end
	end
	return line:count() > 0 and not board:anyFinishable(able)
end

return Lifecycle
