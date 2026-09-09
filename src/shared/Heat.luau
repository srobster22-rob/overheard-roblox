--!strict
-- What a coinage's heat MEANS, in one place.
--
-- The Lexicon panel is the instrument players read to decide what is still safe
-- to say. It was drawing a gradient with a breakpoint of 0.5 that reached red
-- only at 1.0, while the Operator actually acts at `Config.ActThreshold` (0.6).
-- Measured against the real `Heuristic`: heat 0.55 does not act, heat 0.60
-- does. So a coinage at 60% was already giving the group away while the panel
-- shaded it mid-amber and implied 40% of headroom remained.
--
-- Two numbers describing one event, restated in two files, disagreeing. This
-- module exists so there is only one, and so the rule can be swept in tests --
-- the same reason `Shared.Keypad` exists.
--
-- The band above the threshold is deliberately NOT a gradient. Above it there
-- is no "partly": the Operator understands and moves. A ramp there would keep
-- implying headroom that does not exist.

local Config = require(script.Parent.Config)

local Heat = {}

export type Band = "safe" | "understood"

-- The one fact the panel has to get right.
function Heat.isUnderstood(heat: number): boolean
	return heat >= Config.ActThreshold
end

function Heat.band(heat: number): Band
	return if Heat.isUnderstood(heat) then "understood" else "safe"
end

-- How far along the SAFE band a coinage is, 0..1. Only meaningful below the
-- threshold; at or above it the answer is always 1, because the safe band is
-- spent. Callers colour the two bands differently rather than lerping across
-- the boundary.
function Heat.safeProgress(heat: number): number
	if Config.ActThreshold <= 0 then
		return 1
	end
	return math.clamp(heat / Config.ActThreshold, 0, 1)
end

return Heat
