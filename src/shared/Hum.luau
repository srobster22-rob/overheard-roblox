--!strict
-- What the Operator SOUNDS like, per state.
--
-- `isAudible()` is true for two opposite events, `approaching` and `leaving`.
-- One hum at one volume whenever it is true makes the sound of it coming and
-- the sound of it going identical, and a player who hears the hum knows only
-- that it is moving. The retreat exists so a group can hear the room being
-- given up: GAME.md's tell is "you hear it come and you hear it go", and both
-- halves must sound different to be heard.
--
-- Pitch carries the difference rather than volume, because volume is already
-- spoken for -- distance rolloff uses it, so a quieter retreat would be
-- indistinguishable from a further-away approach. A falling tone is the ordinary
-- way a thing sounds when it is leaving.

local Hum = {}

export type Voice = {
	volume: number,
	pitch: number,
}

Hum.LOUD = 0.35
Hum.SILENT = 0

-- Coming for you.
Hum.APPROACH_PITCH = 1
-- Done with you. Low enough to be a different sound, not a detuned version of
-- the same one.
Hum.LEAVE_PITCH = 0.72

function Hum.forState(state: string): Voice
	if state == "approaching" then
		return { volume = Hum.LOUD, pitch = Hum.APPROACH_PITCH }
	elseif state == "leaving" then
		return { volume = Hum.LOUD, pitch = Hum.LEAVE_PITCH }
	end
	-- `closing`, `arrived` and `idle` are the silence the whole game hangs on.
	return { volume = Hum.SILENT, pitch = Hum.APPROACH_PITCH }
end

-- The fade rate, per second. A snap to the target volume "reads as a bug
-- instead of a decision" (see `Presence.luau`), so the smoothing has to be a
-- REAL fade, and this is the only place that can be tested headlessly:
-- `Presence.luau` calls `game:GetService` and `RunService.Heartbeat`, so no
-- lune suite can exercise it directly, and a source sweep confirming it
-- requires this module cannot tell a real fade (`Hum.smooth`) from a snap
-- (`hum.Volume = voice.volume`).
Hum.FADE_PER_SECOND = 3

-- One step of the fade, pulled out of `Presence.luau` so it can be proved here
-- instead of only in Studio. `current` moves toward `target` by at most the
-- whole gap in one frame (`math.min(dt * rate, 1)`), so a long frame cannot
-- overshoot.
function Hum.smooth(current: number, target: number, dt: number): number
	return current + (target - current) * math.min(dt * Hum.FADE_PER_SECOND, 1)
end

-- Can a listener tell these two apart by ear alone?
function Hum.distinguishable(a: Voice, b: Voice): boolean
	if a.volume ~= b.volume then
		return true
	end
	return math.abs(a.pitch - b.pitch) >= 0.1
end

return Hum
