--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: the panel a player reads disagreeing with
-- the rule the server enforces.
--
-- The Lexicon panel is the instrument players use to decide what is still safe
-- to say. Its colour ramp restated a breakpoint of 0.5 and reached red only at
-- 1.0, while the Operator acts at `Config.ActThreshold` (0.6). Measured against
-- the real `Heuristic`: heat 0.55 does not act, heat 0.60 does. So a coinage
-- that was already giving the group away was drawn mid-amber, implying 40% of
-- headroom that did not exist.
--
-- The checks below tie the two together at the CONSTANT, not at the number, so
-- moving `ActThreshold` moves the panel with it.

local fs = require("@lune/fs")

local Harness = require("./harness")
local LuauCode = require("./luaucode")

local rt = Harness.build()
local Heat = rt.require(rt.shared.Heat)
local Config = rt.require(rt.shared.Config)
local Heuristic = rt.require(rt.systems.Heuristic)

local Kit = require("./kit")
local check = Kit.check

print("the boundary is the threshold itself")
local T = Config.ActThreshold
check(`(guard) ActThreshold is a usable fraction ({T})`, T > 0 and T < 1)
check("exactly at the threshold is understood", Heat.isUnderstood(T) == true)
check("a hair below is not", Heat.isUnderstood(T - 0.0001) == false)
check("a hair above is", Heat.isUnderstood(T + 0.0001) == true)
check("zero heat is safe", Heat.isUnderstood(0) == false)
check("full heat is understood", Heat.isUnderstood(1) == true)
check("band names agree with isUnderstood", Heat.band(T) == "understood" and Heat.band(0) == "safe")

print("")
print("the panel's boundary is the SERVER's boundary")
-- The claim that matters: wherever the module says "understood", the real
-- comprehension backend actually acts -- and wherever it says "safe", it does
-- not. Swept, so a single lucky sample cannot carry it.
local secrets = { { concept = "exit", plain = { "exit" }, payload = "archive" } }
local speaker = { UserId = 1 } :: any
local disagreements = 0
local actedAtLeastOnce = false
local safeAtLeastOnce = false
for step = 0, 20 do
	local heat = step / 20
	local coinage = { phrase = "blue one", concept = "exit", heat = heat, sightings = 4 }
	local seen = Heuristic.understand({ speaker = speaker, text = "the blue one", at = 1 }, secrets, { coinage })
	local serverActs = seen.concept ~= nil and seen.confidence >= Config.ActThreshold
	if serverActs then
		actedAtLeastOnce = true
	else
		safeAtLeastOnce = true
	end
	if serverActs ~= Heat.isUnderstood(heat) then
		disagreements += 1
		print(
			`    heat {string.format("%.2f", heat)}: server acts={serverActs}, panel says understood={Heat.isUnderstood(
				heat
			)}`
		)
	end
end
-- Both guards, or a sweep that never acted (or always acted) would pass empty.
check("(guard) the sweep saw the server act", actedAtLeastOnce)
check("(guard) the sweep saw the server stay silent", safeAtLeastOnce)
check(`the panel and the server never disagree ({disagreements} disagreements)`, disagreements == 0)

print("")
print("safeProgress spends exactly the safe band")
check("zero heat is the start of the band", Heat.safeProgress(0) == 0)
check("the threshold is the end of it", Heat.safeProgress(T) == 1)
check("it does not run past the end", Heat.safeProgress(1) == 1)
check("halfway to the threshold is halfway along", math.abs(Heat.safeProgress(T / 2) - 0.5) < 0.0001)
check("negative heat clamps", Heat.safeProgress(-1) == 0)

print("")
print("the client uses the module, and restates no breakpoint of its own")
local clientCode = LuauCode.stripNonCode(fs.readFile("src/client/init.client.luau"))
check(
	"the client requires Shared.Heat",
	string.find(clientCode, "require(ReplicatedStorage.Shared.Heat)", 1, true) ~= nil
)
-- The defect, stated as a rule: the ramp must not carry its own number. Read
-- from stripped code so a comment mentioning 0.5 cannot fail this.
local NL = string.char(10)
local ramp = string.match(clientCode, "local function heatColor%(.-" .. NL .. "end") or ""
check("(guard) found heatColor in live code", #ramp > 0)

-- Scoped to the RAMP BODY, not the whole client. Written against the file it
-- passed while the ramp was reverted to the hard-coded 0.5, because
-- `Heat.isUnderstood` is also used by the row text further down -- a check that
-- cannot fail on the thing it names is worse than no check.
check("heatColor itself asks the module", string.find(ramp, "Heat.isUnderstood", 1, true) ~= nil)
check("heatColor contains no hard-coded 0.5 breakpoint", string.find(ramp, "0.5", 1, true) == nil)
check("heatColor does not restate the threshold value either", string.find(ramp, tostring(T), 1, true) == nil)

Kit.finish()
