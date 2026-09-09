--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: UI that is correct at the one window size
-- somebody happened to look at.
--
-- Every HUD panel carried a hand-picked mix of scale and offset and nothing
-- checked the result. Computed from the live values before R34: five
-- overlapping pairs at 800x480 and 640x360, six at 480x270 — the Lexicon and
-- Your Line buried under the centre panels, and on the narrowest screens under
-- each other. Roblox skews mobile, and the Lexicon is the instrument the game
-- asks players to read.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Hud = rt.require(rt.shared.Hud)

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

-- Real shapes, from phones in landscape up to desktop.
local VIEWPORTS = {
	{ 640, 360 },
	{ 800, 480 },
	{ 854, 480 },
	{ 960, 540 },
	{ 1024, 576 },
	{ 1024, 768 },
	{ 1280, 720 },
	{ 1366, 768 },
	{ 1600, 900 },
	{ 1920, 1080 },
}

local panels = Hud.panels()
check(`(guard) there are panels to place ({#panels})`, #panels >= 5)
check(
	`(guard) the supported minimum is stated ({Hud.MinWidth}x{Hud.MinHeight})`,
	Hud.MinWidth > 0 and Hud.MinHeight > 0
)

print("every panel stays on screen")
local offScreen = 0
for _, size in VIEWPORTS do
	local w, h = size[1], size[2]
	for _, panel in panels do
		local r = Hud.rect(panel, w, h)
		if r.left < 0 or r.top < 0 or r.right > w or r.bottom > h then
			offScreen += 1
			print(`    {panel.name} at {w}x{h}: ({r.left},{r.top})-({r.right},{r.bottom})`)
		end
	end
end
check(`no panel leaves the screen at any supported size ({offScreen} off)`, offScreen == 0)

print("")
print("no two panels that can coexist overlap")
local collisions = 0
for _, size in VIEWPORTS do
	local w, h = size[1], size[2]
	for i = 1, #panels do
		for j = i + 1, #panels do
			local a, b = panels[i], panels[j]
			if not Hud.canCoexist(a.name, b.name) then
				continue
			end
			if Hud.overlaps(Hud.rect(a, w, h), Hud.rect(b, w, h)) then
				collisions += 1
				print(`    {w}x{h}: {a.name} / {b.name}`)
			end
		end
	end
end
check(`nothing collides at any supported size ({collisions} collisions)`, collisions == 0)

print("")
print("the exclusions are real, not a way to silence the sweep")
-- Every excluded pair must ACTUALLY overlap somewhere, or it is an exemption
-- hiding a panel that simply has nowhere to be.
check("the keypad and the on-line banner share the centre column", Hud.canCoexist("The board", "On the line") == false)
local boardPanel = Hud.get("The board")
local onLine = Hud.get("On the line")
check("(guard) both panels exist", boardPanel ~= nil and onLine ~= nil)
if boardPanel and onLine then
	check(
		"...and they really do occupy the same space, so the exclusion earns itself",
		Hud.overlaps(Hud.rect(boardPanel, 1280, 720), Hud.rect(onLine, 1280, 720))
	)
end
check("anything not excluded is required to be disjoint", Hud.canCoexist("Lexicon", "Your line") == true)
check("...in both directions", Hud.canCoexist("On the line", "The board") == false)

print("")
print("the centre column is pinned to offsets, not to a fraction of the height")
-- A scale-based y is what walked these panels up into the top row as the window
-- got shorter. Same offset from the top at every height is the property.
for _, name in { "On the line", "The board" } do
	local panel = Hud.get(name)
	check(`(guard) '{name}' exists`, panel ~= nil)
	if panel then
		local short = Hud.rect(panel, 1280, 360)
		local tall = Hud.rect(panel, 1280, 1080)
		check(`'{name}' sits at the same distance from the top on any screen`, short.top == tall.top)
	end
end

-- And the one that is pinned to the bottom must MOVE with the bottom.
local over = Hud.get("Round over")
check("(guard) 'Round over' exists", over ~= nil)
if over then
	local short = Hud.rect(over, 1280, 360)
	local tall = Hud.rect(over, 1280, 1080)
	check("'Round over' stays with the bottom edge", tall.bottom - short.bottom == 1080 - 360)
	check("...and is inset by the margin", 360 - short.bottom == Hud.Margin)
end

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
