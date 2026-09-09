--!strict
-- Guards a whole class of silent bug: a secret whose payload names a room that
-- does not exist. Pursuit refuses the move, so the Operator simply never
-- reacts, and nothing anywhere reports an error.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".
local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Round = rt.require(rt.systems.Round)
local Config = rt.require(rt.shared.Config)

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

local known: { [string]: boolean } = {}
for _, name in Config.Rooms do
	known[name] = true
end

print("payloads resolve")
local all = Round.pickSecrets(99)
check("the pool is not empty", #all > 0)
for _, secret in all do
	check(`'{secret.concept}' -> '{secret.payload}' is a real room`, known[secret.payload] == true)
end

print("plain terms")
for _, secret in all do
	check(`'{secret.concept}' has plain giveaway terms`, #secret.plain > 0)
end

print("selection")
check("picking fewer than the pool returns that many", #Round.pickSecrets(2) == 2)
check("picking more than the pool is clamped", #Round.pickSecrets(99) == #all)

print("lines")
check("the Operator has a greeting", #Round.LINES.greeting > 0)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
