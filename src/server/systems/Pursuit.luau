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

-- `leaving` is the walk back out after it loses interest. It is AUDIBLE and it
-- never captures, which is the whole point: R25 released the room by switching
-- to `idle` where it stood, and both `arrived` and `idle` are silent with no
-- movement, so the room went from lethal to safe with nothing to signal it.
export type State = "idle" | "approaching" | "closing" | "arrived" | "leaving"

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Pursuit = {}
Pursuit.__index = Pursuit

export type Tracker = typeof(setmetatable(
	{} :: {
		position: Point,
		target: Point?,
		targetName: string?,
		state: State,
		-- Seconds spent standing in the room it arrived at. Reset the moment it
		-- is anything other than `arrived`.
		dwell: number,
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
		dwell = 0,
		speed = Config.PursuitSpeed,
		silenceRadius = Config.SilenceRadius,
		arriveRadius = Config.ArriveRadius,
		rooms = rooms,
		onStateChanged = nil,
	}, Pursuit)
end

function Pursuit.setState(self: Tracker, state: State)
	if self.state == state then
		return
	end
	if state ~= "arrived" then
		-- Dwell only means anything while it is standing somewhere.
		self.dwell = 0
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
-- True while it should be making noise. Approaching AND leaving: you hear it
-- come and you hear it go. The silence in between is the tell.
function Pursuit.isAudible(self: Tracker): boolean
	return self.state == "approaching" or self.state == "leaving"
end

function Pursuit.step(self: Tracker, dt: number)
	if self.state == "arrived" then
		-- Real seconds, because `step` is driven by Heartbeat.
		self.dwell += dt
	end

	local target = self.target
	if not target then
		self:setState("idle")
		return
	end

	local remaining = distance(self.position, target)

	if remaining <= self.arriveRadius then
		self.position = { x = target.x, z = target.z }
		-- Getting home ends the walk out. It must NOT become `arrived`, or the
		-- place it retreated to would start capturing.
		self:setState(if self.state == "leaving" then "idle" else "arrived")
		if self.state == "idle" then
			self.target = nil
		end
		return
	end

	local travel = math.min(self.speed * dt, remaining)
	local dx = (target.x - self.position.x) / remaining
	local dz = (target.z - self.position.z) / remaining
	self.position = {
		x = self.position.x + dx * travel,
		z = self.position.z + dz * travel,
	}

	if self.state == "leaving" then
		-- Still on its way out; classify() describes hunting, not retreating.
		return
	end

	-- Recompute after moving so the state matches where it actually is.
	self:setState(self:classify(distance(self.position, target)))
end

-- Walk back out to a point that is not a room. Used when it loses interest:
-- audible the whole way, capturing nothing, and it ends `idle` rather than
-- `arrived` so the room it just left cannot start taking people again.
function Pursuit.withdrawTo(self: Tracker, point: Point)
	self.target = { x = point.x, z = point.z }
	self.targetName = nil
	self:setState("leaving")
end

-- Has it stood in this room long enough to lose interest?
--
-- Until R25 nothing ever returned it to idle except the round being lost, so
-- once it arrived it stayed for good — and since R24 it captures the whole time
-- it is arrived. A single plain word therefore parked it on top of an objective
-- permanently: nobody could patch that station, `allSolved` was unreachable,
-- and the round could only end in a loss. Both required stations were lockable.
--
-- Asked rather than acted on, so the DURATION stays a dial in Config and this
-- module stays free of clocks.
function Pursuit.shouldLeave(self: Tracker, after: number): boolean
	return self.state == "arrived" and self.dwell >= after
end

return Pursuit
