--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: a promise written in a comment that the
-- number beside it does not keep.
--
-- `Config.OperatorReach` said "being anywhere in that room should not be
-- survivable" and was 22, against a 48-stud room whose corners are 33.94 from
-- the centre. It covered 66% of the floor; the remaining 34% was the perimeter
-- and all four corners, which is exactly where a frightened player stands. The
-- Operator arrived in the room it had understood and could not touch anyone
-- pressed against a wall.
--
-- Nothing caught it because `World.luau` needs Roblox instances to load, so the
-- dimensions were unreachable from every test. `Shared.Layout` exists to put
-- them back in reach.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Layout = rt.require(rt.shared.Layout)
local Config = rt.require(rt.shared.Config)
local Connected = rt.require(rt.systems.Connected)

local failures = 0
local checks = 0
local function check(name: string, condition: boolean)
	checks += 1
	if not condition then
		failures += 1
		print(`  FAIL  {name}`)
	else
		print(`  ok    {name}`)
	end
end

print("the dimensions are sane")
check(`(guard) the room has a size ({Layout.Room})`, Layout.Room > 0)
check("half the room is half the room", Layout.halfRoom() == Layout.Room / 2)
check("the corner is further than the wall", Layout.cornerDistance() > Layout.halfRoom())

print("")
print("the whole room is inside the Operator's reach")
-- The promise, asserted as a promise rather than as the number 33.94.
check("reach covers the nearest wall", Config.OperatorReach >= Layout.halfRoom())
check("reach covers the furthest corner", Config.OperatorReach >= Layout.cornerDistance())

-- Sweep the actual floor through the REAL capture rule, not the arithmetic.
-- A grid, so a formula that happens to satisfy the two checks above but is
-- applied differently in `Connected.reached` still fails here.
local centre = { x = 0, z = 0 }
local line = Connected.new()
local STEP = 2
local inside, escaped = 0, 0
local worst = 0
local userId = 0
for x = -Layout.halfRoom(), Layout.halfRoom(), STEP do
	for z = -Layout.halfRoom(), Layout.halfRoom(), STEP do
		userId += 1
		local point = { x = x, z = z }
		if not Layout.inRoom(centre, point) then
			continue
		end
		inside += 1
		local caught = line:reached(centre, { [userId] = point }, Config.OperatorReach)
		if #caught == 0 then
			escaped += 1
			local d = math.sqrt(x * x + z * z)
			if d > worst then
				worst = d
			end
		end
	end
end
-- Without this the sweep could pass by testing nothing.
check(`(guard) the sweep covered the floor ({inside} points)`, inside > 400)
check(`nobody standing in the room survives ({escaped} escaped, worst at {string.format("%.1f", worst)})`, escaped == 0)

-- The keep side: reach must not be so large it takes the OTHER room too, or
-- distance stops being the mechanic.
print("")
print("but it does not reach the other room")
local far = { x = Layout.Separation, z = 0 }
local caughtFar = line:reached(centre, { [9999] = far }, Config.OperatorReach)
check("a player in the other room is not taken", #caughtFar == 0)
check("reach is smaller than the separation", Config.OperatorReach < Layout.Separation)
-- Even the NEAREST point of the other room must be safe, not just its centre.
local nearEdgeOfOther = { x = Layout.Separation - Layout.halfRoom(), z = 0 }
local caughtEdge = line:reached(centre, { [9998] = nearEdgeOfOther }, Config.OperatorReach)
check("nor is one at the near edge of the other room", #caughtEdge == 0)

print("")
print("the two work points are genuinely far apart")
-- This held only by coincidence of two unrelated literals until R21.
check("the rooms are separated by more than a room's width", Layout.Separation > Layout.Room)
-- The gap between their NEAR EDGES, which is the walk a player actually makes.
-- Stated as its own number rather than as a second copy of the check above.
local gap = Layout.Separation - Layout.Room
check(`the walk between rooms is a real walk ({gap} studs of corridor)`, gap >= Layout.Room)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
