--!strict
-- Which station each player is physically standing at, ON THE SERVER.
--
-- THE BUG THIS EXISTS TO CLOSE: this was client state. The world has one
-- ProximityPrompt per station -- a shared path -- and `prompt.Triggered` fired
-- `OpenBoard` at one player and then the server forgot. The only record of
-- which keypad a player had walked up to lived in `openStation`, a local in
-- `init.client.luau`, and `submitRemote` accepted whatever station id came
-- back. So the station you were acting at was decided by the client.
--
-- That matters beyond exploiting. `Round.luau`'s design rule is that the holder
-- and the actor "are never in the same room -- that is what makes players
-- audible", and the stations stand in different rooms precisely so somebody has
-- to cross the corridor. With the station id unchecked, a player who never
-- leaves the switchboard can clear the breaker, and the second room costs
-- nothing.
--
-- Pure: no Roblox APIs, so the rule is hammered headlessly. Same reason
-- `Shared.Keypad` is a module instead of an `if` in the client -- `init.server`
-- and `init.client` are the two files no headless test can run, so the decision
-- must not live in either.

local ReplicatedStorage_ = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage_.Shared.Layout)
local Config = require(ReplicatedStorage_.Shared.Config)

local Station = {}
Station.__index = Station

export type Desk = typeof(setmetatable(
	{} :: {
		-- userId -> the station id that player most recently reached.
		at: { [number]: string },
		-- userId -> when that player last submitted (R116; was init.server's lastSubmit).
		lastSubmit: { [number]: number },
	},
	Station
))

function Station.new(): Desk
	return setmetatable({ at = {}, lastSubmit = {} }, Station)
end

-- The player triggered a station's prompt. ONE slot per player on purpose:
-- walking up to the breaker gives up the switchboard, so to submit at a station
-- you must have reached it more recently than any other. That is as much of the
-- spatial rule as the platform will give -- a ProximityPrompt has a server-side
-- activation distance but no "walked away" event, so this says "you got there",
-- not "you are still there".
function Station.open(self: Desk, userId: number, stationId: string)
	self.at[userId] = stationId
end

function Station.openedBy(self: Desk, userId: number): string?
	return self.at[userId]
end

-- May this player submit against this station? The whole rule, in one place.
function Station.accepts(self: Desk, userId: number, stationId: string): boolean
	return self.at[userId] == stationId
end

-- Per-player state needs exactly one place that forgets it. `lastSubmit` was
-- cleaned on PlayerRemoving and `misses`/`jammedUntil` were not; adding a third
-- slot with no cleanup would repeat that in the round that names it.
-- Forget where everyone is standing. Called when a new round begins: `desk` is
-- the server's own copy of which keypad each player walked up to, and it used
-- to survive the boundary — so a player who opened the breaker in round one
-- could submit to it from the corridor in round two, which is exactly the gate
-- R12 added to close.
function Station.clear(self: Desk)
	self.at = {}
end

function Station.forget(self: Desk, userId: number)
	self.at[userId] = nil
	self.lastSubmit[userId] = nil
end

-- Rate limiting. Every remote the client can fire needs one, or an exploiter
-- brute-forces two-digit answers instantly. Submit is the only remote a client
-- fires (the prompts are proximity-gated by Roblox; chat is TextChatService).
Station.SUBMIT_COOLDOWN = 0.75

-- May this player submit at all right now? Records the attempt if so. R116
-- moved this from init.server so `forget` (on leave) clears it by construction
-- and the suite can run it.
function Station.tryPace(self: Desk, userId: number, now: number): boolean
	if now - (self.lastSubmit[userId] or 0) < Station.SUBMIT_COOLDOWN then
		return false
	end
	self.lastSubmit[userId] = now
	return true
end

-- May this player enter a code at this station RIGHT NOW? nil if so; otherwise
-- the refusal, and whether the Operator also says "busy" to them (only for a
-- keypad they never opened -- a probe, not an honest mistake).
--
-- R114 moved these gates out of init.server's Submit handler, where the suite
-- could only grep them; a sweep flipped every one without a failure. The
-- ORDER is part of the rule: a finished round and the line come first, then
-- your body, then the keypad you opened.
function Station.gate(
	self: Desk,
	userId: number,
	stationId: string,
	playing: boolean,
	onLine: boolean,
	standing: Layout.Point?,
	stationAt: Layout.Point?
): { reason: string, busy: boolean }?
	if not playing then
		return { reason = "the round is over", busy = false }
	end
	if onLine then
		return { reason = "you are on the line", busy = false }
	end
	if stationAt and not (standing and Layout.within(stationAt, standing, Config.StationReach)) then
		return { reason = "you are not at that station", busy = false }
	end
	if not self:accepts(userId, stationId) then
		return { reason = "you are not at that station", busy = true }
	end
	return nil
end

return Station
