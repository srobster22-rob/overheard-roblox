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

local fs = require("@lune/fs")

local Harness = require("./harness")
local LuauCode = require("./luaucode")

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
-- R77. "Further than the wall" is satisfied by any constant bigger than
-- halfRoom(), which is exactly what a mutation sweep replaced cornerDistance
-- with (a bare 30) and passed. The actual relationship that matters is
-- Pythagorean -- the corner is half*sqrt(2) from the centre, not merely
-- SOME number past the wall -- and this is the version that catches a
-- hardcoded stand-in.
local half = Layout.halfRoom()
check(
	`cornerDistance is derived from halfRoom, not a stand-in ({Layout.cornerDistance()} = {half} * sqrt(2))`,
	math.abs(Layout.cornerDistance() - half * math.sqrt(2)) < 0.0001
)

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

-- R97. The corner walk above also crosses the side wall, so deleting a room's
-- whole south wall passed the entire suite. Straight in through north and
-- south, for BOTH rooms.
for name, centre in { board = Layout.boardCentre(), archive = Layout.archiveCentre() } do
	local middle = { x = centre.x, z = centre.z }
	for side, dz in { north = -1, south = 1 } do
		local out = { x = centre.x, z = centre.z + dz * (half + 6) }
		check(`you cannot walk into the {name} room through its {side} wall`, not Layout.walkIsClear(out, middle))
	end
end

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

print("")
print("the corridor is floored under its doors, and has edges")

-- R28. It was 8 studs wide against a 12-stud doorway, with nothing at its
-- sides, and it is the only floor for the 72 studs between the rooms. Two studs
-- of every doorway approach had no floor; stepping past z = +/-4 anywhere along
-- it dropped you out of the world. Escaping means running out of a room in the
-- dark, so this was worst exactly when it mattered.

check(
	`the corridor is at least as wide as the door it serves ({Layout.corridorWidth()} >= {Layout.Door})`,
	Layout.corridorWidth() >= Layout.Door
)

-- Sweep the doorway span: every z a player can stand in while using a door must
-- have corridor floor under it on the approach.
local doorHalf = Layout.Door / 2
local corridorHalf = Layout.corridorWidth() / 2
local unfloored = 0
for step = -20, 20 do
	local z = doorHalf * (step / 20)
	if math.abs(z) > corridorHalf then
		unfloored += 1
	end
end
check(`no part of a doorway approach is unfloored ({unfloored} gaps)`, unfloored == 0)

