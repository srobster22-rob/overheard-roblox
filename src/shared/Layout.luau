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

local Config = require(script.Parent.Config)

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

-- R77. This comment used to say "how far the Operator reaches when it
-- arrives... DERIVED, so the promise in Config cannot drift from the number
-- again", describing a Config.OperatorReach dial that R23 deleted -- capture
-- is the ROOM itself now (Connected.reachedInRoom), and `Config.luau`'s own
-- comment says so: "There is no OperatorReach dial any more... a radius
-- nobody enforces is worse than none."
--
-- Left as the honest radius primitive rather than deleted, the same call R69
-- made for Connected.reached: it is possible geometry, not currently wired to
-- anything, and `Layout.cornerDistance` -- which exists only to feed this --
-- has exactly one other caller (its own test). NOT claimed to be needed;
-- filed for the owner alongside R73's group-identity question rather than
-- removed on this round's say-so or kept on a stale comment's.
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

-- THE CORRIDOR ---------------------------------------------------------------
--
-- Until R28 it was 8 studs wide against a 12-stud doorway, with nothing at its
-- edges, and it is the ONLY floor for the 72 studs between the two rooms. Two
-- studs of every doorway approach had no floor under it, and a player anywhere
-- along that span who stepped past z = +/-4 fell out of the world — worst
-- exactly when it matters most, since escaping means running out of a room in
-- the dark.

-- Derived from the doorway, so the approach to a door is always floored. A
-- corridor narrower than the door it serves is a hole by construction.
function Layout.corridorWidth(): number
	return Layout.Door
end

-- Where the corridor floor ends and the rooms begin.
function Layout.corridorHalfLength(): number
	return Layout.Separation / 2 - Layout.halfRoom()
end

-- The corridor's own walls, so you cannot walk off the side of it. They stop at
-- the room walls, leaving the doorways open.
-- The width a player can actually WALK, between the corridor's walls.
--
-- Narrower than the floor by a whole character, because the floor's job and the
-- walls' job are different and R28 built one from the other and used it for
-- both. The FLOOR must be at least as wide as a doorway or part of every
-- approach is unfloored (R28's defect). The WALLS must keep a player inside the
-- span a doorway can pass, or the corridor walks them into the frame: a
-- character is about 4 studs across against a 12-stud door, so anyone past
-- z = 4 clipped it while the walls let them reach z = 6. A third of the
-- corridor led to a door they could not fit through, and hugging a wall is what
-- a fleeing player does.
function Layout.corridorClear(): number
	return Layout.Door - Config.PlayerWidth
end

function Layout.corridorWalls(): { Rect }
	local halfW = Layout.corridorClear() / 2
	local endX = Layout.corridorHalfLength()
	return {
		{ minX = -endX, minZ = -halfW, maxX = endX, maxZ = -halfW },
		{ minX = -endX, minZ = halfW, maxX = endX, maxZ = halfW },
	}
end

-- Is `point` within `radius` of `centre`? Used to answer "are you standing at
-- that station" at the moment a player submits, rather than trusting a memory
-- of which prompt they last triggered.
--
-- Until R39 the submit gate was `Station.accepts`, which is
-- `self.at[userId] == stationId` — a record of the last prompt TRIGGERED. The
-- prompt's own activation distance gates the trigger and nothing gated the
-- submit, so a player could prime the Switchboard, walk the 104 studs to the
-- other room, stand beside the holder reading the number, and patch from there.
-- This file's own comment says the read point and the patch point must never be
-- reachable in one glance, and that distance IS the mechanic.
function Layout.within(centre: Point, point: Point, radius: number): boolean
	local dx = point.x - centre.x
	local dz = point.z - centre.z
	return math.sqrt(dx * dx + dz * dz) <= radius
end

-- Every wall in the building.
function Layout.allWalls(): { Rect }
	local out: { Rect } = {}
	for _, centre in { Layout.boardCentre(), Layout.archiveCentre() } do
		for _, wall in Layout.walls(centre, Layout.corridorSide(centre)) do
			table.insert(out, wall)
		end
	end
	for _, wall in Layout.corridorWalls() do
		table.insert(out, wall)
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

-- Where the Operator stands when it has nothing to chase, and where it walks
-- back to when it loses interest.
--
-- THE INVARIANT: it must be further from every room centre than
-- `Config.SilenceRadius`, or an approach that starts here is inaudible for the
-- whole trip. Until R27 the post was the board room's own centre plus 20 studs,
-- inside a silence radius of 26 — so the Operator reached the board room, which
-- holds a required station, having made no sound at all. R26 made that the
-- normal case by sending it home after every linger.
--
-- The corridor runs x = -Separation/2 .. +Separation/2 at z = 0, so any x with
-- |x -/+ Separation/2| >= SilenceRadius satisfies it. This sits well inside that
-- band and away from the player spawn at the midpoint.
-- `tests/layout.luau` asserts the invariant against the real dial rather than
-- trusting this comment.
-- Do the rooms the world builds and the rooms Config declares agree, in both
-- directions? nil if they do, otherwise the message World.build raises. A name
-- declared with no position makes `Pursuit.sendTo` refuse the move, so the
-- Operator never comes and nothing errors -- a silent monster reads as a dead
-- game. R104 moved this out of World.build, which only runs in Studio, so R103's
-- sweep could finally reach it.
function Layout.roomMismatch(built: { [string]: Point }, declared: { string }): string?
	local named: { [string]: boolean } = {}
	for _, name in declared do
		named[name] = true
		if not built[name] then
			return `Config.Rooms declares room '{name}', which World.build gives no position for`
		end
	end
	for name in built do
		if not named[name] then
			return `World.build builds room '{name}', which Config.Rooms does not declare`
		end
	end
	return nil
end

function Layout.operatorPost(): Point
	-- EQUIDISTANT from both rooms, so both get the same warning.
	--
	-- R27 put this at `-Separation / 6` to sit well inside the band and away
	-- from the player spawn, and never checked it for symmetry: forty studs from
	-- the archive and eighty from the board meant the audible part of an
	-- approach was 1.6 seconds to one room and 6.0 to the other. R27's own guard
	-- could not see it — it asserts an approach STARTS audible, which a second
	-- and a half satisfies, and never asked for how long.
	--
	-- The corridor midpoint is the only equidistant point on it, so the post
	-- sits there, pushed to the edge of the corridor floor to leave the spawn
	-- pad clear. Both rooms now hear 3.8 seconds of it.
	--
	-- Derived from the WALKABLE span, not the floor. R52 brought the walls in by
	-- a character's width and this sat a stud outside them -- which would have
	-- made the filed geometry-blind movement defect reachable, since every path
	-- from here to a room crosses the wall line on its way in.
	return { x = 0, z = -(Layout.corridorClear() / 2 - 1) }
end

return Layout
