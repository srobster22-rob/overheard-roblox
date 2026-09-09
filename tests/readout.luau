--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: a panel that is right with one item and
-- wrong with two.
--
-- `renderObjectives` ordered its rows with `LayoutOrder = i` for a held line and
-- `i + 100` for that line's note. With one held line that reads correctly, which
-- is why it survived: every screenshot of this panel had one line on it. With
-- two, it becomes both prompts followed by both notes, and "only you can see
-- this" — a claim about a SPECIFIC line — sits under a different one.
--
-- Two held lines happen in ordinary multiplayer: two players hold one each, one
-- leaves, `redealOrphans` gives the orphan to the survivor.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Readout = rt.require(rt.shared.Readout)
local Objectives = rt.require(rt.systems.Objectives)

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

local function kinds(rows: { Readout.Row }): string
	local out = {}
	for _, row in rows do
		table.insert(out, row.kind)
	end
	return table.concat(out, ",")
end

print("one held line")
local one = Readout.lineRows({
	{ id = "board", solved = false, holding = true, prompt = "jack %s", answer = "47" },
	{ id = "breaker", solved = false, holding = false },
})
check(`(guard) rows were produced ({kinds(one)})`, #one >= 3)
check("the line is rendered from the prompt and the answer", one[1].text == "jack 47")
check("its note follows it immediately", one[2].kind == "note" and one[2].text == Readout.PRIVATE_NOTE)
check("the count is last", one[#one].kind == "count")
check("...and counts every objective, not just yours", one[#one].text == "restored 0/2")

print("")
print("TWO held lines - the defect")
local two = Readout.lineRows({
	{ id = "board", solved = false, holding = true, prompt = "jack %s", answer = "47" },
	{ id = "breaker", solved = false, holding = true, prompt = "breaker %s", answer = "12" },
})
check(`(guard) both lines are held ({kinds(two)})`, #two == 5)
check("every note sits directly under its own line", kinds(two) == "line,note,line,note,count")
check("the first line is first", two[1].text == "jack 47")
check("its note is second", two[2].kind == "note")
check("the second line is third", two[3].text == "breaker 12")
check("its note is fourth", two[4].kind == "note")

-- The property, stated so a future reordering cannot pass by luck: a note must
-- never be preceded by anything but the line it describes.
local misplaced = 0
for index, row in two do
	if row.kind == "note" and (index == 1 or two[index - 1].kind ~= "line") then
		misplaced += 1
	end
end
check(`no note is orphaned from its line ({misplaced} orphaned)`, misplaced == 0)

print("")
print("holding nothing")
local none = Readout.lineRows({
	{ id = "board", solved = false, holding = false },
	{ id = "breaker", solved = true, holding = false },
})
check("the empty message is shown", none[#none].text == Readout.NOTHING_HELD)
check("...and the count reflects the solved one", none[#none - 1].text == "restored 1/2")

-- A solved line you hold is not a line you can act on, so it must not be shown
-- as one, and must not suppress the empty message.
local solvedHeld = Readout.lineRows({
	{ id = "board", solved = true, holding = true, prompt = "jack %s", answer = "47" },
})
check("a solved line you hold is not listed", kinds(solvedHeld) == "count,empty")
check("...and the count sees it", solvedHeld[1].text == "restored 1/1")

print("")
print("against the real Objectives payload, not a hand-made one")
-- The shape comes from `viewFor`, so a change there cannot leave this file
-- testing a payload the game no longer sends.
local board = Objectives.new()
board:add("board", "jack_number", "Line is out. Patch it to jack %s.")
board:add("breaker", "breaker", "Breaker %s is the one that is thrown.")
board:deal({ 1 })
local realRows = Readout.lineRows(board:viewFor(1))
check(`(guard) one player holds both lines ({kinds(realRows)})`, #realRows == 5)
check("the real payload also pairs every note with its line", kinds(realRows) == "line,note,line,note,count")

local otherRows = Readout.lineRows(board:viewFor(2))
check("a player holding nothing sees the empty message", otherRows[#otherRows].text == Readout.NOTHING_HELD)
check("...and no answers leak into their rows", string.find(otherRows[1].text, "restored", 1, true) == 1)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
