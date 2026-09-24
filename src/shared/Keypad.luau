--!strict
-- Who is allowed to write on the keypad.
--
-- THE BUG THIS MODULE EXISTS TO PREVENT. The keypad has one red line under the
-- input. `Heard` is the Operator's VOICE and is broadcast to everyone: the
-- server sends it with a non-empty detail whenever it understands somebody
-- (detail = the concept id), whenever a coinage burns (detail = the concept id)
-- and whenever the Operator arrives somewhere (detail = the room name). If
-- `Heard` wrote to the keypad, a player standing there would see `jack_number`
-- in red, in the slot that otherwise says "that line is jammed - wait 20s",
-- because a DIFFERENT player had spoken.
--
-- That is invisible with one player: you cannot be typing at a keypad and be
-- the one talking. With two it is the main path, because the entire loop of
-- this game is one player talking while another stands at the keypad.
--
-- So the two channels are separate remotes, and the rule about which
-- messages may touch the keypad lives HERE, as a pure function, rather than in
-- an `if` inside the client where nothing headless can reach it:
--
--   `Heard`    - the Operator's voice. Broadcast. NEVER touches the keypad.
--   `Rejected` - why YOUR submit at THAT station failed. FireClient only.
--
-- Being private is not sufficient on its own, which is the second half of this:
-- a rejection is addressed to a player but not to a keypad, and there are
-- several stations. Submit at the breaker, walk away, open the switchboard, and the
-- breaker's refusal paints the switchboard's status line. So a rejection also
-- has to name its station and be dropped if the player is no longer looking at
-- that one.

local Keypad = {}

-- May this rejection be shown on the keypad the player currently has open?
--
-- `openStation` is what the client has on screen (nil when no keypad is open);
-- `messageStation` is the station the server's rejection was about. Both must
-- be present and they must agree. A rejection for a station the player has
-- since walked away from is dropped rather than shown, because a stale error
-- on the wrong keypad reads as the game lying about which line is jammed.
function Keypad.accepts(openStation: string?, messageStation: string?): boolean
	if openStation == nil or messageStation == nil then
		return false
	end
	return openStation == messageStation
end

-- The longest code a keypad takes, and the longest station id a client may
-- name. The answer is two digits; 8 leaves room for dashes and spaces.
Keypad.MAX_VALUE = 8
Keypad.MAX_ID = 32

-- Is a Submit payload even worth looking at? Never trust the client: both must
-- be strings, and both bounded. The id needs its cap as much as the value:
-- the server echoes it straight back through FireClient and uses it as a
-- lookup key, so without one a client could send an id of any length. Kept
-- here rather than in init.server, where the suite could only grep it.
function Keypad.validSubmission(id: any, value: any): boolean
	if typeof(id) ~= "string" or typeof(value) ~= "string" then
		return false
	end
	return #id > 0 and #id <= Keypad.MAX_ID and #value <= Keypad.MAX_VALUE
end

-- Does this push of the board close the keypad in front of the player? Only if
-- THAT station was just solved -- with several stations, solving another must
-- not shut the keypad somebody is typing into. Kept here rather than in
-- init.client, where no test could run it.
function Keypad.closesOn(openStation: string?, entries: { any }): boolean
	if openStation == nil then
		return false
	end
	for _, entry in entries do
		if entry.id == openStation and entry.solved then
			return true
		end
	end
	return false
end

-- Is what the player pressed Enter on worth sending? Not an empty box, and not
-- with no keypad open. (Anything else is the server's to judge: see
-- `validSubmission`, which never trusts the client.)
function Keypad.sends(value: string, openStation: string?): boolean
	return #value > 0 and openStation ~= nil
end

return Keypad
