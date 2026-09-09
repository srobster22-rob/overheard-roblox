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

-- Stations. The board and the deal used to be two independent lists: the
-- server hardcoded one objective while pickSecrets shuffled 3 of 5 secrets, so
-- on 39.6% of servers the only objective's concept was not something the
-- Operator was listening for. Saying the answer out loud was free. These
-- checks are derived from STATIONS and from World's source, never from a
-- hand-kept list, so a station added later cannot slip past them.
print("")
print("stations")
local fs = require("@lune/fs")

local pool: { [string]: boolean } = {}
for _, secret in all do
	pool[secret.concept] = true
end

check("there is at least one station", #Round.STATIONS > 0)

local seenIds: { [string]: boolean } = {}
local worldSource = fs.readFile("src/server/systems/World.luau")
local stationsMap = string.match(worldSource, "stations = {(.-)\n\t\t}") or ""

for _, station in Round.STATIONS do
	check(`station '{station.id}' has a unique id`, seenIds[station.id] == nil)
	seenIds[station.id] = true
	check(`station '{station.id}' wants a concept the secret pool carries`, pool[station.concept] == true)
	check(`station '{station.id}' prompt has a slot for the answer`, string.find(station.prompt, "%%s") ~= nil)
	check(`station '{station.id}' has an action verb`, #station.actionText > 0)
	-- No physical prompt means the objective can never be solved, so
	-- `allSolved` can never be reached and the round cannot end.
	check(
		`World builds a prompt for station '{station.id}'`,
		string.find(stationsMap, `\n\t\t\t{station.id} = `, 1, true) ~= nil
	)
end

-- The load-bearing one: a station's concept must be dealt EVERY time, at any
-- count, including a count smaller than the number of stations.
for count = 0, #all do
	local dealt = Round.dealSecrets(count)
	local got: { [string]: boolean } = {}
	for _, secret in dealt do
		got[secret.concept] = true
	end
	local allIn = true
	for _, station in Round.STATIONS do
		if not got[station.concept] then
			allIn = false
		end
	end
	check(`dealSecrets({count}) still deals every station's concept`, allIn)
end
check("dealSecrets fills up to the requested count", #Round.dealSecrets(#all) == #all)

-- Rooms. `Config.Rooms` and `World.build`'s `rooms` table are two lists that
-- must agree, and until R6 the only thing keeping them in step was a comment.
-- A name declared in Config with no position in World makes `Pursuit.sendTo`
-- refuse the move: the Operator never arrives, nothing errors, and the checks
-- above still pass because they only ask whether a payload is in Config. A
-- room built but not declared is the mirror — this file would reject a payload
-- that would have worked. Both directions, every name, read out of World's
-- source rather than a hand-kept list.
print("")
print("rooms")
local roomsMap = string.match(worldSource, "\n\tlocal rooms: {.-} = {(.-)\n\t}") or ""
local builtRooms: { [string]: boolean } = {}
for name in string.gmatch(roomsMap, "\n\t\t([%a][%w_]*) = ") do
	builtRooms[name] = true
end
check("World's rooms table was found in source", next(builtRooms) ~= nil)
check("Config declares at least one room", #Config.Rooms > 0)
for _, name in Config.Rooms do
	check(`Config declares room '{name}' and World builds it`, builtRooms[name] == true)
end
for name in builtRooms do
	check(`World builds room '{name}' and Config declares it`, known[name] == true)
end

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
