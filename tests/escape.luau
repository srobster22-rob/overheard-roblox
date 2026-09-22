--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: a round whose ending the players cannot
-- reach, or reach for free.
--
-- R138 made restoring the last line open the way out instead of winning: the
-- outside call rings with the street door shut, then the door opens, the
-- Operator is sent for the lobby, and the round is won when everyone still free
-- stands in the lobby. Every rule of that is here, through `Escape.step` -- the
-- one beat the server, the soak and the bots all call -- with a real Pursuit on
-- the real building.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Escape = rt.require(rt.systems.Escape)
local Connected = rt.require(rt.systems.Connected)
local Lifecycle = rt.require(rt.systems.Lifecycle)
local Objectives = rt.require(rt.systems.Objectives)
local Pursuit = rt.require(rt.systems.Pursuit)
local Layout = rt.require(rt.shared.Layout)
local Config = rt.require(rt.shared.Config)
local Readout = rt.require(rt.shared.Readout)
local Round = rt.require(rt.systems.Round)
local Supervisor = rt.require(rt.systems.Supervisor)

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

local rooms = Layout.rooms()
local exit = rooms[Escape.ROOM]
local board = rooms.board
local RING = Config.CallRingSeconds
local present = { 1, 2, 3 }
local function allAt(point)
	return { [1] = point, [2] = point, [3] = point }
end
local function operator()
	return Pursuit.new(rooms, Layout.operatorPost(), Layout.route)
end

print("the exit is the lobby, and the panel says so")
check(`(guard) the exit room is built ({Escape.ROOM})`, exit ~= nil)
check("the exit is the room the night latch is in", Escape.ROOM == Layout.stationRoom("latch"))
check("the panel's way-out note names that room", string.find(Readout.ESCAPE_NOTE, Escape.ROOM, 1, true) ~= nil)

print("")
print("the call opens once")
local way = Escape.new()
check("it starts shut", not way:isOpen())
check("a shut way out settles nothing", way:step(0, operator(), present, Connected.new(), allAt(exit), rooms) == nil)
check("opening it reports the transition", way:open(100) == true)
check("opening it again reports nothing", way:open(101) == false)
check(`it has been open for 5s at 105 ({way:openFor(105)})`, way:openFor(105) == 5)

print("")
print("the door stays shut while the call rings")
local waiting = operator()
local line = Connected.new()
local outcome, sent = way:step(100 + RING - 0.25, waiting, present, line, allAt(exit), rooms)
check(`(guard) the call rings for a while ({RING}s)`, RING > 0)
check("everyone already in the lobby is NOT out while it rings", outcome == nil)
check("...and the Operator has not been sent", not sent and waiting.targetName == nil)
check("nobody is out through a shut door", not way:everyoneOut(present, line, allAt(exit), rooms))
outcome, sent = way:step(100 + RING, waiting, present, line, allAt(exit), rooms)
check("once it has rung, the Operator is sent", sent and way:isReleased())
check(`...for the exit ({tostring(waiting.targetName)}, {waiting.state})`, waiting.targetName == Escape.ROOM)
check("...audibly, on its way", waiting.state == "approaching")
check("...and a group already inside is out at that moment", outcome == "won")
outcome, sent = way:step(100 + RING + 1, waiting, present, line, allAt(exit), rooms)
check("it is sent once, not every beat", not sent)

print("")
print("out means everyone still free, in the lobby")
local door = Escape.new()
door:open(0)
door:step(RING, operator(), present, line, {}, rooms)
check("(guard) the door is open", door:isReleased())
check(
	"one player still in the board room keeps the round going",
	door:step(RING + 1, operator(), present, line, { [1] = exit, [2] = exit, [3] = board }, rooms) == nil
)
check(
	"a player with no known position is not out",
	door:step(RING + 1, operator(), present, line, { [1] = exit, [2] = exit }, rooms) == nil
)
local caught = Connected.new()
caught:connect(3, 0)
check(
	"a player on the line does not have to get out",
	door:step(RING + 1, operator(), present, caught, { [1] = exit, [2] = exit, [3] = board }, rooms) == "won"
)
local allTaken = Connected.new()
for _, id in present do
	allTaken:connect(id, 0)
end
check("a group taken entirely has not escaped", not door:everyoneOut(present, allTaken, allAt(exit), rooms))

-- A building with no exit room lets nobody out, and ends at the limit.
local noExit = { board = board, archive = rooms.archive }
local sealed = Escape.new()
sealed:open(0)
check("with no exit room nobody gets out", sealed:step(RING, operator(), present, line, allAt(board), noExit) == nil)
check(
	"...and the limit still ends it, lost",
	sealed:step(RING + Config.EscapeSeconds, operator(), present, line, allAt(board), noExit) == "lost"
)

