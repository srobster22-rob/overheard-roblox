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
print("the Operator takes the room it arrived in - and only that room")

-- R21 satisfied "being anywhere in that room should not be survivable" with the
-- smallest CIRCLE containing the square. Its tests only ever asked whether
-- everyone INSIDE was taken, never whether anyone outside was -- so nothing saw
-- that the circle spills 9.94 studs past every wall, covering 157% of the
-- room's floor area. A player 29 studs from the centre was out of the room, in
-- the corridor, and still caught. R22 had just given the rooms doors; that made
-- using one pointless.
--
-- Both directions are swept here. The keep side is the half that was missing.

local centre = { x = 0, z = 0 }
local line = Connected.new()
local half = Layout.halfRoom()
local STEP = 2

local inside, escaped = 0, 0
local userId = 0
for x = -half, half, STEP do
	for z = -half, half, STEP do
		userId += 1
		local point = { x = x, z = z }
		inside += 1
		if #line:reachedInRoom(centre, { [userId] = point }, half) == 0 then
			escaped += 1
		end
	end
end
check(`(guard) the sweep covered the floor ({inside} points)`, inside > 400)
check(`nobody standing in the room survives ({escaped} escaped)`, escaped == 0)

-- THE HALF R21 NEVER CHECKED. Sweep a ring outside the walls: everyone there
-- got out, and must stay out.
local outsideTested, wronglyTaken = 0, 0
local nearestWrong = math.huge
for x = -half - 20, half + 20, STEP do
	for z = -half - 20, half + 20, STEP do
		local point = { x = x, z = z }
		if Layout.inRoom(centre, point) then
			continue
		end
		userId += 1
		outsideTested += 1
		if #line:reachedInRoom(centre, { [userId] = point }, half) > 0 then
			wronglyTaken += 1
			local d = math.max(math.abs(x), math.abs(z)) - half
			if d < nearestWrong then
				nearestWrong = d
			end
		end
	end
end
check(`(guard) the sweep tested points outside the room ({outsideTested})`, outsideTested > 200)
check(`nobody outside the room is taken ({wronglyTaken} wrongly taken)`, wronglyTaken == 0)

