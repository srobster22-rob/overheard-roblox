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

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
