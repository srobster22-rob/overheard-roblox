--!strict
-- Every handler, loop and callback runs under Guard. Run: lune run tests/guard
--
-- What this file guards:
--   - `run` returns a function's results, and on an error keeps it (tag,
--     message, a traceback naming the line that threw) instead of throwing.
--   - `wrap` passes arguments and results through, nils included, and a
--     wrapped failure returns nothing.
--   - Only the newest `Guard.KEPT` failures are kept.
--   - The headless sim runs its callbacks and each beat under the guard and
--     reports what it caught, so a bot or session run fails on it.

local Harness = require("./harness")
local Kit = require("./kit")
local check = Kit.check

local rt = Harness.build()
local Guard = rt.require(rt.shared.Guard)

print("a guarded function runs as it would unguarded")
Guard.clear()
local ok, sum, product = Guard.run("test.arithmetic", function(x: number, y: number)
	return x + y, x * y
end, 3, 4)
check("run returns true and every result", ok == true and sum == 7 and product == 12)
check("...and keeps nothing", #Guard.failures() == 0)
local echo = Guard.wrap("test.echo", function(...: any)
	return ...
end)
local first, second, third = echo("one", nil, 3)
check(
	"wrap passes arguments and results through, a nil in the middle too",
	first == "one" and second == nil and third == 3
)

print("")
print("an error is caught, kept and named")
local throwLine = 0
local function throws()
	local nothing: any = nil
	throwLine = (debug.info(1, "l") :: number) + 1
	return nothing.field
end
check("run returns false instead of throwing", Guard.run("test.throws", throws) == false)
local kept = Guard.failures()
check("the failure is kept", #kept == 1)
local failure = kept[1]
check("...with its tag", failure ~= nil and failure.tag == "test.throws")
check("...the error's message", failure ~= nil and string.find(failure.message, "attempt to index nil", 1, true) ~= nil)
check(
	`...and a traceback naming the line that threw (guard:{throwLine})`,
	failure ~= nil and string.find(failure.traceback, `guard:{throwLine}`, 1, true) ~= nil
)
check("a wrapped failure returns nothing", Guard.wrap("test.wrapped", throws)() == nil)
check("...and is kept under its own tag", Guard.failures()[2].tag == "test.wrapped")

Guard.clear()
for i = 1, Guard.KEPT + 5 do
	Guard.run(`test.flood{i}`, throws)
end
local flood = Guard.failures()
check(
	`only the newest {Guard.KEPT} failures are kept`,
	#flood == Guard.KEPT and flood[1].tag == "test.flood6" and flood[#flood].tag == `test.flood{Guard.KEPT + 5}`
)
Guard.clear()
check("clear empties it", #Guard.failures() == 0)

print("")
print("the headless sim guards its callbacks and beats, and reports them")
local Sim = require("../tools/sim")
local sim = Sim.new(11)
sim:begin()
-- A code said aloud reaches `onCodeHeard`, which rerolls it on the board.
sim.board.reroll = function()
	error("planted: the board cannot reroll")
end
local concept, code = next(sim.board:liveCodes())
check("(guard) the board has a live code to say", concept ~= nil)
-- pcall, so an unguarded callback fails this check by name instead of
-- stopping the file.
local said = pcall(function()
	sim:say(1, `its {code}`)
end)
local caught = Sim.Guard.failures()
check("a callback that throws is caught, not fatal", said and #caught == 1)
check("...under the sim's tag for it", caught[1] ~= nil and caught[1].tag == "sim.onCodeHeard")
sim.pursuit.step = function()
	error("planted: the Operator cannot walk")
end
local ticked = pcall(function()
	sim:tick(Sim.Config.TickSeconds)
end)
caught = Sim.Guard.failures()
check("a beat that throws is caught under the beat's tag", ticked and caught[2] ~= nil and caught[2].tag == "sim.beat")
check("reportFailures says a run caught something", Sim.reportFailures() == true)

Kit.finish()