print("")
print("a busy Operator comes at once, and one already there stays put")
local busy = operator()
busy:sendTo("board")
busy:step(1)
-- Someone says an exit word while it is busy: the lobby is queued behind the board.
busy:sendTo(Escape.ROOM)
check(
	"(guard) it is on its way to the board, the lobby queued",
	busy.state == "approaching" and busy.targetName == "board" and busy.pending == Escape.ROOM
)
local call = Escape.new()
call:open(0)
call:step(RING, busy, present, line, {}, rooms)
check(`the outside call outranks the call it was on ({tostring(busy.targetName)})`, busy.targetName == Escape.ROOM)
-- Nothing is left queued: not behind the call it was on, and not the lobby
-- request it had queued, which this trip serves. Kept, that request would bring
-- the Operator back to the lobby after it had given it up and walked home,
-- inside the time limit (R138 review).
check("...rather than queuing behind it, or keeping the request it serves", busy.pending == nil)

local camped = operator()
camped:sendTo(Escape.ROOM)
for _ = 1, 400 do
	camped:step(0.25)
	if camped.state == "arrived" then
		break
	end
end
check("(guard) it stands in the lobby", camped.state == "arrived")
camped:step(5)
local dwellBefore = camped.dwell
local arrivals = 0
camped.onStateChanged = function(state: string)
	if state == "arrived" then
		arrivals += 1
	end
end
local already = Escape.new()
already:open(0)
already:step(RING, camped, present, line, {}, rooms)
check("sending it where it already stands does not make it arrive again", arrivals == 0)
check(
	`...nor restart its time there ({dwellBefore} -> {camped.dwell})`,
	camped.dwell == dwellBefore and dwellBefore > 0
)

print("")
print("it cannot go on forever")
check(`(guard) there is a limit ({Config.EscapeSeconds}s after the door opens)`, Config.EscapeSeconds > 0)
local stuck = Escape.new()
stuck:open(0)
stuck:step(RING, operator(), present, line, {}, rooms)
local last = RING + Config.EscapeSeconds
check(
	"a moment before the limit, nobody out still settles nothing",
	stuck:step(last - 0.25, operator(), present, line, allAt(board), rooms) == nil
)
check(
	"at the limit, with nobody out, it is lost",
	stuck:step(last, operator(), present, line, allAt(board), rooms) == "lost"
)
local takenThere = Connected.new()
takenThere:connect(1, 0)
check(
	"at the limit, a player taken in the lobby does not count as out",
	stuck:step(last, operator(), present, takenThere, { [1] = exit, [2] = board, [3] = board }, rooms) == "lost"
)
check(
	"at the limit, with two out and one who never came, it is won",
	stuck:step(last, operator(), present, line, { [1] = exit, [2] = exit, [3] = board }, rooms) == "won"
)

print("")
print("everyone taken during the escape is a loss")
-- Before R138 a solved board meant the round was already won, so
-- `nobodyCanWin` could say "not lost" the moment the board was solved. Now the
-- round goes on after that, and being taken to the last player must still end it.
local solved = Objectives.new()
local only = solved:add("board", "jack_number", "%s")
only.holder = 1
solved:submit("board", 2, only.answer, 0)
check("(guard) the board is solved", solved:allSolved())
check("everyone taken with the board solved is lost", Lifecycle.nobodyCanWin(present, solved, allTaken))
check("anyone still free with the board solved is not lost", not Lifecycle.nobodyCanWin(present, solved, line))

print("")
print("a new round shuts it, and the call rings again")
way:reset()
check("reset shuts the way out", not way:isOpen() and not way:isReleased())
check("...and it can be opened again", way:open(500) == true)
local again = operator()
local _, sentEarly = way:step(500, again, present, line, {}, rooms)
check("...and does not send the Operator before the call has rung", not sentEarly)
local _, sentAgain = way:step(500 + RING, again, present, line, {}, rooms)
check("...and sends it once the call has rung again", sentAgain and again.targetName == Escape.ROOM)

print("")
print("the way out, raced on the real building")

