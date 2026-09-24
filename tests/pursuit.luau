--!strict
-- The audibility rule is the scare. These tests exist to stop it regressing
-- into "monster makes noise the whole time", which would be a different and
-- much worse game.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".

local Harness = require("./harness")

local rt = Harness.build()
local Pursuit = rt.require(rt.systems.Pursuit)

local Kit = require("./kit")
local check = Kit.check

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
-- R74. A mutation sweep widened the arrive boundary (`<= arriveRadius + 3`)
-- and nothing caught it, because the only existing check sat EXACTLY on the
-- boundary, which passes under either version. Just past it must read
-- differently: still closing, not yet arrived.
check(
	"classify: just past arriveRadius is still closing, not arrived",
	band:classify(band.arriveRadius + 1) == "closing"
)

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

print("")
print("it walks out audibly instead of switching off")

-- R26. R25 released the room with `stop()`, which sets `idle` WHERE IT STANDS.
-- Both `arrived` and `idle` are silent and the body does not move, so the room
-- went from lethal to safe with no signal at all. A monster whose rule cannot be
-- learned reads as unfair -- CLAUDE.md's own words.

local home = { x = 0, z = 0 }
local leaver = tracker()
leaver:sendTo("board")
for _ = 1, 40 do
	leaver:step(1)
	if leaver.state == "arrived" then
		break
	end
end
check("(guard) it arrived and went quiet", leaver.state == "arrived" and leaver:isAudible() == false)

leaver:withdrawTo(home)
check("withdrawing puts it in the leaving state", leaver.state == "leaving")
check("YOU HEAR IT GO", leaver:isAudible() == true)
check("it is no longer arrived, so it captures nothing on the way out", leaver.state ~= "arrived")

-- Audible for the whole walk, not just the first frame.
local heardEvery = true
local steps = 0
for _ = 1, 60 do
	leaver:step(1)
	steps += 1
	if leaver.state == "idle" then
		break
	end
	if not leaver:isAudible() then
		heardEvery = false
	end
end
check(`(guard) the walk out took more than one step ({steps})`, steps > 1)
check("it is audible for the whole walk out", heardEvery)

check("reaching home ends as idle, never arrived", leaver.state == "idle")
check("and it goes quiet again", leaver:isAudible() == false)
check("an idle Operator has no target left", leaver.target == nil)
check("and it does not want to leave again", leaver:shouldLeave(0) == false)

-- The dangerous mistake this could make: retreating INTO a room and counting as
-- arrived there, which would start capturing at the place it fled to.
local intoRoom = tracker()
intoRoom:sendTo("board")
for _ = 1, 40 do
	intoRoom:step(1)
	if intoRoom.state == "arrived" then
		break
	end
end
intoRoom:withdrawTo({ x = ROOMS.archive.x, z = ROOMS.archive.z })
for _ = 1, 60 do
	intoRoom:step(1)
	if intoRoom.state == "idle" then
		break
	end
end
check("withdrawing onto a room centre still ends idle, not arrived", intoRoom.state == "idle")

-- And it can be called back out of a withdrawal mid-walk.
local recalled = tracker()
recalled:sendTo("board")
for _ = 1, 40 do
	recalled:step(1)
	if recalled.state == "arrived" then
		break
	end
end
recalled:withdrawTo(home)
recalled:step(1)
check("(guard) it is on its way out", recalled.state == "leaving")
recalled:sendTo("board")
check("hearing something again pulls it back", recalled.state ~= "leaving")
check("and it is hunting, not retreating", recalled.targetName == "board")

print("")
print("arriving always lands ON the room centre")

-- R30, correcting R26. `step` snapped only on its early-exit branch; the path at
-- the bottom set `arrived` through `classify` WITHOUT moving the position, so an
-- ordinary arrival stopped up to ArriveRadius short. R23's capture box is
-- centred on `pursuit.position`, so it hung that far outside one wall and fell
-- that far short of the opposite one. R26 recorded this as unreachable. It was
-- the normal path.

local landings = 0
local offset = 0
for _, dt in { 0.1, 0.25, 0.5, 1, 2, 3, 7 } do
	local lander = tracker()
	lander:sendTo("board")
	for _ = 1, 2000 do
		lander:step(dt)
		if lander.state == "arrived" then
			break
		end
	end
	if lander.state == "arrived" then
		landings += 1
		local d = math.sqrt((lander.position.x - ROOMS.board.x) ^ 2 + (lander.position.z - ROOMS.board.z) ^ 2)
		if d > 0.0001 then
			offset += 1
			print(`    dt={dt} stopped {string.format("%.2f", d)} studs short`)
		end
	end