-- The edges themselves. Walking sideways out of the corridor must be stopped.
local corridorWalls = Layout.corridorWalls()
check(`(guard) the corridor has walls ({#corridorWalls})`, #corridorWalls == 2)
local midCorridor = { x = 0, z = 0 }
local offTheSide = { x = 0, z = corridorHalf + 20 }
check("you cannot walk off the side of the corridor", not Layout.walkIsClear(midCorridor, offTheSide))
local offTheOtherSide = { x = 0, z = -(corridorHalf + 20) }
check("nor off the other side", not Layout.walkIsClear(midCorridor, offTheOtherSide))

-- REGRESSION GUARD, and the reason this could have gone wrong: corridor walls
-- that ran the full separation would seal both doorways shut and undo R22.
for name, roomCentre in { board = Layout.boardCentre(), archive = Layout.archiveCentre() } do
	check(`the corridor walls do not seal the {name} doorway`, Layout.routeIsClear(Layout.routeToStation(roomCentre)))
end
check(
	`the corridor walls stop at the rooms ({Layout.corridorHalfLength()})`,
	Layout.corridorHalfLength() == Layout.Separation / 2 - Layout.halfRoom()
)

-- And the Operator's post still stands on floor that exists.
local post = Layout.operatorPost()
check("the Operator's post is on the corridor floor", math.abs(post.z) <= corridorHalf)
check("...and within its length", math.abs(post.x) <= Layout.corridorHalfLength())

print("")
print("standing at a station is a place, not a memory")

-- R39. The submit gate was `Station.accepts` — `self.at[userId] == stationId`,
-- a record of the last prompt TRIGGERED. The prompt's own activation distance
-- gates the trigger and nothing gated the submit, so a player could prime the
-- Switchboard, walk the 104 studs to the other room, stand beside the holder
-- reading the number out, and patch from there. This file's own comment says
-- the read point and the patch point must never be reachable in one glance.

local Config = rt.require(rt.shared.Config)

-- The real station positions, from the same arithmetic World builds with.
local boardStation = { x = Layout.boardCentre().x, z = Layout.boardCentre().z - 18 }
local breakerStation = {
	x = Layout.archiveCentre().x + Layout.breakerOffset().x,
	z = Layout.archiveCentre().z + Layout.breakerOffset().z,
}

local stationGap = math.sqrt((boardStation.x - breakerStation.x) ^ 2 + (boardStation.z - breakerStation.z) ^ 2)
check(`(guard) the two act-stations really are far apart ({math.floor(stationGap)} studs)`, stationGap > 50)
check(
	`(guard) reach is far smaller than that gap ({Config.StationReach})`,
	Config.StationReach > 0 and Config.StationReach < stationGap
)

check("standing on the station counts", Layout.within(boardStation, boardStation, Config.StationReach))
check(
	"standing just inside the reach counts",
	Layout.within(
		boardStation,
		{ x = boardStation.x + Config.StationReach - 0.5, z = boardStation.z },
		Config.StationReach
	)
)
check(
	"standing exactly at the reach counts",
	Layout.within(boardStation, { x = boardStation.x + Config.StationReach, z = boardStation.z }, Config.StationReach)
)
check(
	"a step beyond it does not",
	not Layout.within(
		boardStation,
		{ x = boardStation.x + Config.StationReach + 0.5, z = boardStation.z },
		Config.StationReach
	)
)

-- The defect, stated as the situation it allowed.
check(
	"you cannot patch the Switchboard from the other act-station",
	not Layout.within(boardStation, breakerStation, Config.StationReach)
)
check(
	"nor from beside the player reading at the Directory",
	not Layout.within(
		boardStation,
		{ x = Layout.archiveCentre().x, z = Layout.archiveCentre().z - 18 },
		Config.StationReach
	)
)
check("nor from the corridor between the rooms", not Layout.within(boardStation, Layout.spawn(), Config.StationReach))

-- Reach must not be so wide it swallows the room, or "be at the station" quietly
-- becomes "be somewhere in the building".
check(
	"reach does not cover the whole room it stands in",
	not Layout.within(
		boardStation,
		{ x = Layout.boardCentre().x, z = Layout.boardCentre().z + Layout.halfRoom() },
		Config.StationReach
	)
)

-- Sweep a ring rather than trusting the four samples above.
local inside, outside = 0, 0
for step = 0, 35 do
	local angle = (step / 36) * math.pi * 2
	local near = {
		x = boardStation.x + math.cos(angle) * (Config.StationReach - 1),
		z = boardStation.z + math.sin(angle) * (Config.StationReach - 1),
	}
	local far = {
		x = boardStation.x + math.cos(angle) * (Config.StationReach + 1),
		z = boardStation.z + math.sin(angle) * (Config.StationReach + 1),
	}
	if Layout.within(boardStation, near, Config.StationReach) then
		inside += 1
	end
	if not Layout.within(boardStation, far, Config.StationReach) then
		outside += 1
	end
end
check(`every point just inside the reach is accepted ({inside}/36)`, inside == 36)
check(`every point just outside it is refused ({outside}/36)`, outside == 36)

print("")
print("you can only open a keypad where it will take your answer")

-- R44. `StationReach`'s comment claimed it was "slightly wider than the prompt's
-- own activation distance", and that distance was a bare `10` in World.luau
-- derived from nothing. The relationship held by coincidence of two hand-typed
-- numbers in different files.
--
-- If the prompt distance ever passed the reach, a player could TRIGGER a keypad
-- at a distance where every answer is refused -- and be told "you are not at
-- that station" while standing exactly where the game let them open it.

check(
	`the prompt opens no further out than the answer is accepted ({Config.PromptReach} <= {Config.StationReach})`,
	Config.PromptReach <= Config.StationReach
)
check(
	`(guard) both are real distances ({Config.PromptReach}, {Config.StationReach})`,
	Config.PromptReach > 0 and Config.StationReach > 0
)

-- The band between them is the drift allowance the comment promises. It must
-- exist -- equal values would refuse a player standing exactly where they
-- triggered it, on any rounding.
check(
	`there is room for a stud of drift ({Config.StationReach - Config.PromptReach})`,
	Config.StationReach > Config.PromptReach
)

-- And the world must USE the dial rather than carry its own copy, or the two
-- can drift apart again while this file goes on passing.
local worldSource = fs.readFile("src/server/systems/World.luau")
local worldCode = LuauCode.stripNonCode(worldSource)
check(
	"World sets the prompt distance from the dial",
	string.find(worldCode, "MaxActivationDistance = Config.PromptReach", 1, true) ~= nil
)

-- Sweep the band: everywhere the prompt can be triggered, an answer must be
-- accepted. This is the property, not the two numbers.
local station = { x = 0, z = 0 }
local refusedInsidePrompt = 0
for step = 0, 40 do
	local d = Config.PromptReach * (step / 40)
	if not Layout.within(station, { x = d, z = 0 }, Config.StationReach) then
		refusedInsidePrompt += 1
	end
end
check(
	`every distance the prompt allows is a distance submit accepts ({refusedInsidePrompt} refused)`,
	refusedInsidePrompt == 0
)

-- The keep side: reach must not be so much wider that "at the station" stops
-- meaning anything. One room's half-width is the outer bound R39 established.
check(
	`the drift allowance stays small ({Config.StationReach - Config.PromptReach} <= {Layout.halfRoom()})`,
	Config.StationReach - Config.PromptReach <= Layout.halfRoom()
)

print("")
print("every room hears it for the same length of time")

-- R50. R27 asserts an approach STARTS audible, and never asks for how long. Its
-- post sat at -Separation/6 -- forty studs from the archive, eighty from the
-- board -- so the audible part of an approach was 1.6 seconds to one room and
-- 6.0 to the other. A second and a half is not "you hear it crossing the
-- building", which is the promise GAME.md makes, and R27's guard was satisfied
-- by it.

local audible: { [string]: number } = {}
local postAt = Layout.operatorPost()
for name, centre in { board = Layout.boardCentre(), archive = Layout.archiveCentre() } do
	local distance = math.sqrt((postAt.x - centre.x) ^ 2 + (postAt.z - centre.z) ^ 2)
	-- It goes quiet inside SilenceRadius, so the audible leg ends there.
	local travel = (distance - Config.ArriveRadius) / Config.PursuitSpeed
	local silent = (Config.SilenceRadius - Config.ArriveRadius) / Config.PursuitSpeed
	audible[name] = travel - silent
end

local shortest, longest = math.huge, 0
local rooms = 0
for name, seconds in audible do
	rooms += 1
	shortest = math.min(shortest, seconds)
	longest = math.max(longest, seconds)
	check(`(measured) the {name} hears {string.format("%.1f", seconds)}s of approach`, seconds > 0)
end
check(`(guard) more than one room was measured ({rooms})`, rooms >= 2)

-- The warning must be long enough to react to. A player crosses the corridor at
-- Roblox's default WalkSpeed in a couple of seconds; less warning than that is
-- not a tell, it is a surprise.
local REACTABLE = 2
check(
	`the least-warned room still gets a usable warning ({string.format("%.1f", shortest)}s >= {REACTABLE}s)`,
	shortest >= REACTABLE
)

-- And no room may be told much more than another, or the tell means different
-- things in different parts of the building.
check(
	`no room hears much more than another ({string.format("%.1f", shortest)}s vs {string.format("%.1f", longest)}s)`,
	longest - shortest < 1
)

-- The mechanism, stated so a future move of the post has to keep it: the post is
-- equidistant from every room.
local distances: { number } = {}
for _, centre in { Layout.boardCentre(), Layout.archiveCentre() } do
	table.insert(distances, math.sqrt((postAt.x - centre.x) ^ 2 + (postAt.z - centre.z) ^ 2))
end
check(
	`the post is equidistant from both rooms ({string.format("%.1f", distances[1])} vs {string.format(
		"%.1f",
		distances[2]
	)})`,
	math.abs(distances[1] - distances[2]) < 1
)

-- It must still be somewhere a player can be, or the post is inside a wall.
check("the post is still on the corridor floor", math.abs(postAt.z) <= Layout.corridorWidth() / 2)
check("...and clear of the spawn pad's centre", math.abs(postAt.z) > 0)

print("")
print("anywhere you can walk, you can get through the door")

-- R52. R28 derived the corridor from the doorway and used that one number for
-- both the FLOOR and the WALLS. Those are different jobs. The floor must cover
-- the whole approach or part of it is unfloored -- that was R28's defect. The
-- walls must keep a player inside the span a doorway can pass, and nothing was
-- keeping them: a character is about 4 studs across against a 12-stud door, so
-- anyone past z = 4 clipped the frame while the walls let them reach z = 6. A
-- third of the corridor led to a door they could not fit through, and hugging a
-- wall is exactly what a fleeing player does.

local bodyHalf = Config.PlayerWidth / 2
check(`(guard) a player has a width ({Config.PlayerWidth})`, Config.PlayerWidth > 0)
check(`(guard) the doorway has a width ({Layout.Door})`, Layout.Door > 0)

-- R28's rule, unchanged: the floor still covers the doorway.
check(
	`the floor is still at least as wide as the door ({Layout.corridorWidth()} >= {Layout.Door})`,
	Layout.corridorWidth() >= Layout.Door
)

-- The walkable span is narrower than the floor, by exactly a character.
check(
	`the walls are inset by a character ({Layout.corridorClear()} = {Layout.Door} - {Config.PlayerWidth})`,
	Layout.corridorClear() == Layout.Door - Config.PlayerWidth
)
check(`(guard) there is still a corridor to walk down ({Layout.corridorClear()})`, Layout.corridorClear() > 0)
check(
	`(guard) the walls really are the narrower of the two ({Layout.corridorClear()} < {Layout.corridorWidth()})`,
	Layout.corridorClear() < Layout.corridorWidth()
)

-- The property, swept rather than asserted at one point: stand anywhere between
-- the walls and the whole character fits through the doorway.
local wallEdge = Layout.corridorClear() / 2
local clipping = 0
local sampled = 0
for step = -40, 40 do
	local z = wallEdge * (step / 40)
	sampled += 1
	if math.abs(z) + bodyHalf > Layout.Door / 2 then
		clipping += 1
	end
end
check(`(guard) the walkable width was swept ({sampled} positions)`, sampled > 50)
check(`nowhere you can stand clips the frame ({clipping} of {sampled})`, clipping == 0)

-- The wall itself is the case that matters, because that is where a fleeing
-- player is.
check(
	`pressed against the wall you still fit ({wallEdge} + {bodyHalf} <= {Layout.Door / 2})`,
	wallEdge + bodyHalf <= Layout.Door / 2
)

-- And the control: a stud further out and the sweep does see a clip, so the
-- check above is not passing because it cannot fail.
check("(control) a stud outside the wall DOES clip the frame", (wallEdge + 1) + bodyHalf > Layout.Door / 2)

-- The walls have to be where the number says, not merely computed from it.
local insetWalls = Layout.corridorWalls()
local widest = 0
for _, wall in insetWalls do
	widest = math.max(widest, math.abs(wall.minZ), math.abs(wall.maxZ))
end
check(`(guard) the corridor has walls ({#insetWalls})`, #insetWalls > 0)
check(`the built walls sit at the walkable edge ({widest} = {wallEdge})`, math.abs(widest - wallEdge) < 0.01)
check(
	`...which is inside the floor's edge ({widest} < {Layout.corridorWidth() / 2})`,
	widest < Layout.corridorWidth() / 2
)

-- The Operator's post must be inside the WALLS, not merely on the floor. A post
-- a stud outside them puts every path from it to a room across the wall line,
-- which is the filed geometry-blind movement defect made reachable.
local post52 = Layout.operatorPost()
check(
	`the post is inside the walls, not just on the floor ({math.abs(post52.z)} <= {wallEdge})`,
	math.abs(post52.z) <= wallEdge
)

-- A straight walk from the post to either room never leaves the corridor.
for name, centre in { board = Layout.boardCentre(), archive = Layout.archiveCentre() } do
	local strayed = 0
	local walked = 0
	for step = 0, 60 do
		local t = step / 60
		local z = post52.z + (centre.z - post52.z) * t
		local x = post52.x + (centre.x - post52.x) * t
		if math.abs(x) <= Layout.corridorHalfLength() then
			walked += 1
			if math.abs(z) > wallEdge then
				strayed += 1
			end
		end
	end
	check(`(guard) the walk to the {name} crosses the corridor ({walked} steps)`, walked > 5)
	check(`the Operator's walk to the {name} stays between the walls ({strayed} outside)`, strayed == 0)
end

print("")
print("crosses(): the primitive itself, never unit-tested before")

-- R69. Layout.crosses feeds walkIsClear/routeIsClear, which R41 and R42 use to
-- decide what a station's prompt may reveal. It has a "parallel to the wall"
-- branch with no test of its own -- a mutation sweep made it return TRUE for a
-- parallel segment (the wrong answer) and nothing in the whole suite noticed,
-- because nothing exercises the primitive directly; only through paths this
-- game's two rooms happen never to run exactly parallel to a wall.
local wallX = { minX = 10, minZ = -5, maxX = 10, maxZ = 5 }

-- A segment that actually crosses the wall's span.
check("a segment crossing the wall's x is caught", Layout.crosses(wallX, { x = 5, z = 0 }, { x = 15, z = 0 }))
-- Both ends on the same side: never crosses.
check("both ends on the near side do not cross", not Layout.crosses(wallX, { x = 5, z = 0 }, { x = 8, z = 0 }))
check("both ends on the far side do not cross", not Layout.crosses(wallX, { x = 15, z = 0 }, { x = 20, z = 0 }))
-- Crossing at x but outside the wall's z-span: does not cross.
check(
	"crossing the line but missing the wall's span does not cross",
	not Layout.crosses(wallX, { x = 5, z = 20 }, { x = 15, z = 20 })
)
-- PARALLEL to the wall: never crosses, whatever x it runs along.
check(
	"a segment running parallel to the wall does not cross it",
	not Layout.crosses(wallX, { x = 10, z = -20 }, { x = 10, z = 20 })
)
check(
	"...even lined up exactly on the wall's own x",
	not Layout.crosses({ minX = 10, minZ = -5, maxX = 10, maxZ = 5 }, { x = 10, z = -100 }, { x = 10, z = 100 })
)

-- The Z-facing wall gets the same sweep, since crosses branches on which
-- dimension is constant.
local wallZ = { minX = -5, minZ = 10, maxX = 5, maxZ = 10 }
check("a segment crossing the wall's z is caught", Layout.crosses(wallZ, { x = 0, z = 5 }, { x = 0, z = 15 }))
check(
	"parallel to a Z-facing wall does not cross it either",
	not Layout.crosses(wallZ, { x = -20, z = 10 }, { x = 20, z = 10 })
)

print("")
print("routeIsClear checks every leg, not only the first")

-- R76. A mutation sweep narrowed routeIsClear's loop to check only the FIRST
-- leg (`for i = 1, 1` instead of `for i = 1, #route - 1`), and every existing
-- check of it still passed -- because a real route's first leg (spawn to the
-- doorway) is always clear, so nothing had ever proven the function looks past
-- it. Built directly on the corridor's own south wall rather than a room's
-- doorway, so the crossing is unambiguous.
local corridorHalfZ = Layout.corridorClear() / 2
local clearA = { x = 0, z = 0 }
local clearB = { x = 0, z = corridorHalfZ - 1 }
local acrossTheWall = { x = 0, z = corridorHalfZ + 5 }
check("(guard) the first leg alone is clear", Layout.walkIsClear(clearA, clearB))
check("(guard) the second leg really does cross the corridor wall", not Layout.walkIsClear(clearB, acrossTheWall))
check(
	"routeIsClear reports the whole route blocked, from the SECOND leg",
	not Layout.routeIsClear({ clearA, clearB, acrossTheWall })
)
-- (control) the same three points, minus the crossing leg, must read clear --
-- proving the check above is not simply always false.
check("(control) dropping the blocked leg reads clear again", Layout.routeIsClear({ clearA, clearB }))

print("")
print("the Operator's own path is geometry-aware, not geometry-blind")

-- R79. "Geometry-blind movement" has been filed since R29: Pursuit.step moves
-- in a genuine straight line -- distance(self.position, target), then
-- interpolated toward it -- with no wall awareness at all. Layout.walkIsClear
-- and routeIsClear exist for exactly this and had ZERO production callers;
-- only tests/layout.luau used them, and only against the PLAYER's walk from
-- spawn to a station, never against the Operator's own path.
--
-- R52 nearly proved the risk live: repositioning operatorPost() briefly left
-- it one stud outside the corridor walls, "which would have made the filed
-- geometry-blind-movement defect reachable." Caught by a human noticing a
-- number looked wrong, not by any test built for this -- R52's own 20 checks
-- are a bespoke corridor-wall sweep, not a use of the shared primitive.
--
-- The waypoints are DERIVED from Config.Rooms and Layout.operatorPost(), never
-- hand-typed, so a third room (R9's future work) is covered automatically
-- rather than needing this test rewritten to notice it exists.
local waypoints = { { name = "post", at = Layout.operatorPost() } }
for _, room in Config.Rooms do
	local centre = if room == "board"
		then Layout.boardCentre()
		elseif room == "archive" then Layout.archiveCentre()
		else nil
	check(`(guard) '{room}' has a known centre`, centre ~= nil)
	if centre then
		table.insert(waypoints, { name = room, at = centre })
	end
end
check(`(guard) there is more than one waypoint to route between ({#waypoints})`, #waypoints >= 2)

local blocked: { string } = {}
local checked = 0
for _, from in waypoints do
	for _, to in waypoints do
		if from.name ~= to.name then
			checked += 1
			if not Layout.walkIsClear(from.at, to.at) then
				table.insert(blocked, `{from.name} -> {to.name}`)
			end
		end
	end
end
check(`(guard) every ordered pair was checked ({checked})`, checked == #waypoints * (#waypoints - 1))
check(`every straight line the Operator can walk is clear ({#blocked} blocked)`, #blocked == 0)
if #blocked > 0 then
	print(`        blocked: {table.concat(blocked, ", ")}`)
end

-- (control) a post placed OUTSIDE the walls -- R52's exact near-miss -- must
-- be caught by this same sweep, or it is not measuring what it claims to.
local outsidePost = { x = 0, z = -(Layout.corridorWidth() / 2 - 1) }
check(
	"(control) R52's near-miss placement is caught by this check",
	not Layout.walkIsClear(outsidePost, Layout.boardCentre())
)

print("")
print("the rooms the world builds are the rooms Config declares (R104)")

local builtRooms = { board = Layout.boardCentre(), archive = Layout.archiveCentre() }
local real = Layout.roomMismatch(builtRooms, Config.Rooms)
check(`the shipped Config.Rooms matches the built rooms ({real or "ok"})`, real == nil)
local missing = Layout.roomMismatch({ board = Layout.boardCentre() }, { "board", "archive" })
check(
	"a declared room with no position is caught, by name",
	missing ~= nil and string.find(missing, "'archive'", 1, true) ~= nil
)
local extra = Layout.roomMismatch(builtRooms, { "board" })
check(
	"a built room nobody declared is caught, by name",
	extra ~= nil
		and string.find(extra, "'archive'", 1, true) ~= nil
		and string.find(extra, "does not declare", 1, true) ~= nil
)

print("")
print("World builds the rooms where Layout says they are (R105)")

-- World.build cannot run headlessly, so every capture, walk and room test
-- here uses Layout's centres. They are only the world's centres if World
-- takes them FROM Layout rather than computing its own copy.
check(
	"World takes the board room's origin from Layout.boardCentre",
	string.find(worldCode, "Layout.boardCentre()", 1, true) ~= nil
)
check(
	"World takes the records room's origin from Layout.archiveCentre",
	string.find(worldCode, "Layout.archiveCentre()", 1, true) ~= nil
)
check(
	"World computes no room origin of its own from the separation",
	string.find(worldCode, "SEPARATION / 2", 1, true) == nil
)

print("")
print("every station is placed from Layout, and the breaker can be walked to (R106)")

check("World places stations by Layout.stationOffset", string.find(worldCode, "Layout.stationOffset()", 1, true) ~= nil)
check(
	"World places the breaker by Layout.breakerOffset",
	string.find(worldCode, "Layout.breakerOffset()", 1, true) ~= nil
)
check(
	"World carries no literal station offset of its own",
	string.find(worldCode, "Vector3.new(0, 4, -18)", 1, true) == nil
		and string.find(worldCode, "Vector3.new(18, 4, 0)", 1, true) == nil
)
local archive = Layout.archiveCentre()
local breakerPoint = { x = archive.x + Layout.breakerOffset().x, z = archive.z + Layout.breakerOffset().z }
check("the breaker stands inside the records room", Layout.inRoom(archive, breakerPoint))
check(
	"you can walk from spawn through the door to the breaker",
	Layout.routeIsClear({ Layout.spawn(), Layout.doorPoint(archive), breakerPoint })
)

check("World spawns players at Layout.spawn (R107)", string.find(worldCode, "Layout.spawn()", 1, true) ~= nil)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
