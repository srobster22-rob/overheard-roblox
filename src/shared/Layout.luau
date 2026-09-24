--!strict
-- The exchange's dimensions, and the facts that follow from them.
--
-- They live here, not in `World.luau`, because World needs Roblox instances to
-- load and no test can reach it. Anything that follows from them is derived in
-- code, never restated by hand: a hand-copied number drifts from the geometry,
-- and a gap in the geometry (a room with no doorway, a floor narrower than its
-- door) is invisible until something walks the building.
--
-- Pure arithmetic, no Roblox APIs, so `tests/layout.luau` can sweep all of it.

local Config = require(script.Parent.Config)

local Layout = {}

-- Room footprint, studs. Square.
Layout.Room = 48

-- Distance between the two corridor-end rooms' centres. The read point and
-- the patch point must never be reachable in one glance: distance IS the
-- mechanic.
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
-- than this leaves a survivable pocket inside the room: the perimeter and the
-- corners, exactly where a frightened player stands.
function Layout.cornerDistance(): number
	local half = Layout.halfRoom()
	return math.sqrt(half * half + half * half)
end

-- The radius that covers the whole room from its centre. NOT the Operator's
-- reach: capture is the ROOM itself (`Connected.reachedInRoom`), and nothing
-- in the game calls this. Kept as honest geometry rather than deleted, like
-- `Connected.reached`; `Layout.cornerDistance` exists to feed it and is
-- otherwise called only by its own test. Whether to remove both is parked
-- with the owner (unused Layout helpers, OWNER.md).
function Layout.reach(): number
	return Layout.cornerDistance()
end

function Layout.boardCentre(): Point
	return { x = Layout.Separation / 2, z = 0 }
end

function Layout.archiveCentre(): Point
	return { x = -Layout.Separation / 2, z = 0 }
end

-- The third room, the front hall with the street door. It hangs off the
-- corridor's midpoint through a short passage, so it is a third direction
-- rather than a third point on one line. Its distance from the Operator's post
-- is DERIVED to equal the board room's, so every room hears the same length of
-- approach (asserted in tests/layout.luau).
function Layout.lobbyCentre(): Point
	local post = Layout.operatorPost()
	local board = Layout.boardCentre()
	local reach = math.sqrt((board.x - post.x) ^ 2 + (board.z - post.z) ^ 2)
	return { x = 0, z = post.z + reach }
end

-- Every room the world builds, by the name `Config.Rooms` and secret payloads
-- use. World builds from it, walls are derived from it, and the walk tests
-- sweep it. A new room is NOT only an entry here: it needs a door side
-- (`corridorSide`), a way in from the corridor (the lobby has `passageWalls`,
-- `passageFloor` and a cut in `corridorWalls`), and a model name in World.
-- What tests/layout.luau catches: a room the Operator cannot walk to from the
-- post or another room, a place whose route is walled, and a room with no
-- model name in World. Passage walls and floor are checked for the lobby only.
function Layout.rooms(): { [string]: Point }
	return {
		board = Layout.boardCentre(),
		archive = Layout.archiveCentre(),
		lobby = Layout.lobbyCentre(),
	}
end

-- Where players start: the corridor's midpoint, at the foot of the passage.
function Layout.spawn(): Point
	return { x = 0, z = 0 }
end

-- Where each thing a player walks up to stands: the room it is in, and its
-- offset from that room's centre. Keyed by `Round.STATIONS[].id`, plus the
-- reader. Kept here so a test walks to the same point the world actually
-- builds: literals copied by hand into World and a test agree only by
-- coincidence. Placement as data is DECISIONS D5.
--   board    against the room's -z wall
--   breaker  toward the records room's doorway wall
--   latch    on the lobby's far wall: the street door itself (DECISIONS D4)
--   reader   the card index, against the records room's -z wall
local PLACES: { [string]: { room: string, offset: Point } } = {
	board = { room = "board", offset = { x = 0, z = -18 } },
	breaker = { room = "archive", offset = { x = 18, z = 0 } },
	latch = { room = "lobby", offset = { x = 0, z = 18 } },
	reader = { room = "archive", offset = { x = 0, z = -18 } },
}

-- The room a place is in, or nil for an id with no place.
function Layout.stationRoom(id: string): string?
	local place = PLACES[id]
	return if place then place.room else nil
end

-- Where a place stands in the world, or nil for an id with no place.
function Layout.stationPoint(id: string): Point?
	local place = PLACES[id]
	local centre = place and Layout.rooms()[place.room]
	if not (place and centre) then
		return nil
	end
	return { x = centre.x + place.offset.x, z = centre.z + place.offset.z }
