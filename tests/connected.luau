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

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
