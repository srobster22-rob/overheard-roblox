--!strict
-- THE WAY OUT (R138): GAME.md's last two phases, "The Call" and "Out".
--
-- Restoring the last line used to win the round on the spot. Now it opens the
-- escape:
--   THE CALL  the outside call rings for `Config.CallRingSeconds`. The street
--             door stays shut, so nobody is out yet however close they stand.
--   OUT       the call has rung: the door opens and the Operator is sent for
--             the lobby, where the door is. The round is won the moment every
--             player still free stands in the lobby. Whoever is in there when
--             it arrives is taken; the rest can still get in once it has gone.
-- It cannot go on forever: `Config.EscapeSeconds` after the door opens the
-- round ends, won if anyone free got out and lost if nobody did. (One player
-- who never comes would otherwise hold the round open for good.)
--
-- `step` is the one beat of all of this. The server, the soak and the playtest
-- bots all call it, so there is one copy of the rule. Pure and clockless like
-- Lifecycle: it is TOLD the time and where everyone stands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
-- For their types only: who is on the line, how a round ends, the Operator.
local Connected = require(script.Parent.Connected)
local Lifecycle = require(script.Parent.Lifecycle)
local Pursuit = require(script.Parent.Pursuit)

local Escape = {}
Escape.__index = Escape

-- The room with the street door: where the group gets out, and where the
-- Operator goes once the call has rung. A `Layout.rooms()` name, and the room
-- the night latch stands in (tests/escape.luau holds the two together).
Escape.ROOM = "lobby"

export type Tracker = typeof(setmetatable(
	{} :: {
		-- When the last line went through, or nil while there is work left.
		openedAt: number?,
		-- When the call finished ringing and the door opened, or nil before.
		releasedAt: number?,
	},
	Escape
))

function Escape.new(): Tracker
	return setmetatable({ openedAt = nil, releasedAt = nil }, Escape)
end

function Escape.isOpen(self: Tracker): boolean
	return self.openedAt ~= nil
end

-- Has the call rung, so the door is open and the Operator on its way?
function Escape.isReleased(self: Tracker): boolean
	return self.releasedAt ~= nil
end

-- Seconds since the call started ringing; 0 while there is work left.
function Escape.openFor(self: Tracker, now: number): number
	local openedAt = self.openedAt
	return if openedAt then now - openedAt else 0
end

-- Starts the call. True only on the transition, so the server announces it
-- once however often the board is asked.
function Escape.open(self: Tracker, now: number): boolean
	if self.openedAt ~= nil then
		return false
	end
	self.openedAt = now
	return true
end

-- Every player still free, standing in the exit room with the door open.
-- Players on the line do not have to get out (they cannot act), but at least
-- one free player must, so a group that has been taken entirely has not escaped.
function Escape.everyoneOut(
	self: Tracker,
	present: { number },
	line: Connected.Line,
	positions: { [number]: Layout.Point },
	rooms: { [string]: Layout.Point }
): boolean
	local exit = rooms[Escape.ROOM]
	if self.releasedAt == nil or exit == nil then
		return false
	end
	local free = 0
	for _, userId in present do
		if not line:isConnected(userId) then
			free += 1
			local at = positions[userId]
			if not (at and Layout.inRoom(exit, at)) then
				return false
			end
		end
	end
	return free > 0
end

-- At least one player still free, standing in the exit room.
local function anyoneOut(
	present: { number },
	line: Connected.Line,
	positions: { [number]: Layout.Point },
	exit: Layout.Point
): boolean
	for _, userId in present do
		local at = positions[userId]
		if not line:isConnected(userId) and at and Layout.inRoom(exit, at) then
			return true
		end
	end
	return false
end

-- One beat of the way out. Returns the round's outcome if this beat settles
-- it, and whether this beat sent the Operator.
--
-- The Operator goes by `sendNow`, never `sendTo`: the outside call outranks the
-- call it is on (a busy Operator would only queue the lobby), and one already
-- standing in the lobby must stay put rather than arrive again.
function Escape.step(
	self: Tracker,
	now: number,
	pursuit: Pursuit.Tracker,
	present: { number },
	line: Connected.Line,
	positions: { [number]: Layout.Point },
	rooms: { [string]: Layout.Point }
): (Lifecycle.Outcome?, boolean)
	local openedAt = self.openedAt
	if openedAt == nil then
		return nil, false
	end

	local sent = false
	if self.releasedAt == nil then
		if now - openedAt < Config.CallRingSeconds then
			return nil, false
		end
		self.releasedAt = now
		pursuit:sendNow(Escape.ROOM)
		sent = true
	end

	if self:everyoneOut(present, line, positions, rooms) then
		return "won", sent
	end
	if now - (self.releasedAt :: number) >= Config.EscapeSeconds then
		local exit = rooms[Escape.ROOM]
		return if exit and anyoneOut(present, line, positions, exit) then "won" else "lost", sent
	end
	return nil, sent
end

-- A new round shuts it.
function Escape.reset(self: Tracker)
	self.openedAt = nil
	self.releasedAt = nil
end

return Escape
