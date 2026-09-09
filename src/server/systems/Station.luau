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
-- audible", and the two stations are 120 studs apart precisely so somebody has
-- to cross the corridor. With the station id unchecked, a player who never
-- leaves the switchboard can clear the breaker, and the second room costs
-- nothing.
--
-- Pure: no Roblox APIs, so the rule is hammered headlessly. Same reason
-- `Shared.Keypad` is a module instead of an `if` in the client -- `init.server`
-- and `init.client` are the two files no headless test can run, so the decision
-- must not live in either.

local Station = {}
Station.__index = Station

export type Desk = typeof(setmetatable(
	{} :: {
		-- userId -> the station id that player most recently reached.
		at: { [number]: string },
	},
	Station
))

function Station.new(): Desk
	return setmetatable({ at = {} }, Station)
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
function Station.forget(self: Desk, userId: number)
	self.at[userId] = nil
end

return Station
