--!strict
-- The audibility rule is the scare. These tests exist to stop it regressing
-- into "monster makes noise the whole time", which would be a different and
-- much worse game.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".
local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Pursuit = rt.require(rt.systems.Pursuit)

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

local ROOMS = {
	board = { x = 60, z = 0 },
	archive = { x = -60, z = 0 },
}

local function tracker()
	return Pursuit.new(ROOMS, { x = 0, z = 0 })
end

print("targeting")
local t = tracker()
check("starts idle", t.state == "idle")
check("starts inaudible", t:isAudible() == false)
check("a known payload is accepted", t:sendTo("board") == true)
check("targeting makes it audible", t:isAudible() == true)

local unknown = tracker()
check("an unknown payload is refused", unknown:sendTo("nowhere") == false)
check("and it stays idle", unknown.state == "idle")

print("movement")
local m = tracker()
m:sendTo("board")
local before = Pursuit.distance(m.position, ROOMS.board)
m:step(1)
local after = Pursuit.distance(m.position, ROOMS.board)
check("stepping closes distance", after < before)
check("it does not teleport", (before - after) <= m.speed + 0.001)

print("the silence rule")
local s = tracker()
s:sendTo("board")
-- Walk it in one second at a time and record when it stopped being audible.
local audibleAt: { number } = {}
for _ = 1, 40 do
	s:step(1)
	table.insert(audibleAt, if s:isAudible() then 1 else 0)
	if s.state == "arrived" then
		break
	end
end
check("it eventually arrives", s.state == "arrived")
check("it was audible at the start", audibleAt[1] == 1)
check("it is NOT audible on arrival", s:isAudible() == false)

-- Once it goes quiet it must stay quiet. A monster that goes silent and then
-- noisy again while closing destroys the tell.
local wentQuiet = false
local brokeSilence = false
for _, v in audibleAt do
	if v == 0 then
		wentQuiet = true
	elseif wentQuiet and v == 1 then
		brokeSilence = true
	end
end
check("it goes quiet before arriving", wentQuiet)
check("and never becomes audible again while closing", not brokeSilence)

print("state changes")
local seen: { string } = {}
local c = tracker()
c.onStateChanged = function(state: string)
	table.insert(seen, state)
end
c:sendTo("board")
for _ = 1, 40 do
	c:step(1)
	if c.state == "arrived" then
		break
	end
end
check("approaching is reported", table.find(seen, "approaching") ~= nil)
check("closing is reported", table.find(seen, "closing") ~= nil)
check("arrived is reported", table.find(seen, "arrived") ~= nil)
check(
	"arrived is reported exactly once",
	(function()
		local n = 0
		for _, v in seen do
			if v == "arrived" then
				n += 1
			end
		end
		return n == 1
	end)()
)

print("retargeting")
local r = tracker()
r:sendTo("board")
for _ = 1, 40 do
	r:step(1)
	if r.state == "arrived" then
		break
	end
end
r:sendTo("archive")
check("a new target makes it audible again", r:isAudible() == true)
check("and it is no longer arrived", r.state ~= "arrived")

print("stopping")
local st = tracker()
st:sendTo("board")
st:stop()
st:step(1)
check("stopping returns it to idle", st.state == "idle")
check("and silences it", st:isAudible() == false)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