end

-- Is a point inside the room centred on `centre`?
function Layout.inRoom(centre: Point, point: Point): boolean
	local half = Layout.halfRoom()
	return math.abs(point.x - centre.x) <= half and math.abs(point.z - centre.z) <= half
end

-- Which side of a room faces the corridor. "west" is the -x wall, "east" the
-- +x. A room off the corridor's line (|x| under half a room) faces it across
-- z: "north" is the -z wall, for a room above the corridor like the lobby, and
-- "south" the +z wall, for one below it.
function Layout.corridorSide(centre: Point): string
	if math.abs(centre.x) < Layout.halfRoom() then
		return if centre.z > 0 then "north" else "south"
	end
	return if centre.x > 0 then "west" else "east"
end

-- The wall segments of one room, in world space. The side named by `openOn` is
-- built as TWO segments with the doorway between them. Order is north, south,
-- west, east, which is the order World numbers them Wall1..WallN in.
function Layout.walls(centre: Point, openOn: string): { Rect }
	local half = Layout.halfRoom()
	local doorHalf = Layout.Door / 2
	local out: { Rect } = {}

	local function add(minX: number, minZ: number, maxX: number, maxZ: number)
		table.insert(out, { minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ })
	end

	for _, side in { "north", "south" } do
		local z = if side == "north" then centre.z - half else centre.z + half
		if side == openOn then
			add(centre.x - half, z, centre.x - doorHalf, z)
			add(centre.x + doorHalf, z, centre.x + half, z)
		else
			add(centre.x - half, z, centre.x + half, z)
		end
	end

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
-- It is the ONLY floor for the 72 studs between its end rooms, so any strip of
-- a doorway's approach it does not cover drops a player out of the world. That
-- is worst exactly when it matters most: escaping means running out of a room
-- in the dark.

-- Derived from the doorway, so the approach to a door is always floored. A
-- corridor narrower than the door it serves is a hole by construction.
function Layout.corridorWidth(): number
	return Layout.Door
end

-- Where the corridor floor ends and the rooms begin.
function Layout.corridorHalfLength(): number
	return Layout.Separation / 2 - Layout.halfRoom()
end

-- The width a player can actually WALK, between the corridor's walls.
--
-- Narrower than the floor by a whole character, because the floor and the
-- walls do different jobs and one width cannot serve both. The FLOOR must be
-- at least as wide as a doorway or part of every approach is unfloored. The
-- WALLS must keep a player inside the span a doorway can pass, or the corridor
-- walks them into the frame: a character is about 4 studs across against a
-- 12-stud door, so anyone past z = 4 clips it, and walls at the floor's edge
-- would let them reach z = 6. Hugging a wall is what a fleeing player does.
function Layout.corridorClear(): number
	return Layout.Door - Config.PlayerWidth
end

-- The corridor's own walls, so you cannot walk off the side of it. They stop at
-- the room walls, leaving the doorways open. Three segments: the south wall
-- runs the whole length; the north wall is cut at the midpoint where the
-- passage to the lobby leaves.
function Layout.corridorWalls(): { Rect }
	local halfW = Layout.corridorClear() / 2
	local endX = Layout.corridorHalfLength()
	return {
		{ minX = -endX, minZ = -halfW, maxX = endX, maxZ = -halfW },
		{ minX = -endX, minZ = halfW, maxX = -halfW, maxZ = halfW },
		{ minX = halfW, minZ = halfW, maxX = endX, maxZ = halfW },
	}
end

-- Where the passage meets the lobby's doorway wall.
function Layout.passageEnd(): number
	return Layout.lobbyCentre().z - Layout.halfRoom()
end

-- The passage's floor: as wide as the corridor floor (so the lobby door's
-- approach is floored, the corridor's own rule), from the corridor floor's
-- edge to the lobby's door wall with no gap.
function Layout.passageFloor(): Rect
	local halfFloor = Layout.corridorWidth() / 2
	return { minX = -halfFloor, minZ = halfFloor, maxX = halfFloor, maxZ = Layout.passageEnd() }
end

-- The passage from the corridor's midpoint up to the lobby door. Same walkable
-- width as the corridor, for the same reason (a character must fit the door
-- the walls lead to).
function Layout.passageWalls(): { Rect }
	local halfW = Layout.corridorClear() / 2
	local top = Layout.passageEnd()
	return {
		{ minX = -halfW, minZ = halfW, maxX = -halfW, maxZ = top },
		{ minX = halfW, minZ = halfW, maxX = halfW, maxZ = top },
	}
end