end
check(`(guard) every step size reached the room ({landings}/7)`, landings == 7)
check(`arrival is exactly on the centre at every step size ({offset} offset)`, offset == 0)

print("")
print("a new round puts it back at its post")

-- R29 began the next round with `stop()`, which clears the target and goes idle
-- but leaves the POSITION where it stood. So round two started with the Operator
-- inside the room it had hunted, and the next understanding of that room made it
-- `arrived` on the spot: no approach, no hum, instant capture.

local post = { x = -40, z = 0 }
local across = tracker()
across:sendTo("board")
for _ = 1, 200 do
	across:step(0.5)
	if across.state == "arrived" then
		break
	end
end
check("(guard) it ended the round inside the room", across.state == "arrived")

across:sendHome(post)
check("a new round puts it at the post", across.position.x == post.x and across.position.z == post.z)
check("idle, not arrived", across.state == "idle")
check("silent", across:isAudible() == false)
check("with nothing to chase", across.target == nil and across.targetName == nil)
check("and no dwell carried over", across:shouldLeave(0) == false)

-- The point of it: the next round's approach is a real approach again.
across:sendTo("board")
check("being sent again does NOT arrive instantly", across.state ~= "arrived")
check("and you hear it coming", across:isAudible())

print("")
print("it finishes the call it started")

-- R36. `sendTo` retargeted unconditionally, so with two concepts in play the
-- two plain words cancelled each other: alternating them once a second held the
-- Operator 40 studs from either room for FIVE MINUTES, audible throughout and
-- able to capture nobody, because capture requires `arrived`. The counterplay to
-- a monster that hunts what you say became saying more of it.

local function alternate(seconds: number)
	local t = tracker()
	local dt = 0.5
	local flip = false
	t:sendTo("board")
	for step = 1, math.floor(seconds / dt) do
		t:step(dt)
		if t.state == "arrived" then
			return t, true
		end
		if step % 2 == 0 then
			flip = not flip
			t:sendTo(if flip then "archive" else "board")
		end
	end
	return t, false
end

local spammed, reached = alternate(60)
check("alternating both giveaways no longer stops it arriving", reached)
check("(guard) and it really did arrive somewhere", spammed.state == "arrived")

-- The queued room is not lost, it is deferred.
local queued = tracker()
queued:sendTo("board")
queued:step(0.5)
check("(guard) it is on its way to the board", queued.targetName == "board")
check("a second room is accepted", queued:sendTo("archive") == true)
check("...but does not steal the current call", queued.targetName == "board")
check("...and is remembered", queued.pending == "archive")

for _ = 1, 200 do
	queued:step(0.5)
	if queued.state == "arrived" then
		break
	end
end
check("it still finishes the first call", queued.state == "arrived" and queued.targetName == "board")
check("the queued room is not taken while it stands there", queued:takePending() == false)

queued:withdrawTo({ x = 0, z = 0 })
for _ = 1, 400 do
	queued:step(0.5)
	if queued.state == "idle" then
		break
	end
end
check("(guard) it walked home", queued.state == "idle")
check("now it answers the queued room", queued:takePending() == true)
check("...and is heading there", queued.targetName == "archive")
check("...with nothing left queued", queued.pending == nil)

-- Saying the SAME room again must not queue a pointless second trip.
local same = tracker()
same:sendTo("board")
same:step(0.5)
same:sendTo("board")
check("re-saying the room it is already going to queues nothing", same.pending == nil)

-- A queue must not survive a reset, or a new round starts by chasing something
-- somebody said in the last one.
local reset = tracker()
reset:sendTo("board")
reset:step(0.5)
reset:sendTo("archive")
check("(guard) something is queued", reset.pending == "archive")
reset:sendHome({ x = 0, z = 0 })
check("going home clears the queue", reset.pending == nil)

local stopped = tracker()
stopped:sendTo("board")
stopped:step(0.5)
stopped:sendTo("archive")
stopped:stop()
check("stopping clears it too", stopped.pending == nil)

print("")
print("it says whether the call was actually placed")

-- R55. `sendTo` returned a bare `true` whether it turned the Operator toward a
-- room or merely stashed the request in `pending`, where the next request
-- overwrites it. R54's Supervisor believed that `true`: measured over 4,000
-- ticks with the Operator kept busy, it announced 117 silence calls, ONE of
-- which turned it toward the room -- 77 swallowed into `pending`, 39 where it
-- was already going. Every one of the other 116 told every player a line about
-- a call that was never placed, and forgave the silent player for 25 seconds.
--
-- R11's lesson in a new place: a hum that sometimes means nothing is worse than
-- no hum, and a sentence is no different.

