--!strict
-- Where the Operator goes, and — more importantly — when it stops making noise.
--
-- Pure logic on plain {x, z} points so it can be tested headlessly. The Roblox
-- embodiment (parts, sounds, movement) lives in Presence and does no thinking.
--
-- THE RULE THIS ENCODES: sound before sight, and silence is the tell.
-- It is audible while it crosses the building and goes quiet once it is close.
-- The scare is not the noise arriving; it is the noise STOPPING.

export type Point = { x: number, z: number }

export type State = "idle" | "approaching" | "closing" | "arrived"

local Pursuit = {}
Pursuit.__index = Pursuit

export type Tracker = typeof(setmetatable(
	{} :: {
		position: Point,
		target: Point?,
		targetName: string?,
		state: State,
		speed: number,
		-- Inside this radius it stops making noise.
		silenceRadius: number,
		arriveRadius: number,
		rooms: { [string]: Point },
		onStateChanged: ((state: State, targetName: string?) -> ())?,
	},
	Pursuit
))

local function distance(a: Point, b: Point): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

Pursuit.distance = distance

function Pursuit.new(rooms: { [string]: Point }, start: Point): Tracker
	return setmetatable({
		position = { x = start.x, z = start.z },
		target = nil,
		targetName = nil,
		state = "idle" :: State,
		speed = 9,
		silenceRadius = 26,
		arriveRadius = 4,
		rooms = rooms,
		onStateChanged = nil,
	}, Pursuit)
end

function Pursuit.setState(self: Tracker, state: State)
	if self.state == state then
		return
	end
	self.state = state
	if self.onStateChanged then
		(self.onStateChanged :: any)(state, self.targetName)
	end
end

-- The ONLY place that decides what the state should be. Both `sendTo` and
-- `step` route through it, so a caller can no longer assert a state the
-- geometry contradicts.
--
-- It used to be inlined in `step` alone, while `sendTo` simply declared
-- "approaching". `onUnderstood` calls `sendTo` on EVERY utterance it
-- understands, not just the first, so every time the group said the giveaway
-- again the hum was re-armed at whatever distance it had already reached:
-- driven once per step it stayed audible at distance 0.0, standing on top of
-- the players, and re-announced its arrival six times in six seconds. The
-- silence rule at the top of this file never fired on the main path -- and
-- talking is the main path.
function Pursuit.classify(self: Tracker, remaining: number): State
	if remaining <= self.arriveRadius then
		return "arrived"
	elseif remaining <= self.silenceRadius then
		return "closing"
	end
	return "approaching"
end

-- Called when the Operator understands something. `payload` names a room.
-- An unknown payload is ignored rather than guessed at: sending it to the wrong
-- room on a misunderstanding would read as the monster cheating.
function Pursuit.sendTo(self: Tracker, payload: string): boolean
	local room = self.rooms[payload]
	if not room then
		return false
	end
	local target = { x = room.x, z = room.z }
	self.target = target
	self.targetName = payload
	-- Derived, never asserted. Re-sending it somewhere it is already close to
	-- must not make it loud again, and re-sending it where it already stands
	-- must not re-fire `arrived`.
	self:setState(self:classify(distance(self.position, target)))
	return true
end

function Pursuit.stop(self: Tracker)
	self.target = nil
	self.targetName = nil
	self:setState("idle")
end

-- True while it should be making noise. The whole design hangs off this.
function Pursuit.isAudible(self: Tracker): boolean
	return self.state == "approaching"
end

function Pursuit.step(self: Tracker, dt: number)
	local target = self.target
	if not target then
		self:setState("idle")
		return
	end

	local remaining = distance(self.position, target)

	if remaining <= self.arriveRadius then
		self.position = { x = target.x, z = target.z }
		self:setState("arrived")
		return
	end

	local travel = math.min(self.speed * dt, remaining)
	local dx = (target.x - self.position.x) / remaining
	local dz = (target.z - self.position.z) / remaining
	self.position = {
		x = self.position.x + dx * travel,
		z = self.position.z + dz * travel,
	}

	-- Recompute after moving so the state matches where it actually is.
	self:setState(self:classify(distance(self.position, target)))
end

return Pursuit
