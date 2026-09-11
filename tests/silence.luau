--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: the winning strategy being to not play.
--
-- The Operator hunts by meaning, so every rule in this game punishes speaking
-- and nothing at all punished not speaking. Measured before the Supervisor
-- existed, four players, 2,400 ticks (600 simulated seconds):
--
--   a group that talks    16 rounds won, 96 captures, the Operator not idle for
--                         2,120 of 2,400 ticks
--   a group that says      20 rounds won,  0 captures, the Operator NEVER LEFT
--   nothing in-game                        ITS POST
--
-- Silence did not merely survive better, it WON MORE, and the monster was never
-- switched on at all. A group on a voice call outside Roblox could pass every
-- answer and play an unopposed fetch quest against a statue.
--
-- No rule-level test could see this, because every rule was right on its own.
-- It is the shape of R46/R47/R48 again: the defect is in what the rules leave
-- out, and only a whole session shows it. `tests/soak.luau` now holds the
-- measurement permanently.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Silence = rt.require(rt.shared.Silence)
local Config = rt.require(rt.shared.Config)
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

print("the rule, tied to the dial rather than to a number")

check(`(guard) there is a speaking deadline ({Config.SpeakEvery}s)`, Config.SpeakEvery > 0)
check("a player who just spoke is clear", Silence.band(0) == "clear")
check("...and under no pressure", Silence.pressure(0) == 0)
check(`at the deadline the call goes through ({Config.SpeakEvery}s)`, Silence.isOverdue(Config.SpeakEvery))
check("a moment before it does not", not Silence.isOverdue(Config.SpeakEvery - 0.01))
check("pressure is exactly full at the deadline", Silence.pressure(Config.SpeakEvery) == 1)
check("and never more than full", Silence.pressure(Config.SpeakEvery * 10) == 1)

-- Heat's lesson, restated: above the threshold there is no "partly". A ramp
-- there implies headroom that does not exist.
check("the band above the deadline is flat, not a gradient", Silence.band(Config.SpeakEvery * 3) == "overdue")

print("")
print("the warning arrives with time to act on it")

check(`(guard) there is a warning point ({Config.SpeakWarning}s)`, Config.SpeakWarning > 0)
check("the warning comes before the deadline", Config.SpeakWarning < Config.SpeakEvery)
check(`at the warning point the band changes ({Config.SpeakWarning}s)`, Silence.band(Config.SpeakWarning) == "warned")
check("just before it, still clear", Silence.band(Config.SpeakWarning - 0.01) == "clear")
check(`the lead is long enough to say something ({Silence.warningLeadSeconds()}s)`, Silence.warningLeadSeconds() >= 10)

-- The bands must be ordered and total: every quiet duration lands in exactly
-- one, and they only ever get worse with time.
local seen: { [string]: boolean } = {}
local worsened = 0
local previous = "clear"
local ranks = { clear = 1, warned = 2, overdue = 3 }
for step = 0, 200 do
	local quiet = (Config.SpeakEvery * 2) * (step / 200)
	local band = Silence.band(quiet)
	seen[band] = true
	if ranks[band] < ranks[previous] then
		worsened += 1
	end
	previous = band
end
check("silence never makes a player SAFER", worsened == 0)
check("(guard) all three bands were reached", seen.clear and seen.warned and seen.overdue)

print("")
print("the Supervisor watches who has not spoken")

