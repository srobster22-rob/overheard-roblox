--!strict
-- Play OVERHEARD from a session file: every line is one thing a player does,
-- replayed on tools/sim.luau (the real server modules, on a stepped clock).
-- Run from the project root:
--     lune run tools/play <session file>
-- Replay is deterministic, so a session is played by adding lines to the file
-- and running it again. This is how a playtester who is not a script plays:
-- it reads what each player sees, then writes what they say and do next.
--
-- The session language, one command per line:
--     seed 7                      the first line only; which game is dealt
--     Ana: meet me at the thing   a chat message (heard only while a round is live)
--     Ana goes to lobby           walk to a room: board, archive or lobby; the
--                                 clock runs for the walk (about 7 s)
--     Bo enters board 47          enter a code at a station in the room you
--                                 stand in: board, breaker or latch
--     wait 5                      let 5 seconds pass
--     look                        print everyone's screen at this point
--     next round                  the intermission, then the next round
--     # anything                  a comment
-- The players are Ana, Bo, Cy and Dee. Everything a player could see is
-- printed: the event trace, and at `look` and at the end each player's screen
-- (their panel, whether they are on the line, their silence clock, the hum)
-- plus the Lexicon panel everyone shares.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Sim = require("./sim")

local path = process.args[1]
if path == nil then
	print("usage: lune run tools/play <session file>   (the session language is at the top of tools/play.luau)")
	process.exit(2)
end

local ID: { [string]: number } = {}
for id, name in Sim.NAMES do
	ID[string.lower(name)] = id
end

local lines: { string } = {}
for raw in string.gmatch(string.gsub(fs.readFile(path :: string), "\r\n", "\n") .. "\n", "(.-)\n") do
	table.insert(lines, raw)
end

local seed = 7
local first = 1
while first <= #lines and (string.match(lines[first], "^%s*$") or string.match(lines[first], "^%s*#")) do
	first += 1
end
local seedLine = lines[first] and string.match(lines[first], "^%s*seed%s+(%d+)%s*$")
if seedLine then
	seed = tonumber(seedLine) :: number
	first += 1
end

local sim = Sim.new(seed)
sim:begin()

local function look()
	print("")
	for id = 1, #Sim.NAMES do
		for _, text in sim:view(id) do
			print(text)
		end
	end
	local lexicon = sim:lexicon()
	print(`Lexicon panel: {if #lexicon > 0 then table.concat(lexicon, " | ") else "(empty)"}`)
	print("")
end

local function fail(number: number, text: string, why: string)
	print(`line {number}: "{text}": {why}`)
	process.exit(1)
end

for number = first, #lines do
	local text = lines[number]
	local trimmed = string.match(text, "^%s*(.-)%s*$") :: string
	if trimmed == "" or string.sub(trimmed, 1, 1) == "#" then
		continue
	end
	local who, said = string.match(trimmed, "^(%a+):%s*(.+)$")
	local mover, room = string.match(trimmed, "^(%a+) goes to (%a+)$")
	local enterer, station, code = string.match(trimmed, "^(%a+) enters (%a+) (%S+)$")
	local seconds = string.match(trimmed, "^wait%s+([%d%.]+)$")
	if who then
		local id = ID[string.lower(who)] or fail(number, text, "no such player")
		sim:say(id, said)
	elseif mover then
		local id = ID[string.lower(mover)] or fail(number, text, "no such player")
		if sim.rooms[room] == nil then
			fail(number, text, "the rooms are board, archive and lobby")
		end
		local from = sim.roomOf[id]
		sim:trace(`   {Sim.NAMES[id]} walks from the {from} room to the {room} room`)
		sim:tick(sim:walkSeconds(from, room))
		if sim.line:isConnected(id) then
			sim:trace(`   {Sim.NAMES[id]} is on the line and cannot walk`)
		else
			sim:move(id, room)
		end
	elseif enterer then
		local id = ID[string.lower(enterer)] or fail(number, text, "no such player")
		if sim.line:isConnected(id) then
			sim:trace(`   {Sim.NAMES[id]} is on the line and cannot use a keypad`)
		else
			local result = sim:submit(id, station, code)
			if not result.ok then
				sim:trace(`   {Sim.NAMES[id]}'s code at the {station} is refused: {tostring(result.reason)}`)
			end
		end
	elseif seconds then
		sim:tick(tonumber(seconds) :: number)
	elseif trimmed == "look" then
		look()
	elseif trimmed == "next round" then
		sim:nextRound()
		sim:trace(`===== ROUND {sim.round.number} =====`)
	else
		fail(number, text, "not a command (see the top of tools/play.luau)")
	end
end

look()
