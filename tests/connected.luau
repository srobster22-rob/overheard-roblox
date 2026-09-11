--!strict
-- Being connected is the only real consequence in the game, so its rules get
-- asserted rather than assumed.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
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

local A, B, C = 1, 2, 3

print("connecting")
local line = Connected.new()
check("nobody starts connected", line:isConnected(A) == false)
check("count starts at zero", line:count() == 0)

local announced = 0
line.onConnected = function()
	announced += 1
end
check("connecting reports true the first time", line:connect(A, 10) == true)
check("they are now connected", line:isConnected(A) == true)
check("it announced once", announced == 1)

-- The Operator can arrive, be re-sent and arrive again. Announcing the same
-- capture twice reads as a bug to the player.
check("connecting again reports false", line:connect(A, 11) == false)
check("and does not announce again", announced == 1)
check("count reflects one", line:count() == 1)

print("leaving")
line:forget(A)
check("forgetting clears them", line:isConnected(A) == false)
check("so a rejoin is not already caught", line:connect(A, 12) == true)

print("reach")
local r = Connected.new()
local positions = {
	[A] = { x = 0, z = 0 },
	[B] = { x = 5, z = 0 },
	[C] = { x = 100, z = 0 },
}
local caught = r:reached({ x = 0, z = 0 }, positions, 10)
check("it takes everyone inside reach", #caught == 2)
check("nearest are the ones taken", caught[1] == A and caught[2] == B)
check("someone across the building is safe", table.find(caught, C) == nil)

-- Boundary: exactly at the reach distance counts as caught. Stated so a later
-- round does not "fix" it in the other direction by accident.
local edge = Connected.new()
check("exactly at reach is caught", #edge:reached({ x = 0, z = 0 }, { [A] = { x = 10, z = 0 } }, 10) == 1)
check("just outside reach is not", #edge:reached({ x = 0, z = 0 }, { [A] = { x = 10.1, z = 0 } }, 10) == 0)

print("already-connected players are not re-taken")
local again = Connected.new()
again:connect(A, 1)
local second = again:reached({ x = 0, z = 0 }, positions, 10)
check("an already-connected player is skipped", table.find(second, A) == nil)
check("but their neighbour is still taken", table.find(second, B) ~= nil)

print("losing")
local lose = Connected.new()
check("an empty server is not a loss", lose:allTaken({}) == false)
lose:connect(A, 1)
check("one of two taken is not a loss", lose:allTaken({ A, B }) == false)
lose:connect(B, 2)
check("both taken is a loss", lose:allTaken({ A, B }) == true)
check("a fresh joiner un-loses it", lose:allTaken({ A, B, C }) == false)

print("")
print("occupancy is continuous, not a single frame")

-- R24. Capture used to run ONLY from `pursuit.onStateChanged` on the transition
-- to `arrived`, and `Pursuit.setState` returns early when the state is
-- unchanged. So the Operator took whoever stood in the room at that one instant
-- and was harmless from then on: demonstrated at 60 seconds standing beside it,
-- `captures=0`. The server now asks every `Config.TickSeconds`.
--
-- Modelled here against the REAL Pursuit and Connected, driven the way the
-- server drives them, because `init.server` cannot be loaded headlessly.

local Pursuit = rt.require(rt.systems.Pursuit)
local Layout = rt.require(rt.shared.Layout)

local board = Layout.boardCentre()
local tracker = Pursuit.new({ board = { x = board.x, z = board.z } }, { x = 0, z = 0 })
local occupancy = Connected.new()
local positions: { [number]: { x: number, z: number } } = { [1] = { x = 0, z = 0 } }

local captured = 0
local function tick()
	-- Exactly the server's rule: while it is standing in the room, it is taking.
	if tracker.state ~= "arrived" then
		return
	end
	for _, id in occupancy:reachedInRoom(tracker.position, positions, Layout.halfRoom()) do
		if occupancy:connect(id, 0) then
			captured += 1
		end
	end
end

tracker:sendTo("board")
for _ = 1, 40 do
	tracker:step(1)
	tick()
	if tracker.state == "arrived" then
		break
	end
end
check("(guard) the Operator reached the room", tracker.state == "arrived")
check("a player out in the corridor is not taken", captured == 0)

-- The defect: walk in AFTER it has arrived.
positions[1] = { x = board.x, z = board.z }
check("(guard) the player is now inside that room", Layout.inRoom(board, positions[1]))
tick()
check("walking in after it arrived is still fatal", captured == 1)
check("and the player is on the line", occupancy:isConnected(1) == true)

-- Idempotent across ticks: standing there must not re-announce every 0.25s.
local before = captured
for _ = 1, 20 do
	tick()
end
check("standing there does not re-capture on every tick", captured == before)

-- Someone who leaves before the next tick is not taken by a stale position.
local second = Connected.new()
local movers: { [number]: { x: number, z: number } } = { [2] = { x = board.x, z = board.z } }
local out = 0
movers[2] = { x = 0, z = 0 }
for _, id in second:reachedInRoom(board, movers, Layout.halfRoom()) do
	out += 1
	local _ = id
end
check("a player who left the room is not taken", out == 0)

-- R25: and the room has to become SAFE again, or R24's continuous capture is a
-- permanent softlock. Same driver, now including the release the server runs.
local LINGER = 10
local released = false
local function tickWithRelease()
	if tracker.state == "arrived" then
		for _, id in occupancy:reachedInRoom(tracker.position, positions, Layout.halfRoom()) do
			if occupancy:connect(id, 0) then
				captured += 1
			end
		end
	end
	if tracker:shouldLeave(LINGER) then
		tracker:stop()
		released = true
	end
end

local latecomer = 42
positions[latecomer] = { x = board.x, z = board.z }
for _ = 1, LINGER + 2 do
	tracker:step(1)
	tickWithRelease()
end
check("the Operator eventually gives up the room", released)
check("(guard) it is no longer standing on the objective", tracker.state == "idle")
check("(guard) somebody was taken while it was still there", occupancy:isConnected(latecomer))

-- The point of the fix: a player arriving AFTER it leaves can work in peace.
local afterwards = 43
positions[afterwards] = { x = board.x, z = board.z }
for _ = 1, 20 do
	tickWithRelease()
end
check("a player who comes after it has gone is safe", occupancy:isConnected(afterwards) == false)

print("")
print("taking a room: connect AND forget (R112)")

-- R112. The soak ran a copy of this that connected but never told the
-- Supervisor to forget -- 7 of its 28 normal-session calls chased players
-- already on the line. Now there is one function, and it is run here.
do
	local Supervisor_ = rt.require(rt.systems.Supervisor)
	local Layout_ = rt.require(rt.shared.Layout)
	local centre = Layout_.boardCentre()
	local half = Layout_.halfRoom()
	local sup = Supervisor_.new()
	sup:watch(1, 0)
	sup:watch(2, 0)
	local l = Connected.new()
	local positions = { [1] = { x = centre.x, z = centre.z }, [2] = Layout_.spawn() }
	local reached, newly = l:takeInRoom(centre, positions, half, 5, sup)
	check(
		"the player in the room is reached and newly connected",
		#reached == 1 and reached[1] == 1 and #newly == 1 and newly[1] == 1
	)
	check("...and put on the line", l:isConnected(1))
	check("...and FORGOTTEN by the Supervisor", sup:quietFor(1, 10) == nil)
	check(
		"(control) the player outside is neither taken nor forgotten",
		not l:isConnected(2) and sup:quietFor(2, 10) ~= nil
	)
	local again, newAgain = l:takeInRoom(centre, positions, half, 6, sup)
	check("taking the room again takes and tells nobody twice", #again == 0 and #newAgain == 0)
end

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