-- Where the passage leaves the corridor. The Operator walks in straight lines,
-- so any trip between the lobby and the corridor's end rooms turns here.
function Layout.junction(): Point
	return { x = 0, z = 0 }
end

-- Is `point` within `radius` of `centre`? Used to answer "are you standing at
-- that station" at the moment a player submits, rather than trusting a memory
-- of which prompt they last triggered.
--
-- A record of the last prompt TRIGGERED is not enough. The prompt's activation
-- distance gates the trigger, not the submit, so a player could trigger a
-- station's prompt, walk to the other room, stand beside the holder reading
-- the number, and patch from there. The read point and the patch point must
-- never be reachable in one glance: distance IS the mechanic
-- (`Layout.Separation`).
function Layout.within(centre: Point, point: Point, radius: number): boolean
	local dx = point.x - centre.x
	local dz = point.z - centre.z
	return math.sqrt(dx * dx + dz * dz) <= radius
end

-- Every wall in the building.
function Layout.allWalls(): { Rect }
	local out: { Rect } = {}
	for _, centre in Layout.rooms() do
		for _, wall in Layout.walls(centre, Layout.corridorSide(centre)) do
			table.insert(out, wall)
		end
	end
	for _, wall in Layout.corridorWalls() do
		table.insert(out, wall)
	end
	for _, wall in Layout.passageWalls() do
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
	if side == "north" or side == "south" then
		return { x = centre.x, z = if side == "north" then centre.z - half else centre.z + half }
	end
	return {
		x = if side == "west" then centre.x - half else centre.x + half,
		z = centre.z,
	}
end

-- The turns the Operator takes between two points, not counting either end.
-- None when the straight line is clear; otherwise one, through the junction.
-- Every pair of rooms and the post is covered by those two cases, which
-- tests/layout.luau checks leg by leg rather than trusting this comment.
function Layout.route(from: Point, to: Point): { Point }
	if Layout.walkIsClear(from, to) then
		return {}
	end
	return { Layout.junction() }
end

-- The walk from spawn to a named place, as legs: through its room's door, then
-- to the spot it stands on. nil for an id with no place. NOT a straight line:
-- the door is 12 studs wide and the board station sits 18 studs off the room's
-- centre line, so the direct line from the corridor clips the wall even with
-- the doorway open. A reachability test that demanded a clear straight line
-- would report the building unplayable and push someone to widen the door --
-- fixing the test's model rather than the game.
function Layout.routeToStationId(id: string): { Point }?
	local room = Layout.stationRoom(id)
	local centre = room and Layout.rooms()[room]
	local at = Layout.stationPoint(id)
	if not (centre and at) then
		return nil
	end
	return { Layout.spawn(), Layout.doorPoint(centre), at }
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

-- Do the rooms the world builds and the rooms Config declares agree, in both
-- directions? nil if they do, otherwise the message World.build raises. A name
-- declared with no position makes `Pursuit.sendTo` refuse the move, so the
-- Operator never comes and nothing errors -- a silent monster reads as a dead
-- game. It lives here rather than in World.build, which only runs in Studio,
-- so the headless tests can reach it.
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

-- Where the Operator stands when it has nothing to chase, and where it walks
-- back to when it loses interest.
--
-- THE INVARIANT: it must be further from every room centre than
-- `Config.SilenceRadius`, or an approach that starts here is inaudible for the
-- whole trip. The Operator walks home after every linger, so that would be the
-- normal case, not a corner of one.
--
-- The corridor runs x = -Separation/2 .. +Separation/2 at z = 0, so any x with
-- |x -/+ Separation/2| >= SilenceRadius satisfies it.
-- `tests/layout.luau` asserts the invariant against the real dial rather than
-- trusting this comment.
function Layout.operatorPost(): Point
	-- EQUIDISTANT from both corridor-end rooms, so both get the same warning
	-- (and `lobbyCentre` is placed to match, so the lobby does too). An
	-- off-centre post gives one room a long audible approach and the other a
	-- short one, and a guard that only asks whether an approach STARTS audible
	-- cannot see that: it must ask for how long.
	--
	-- The corridor midpoint is the only equidistant point on it, so the post
	-- sits there, pushed to the edge of the corridor floor to leave the spawn
	-- pad clear. Both rooms hear 3.8 seconds of it.
	--
	-- Derived from the WALKABLE span, not the floor. The Operator walks each leg
	-- in a straight line and does not see walls, so a post outside the corridor
	-- walls would put the wall line across every path from here to a room.
	return { x = 0, z = -(Layout.corridorClear() / 2 - 1) }
end

return Layout