local idle = tracker()
local accepted, onItsWay = idle:sendTo("board")
check("an idle Operator takes the call", accepted)
check("...and is on its way", onItsWay)
check("(guard) ...which the state agrees with", idle.state == "approaching" or idle.state == "closing")

-- Now it is committed. A call to the OTHER room is only a note in `pending`.
local queuedAccepted, queuedOnItsWay = idle:sendTo("archive")
check("a call while it is committed is still accepted", queuedAccepted)
check("...but it is NOT on its way", not queuedOnItsWay)
check("(guard) ...because the request went into pending", idle.pending == "archive")
check("(guard) ...and it is still heading where it was", idle.targetName == "board")

-- And the note is overwritten, which is why a caller must not treat it as done.
idle:sendTo("board")
check("a queued room is replaced by the next request", idle.pending ~= "archive" or idle.targetName == "board")

-- Re-sending it where it is already going is on its way, not a new trip.
local again = tracker()
again:sendTo("board")
local _, stillGoing = again:sendTo("board")
check("re-sending it where it already goes is on its way", stillGoing)

-- A room that does not exist is neither.
local nowhere = tracker()
local badAccepted, badOnItsWay = nowhere:sendTo("boiler room")
check("an unknown room is refused", not badAccepted)
check("...and is certainly not on its way", not badOnItsWay)

-- The property, swept: whenever `onItsWay` is true the Operator's target really
-- is that room, and whenever it is false the target is unchanged. This is the
-- whole contract the Supervisor now leans on.
local swept, wrong = 0, 0
local mixed = tracker()
for step = 1, 60 do
	local room = if step % 2 == 0 then "board" else "archive"
	local before = mixed.targetName
	local _, went = mixed:sendTo(room)
	swept += 1
	if went then
		if mixed.targetName ~= room then
			wrong += 1
		end
	elseif mixed.targetName ~= before then
		wrong += 1
	end
	mixed:step(0.25)
end
check(`(guard) the contract was swept ({swept} calls)`, swept >= 50)
check(`'on its way' always means the target really moved there ({wrong} wrong)`, wrong == 0)

print("")
print("it takes the turns its route gives it (R137)")

-- A stub route function, so these hold whatever the building looks like: every
-- trip turns at a point chosen here, and every call is recorded.
local calls: { { from: { x: number, z: number }, to: { x: number, z: number } } } = {}
local turnAt = { x = 30, z = 40 }
local function viaTurn(from, to)
	table.insert(calls, { from = { x = from.x, z = from.z }, to = { x = to.x, z = to.z } })
	return { turnAt }
end

local walker = Pursuit.new(ROOMS, { x = 0, z = 0 }, viaTurn)
walker:sendTo("board")
local closestToTurn = math.huge
for _ = 1, 200 do
	walker:step(0.25)
	local dx, dz = walker.position.x - turnAt.x, walker.position.z - turnAt.z
	closestToTurn = math.min(closestToTurn, math.sqrt(dx * dx + dz * dz))
	if walker.state == "arrived" then
		break
	end
