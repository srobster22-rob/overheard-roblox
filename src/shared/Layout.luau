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
-- corners — precisely where a frightened player stands. The Operator arrived in
-- the room it had understood and could not touch anyone against a wall.
--
-- Pure arithmetic, no Roblox APIs, so `tests/layout.luau` can sweep it.

local Layout = {}

-- Room footprint, studs. Square.
Layout.Room = 48

-- Distance between the two work rooms' centres. The read point and the patch
-- point must never be reachable in one glance: distance IS the mechanic.
Layout.Separation = 120

Layout.Floor = 0

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

-- How far the Operator reaches when it arrives. DERIVED, so the promise in the
-- comment above cannot drift from the number again: it stops at the room
-- centre, and the whole room is inside this.
function Layout.reach(): number
	return Layout.cornerDistance()
end

-- Is a point inside the room centred on `centre`? Used by the tests to sweep
-- the floor rather than sample a few spots.
function Layout.inRoom(centre: { x: number, z: number }, point: { x: number, z: number }): boolean
	local half = Layout.halfRoom()
	return math.abs(point.x - centre.x) <= half and math.abs(point.z - centre.z) <= half
end

return Layout
