--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: one sound standing for two opposite
-- events.
--
-- `Presence` played a single hum at a single volume whenever `isAudible()` was
-- true, and `isAudible()` is true for `approaching` AND for `leaving`. So the
-- Operator coming for you and the Operator giving up sounded exactly the same,
-- and hearing the hum told a player only that it was moving.
--
-- R26 built the retreat so a group could hear the room being given up, and said
-- in its own entry that whether it READ as retreating was the claim it could not
-- make. It read as nothing. GAME.md's tell is "you hear it come and you hear it
-- go"; half of it was not delivered.
--
-- This is R50's lesson in its purest form: a boolean answering "is it making
-- noise" cannot distinguish two events that both make noise.

local Harness = require("./harness")

local rt = Harness.build()
local Hum = rt.require(rt.shared.Hum)
local Pursuit = rt.require(rt.systems.Pursuit)
local Layout = rt.require(rt.shared.Layout)

local Kit = require("./kit")
local check = Kit.check

print("coming and going are different sounds")
local approaching = Hum.forState("approaching")
local leaving = Hum.forState("leaving")
check("approaching is audible", approaching.volume > 0)
check("leaving is audible", leaving.volume > 0)
check("...and they are told apart by ear", Hum.distinguishable(approaching, leaving))

-- Pitch carries it, not volume: volume is already spoken for by distance
-- rolloff, so a quieter retreat is indistinguishable from a further-away
-- approach.
check("both are the same loudness", approaching.volume == leaving.volume)
check(`the retreat is pitched differently ({approaching.pitch} vs {leaving.pitch})`, approaching.pitch ~= leaving.pitch)
check("...and by enough to hear, not a detune", math.abs(approaching.pitch - leaving.pitch) >= 0.1)
check("the retreat is the LOWER of the two", leaving.pitch < approaching.pitch)

print("")
print("silence is still silence")
for _, state in { "idle", "closing", "arrived" } do
	local voice = Hum.forState(state)
	check(`'{state}' makes no sound at all`, voice.volume == 0)
end

-- The silence between them is the scare, so it must not be merely quieter.
check("silence is zero, not a low volume", Hum.forState("closing").volume == Hum.SILENT)
check("(guard) and audible is meaningfully above it", Hum.LOUD > Hum.SILENT)

print("")
print("every state Pursuit can be in has a voice")
-- Swept against the real tracker rather than a list typed here, so a sixth state
-- added later cannot arrive without a sound.
local seen: { [string]: boolean } = {}
local rooms = { board = Layout.boardCentre(), archive = Layout.archiveCentre() }
local tracker = Pursuit.new(rooms, Layout.operatorPost())
seen[tracker.state] = true
tracker:sendTo("board")
for _ = 1, 400 do
	tracker:step(0.25)
	seen[tracker.state] = true
	if tracker.state == "arrived" then
		break
	end
end
tracker:withdrawTo(Layout.operatorPost())
for _ = 1, 400 do
	tracker:step(0.25)
	seen[tracker.state] = true
	if tracker.state == "idle" then
		break
	end
end

local states = 0
for state in seen do
	states += 1
	local voice = Hum.forState(state)
	check(`'{state}' has a volume and a pitch`, voice.volume >= 0 and voice.pitch > 0)
end
check(`(guard) a whole cycle was walked ({states} states)`, states >= 4)

-- And the two that make noise are exactly the two that should.
local noisy = 0
for state in seen do
	if Hum.forState(state).volume > 0 then
		noisy += 1
	end
end
check(`exactly two states make a sound ({noisy})`, noisy == 2)
check("approaching is one of them", Hum.forState("approaching").volume > 0)
check("leaving is the other", Hum.forState("leaving").volume > 0)

print("")
print("the fade is a real fade, not a snap")

-- R65. A mutation sweep replaced Presence's smoothing with a snap
-- (`hum.Volume = voice.volume`) and NOTHING in the whole suite noticed --
-- because `Presence.luau` cannot be run headlessly (`game:GetService`,
-- `RunService.Heartbeat`), and the only guard on it was a source sweep that
-- cannot tell a fade from a snap. The math is pulled out into `Hum.smooth` so
-- it can be proved here.

check("(guard) there is a fade rate", Hum.FADE_PER_SECOND > 0)

-- One small step must not jump all the way to the target.
local afterOneFrame = Hum.smooth(0, 1, 1 / 60)
check(`a single frame does not snap to the target ({afterOneFrame})`, afterOneFrame > 0 and afterOneFrame < 1)

-- Repeated small steps must converge, monotonically, toward the target.
local level = 0
local steps = 0
local wentBackwards = 0
for _ = 1, 600 do
	local next_ = Hum.smooth(level, 1, 1 / 60)
	if next_ < level - 0.0001 then
		wentBackwards += 1
	end
	level = next_
	steps += 1
	if level > 0.999 then
		break
	end
end
check(`(guard) it actually took more than one frame to arrive ({steps})`, steps > 1)
check("it never moves away from the target", wentBackwards == 0)
check(`it eventually reaches the target ({level})`, level > 0.999)

-- A very long frame (a hitch) must still land AT the target, not overshoot past
-- it into a negative or a volume louder than the target ever asked for.
check("a long frame lands exactly at the target, not past it", Hum.smooth(0, 1, 10) == 1)
check("...symmetrically, fading down", Hum.smooth(1, 0, 10) == 0)

-- (control) the snap itself must fail the "takes more than one frame" guard,
-- or this whole check is not measuring the thing it claims to.
local snapSteps = 0
local snapLevel = 0
for _ = 1, 600 do
	snapLevel = 1 -- what `hum.Volume = voice.volume` does every frame
	snapSteps += 1
	if snapLevel > 0.999 then
		break
	end
end
check("(control) a snap arrives in exactly one step", snapSteps == 1)

print("")
print("what the ear can tell apart (R102 mutation sweep)")
check(
	"a louder hum at the same pitch is distinguishable",
	Hum.distinguishable({ volume = 0.2, pitch = 1 } :: any, { volume = 0.6, pitch = 1 } :: any)
)
check(
	"(control) the same volume with a hair of pitch is not",
	not Hum.distinguishable({ volume = 0.2, pitch = 1 } :: any, { volume = 0.2, pitch = 1.05 } :: any)
)

Kit.finish()
