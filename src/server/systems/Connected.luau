--!strict
-- Being caught, OVERHEARD's way.
--
-- You are not killed and not removed. You are CONNECTED: put on the line, where
-- you can be heard but not answered. You keep the fact you were holding and you
-- can still say it out loud — your team can still use you. What you lose is the
-- ability to ACT. You can no longer patch anything yourself.
--
-- That is deliberate, and it is the opposite of how horror games usually treat
-- death. Removing a player from a co-op horror game removes them from the room
-- and they go and do something else. Here, losing turns you into pure voice,
-- which is exactly what this game is made of.
--
-- Pure logic on plain {x, z} points, so it tests headlessly.

export type Point = { x: number, z: number }

local Connected = {}
Connected.__index = Connected

export type Line = typeof(setmetatable(
	{} :: {
		-- userId -> the time they were connected.
		held: { [number]: number },
		onConnected: ((userId: number, at: number) -> ())?,
	},
	Connected
))

function Connected.new(): Line
	return setmetatable({
		held = {},
		onConnected = nil,
	}, Connected)
end

function Connected.isConnected(self: Line, userId: number): boolean
	return self.held[userId] ~= nil
end

-- Idempotent on purpose. The Operator can arrive, be re-sent, and arrive again;
-- announcing that the same player was taken twice reads as a bug.
function Connected.connect(self: Line, userId: number, at: number): boolean
	if self.held[userId] ~= nil then
		return false
	end
	self.held[userId] = at
	if self.onConnected then
		(self.onConnected :: any)(userId, at)
	end
	return true
end

-- Leaving the server clears you, or a rejoin would arrive already caught.
function Connected.forget(self: Line, userId: number)
	self.held[userId] = nil
end

function Connected.clear(self: Line)
	self.held = {}
end

function Connected.count(self: Line): number
	local n = 0
	for _ in self.held do
		n += 1
	end
	return n
end

local function distance(a: Point, b: Point): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Who the Operator takes when it arrives: everyone inside `reach`, and nobody
-- who is already connected.
--
-- It takes EVERYONE in reach rather than one victim. Taking a single player
-- would make standing together safe-ish and reward huddling, and huddling is
-- the opposite of a game about having to transmit facts across a building.
function Connected.reached(self: Line, at: Point, positions: { [number]: Point }, reach: number): { number }
	local caught: { number } = {}
	for userId, position in positions do
		if not self:isConnected(userId) and distance(at, position) <= reach then
			table.insert(caught, userId)
		end
	end
	table.sort(caught)
	return caught
end

-- The round is lost when nobody is left who can act.
function Connected.allTaken(self: Line, userIds: { number }): boolean
	if #userIds == 0 then
		return false
	end
	for _, userId in userIds do
		if not self:isConnected(userId) then
			return false
		end
	end
	return true
end

return Connected
