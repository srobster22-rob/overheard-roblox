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

-- THE MAIN PATH. `onUnderstood` calls `sendTo` on every utterance it
-- understands, not just the first, and the whole game is players talking about
-- the thing it is listening for. So `sendTo` being called repeatedly WHILE it
-- travels is the normal case, not an edge case. It used to assert
-- "approaching" outright, which re-armed the hum at every distance.
print("re-sent while it is already on the way")

local band = tracker()
check("classify: far away is approaching", band:classify(band.silenceRadius + 1) == "approaching")
check("classify: inside the silence radius is closing", band:classify(band.silenceRadius) == "closing")
check("classify: on top of it is arrived", band:classify(band.arriveRadius) == "arrived")

local nagged = tracker()
local arrivals = 0
nagged.onStateChanged = function(state: string)
	if state == "arrived" then
		arrivals += 1
	end
end
nagged:sendTo("board")
local nagAudible: { number } = {}
for _ = 1, 12 do
	nagged:step(1)
	-- Somebody says the giveaway again.
	nagged:sendTo("board")
	table.insert(nagAudible, if nagged:isAudible() then 1 else 0)
end
check("it still arrives even while being re-sent", nagged.state == "arrived")
check("it is NOT audible on arrival, however much was said", nagged:isAudible() == false)
check("arrived is announced exactly once, not once per utterance", arrivals == 1)

local nagWentQuiet, nagBrokeSilence = false, false
for _, v in nagAudible do
	if v == 0 then
		nagWentQuiet = true
	elseif nagWentQuiet and v == 1 then
		nagBrokeSilence = true
	end
end
-- Guard: if the sweep never heard it at all, the two checks below pass
-- vacuously and prove nothing.
check("the re-sent walk was audible at some point (guard)", table.find(nagAudible, 1) ~= nil)
check("it still goes quiet while being re-sent", nagWentQuiet)
check("and being re-sent never turns the hum back on", not nagBrokeSilence)

-- The two boundary cases, each on its own, so neither is inferred from the walk.
local closingRe = tracker()
closingRe:sendTo("board")
while closingRe.state == "approaching" do
	closingRe:step(1)
end
check("walked it into the closing band (guard)", closingRe.state == "closing")
closingRe:sendTo("board")
check("re-sending it while closing leaves it closing", closingRe.state == "closing")
check("and it stays silent", closingRe:isAudible() == false)

local standing = tracker()
standing:sendTo("board")
for _ = 1, 40 do
	standing:step(1)
	if standing.state == "arrived" then
		break
	end
end
check("walked it all the way in (guard)", standing.state == "arrived")
standing:sendTo("board")
check("re-sending it to the room it stands in leaves it arrived", standing.state == "arrived")
check("and does not make it audible again", standing:isAudible() == false)

print("stopping")
local st = tracker()
st:sendTo("board")
st:stop()
st:step(1)
check("stopping returns it to idle", st.state == "idle")
check("and silences it", st:isAudible() == false)

print("")
print("it loses interest instead of parking forever")

-- R25. Nothing except the round being lost ever returned it to idle, and since
-- R24 it captures the whole time it is `arrived`. So one plain word parked it on
-- top of an objective for the rest of the round: nobody could reach that
-- station, `allSolved` was unreachable, and the round could only end in a loss.
-- Both required stations were lockable this way.

local dweller = tracker()
dweller:sendTo("board")
for _ = 1, 40 do
	dweller:step(1)
	if dweller.state == "arrived" then
		break
	end
end
check("(guard) it arrived", dweller.state == "arrived")
check("it does not leave the instant it lands", dweller:shouldLeave(10) == false)

-- Dwell is real time, accumulated by step.
for _ = 1, 9 do
	dweller:step(1)
end
check("nine seconds in, it is still interested", dweller:shouldLeave(10) == false)
dweller:step(1)
check("ten seconds in, it has had enough", dweller:shouldLeave(10) == true)

-- The server acts on the answer; the module only reports it.
check("it is still arrived until someone stops it", dweller.state == "arrived")
dweller:stop()
check("stopping releases the room", dweller.state == "idle")
check("and a released Operator is not still leaving", dweller:shouldLeave(10) == false)

-- Dwell must not survive the trip: arriving somewhere new starts the clock over,
-- or the second room would be released the moment it got there.
local again = tracker()
again:sendTo("board")
for _ = 1, 40 do
	again:step(1)
	if again.state == "arrived" then
		break
	end
end
for _ = 1, 30 do
	again:step(1)
end
check("(guard) it has dwelt long enough to leave", again:shouldLeave(10) == true)
again:sendTo("archive")
check("being sent somewhere new resets the dwell", again:shouldLeave(10) == false)
for _ = 1, 40 do
	again:step(1)
	if again.state == "arrived" then
		break
	end
end
check("(guard) it arrived at the new room", again.state == "arrived")
check("and it does not immediately leave that one", again:shouldLeave(10) == false)

-- A tracker that never arrived must never claim it is time to go.
local travelling = tracker()
travelling:sendTo("board")
travelling:step(1)
check("(guard) it is still on its way", travelling.state ~= "arrived")
check("something still travelling never wants to leave", travelling:shouldLeave(0) == false)
local idle = tracker()
check("an idle Operator never wants to leave", idle:shouldLeave(0) == false)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