-- The rules above against the Operator's real walk. Every line is restored at
-- once, with the group split between the board room and the archive, and the
-- group runs for the lobby `runAfter` seconds after the call starts ringing:
-- inside the ring, while it walks, while it stands there, after it has gone --
-- or one player never comes. Wired like the server: players move at the top of
-- the beat, and capture and the loss come before the way out. Config's timing
-- comments quote the numbers measured here.
local function race(runAfter: number, start: Layout.Point?, afk: number?)
	math.randomseed(1)
	local work = Objectives.new()
	for _, station in Round.STATIONS do
		work:add(station.id, station.concept, station.prompt)
	end
	local group = { 1, 2, 3, 4 }
	work:deal(group)
	for _, objective in work.list do
		for _, userId in group do
			if userId ~= objective.holder and work:submit(objective.id, userId, objective.answer, 0).ok then
				break
			end
		end
	end
	local onTheLine = Connected.new()
	local round = Lifecycle.new()
	local pursuit = Pursuit.new(rooms, start or Layout.operatorPost(), Layout.route)
	local escape = Escape.new()
	local standing = { [1] = board, [2] = board, [3] = rooms.archive, [4] = rooms.archive }
	escape:open(0)
	local now: number, arrivedAt: number? = 0, nil
	for _ = 1, math.floor(120 / Config.TickSeconds) do
		now += Config.TickSeconds
		-- The players' part: once it has rung for `runAfter`, everyone still free
		-- who is coming stands in the lobby.
		if escape:openFor(now) >= runAfter then
			for _, userId in group do
				if userId ~= afk and not onTheLine:isConnected(userId) then
					standing[userId] = exit
				end
			end
		end
		pursuit:step(Config.TickSeconds)
		if pursuit.state == "arrived" and pursuit.targetName == Escape.ROOM then
			arrivedAt = arrivedAt or now
		end
		if round:isPlaying() and pursuit.state == "arrived" then
			onTheLine:takeInRoom(pursuit.position, standing, Layout.halfRoom(), now, Supervisor.new())
		end
		if round:isPlaying() and Lifecycle.nobodyCanWin(group, work, onTheLine) then
			round:finish("lost", now)
		end
		local settled = if round:isPlaying() then escape:step(now, pursuit, group, onTheLine, standing, rooms) else nil
		if settled then
			round:finish(settled, now)
		end
		if pursuit:shouldLeave(Config.LingerSeconds) then
			pursuit:withdrawTo(Layout.operatorPost())
		end
		if not round:isPlaying() then
			break
		end
	end
	return {
		outcome = round.outcome,
		endedAt = round.endedAt or -1,
		released = escape:isReleased(),
		taken = onTheLine:count(),
		arrivedAt = arrivedAt,
	}
end

local fromPost = race(1000)
check(`(guard) the Operator reached the lobby ({tostring(fromPost.arrivedAt)}s)`, fromPost.arrivedAt ~= nil)
local arriveFromPost = fromPost.arrivedAt or 0
check(
	`(measured) from its post it reaches the lobby {arriveFromPost}s after the ring starts`,
	arriveFromPost > RING and arriveFromPost < RING + 10
)
local fromRoom = race(1000, board)
local arriveFromRoom = fromRoom.arrivedAt or 0
check(`(measured) from the board room it takes longer ({arriveFromRoom}s)`, arriveFromRoom > arriveFromPost)

-- The run it races, for players: the longest walk to the lobby door, from a far
-- corner of the board room through its door and the junction.
local half = Layout.halfRoom()
local boardDoor = Layout.doorPoint(board)
local farCorner = { x = board.x + half, z = board.z + half }
local longestRun = Pursuit.distance(farCorner, boardDoor)
	+ Pursuit.distance(boardDoor, Layout.junction())
	+ Pursuit.distance(Layout.junction(), Layout.doorPoint(exit))
local WALK = 16 -- Roblox's default WalkSpeed, studs per second
local inHand = arriveFromPost - longestRun / WALK
check(
	`(measured) the longest run is {math.floor(longestRun)} studs; running at once leaves {math.floor(inHand * 10) / 10}s in hand`,
	inHand > 5
)
local afterItLeaves = RING + Config.EscapeSeconds - (arriveFromRoom + Config.LingerSeconds)
check(
	`(measured) waiting it out leaves {afterItLeaves}s to make that run before the limit`,
	afterItLeaves > longestRun / WALK
)

local early = race(4)
check(
	`a group already in the lobby is out the moment the call has rung ({early.outcome}, {early.endedAt}s)`,
	early.outcome == "won" and early.endedAt == RING and early.taken == 0
)
local quick = race(RING + 2)
check(
	`a group that runs before it arrives gets out ({quick.outcome}, {quick.taken} taken)`,
	quick.outcome == "won" and quick.released and quick.taken == 0
)
local late = race(math.ceil(arriveFromPost) + 5)
check(
	`a group that walks in while it stands there is taken ({late.outcome}, {late.taken} taken)`,
	late.outcome == "lost" and late.taken == 4
)
local patient = race(math.ceil(arriveFromPost) + Config.LingerSeconds + 8)
check(
	`a group that waits until it has gone gets out ({patient.outcome}, {patient.taken} taken)`,
	patient.outcome == "won" and patient.taken == 0
)
local stranded = race(RING + 2, nil, 4)
check(
	`one player who never comes cannot hold the round open ({stranded.outcome} at {stranded.endedAt}s)`,
	stranded.outcome ~= nil and math.abs(stranded.endedAt - (RING + Config.EscapeSeconds)) < 0.001
)
-- The three who ran waited in the lobby for the fourth and were taken there;
-- taken players are not out, so the limit finds nobody free outside.
check(
	`...and the runners it took in the lobby do not count as out ({stranded.outcome}, {stranded.taken} taken)`,
	stranded.outcome == "lost" and stranded.taken == 3
)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