local sup = Supervisor.new()
check("a player nobody is watching has no clock", sup:quietFor(1, 100) == nil)
check("...and cannot be called", #sup:overdue(100) == 0)

sup:watch(1, 0)
sup:watch(2, 0)
check("a watched player has a clock", sup:quietFor(1, 0) == 0)
check("that runs with time", sup:quietFor(1, 10) == 10)
check(
	"speaking resets it",
	(function()
		sup:hear(1, 10)
		return sup:quietFor(1, 10) == 0
	end)()
)

-- A player who joins mid-round has not been silent since the round began.
local late = Supervisor.new()
late:watch(9, 500)
check("a player who joins late starts clear, not overdue", not Silence.isOverdue(late:quietFor(9, 500) :: number))
check("(control) ...whereas starting their clock at zero would call them at once", Silence.isOverdue(500))

-- And chat from somebody the round is not watching must not enroll them.
local unwatched = Supervisor.new()
unwatched:hear(77, 5)
check("hearing an unwatched player does not start watching them", unwatched:quietFor(77, 5) == nil)

print("")
print("who gets called, and how often")

local room = Supervisor.new()
for _, userId in { 10, 20, 30 } do
	room:watch(userId, 0)
end
room:hear(10, 2)
room:hear(20, 5)
-- 30 never speaks at all, so its clock still reads from the watch at 0.
local due = room:overdue(Config.SpeakEvery + 6)
check(`everyone past the deadline is called ({#due})`, #due == 3)
check("the longest-quiet player comes first", due[1] == 30)
check("...then the next longest", due[2] == 10)
check("...then the most recent talker", due[3] == 20)

-- Two players equally quiet are ordered by id, so the answer is total rather
-- than left to whichever the loop reached first.
local tied = Supervisor.new()
tied:watch(200, 0)
tied:watch(100, 0)
local both = tied:overdue(Config.SpeakEvery + 1)
check(`(guard) both tied players are due ({#both})`, #both == 2)
check("a tie is broken by id, not by iteration order", both[1] == 100 and both[2] == 200)

-- Ordering must not depend on table iteration, which is not stable.
local same = true
for _ = 1, 20 do
	local again = room:overdue(Config.SpeakEvery + 6)
	for i, userId in due do
		if again[i] ~= userId then
			same = false
		end
	end
end
check("the order is the same every time it is asked", same)

-- Nobody is called before their clock runs out.
check("nobody is due before the deadline", #room:overdue(Config.SpeakEvery - 1) == 0)
check(
	`(guard) ...and they are due just after it ({#room:overdue(Config.SpeakEvery + 0.5)})`,
	#room:overdue(Config.SpeakEvery + 0.5) > 0
)

-- One call per player, not one per tick. R11 and R24 were both this mistake.
local at = Config.SpeakEvery + 6
check(
	"(guard) they are due in the first place",
	(function()
		for _, userId in room:overdue(at) do
			if userId == 30 then
				return true
			end
		end
		return false
	end)()
)
room:called(30, at)
local duringCooldown = 0
for step = 0, 20 do
	local now = at + (Config.SupervisorCooldown - 1) * (step / 20)
	for _, userId in room:overdue(now) do
		if userId == 30 then
			duringCooldown += 1
		end
	end
end
check(
	`a called player is left alone for the whole cooldown ({Config.SupervisorCooldown}s, {duringCooldown} calls)`,
	duringCooldown == 0
)
check(
	"...and they are due again once it passes",
	(function()
		for _, userId in room:overdue(at + Config.SupervisorCooldown + 1) do
			if userId == 30 then
				return true
			end
		end
		return false
	end)()
)

print("")
print("the round boundary")

-- R31: per-round state that crosses the boundary. A player quiet through an
-- eight-second intermission must not be called in the first seconds of play.
local across = Supervisor.new()
across:watch(5, 0)
across:called(5, 10)
check(
	"(guard) they are overdue before the reset",
	Silence.isOverdue(across:quietFor(5, Config.SpeakEvery + 1) :: number)
)
across:reset(Config.SpeakEvery + 1)
check("a new round restarts every clock", across:quietFor(5, Config.SpeakEvery + 1) == 0)
check("...and nobody is due at the start of it", #across:overdue(Config.SpeakEvery + 1) == 0)
check("...and the cooldown does not carry over either", across.lastCalled[5] == nil)

-- Leaving clears the player entirely, both halves.
across:forget(5)
check("a player who leaves is forgotten", across:quietFor(5, 999) == nil)

print("")
print("the clock is legible before it fires, not after")

-- R56. R54 built a monster that takes you on a timer and R55 measured its real
-- dispatches tripling. Nothing on screen said the timer existed: no remote
-- carried it, so the client could not have drawn it if it wanted to, and the
-- one warning went down the OPERATOR's voice channel -- the fourth time in this
-- project two events shared one signal (R10, R13, R51).
--
-- `CLAUDE.md`: the monster must be legible, or the scare reads as unfair.

-- Every band a player can be in has words. Swept from the band function against
-- real durations rather than from a list typed here, so a fourth band added
-- later cannot arrive mute.
local bandsSeen: { [string]: boolean } = {}
for step = 0, 300 do
	bandsSeen[Silence.band((Config.SpeakEvery * 2) * (step / 300))] = true
end
local spoken = 0
for band in bandsSeen do
	spoken += 1
	local note = Silence.note(band :: any)
	check(`'{band}' has words ({note})`, typeof(note) == "string" and #note > 0)
end
check(`(guard) every band was reached ({spoken})`, spoken >= 3)

-- The three must be DIFFERENT, or the panel says the same thing while the
-- player's situation changes -- which is the defect this round is about, moved
-- one layer down.
local texts: { [string]: string } = {}
local collisions = 0
for band in bandsSeen do
	local note = Silence.note(band :: any)
	if texts[note] then
		collisions += 1
	end
	texts[note] = band
end
check(`no two bands read the same ({collisions} collisions)`, collisions == 0)

-- The bar and the words must agree: full pressure is the overdue band, empty is
-- clear. A meter that fills before the rule fires would teach the wrong rule.
check("an empty bar means clear", Silence.band(0) == "clear" and Silence.pressure(0) == 0)
check(
	"a full bar means the call is going through",
	Silence.pressure(Config.SpeakEvery) == 1 and Silence.band(Config.SpeakEvery) == "overdue"
)
local mismatches = 0
for step = 0, 200 do
	local quiet = Config.SpeakEvery * (step / 200)
	if (Silence.pressure(quiet) >= 1) ~= Silence.isOverdue(quiet) then
		mismatches += 1
	end
end
check(`the bar is full exactly when the rule fires ({mismatches} disagreements)`, mismatches == 0)

print("")
print("the bar keeps moving between pushes")

-- R58. R56 pushed the clock on band change -- 4 replications in 600 ticks
-- instead of 1,200, which is the right call -- and drew the bar from the
-- pressure sent at that instant. Measured for one silent player: the bar showed
-- three positions in the whole countdown (0.01 at t=0.2s, 0.67 at t=30s, 1.00 at
-- t=45s) and stood PERFECTLY STILL for 29.5 of the 45 seconds.
--
-- R56's stated purpose was that the rule be "legible before it fires rather than
-- after". A bar that does not move for two-thirds of the wait says nothing about
-- time passing, and the first thing it says is that you are already out of time.
--
-- The gap is filled from what the push carried -- how full, and how long left --
-- which gives the rate without the client knowing a single dial.

check("(guard) a fresh clock has the whole deadline left", Silence.secondsLeft(0) == Config.SpeakEvery)
check("...and none of it once the deadline passes", Silence.secondsLeft(Config.SpeakEvery + 5) == 0)
check("...never negative", Silence.secondsLeft(Config.SpeakEvery * 10) == 0)

-- Nothing has elapsed: the bar is exactly where the push put it.
check("at the moment of the push the bar is what was sent", Silence.fill(0.25, 30, 0) == 0.25)

-- And it arrives at full exactly when the deadline does, not before or after.
check("it reaches full exactly at the deadline", Silence.fill(0, Config.SpeakEvery, Config.SpeakEvery) == 1)
check("...not before", Silence.fill(0, Config.SpeakEvery, Config.SpeakEvery - 1) < 1)
check("...and never past it", Silence.fill(0, Config.SpeakEvery, Config.SpeakEvery * 3) == 1)

-- An overdue push holds at full rather than dividing by a zero deadline.
check("an overdue clock holds at full", Silence.fill(1, 0, 10) == 1)
check("...however long it is left there", Silence.fill(1, 0, 10000) == 1)

-- THE PROPERTY, and the defect stated as a measurement: replay the real push
-- schedule for a silent player and ask how long the bar ever stands still.
local pushes: { { p: number, left: number, at: number } } = {}
do
	local shown: string? = nil
	local now = 0
	for _ = 1, 4 * 60 do
		now += Config.TickSeconds
		local band = Silence.band(now)
		if shown ~= band then
			shown = band
			table.insert(pushes, { p = Silence.pressure(now), left = Silence.secondsLeft(now), at = now })
		end
	end
end
check(`(guard) the real schedule is sparse ({#pushes} pushes in 60s)`, #pushes <= 4)

local function barAt(t: number): number
	local latest = pushes[1]
	for _, push in pushes do
		if push.at <= t then
			latest = push
		end
	end
	return Silence.fill(latest.p, latest.left, t - latest.at)
end

local worstStill, still, previous = 0, 0, -1
local samples = 0
for step = 1, 60 * 10 do
	local t = step / 10
	if t > Config.SpeakEvery then
		break
	end
	samples += 1
	local now = barAt(t)
	if math.abs(now - previous) < 0.0001 then
		still += 0.1
		worstStill = math.max(worstStill, still)
	else
		still = 0
	end
	previous = now
end
check(`(guard) the countdown was sampled ({samples} points)`, samples > 100)
check(`the bar is never still for long ({string.format("%.1f", worstStill)}s)`, worstStill < 1)
-- (control) drawing ONLY what the push carried -- R56's behaviour -- must fail
-- that same measurement, or it is not measuring anything.
local stillR56, wasR56 = 0, -1
local worstR56 = 0
for step = 1, 60 * 10 do
	local t = step / 10
	if t > Config.SpeakEvery then
		break
	end
	local latest = pushes[1]
	for _, push in pushes do
		if push.at <= t then
			latest = push
		end
	end
	if math.abs(latest.p - wasR56) < 0.0001 then
		stillR56 += 0.1
		worstR56 = math.max(worstR56, stillR56)
	else
		stillR56 = 0
	end
	wasR56 = latest.p
end
check(`(control) drawing only the push stands still for {string.format("%.1f", worstR56)}s`, worstR56 > 10)

-- It only ever goes up while a player stays quiet. A bar that dips would read as
-- the player having gained time they did not.
local dips = 0
local last = -1
for step = 0, 400 do
	local t = Config.SpeakEvery * (step / 400)
	local now = barAt(t)
	if now < last - 0.0001 then
		dips += 1
	end
	last = now
end
check(`the bar never goes backwards while you stay quiet ({dips} dips)`, dips == 0)

print("")
print("a player the Supervisor is not watching has no clock (R99)")
do
	local sup2 = Supervisor.new()
	sup2:watch(1, 0)
	check("an unwatched player has no band", sup2:band(99, 10) == nil)
	check("(control) a watched player has one", sup2:band(1, 10) ~= nil)
end

print("")
print("the bar at the deadline (R102 mutation sweep)")
local atDeadline = Silence.fill(0.5, 0, 0)
check(`with no seconds left the bar is full, not NaN ({atDeadline})`, atDeadline == 1)
check("past the deadline it is full too", Silence.fill(0.2, -3, 1) == 1)

print("")
print("putting through a silent line, RUN rather than grepped (R110)")

do
	local Pursuit = rt.require(rt.systems.Pursuit)
	local Layout = rt.require(rt.shared.Layout)
	local rooms = { board = Layout.boardCentre(), archive = Layout.archiveCentre() }
	local order = { "board", "archive" }
	local late = Config.SpeakEvery + 1
	local function fresh()
		local s = Supervisor.new()
		s:watch(1, 0)
		s:watch(2, 1)
		return s, Pursuit.new(rooms, Layout.operatorPost())
	end
	local function isOverdue(s, id): boolean
		return table.find(s:overdue(late), id) ~= nil
	end
	local inBoard = { x = rooms.board.x, z = rooms.board.z }

	local s, p = fresh()
	local who, news = s:putThrough(p, rooms, order, { [1] = inBoard }, late)
	check("an idle Operator is sent to the silent player's room", who == 1 and p.targetName == "board")
	check("...and that is announced", news == true)
	check("...and the player is forgiven", not isOverdue(s, 1))

	s, p = fresh()
	p:sendTo("board")
	who, news = s:putThrough(p, rooms, order, { [1] = inBoard }, late)
	check("a trip already coming here answers the silence", who == 1 and not isOverdue(s, 1))
	check("...but is not announced again", news == false)

	s, p = fresh()
	p:sendTo("archive")
	check("(guard) the Operator is committed elsewhere", p.state == "approaching")
	who, news = s:putThrough(p, rooms, order, { [1] = inBoard }, late)
	check("a call that only queues calls nobody", who == nil and news == false)
	check("...forgives nobody", isOverdue(s, 1))
	check("...and leaves the room waiting in pending", p.pending == "board")

	s, p = fresh()
	who = s:putThrough(p, rooms, order, { [1] = Layout.spawn(), [2] = inBoard }, late)
	check("a silent player in the corridor is passed over for the next", who == 2 and isOverdue(s, 1))

	s, p = fresh()
	who = s:putThrough(p, rooms, order, { [2] = inBoard }, late)
	check("a player with no body is skipped, not forgiven", who == 2 and isOverdue(s, 1))
end

print("")
print("each panel is told once per change, and again after a reset (R115)")
do
	local s = Supervisor.new()
	s:watch(1, 0)
	local first = s:bandNews(1, 1)
	check("the first band is news", first == "clear")
	check("the same band a tick later is not", s:bandNews(1, 1.25) == nil)
	local warned, quiet = s:bandNews(1, Config.SpeakWarning + 1)
	check("a change of band is news", warned == "warned" and quiet > Config.SpeakWarning)
	-- The case that matters: the band after the reset EQUALS the last one told.
	local r = Supervisor.new()
	r:watch(1, 0)
	check("(guard) told 'clear' once", r:bandNews(1, 1) == "clear" and r:bandNews(1, 2) == nil)
	r:reset(100)
	check("after a reset the SAME band as before is news again", r:bandNews(1, 101) == "clear")
	s:forget(1)
	check("a forgotten player is told nothing", s:bandNews(1, 102) == nil)
	s:watch(1, 103)
	check("...and is told afresh when watched again", s:bandNews(1, 104) == "clear")
end

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
