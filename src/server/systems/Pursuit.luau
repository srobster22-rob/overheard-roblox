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
-- never captures, which is the whole point: `arrived` and `idle` are both
-- silent and still, so switching from one to the other where it stands would
-- turn a lethal room safe with nothing to signal it.
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
		-- The turns still to take before `target`, nearest first (DECISIONS D5).
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

-- Set off for a named room. The state is derived, never asserted: re-sending it
-- somewhere it is already close to must not make it loud again, and re-sending
-- it where it already stands must not re-fire `arrived` (setState ignores a
-- repeat, so its time there is kept too).
local function headFor(self: Tracker, payload: string, room: Point)
	local target = { x = room.x, z = room.z }
	setCourse(self, target)
	self.targetName = payload
	-- A request queued for this room is served by this trip. Kept, it would send
	-- the Operator back once it had given the room up and walked home: back into
	-- the lobby, say, while the way out is still open.
	if self.pending == payload then
		self.pending = nil
	end
	self:setState(self:classify(distance(self.position, target)))
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
-- `step` route through it, so a caller cannot assert a state the geometry
-- contradicts.
--
-- `onUnderstood` calls `sendTo` on EVERY utterance it understands, not just
-- the first. If `sendTo` declared "approaching" itself, each repeat of the
-- giveaway would re-arm the hum at whatever distance it had reached: audible
-- while standing on top of the players, and announcing its arrival again and
-- again. The silence rule at the top of this file would never fire on the main
-- path -- and talking is the main path.
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
-- Retargeting on every call would be a livelock: alternating two plain words
-- would hold the Operator between two rooms for as long as the group kept it
-- up, audible the whole time and able to capture nobody, because capture
-- requires `arrived`. The counterplay to a monster that hunts what you say
-- would be saying MORE of it, which inverts the design. It needs no
-- coordination either — two players panicking and both blurting giveaways
-- produce it by accident.
--
-- Being called back out of a RETREAT is allowed: a retreat is not a call in
-- progress.
-- Returns `accepted, onItsWay`.
--
-- `accepted` is whether the room exists. `onItsWay` is whether the Operator
-- is ACTUALLY heading there now, and the two differ whenever it is already
-- committed elsewhere: the request goes into `pending`, where the next one
-- overwrites it.
--
-- A caller that announces a call, as the Supervisor does, must go by
-- `onItsWay`: while the Operator is kept busy most requests are queued, and
-- telling every player about a call that was not placed is a lie. A hum that
-- sometimes means nothing is worse than no hum, and the same is true of a
-- sentence.
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
	headFor(self, payload, room)
	return true, true
end

-- Sent somewhere it must go NOW, whatever call it is on (the outside call, in
-- Escape.step). Unlike `sendTo` it is never queued behind a call in progress,
-- and a retreat is turned round too. Unlike `stop` then `sendTo` it keeps a
-- room already queued, and an Operator already standing in that room stays
-- `arrived` with its time there intact, rather than arriving again.
function Pursuit.sendNow(self: Tracker, payload: string): boolean
	local room = self.rooms[payload]
	if not room then
		return false
	end
	headFor(self, payload, room)
	return true
end

function Pursuit.stop(self: Tracker)
	self.target = nil
	self.route = {}
	self.targetName = nil
	self.pending = nil
	self:setState("idle")
end

-- True while it should be making noise. The whole design hangs off this.
-- Approaching AND leaving: you hear it come and you hear it go. The silence in
-- between is the tell.
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
		-- SNAP to the centre. Arriving without moving would leave the Operator
		-- up to `ArriveRadius` short of it, and the room-shaped capture is
		-- centred on `pursuit.position`, so the box would hang that far outside
		-- one wall and fall that far short of the opposite one. This is the
		-- normal arrival path, not an edge case.
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
-- `stop()` alone is not enough. It clears the target and goes idle but leaves
-- the POSITION where it stood, so the next round would begin with the Operator
-- inside the room it had hunted -- and the next understanding of that room
-- would make it `arrived` on the spot, with no approach and no sound at all.
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
-- It must leave on its own. It captures the whole time it is `arrived`, so an
-- Operator that stayed for good would park on top of a station after a single
-- plain word: nobody could work that station, `allSolved` would be
-- unreachable, and the round could only end in a loss.
--
-- Asked rather than acted on, so the DURATION stays a dial in Config and this
-- module stays free of clocks.
function Pursuit.shouldLeave(self: Tracker, after: number): boolean
	return self.state == "arrived" and self.dwell >= after
end

return Pursuit