-- The specific point that used to be caught: through the door and into the
-- corridor, 29 studs from the centre.
local throughTheDoor = { x = -(half + 5), z = 0 }
check("getting through the door and out saves you", #line:reachedInRoom(centre, { [7001] = throughTheDoor }, half) == 0)
check("(guard) and that point really is outside the room", not Layout.inRoom(centre, throughTheDoor))

-- Standing in the doorway itself is still inside. Stated so a later round does
-- not "fix" the boundary the other way by accident.
local inTheDoorway = { x = -half, z = 0 }
check("the doorway line itself is still inside", #line:reachedInRoom(centre, { [7002] = inTheDoorway }, half) == 1)

-- The other room is untouched, which was true before and must stay true.
local otherRoom = { x = Layout.Separation, z = 0 }
check("a player in the other room is not taken", #line:reachedInRoom(centre, { [7003] = otherRoom }, half) == 0)

print("")
print("the two work points are genuinely far apart")
-- This held only by coincidence of two unrelated literals until R21.
check("the rooms are separated by more than a room's width", Layout.Separation > Layout.Room)
-- The gap between their NEAR EDGES, which is the walk a player actually makes.
-- Stated as its own number rather than as a second copy of the check above.
local gap = Layout.Separation - Layout.Room
check(`the walk between rooms is a real walk ({gap} studs of corridor)`, gap >= Layout.Room)

print("")
print("you can actually walk to the stations")

-- THE DEFECT R22 FOUND. `World.room()` built four full-span walls and cut no
-- gap, so both work rooms were sealed boxes: the walk from the corridor to the
-- Switchboard crossed the wall plane x=36 at z=-10.8, inside a wall spanning
-- z=-24..24. Every system in the game sat behind a wall with no door in it, and
-- nothing caught it because World needs Roblox instances to load.

local spawn = Layout.spawn()
local offset = Layout.stationOffset()
local walls = Layout.allWalls()
check(`(guard) the building has walls to be blocked by ({#walls})`, #walls >= 8)

for name, centre in { board = Layout.boardCentre(), archive = Layout.archiveCentre() } do
	local station = { x = centre.x + offset.x, z = centre.z + offset.z }
	check(`the {name} station is inside its room (guard)`, Layout.inRoom(centre, station))

	-- The route, not a straight line. The station sits 18 studs off the room's
	-- centre line, so the direct walk from the corridor clips the wall at
	-- z=-10.8 even with the door open; a player goes to the door, then to the
	-- station. Demanding a clear straight line here would have reported the
	-- building unplayable and argued for a 22-stud door -- fixing the model
	-- instead of the game.
	local route = Layout.routeToStation(centre)
	check(`(guard) the {name} route has legs ({#route})`, #route >= 3)
	check(`you can walk from the corridor to the {name} station`, Layout.routeIsClear(route))

	check(`the corridor leg to {name} is clear`, Layout.walkIsClear(spawn, Layout.doorPoint(centre)))
	check(`the doorway leg to {name} is clear`, Layout.walkIsClear(Layout.doorPoint(centre), station))
end

-- The keep side: the doorway must be a doorway, not a missing wall. Walking at
-- the room's far corner must still be blocked, or the room has no walls at all.
local board = Layout.boardCentre()
local half = Layout.halfRoom()
local outsideCorner = { x = board.x + half + 10, z = board.z + half + 10 }
local insideCorner = { x = board.x + half - 2, z = board.z + half - 2 }
check("you cannot walk in through the far corner", not Layout.walkIsClear(outsideCorner, insideCorner))

-- And the wall the door is NOT in must still stop you.
local behind = { x = board.x + half + 10, z = board.z }
local inside = { x = board.x, z = board.z }
check("you cannot walk in through the back wall", not Layout.walkIsClear(behind, inside))

-- The doorway is where the corridor is, not somewhere unreachable.
local doorApproach = { x = board.x - half - 6, z = board.z }
check("the doorway faces the corridor", Layout.walkIsClear(doorApproach, inside))
check(`(guard) the door has a width ({Layout.Door})`, Layout.Door > 0 and Layout.Door < Layout.Room)

print("")
print("every approach starts where you can hear it")

-- R27. `operatorStart` was the board room's centre plus 20 studs, and
-- `classify()` calls anything within `Config.SilenceRadius` (26) `closing`,
-- which is inaudible. So the Operator reached the board room -- which holds a
-- required station -- having made no sound at all, while the archive got the
-- full warning. R26 made it the normal case by sending it home after every
-- linger. "Silence is the tell" is the game's central promise; half the
-- building never got it.
--
-- Asserted against the real dial and swept through the real Pursuit, not
-- against the number 26.

local Pursuit = rt.require(rt.systems.Pursuit)
local post = Layout.operatorPost()
local rooms = { board = Layout.boardCentre(), archive = Layout.archiveCentre() }

local roomCount = 0
for _ in rooms do
	roomCount += 1
end
check(`(guard) there are rooms to approach ({roomCount})`, roomCount >= 2)

for name, roomCentre in rooms do
	local d = math.sqrt((post.x - roomCentre.x) ^ 2 + (post.z - roomCentre.z) ^ 2)
	check(
		`the post is outside the silence radius of {name} ({string.format("%.1f", d)} > {Config.SilenceRadius})`,
		d > Config.SilenceRadius
	)

	-- The invariant is about being HEARD, so sweep the real walk rather than
	-- trusting the distance.
	local walker = Pursuit.new(rooms, post)
	walker:sendTo(name)
	local everAudible = walker:isAudible()
	local steps = 0
	for _ = 1, 200 do
		walker:step(0.5)
		steps += 1
		if walker:isAudible() then
			everAudible = true
		end
		if walker.state == "arrived" then
			break
		end
	end
	check(`(guard) it actually reached {name} ({steps} steps)`, walker.state == "arrived")
	check(`you hear it coming to {name}`, everAudible)
end

-- The post must not be somewhere a player cannot see it coming FROM either:
-- it stands in the corridor, not inside a room.
for name, roomCentre in rooms do
	check(`the post is not inside {name}`, not Layout.inRoom(roomCentre, post))
end

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
