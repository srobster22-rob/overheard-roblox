--!strict
-- Where the HUD panels go, as arithmetic.
--
-- Until R34 each panel carried a hand-picked mix of scale and offset and
-- nothing checked the result. Computed against the live values, they collided:
-- five overlapping pairs at 800x480 and at 640x360, six at 480x270 — the
-- Lexicon and Your Line both buried under the centre panels, and on the
-- narrowest screens under each other. Roblox skews heavily mobile, so that is a
-- large share of players reading the Lexicon through a box sitting on top of
-- it, and the Lexicon is the instrument the game asks them to read.
--
-- The rects live here, pure, so `tests/hud.luau` can sweep every viewport
-- instead of somebody opening Studio at one window size and calling it fine.

local Hud = {}

-- The smallest viewport the layout promises to be correct at. Below this the
-- panels are simply too big for the screen and the honest answer is a UIScale,
-- which is a separate piece of work; the tests assert the promise, not a
-- fiction about phones in portrait.
Hud.MinWidth = 640
Hud.MinHeight = 360

Hud.Margin = 16

export type Panel = {
	name: string,
	width: number,
	height: number,
	scaleX: number,
	offsetX: number,
	scaleY: number,
	offsetY: number,
	anchorX: number,
	anchorY: number,
}

export type Rect = { left: number, top: number, right: number, bottom: number }

-- Top row heights drive everything below them, so they are named once.
local LINE_H = 120
local LEX_H = 140
local TOP_BOTTOM = Hud.Margin + math.max(LINE_H, LEX_H)

local PANELS: { Panel } = {
	{
		name = "Lexicon",
		width = 260,
		height = LEX_H,
		scaleX = 1,
		offsetX = -Hud.Margin,
		scaleY = 0,
		offsetY = Hud.Margin,
		anchorX = 1,
		anchorY = 0,
	},
	{
		name = "Your line",
		width = 300,
		height = LINE_H,
		scaleX = 0,
		offsetX = Hud.Margin,
		scaleY = 0,
		offsetY = Hud.Margin,
		anchorX = 0,
		anchorY = 0,
	},
	-- Centre column, pinned to OFFSETS below the top row rather than to a
	-- fraction of the height. A scale-based y is what put these on top of the
	-- top row the moment the window got short.
	{
		name = "On the line",
		width = 300,
		height = 64,
		scaleX = 0.5,
		offsetX = 0,
		scaleY = 0,
		offsetY = TOP_BOTTOM + 12,
		anchorX = 0.5,
		anchorY = 0,
	},
	{
		name = "The board",
		width = 280,
		height = 130,
		scaleX = 0.5,
		offsetX = 0,
		scaleY = 0,
		offsetY = TOP_BOTTOM + 12,
		anchorX = 0.5,
		anchorY = 0,
	},
	-- The Supervisor's clock. Bottom-LEFT rather than the centre column, because
	-- it is the only panel that is true continuously: the centre column is
	-- events (a keypad, a capture, a result) and this is a state you glance at
	-- while doing something else. It is also the panel a player looks at while
	-- typing at a keypad, and the keypad owns the centre.
	{
		name = "Supervisor",
		-- 150, not the 220 this started at. At MinWidth the centre column runs
		-- 180..460, so a bottom-left panel has 164 of gutter and 220 reached
		-- into the keypad. R34's sweep caught it; the number is derived from the
		-- gutter, not chosen.
		width = 150,
		height = 52,
		scaleX = 0,
		offsetX = Hud.Margin,
		scaleY = 1,
		offsetY = -Hud.Margin,
		anchorX = 0,
		anchorY = 1,
	},
	-- Pinned to the BOTTOM, so it cannot walk up into the centre column as the
	-- window shrinks.
	{
		name = "Round over",
		width = 320,
		height = 92,
		scaleX = 0.5,
		offsetX = 0,
		scaleY = 1,
		offsetY = -Hud.Margin,
		anchorX = 0.5,
		anchorY = 1,
	},
}

function Hud.panels(): { Panel }
	return PANELS
end

function Hud.get(name: string): Panel?
	for _, panel in PANELS do
		if panel.name == name then
			return panel
		end
	end
	return nil
end

function Hud.rect(panel: Panel, width: number, height: number): Rect
	local left = panel.scaleX * width + panel.offsetX - panel.anchorX * panel.width
	local top = panel.scaleY * height + panel.offsetY - panel.anchorY * panel.height
	return { left = left, top = top, right = left + panel.width, bottom = top + panel.height }
end

function Hud.overlaps(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

-- Panels that can never be on screen at the same time, and why. The keypad is
-- closed both when you are put on the line and when the round ends, so it
-- shares the centre column with `On the line` deliberately rather than by
-- accident. Anything NOT listed here must never overlap.
local EXCLUSIVE: { { string } } = {
	{ "The board", "On the line" },
	{ "The board", "Round over" },
	-- The Supervisor only runs while the round is being played, so its clock and
	-- the result of the round are never on screen together. Both want the bottom
	-- of the window and at MinWidth the centre panel leaves only 144 there.
	-- This is an exclusion with a reason, not a way around the sweep: the KEYPAD
	-- is not excluded, because seeing your clock while typing is the moment the
	-- panel exists for.
	{ "Round over", "Supervisor" },
}

function Hud.canCoexist(a: string, b: string): boolean
	for _, pair in EXCLUSIVE do
		if (pair[1] == a and pair[2] == b) or (pair[1] == b and pair[2] == a) then
			return false
		end
	end
	return true
end

return Hud
