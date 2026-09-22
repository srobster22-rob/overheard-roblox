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
		-- A room it heard about while already on its way. It finishes the call
		-- it started before taking the next one.
		pending: string?,
		state: State,
		-- Seconds spent standing in the room it arrived at. Reset the moment it
		-- is anything other than `arrived`.
		dwell: number,
		speed: number,
		-- Inside this radius it stops making noise.
		silenceRadius: number,
		arriveRadius: number,
		rooms: { [string]: Point },
		-- The turns still to take before `target`, nearest first (R137).
		route: { Point },
		-- How to get from a point to a target: the turns between them. nil walks
		-- straight, which is right for any building whose rooms all sit on one
		-- line; the server passes `Layout.route` once a room is off the corridor.
		routeFor: ((from: Point, to: Point) -> { Point })?,
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

function Pursuit.new(
	rooms: { [string]: Point },
	start: Point,
	routeFor: ((from: Point, to: Point) -> { Point })?
): Tracker
	return setmetatable({
		position = { x = start.x, z = start.z },
		target = nil,
		targetName = nil,
		pending = nil,
		state = "idle" :: State,
		dwell = 0,
		speed = Config.PursuitSpeed,
		silenceRadius = Config.SilenceRadius,
		arriveRadius = Config.ArriveRadius,
		rooms = rooms,
		route = {},
		routeFor = routeFor,
		onStateChanged = nil,
	}, Pursuit)
end

-- Move straight toward `point` by at most one step's travel, landing on it
-- exactly when in reach. Returns whether it got there.
local function advance(self: Tracker, point: Point, dt: number): boolean
	local leg = distance(self.position, point)
	local travel = math.min(self.speed * dt, leg)
	if travel >= leg then
		self.position = { x = point.x, z = point.z }
		return true
	end
	self.position = {
		x = self.position.x + (point.x - self.position.x) / leg * travel,
		z = self.position.z + (point.z - self.position.z) / leg * travel,
	}
	return false
end

-- Head for `target`, planning the turns on the way. The one place a new
-- destination is set, so the route can never belong to an old target.
local function setCourse(self: Tracker, target: Point)
	self.target = target
	self.route = if self.routeFor then table.clone(self.routeFor(self.position, target)) else {}
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
-- IT FINISHES THE CALL IT STARTED. A different room heard mid-approach is
-- QUEUED, not switched to.
--
-- `sendTo` used to retarget unconditionally, and with two concepts in play that
-- is a livelock: alternating the two plain words once a second held the
-- Operator 40 studs from either room for five minutes, audible the whole time
-- and able to capture nobody, because capture requires `arrived`. The
-- counterplay to a monster that hunts what you say became saying MORE of it,
-- which inverts the design. It needs no coordination either — two players
-- panicking and both blurting giveaways produce it by accident.
--
-- Being called back out of a RETREAT is still allowed: that is R26's rule and a
-- retreat is not a call in progress.
-- Returns `accepted, onItsWay`.
--
-- `accepted` is whether the room exists. `onItsWay` is whether the Operator
-- is ACTUALLY heading there now, and the two differ whenever it is already
-- committed elsewhere: the request goes into `pending`, where the next one
-- overwrites it.
--
-- This used to return a bare `true` for both, and R54's Supervisor believed
-- it. Measured over 4,000 ticks with the Operator kept busy: 117 silence
-- calls announced, ONE that turned it toward the room, 77 swallowed into
-- `pending` and 39 where it was already going. Every one of the 116 told
-- every player a line about a call that was not placed, and forgave the
-- silent player for 25 seconds. A hum that sometimes means nothing is worse
-- than no hum (R11), and the same is true of a sentence.
function Pursuit.sendTo(self: Tracker, payload: string): (boolean, boolean)
	local room = self.rooms[payload]
	if not room then
		return false, false
	end

	local busy = self.state == "approaching" or self.state == "closing"
	if busy and self.targetName ~= payload then
		self.pending = payload
		return true, false
	end
	local target = { x = room.x, z = room.z }
	setCourse(self, target)
	self.targetName = payload
	-- Derived, never asserted. Re-sending it somewhere it is already close to
	-- must not make it loud again, and re-sending it where it already stands
	-- must not re-fire `arrived`.
	self:setState(self:classify(distance(self.position, target)))
	return true, true
end

function Pursuit.stop(self: Tracker)
	self.target = nil
	self.route = {}
	self.targetName = nil
	self.pending = nil
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

	-- A turn still to take: walk to it first. It is never `arrived` while a
	-- turn is left: arriving snaps it to the room and starts capturing, and a
	-- turn is not the room, however close to it the turn lies. The step after
	-- the last turn is taken judges arrival at the target itself.
	local turn = self.route[1]
	if turn then
		if advance(self, turn, dt) then
			table.remove(self.route, 1)
		end
		if self.state ~= "leaving" then
			local state = self:classify(distance(self.position, target))
			self:setState(if state == "arrived" then "closing" else state)
		end
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

	advance(self, target, dt)

	if self.state == "leaving" then
		-- Still on its way out; classify() describes hunting, not retreating.
		return
	end

	-- Recompute after moving so the state matches where it actually is.
	local now = distance(self.position, target)
	if now <= self.arriveRadius then
		-- SNAP. This branch used to set `arrived` through `classify` without
		-- moving the position, so an ordinary arrival left the Operator up to
		-- `ArriveRadius` short of the centre -- and R23's room-shaped capture is
		-- centred on `pursuit.position`, so the box hung that far outside one
		-- wall and fell that far short of the opposite one. R26 recorded this
		-- case as unreachable; it is the normal path.
		self.position = { x = target.x, z = target.z }
	end
	self:setState(self:classify(distance(self.position, target)))
end

-- Walk back out to a point that is not a room. Used when it loses interest:
-- audible the whole way, capturing nothing, and it ends `idle` rather than
-- `arrived` so the room it just left cannot start taking people again.
function Pursuit.withdrawTo(self: Tracker, point: Point)
	setCourse(self, { x = point.x, z = point.z })
	self.targetName = nil
	self:setState("leaving")
end

-- Put it back at its post between rounds. A PLACEMENT, not a walk: nobody is
-- watching during an intermission, and walking it home would leave the room
-- lethal until it got there.
--
-- `stop()` alone was not enough. It clears the target and goes idle but leaves
-- the POSITION where it stood, so round two began with the Operator inside the
-- room it had hunted -- and the next understanding of that room made it
-- `arrived` on the spot, with no approach and no sound at all.
function Pursuit.sendHome(self: Tracker, point: Point)
	self.position = { x = point.x, z = point.z }
	self.target = nil
	self.route = {}
	self.targetName = nil
	self.pending = nil
	self.dwell = 0
	self:setState("idle")
end

-- Take up a room heard while it was busy. Only once it is idle: it finishes the
-- call, holds the room, walks home, and then answers the next one. Returns true
-- if it actually set off.
function Pursuit.takePending(self: Tracker): boolean
	local next_ = self.pending
	if next_ == nil or self.state ~= "idle" then
		return false
	end
	self.pending = nil
	return self:sendTo(next_)
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
