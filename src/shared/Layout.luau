--!strict
-- The exchange's dimensions, and the facts that follow from them.
--
-- These used to be three `local`s inside `World.luau`, which needs Roblox
-- instances to load — so no test could reach them, and `Config.OperatorReach`
-- restated a number derived from them by hand. It drifted, exactly as
-- hand-restated numbers do:
--
--   Config said "being anywhere in that room should not be survivable".
--   The room is 48x48, so its corners are 33.94 studs from the centre.
--   The reach was 22.
--
-- That covers 66% of the floor. The other 34% is the perimeter and all four
-- corners — precisely where a frightened player stands.
--
-- R22 found the larger consequence of the same blind spot: the rooms had no
-- DOORS. `World.room()` built four full-span walls and nothing cut a gap, so
-- the straight walk from the corridor to the Switchboard crossed the wall plane
-- x=36 at z=-10.8, inside a wall spanning z=-24..24. Both work rooms were
-- sealed boxes and every system in the game sat behind one.
--
-- Pure arithmetic, no Roblox APIs, so `tests/layout.luau` can sweep all of it.

local Layout = {}

-- Room footprint, studs. Square.
Layout.Room = 48

-- Distance between the two work rooms' centres. The read point and the patch
-- point must never be reachable in one glance: distance IS the mechanic.
Layout.Separation = 120

Layout.Floor = 0

-- Clear width of a doorway, studs. Wider than the corridor so a player arriving
-- at an angle still finds the gap.
Layout.Door = 12

export type Point = { x: number, z: number }
-- A wall segment. Axis-aligned and one stud thick, so one of the two spans is
-- degenerate (minX == maxX for a north-south wall).
export type Rect = { minX: number, minZ: number, maxX: number, maxZ: number }

-- Half the room's width. The nearest wall.
function Layout.halfRoom(): number
	return Layout.Room / 2
end

-- Distance from the room's centre to its furthest corner. Any radius smaller
-- than this leaves a survivable pocket inside the room.
function Layout.cornerDistance(): number
	local half = Layout.halfRoom()
	return math.sqrt(half * half + half * half)
end

-- How far the Operator reaches when it arrives. DERIVED, so the promise in
-- Config cannot drift from the number again: it stops at the room centre, and
-- the whole room is inside this.
function Layout.reach(): number
	return Layout.cornerDistance()
end

function Layout.boardCentre(): Point
	return { x = Layout.Separation / 2, z = 0 }
end

function Layout.archiveCentre(): Point
	return { x = -Layout.Separation / 2, z = 0 }
end

-- Where players start: the corridor, between the two rooms.
function Layout.spawn(): Point
	return { x = 0, z = 0 }
end

-- Where a station stands inside its room, relative to the room centre. Kept
-- here so a test walks to the same point the world actually builds.
function Layout.stationOffset(): Point
	return { x = 0, z = -18 }
end

-- Is a point inside the room centred on `centre`?
function Layout.inRoom(centre: Point, point: Point): boolean
	local half = Layout.halfRoom()
	return math.abs(point.x - centre.x) <= half and math.abs(point.z - centre.z) <= half
end

-- Which side of a room faces the corridor. "west" is the -x wall, "east" the +x.
function Layout.corridorSide(centre: Point): string
	return if centre.x > 0 then "west" else "east"
end

-- The wall segments of one room, in world space. The side named by `openOn` is
-- built as TWO segments with the doorway between them.
function Layout.walls(centre: Point, openOn: string): { Rect }
	local half = Layout.halfRoom()
	local doorHalf = Layout.Door / 2
	local out: { Rect } = {}

	local function add(minX: number, minZ: number, maxX: number, maxZ: number)
		table.insert(out, { minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ })
	end

	-- North and south walls always run the full span.
	add(centre.x - half, centre.z - half, centre.x + half, centre.z - half)
	add(centre.x - half, centre.z + half, centre.x + half, centre.z + half)

	for _, side in { "west", "east" } do
		local x = if side == "west" then centre.x - half else centre.x + half
		if side == openOn then
			add(x, centre.z - half, x, centre.z - doorHalf)
			add(x, centre.z + doorHalf, x, centre.z + half)
		else
			add(x, centre.z - half, x, centre.z + half)
		end
	end

	return out
end

-- Every wall in the building.
function Layout.allWalls(): { Rect }
	local out: { Rect } = {}
	for _, centre in { Layout.boardCentre(), Layout.archiveCentre() } do
		for _, wall in Layout.walls(centre, Layout.corridorSide(centre)) do
			table.insert(out, wall)
		end
	end
	return out
end

-- Does the straight walk from `a` to `b` cross this wall? Segment against
-- segment, because the walls are one stud thick.
function Layout.crosses(wall: Rect, a: Point, b: Point): boolean
	if wall.minX == wall.maxX then
		local x = wall.minX
		if (a.x - x) * (b.x - x) > 0 then
			return false -- both ends on the same side
		end
		if a.x == b.x then
			return false -- parallel to the wall
		end
		local t = (x - a.x) / (b.x - a.x)
		local z = a.z + t * (b.z - a.z)
		return z >= wall.minZ and z <= wall.maxZ
	end

	local z = wall.minZ
	if (a.z - z) * (b.z - z) > 0 then
		return false
	end
	if a.z == b.z then
		return false
	end
	local t = (z - a.z) / (b.z - a.z)
	local x = a.x + t * (b.x - a.x)
	return x >= wall.minX and x <= wall.maxX
end

-- Can you walk straight from `a` to `b` without meeting a wall?
function Layout.walkIsClear(a: Point, b: Point): boolean
	for _, wall in Layout.allWalls() do
		if Layout.crosses(wall, a, b) then
			return false
		end
	end
	return true
end

-- The middle of a room's doorway, on the corridor side.
function Layout.doorPoint(centre: Point): Point
	local half = Layout.halfRoom()
	local side = Layout.corridorSide(centre)
	return {
		x = if side == "west" then centre.x - half else centre.x + half,
		z = centre.z,
	}
end

-- The route a player actually takes, as legs. NOT a straight line: the door is
-- 12 studs wide and the station sits 18 studs off the room's centre line, so
-- the direct line from the corridor clips the wall at z=-10.8 even with the
-- doorway open. A reachability test that demanded a clear straight line would
-- report the building unplayable and push someone to widen the door to 22
-- studs to satisfy it — fixing the test's model rather than the game.
function Layout.routeToStation(centre: Point): { Point }
	local offset = Layout.stationOffset()
	return {
		Layout.spawn(),
		Layout.doorPoint(centre),
		{ x = centre.x + offset.x, z = centre.z + offset.z },
	}
end

-- Every leg of a route is walkable.
function Layout.routeIsClear(route: { Point }): boolean
	for i = 1, #route - 1 do
		if not Layout.walkIsClear(route[i], route[i + 1]) then
			return false
		end
	end
	return true
end

return Layout