end
check(`it walks through the turn, not past it ({string.format("%.2f", closestToTurn)} studs)`, closestToTurn < 0.001)
check("...and still arrives at the room", walker.state == "arrived")
check("...on the room's centre", walker.position.x == ROOMS.board.x and walker.position.z == ROOMS.board.z)
check("...with no turn left over", #walker.route == 0)

-- A turn inside the arrive radius of the room must not count as arriving:
-- arriving snaps to the room and starts capturing, and a turn is not the room.
local nearTurn = { x = ROOMS.board.x - 2, z = 1 }
local close = Pursuit.new(ROOMS, { x = 0, z = 0 }, function()
	return { nearTurn }
end)
close:sendTo("board")
local arrivedEarly = false
for _ = 1, 200 do
	close:step(0.25)
	if close.state == "arrived" and #close.route > 0 then
		arrivedEarly = true
	end
	if close.state == "arrived" then
		break
	end
end
check("it is never 'arrived' with a turn still to take", not arrivedEarly)
check(
	"...and arrives on the centre once the turn is taken",
	close.state == "arrived" and close.position.x == ROOMS.board.x and close.position.z == ROOMS.board.z
)

-- Every new destination is re-planned from where it stands now.
table.clear(calls)
local replan = Pursuit.new(ROOMS, { x = 0, z = 0 }, viaTurn)
replan:sendTo("board")
replan:step(1)
local midway = { x = replan.position.x, z = replan.position.z }
replan:sendTo("board")
check(
	"re-sending it plans again from where it stands",
	#calls == 2 and calls[2].from.x == midway.x and calls[2].from.z == midway.z
)
replan:withdrawTo({ x = 0, z = 0 })
check("withdrawing plans a route too", #calls == 3 and #replan.route == 1)
replan:stop()
check("stopping forgets the route", #replan.route == 0)
replan:sendTo("archive")
replan:sendHome({ x = 0, z = 0 })
check("going home between rounds forgets the route", #replan.route == 0)

-- A retreat that has to turn is still a retreat: audible, never capturing,
-- and it ends idle at the post (R25), not `arrived` there.
local out = Pursuit.new(ROOMS, ROOMS.board, function()
	return { { x = 30, z = 40 } }
end)
out:withdrawTo({ x = 0, z = 0 })
local stayedLeaving = true
for _ = 1, 400 do
	out:step(0.25)
	if out.state ~= "leaving" and out.state ~= "idle" then
		stayedLeaving = false
	end
	if out.state == "idle" then
		break
	end
end
check("a retreat with a turn stays 'leaving' and ends idle", stayedLeaving and out.state == "idle")

-- On a turn that lies inside the silence radius it is already silent: the
-- turn branch classifies against the room, like the straight walk does.
local near = Pursuit.new(ROOMS, { x = 0, z = 0 }, function()
	return { { x = 50, z = 10 } }
end)
near:sendTo("board")
local audibleOnTurn: boolean? = nil
for _ = 1, 400 do
	near:step(0.25)
	if near.position.x == 50 and near.position.z == 10 then
		audibleOnTurn = near:isAudible()
		break
	end
end
check("on a turn inside the silence radius it is silent", audibleOnTurn == false)

print("")
print("sent somewhere it must go now (R138)")

-- `sendNow` is how the outside call sends it: never queued, a queued room kept,
-- and no second arrival where it already stands.
local urgent = tracker()
urgent:sendTo("board")
urgent:step(1)
urgent:sendTo("archive")
check("(guard) a second room was queued behind the first", urgent.pending == "archive")
check("an unknown room is refused", urgent:sendNow("nowhere") == false)
check("sending it now is accepted", urgent:sendNow("archive") == true)
check("...and it turns for that room at once", urgent.targetName == "archive" and urgent.state == "approaching")

local fresh = { board = ROOMS.board, archive = ROOMS.archive, lobby = { x = 0, z = 60 } }
local withLobby = Pursuit.new(fresh, { x = 0, z = 0 })
withLobby:sendTo("board")
withLobby:step(1)
withLobby:sendTo("archive")
withLobby:sendNow("lobby")
check("a room already queued stays queued", withLobby.pending == "archive")

-- A request queued for the room it is now sent to is served by that trip.
local served = tracker()
served:sendTo("board")
served:step(1)
served:sendTo("archive")
check("(guard) the archive was queued behind the board", served.pending == "archive")
served:sendNow("archive")
check("a queued request for the room it is sent to now is served, not kept", served.pending == nil)
local heardAgain = tracker()
heardAgain:sendTo("board")
heardAgain:step(1)
heardAgain:sendTo("archive")
for _ = 1, 40 do
	heardAgain:step(1)
	if heardAgain.state == "arrived" then
		break
	end
end
heardAgain:sendTo("archive")
check(
	`...and so is one heard again once it stands elsewhere ({tostring(heardAgain.pending)})`,
	heardAgain.targetName == "archive" and heardAgain.pending == nil
)

local standingThere = tracker()
standingThere:sendTo("board")
for _ = 1, 40 do
	standingThere:step(1)
	if standingThere.state == "arrived" then
		break
	end
end
standingThere:step(3)
local arrivedAgain = 0
standingThere.onStateChanged = function(state: string)
	if state == "arrived" then
		arrivedAgain += 1
	end
end
local dwelt = standingThere.dwell
standingThere:sendNow("board")
check("sending it now where it stands does not arrive again", arrivedAgain == 0)
check("...and keeps its time there", standingThere.dwell == dwelt and dwelt > 0)

-- Walking out of a room is not being on a call to it: sent back now, it turns.
standingThere:withdrawTo({ x = 0, z = 0 })
standingThere:step(1)
check("(guard) it is walking out of the board room", standingThere.state == "leaving")
standingThere:sendNow("board")
check(
	`sent back now, it turns round ({tostring(standingThere.targetName)}, {standingThere.state})`,
	standingThere.targetName == "board" and standingThere.state ~= "leaving"
)

-- (control) with no route function it walks straight, as it always did.
local straight = tracker()
straight:sendTo("board")
straight:step(0.25)
check("(control) no route function means no turns", #straight.route == 0 and straight.position.z == 0)

Kit.finish()
