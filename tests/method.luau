--!strict
-- It learns how you pass a code (DECISIONS D13). Run: lune run tests/method
--
-- What this file guards:
--   - The marks a line holds: digits glued or apart, capitals glued ("GF"),
--     letter names and radio words, "again", and a name that opens a sentence,
--     which is who is spoken to and marks nothing.
--   - Each way is credited at a restore from the holder's newest line with a
--     mark in it, warns at the second credit, is understood at the third, and
--     hears the fourth use: read back, spent, walked to.
--   - It reads a player's lines only against the codes that player has seen.
--     A way that reads the evidence as another number loses a credit. A line
--     that said the code plainly credits no way. The round boundary cools a
--     way unless it was understood and used; a finished round's lines are
--     never credited in the next.
--   - The wall shows each way under "how you pass codes".
--   - The scheme corpus (PLAYBOOK TRY): every scheme a group has won with,
--     replayed; 10 of the 11 are read (not private facts).
--   - Null gates: the blind chat corpus teaches no way, and with every way
--     understood it spends almost no code.
-- Through the public surface: Method.marks/WAYS, Operator.hear/creditCode/
-- coolRound/forgetObservations/methodRows, Round.wallRows, Readout.

local fs = require("@lune/fs")

local Harness = require("./harness")

local rt = Harness.build()
local Method = rt.require(rt.systems.Method)
local Operator = rt.require(rt.systems.Operator)
local Round = rt.require(rt.systems.Round)
local Readout = rt.require(rt.shared.Readout)
local Config = rt.require(rt.shared.Config)

local Kit = require("./kit")
local check = Kit.check

math.randomseed(158)

local pool = Round.dealSecrets(99)
local NAMES = { ana = true, bo = true, cy = true, dee = true }

-- What a line marks, as "d3 d9" (d for a digit, l for a letter).
local function shape(text: string, names: { [string]: boolean }?): string
	local out: { string } = {}
	for _, mark in Method.marks(text, names) do
		table.insert(out, `{string.sub(mark.kind, 1, 1)}{mark.value or "?"}`)
	end
	return table.concat(out, " ")
end

print("what a line marks")
check('"banana 39": two digits, glued', shape("banana 39") == "d3 d9")
check('"three then nine": digit words', shape("three then nine") == "d3 d9")
check('"Bo: GF, here": two capitals are two letters', shape("GF, here") == "lg lf")
check('"gf" and "go" in lower case are words, not letters', shape("gf go") == "")
check('"C then E": letters with a word between', shape("C then E") == "lc le")
check('"bee ay", "bravo alpha": letter names and radio words', shape("bee ay bravo alpha") == "lb la lb la")
check('"2 again": the digit said twice', shape("2 again") == "d2 d2")
check('"again" alone repeats the line before it', shape("again") == "r?")
check('"dee, ay aitch": a name opening the line is who is spoken to', shape("dee, ay aitch", NAMES) == "la lh")
check("...but not a letter elsewhere in it", shape("ok dee 4", NAMES) == "ld d4")
check("(control) without the names, dee is a letter", shape("dee, ay aitch") == "ld la lh")

-- An Operator whose players have each seen the codes in `seen` (by player),
-- recording what it says and hears.
local function operator(seen: { [number]: { [string]: string } })
	local op = Operator.new(pool)
	local log = { heard = {} :: { string }, codes = {} :: { string }, method = {} :: { string }, lettered = 0 }
	op.liveCodes = function()
		local all: { [string]: string } = {}
		for _, codes in seen do
			for concept, code in codes do
				all[concept] = code
			end
		end
		return all
	end
	op.seenCodes = function(userId: number)
		return seen[userId] or {}
	end
	op.names = function()
		return NAMES
	end
	op.onUnderstood = function(concept: string, _payload: string, _confidence: number, heard: string?)
		table.insert(log.heard, `{concept}:{heard or ""}`)
	end
	op.onCodeHeard = function(concept: string)
		table.insert(log.codes, concept)
	end
	op.onMethod = function(kind: string, way: string, says: string)
		table.insert(log.method, `{kind} {way} {says}`)
	end
	op.onLettered = function()
		log.lettered += 1
	end
	return op, log
end

local function say(op: any, who: number, text: string, at: number)
	op:hear({ speaker = { UserId = who }, text = text, at = at })
end

-- Each way, taught by one holder (player 1) with three codes, then used on a
-- fourth. `tell` gives the lines that pass a code that way.
local WAYS = {
	{
		id = "turned",
		codes = { "93", "18", "57", "46" },
		tell = function(code: string): { string }
			return { `banana {string.reverse(code)}` }
		end,
	},
	{
		id = "apart",
		codes = { "38", "27", "83", "62" },
		tell = function(code: string): { string }
			return { "cy flippy", string.sub(code, 1, 1), string.sub(code, 2, 2) }
		end,
	},
	{
		id = "apart",
		label = "apart, with again",
		codes = { "44", "66", "22", "33" },
		tell = function(code: string): { string }
			return { string.sub(code, 1, 1), "again" }
		end,
	},
	{
		id = "lettersA1",
		label = "letters, glued",
		codes = { "76", "81", "42", "99" },
		tell = function(code: string): { string }
			local A = "abcdefghi"
			local function letter(d: string): string
				return string.upper(string.sub(A, tonumber(d) :: number, tonumber(d) :: number))
			end
			return { `Cy, {letter(string.sub(code, 1, 1))}{letter(string.sub(code, 2, 2))}` }
		end,
	},
	{
		id = "lettersA1",
		label = "letters, a word between",
		codes = { "35", "19", "86", "44" },
		tell = function(code: string): { string }
			local A = "abcdefghi"
			local function letter(d: string): string
				return string.upper(string.sub(A, tonumber(d) :: number, tonumber(d) :: number))
			end
			return { `bo, {letter(string.sub(code, 1, 1))} then {letter(string.sub(code, 2, 2))}` }
		end,
	},
	{
		id = "lettersA0",
		codes = { "59", "21", "73", "48" },
		tell = function(code: string): { string }
			local A = "abcdefghij"
			local names = { a = "ay", b = "bee", c = "see", d = "dee", e = "ee", f = "eff", g = "gee", h = "aitch" }
			local function letter(d: string): string
				local l = string.sub(A, (tonumber(d) :: number) + 1, (tonumber(d) :: number) + 1)
				return names[l] or l
			end
			return { `yours is {letter(string.sub(code, 1, 1))} {letter(string.sub(code, 2, 2))}` }
		end,
	},
}

print("")
print("each way: warned at the second restore, understood at the third, heard at the fourth")
for _, case in WAYS do
	local label = (case :: any).label or case.id
	local seen: { [number]: { [string]: string } } = { [1] = {} }
	local op, log = operator(seen)
	local at = 0
	for i = 1, 3 do
		local code = case.codes[i]
		seen[1] = { jack_number = code }
		for _, text in case.tell(code) do
			at += 2
			say(op, 1, text, at)
		end
		at += 2
		seen[1] = {}
		op:creditCode(code, at, 1)
		if i == 2 then
			local warned = log.method[#log.method]
			check(
				`{label}: the second restore says "{Round.LINES.noting}" ({warned or "nothing"})`,
				warned == `noting {case.id} {Method.NOTING_LINE}`
			)
		end
	end
	local way = nil
	for _, w in Method.WAYS do
		if w.id == case.id then
			way = w
		end
	end
	if case.id == "lettersA1" or case.id == "lettersA0" then
		check(`{label}: the third restore says the letters are understood, once`, log.lettered == 1)
	else
		check(
			`{label}: the third restore says it is understood ("{(Round.LINES :: any)[(way :: any).line]}")`,
			log.method[#log.method] == `understood {case.id} {(way :: any).line}`
		)
	end
	check(`{label}: no code was heard while it learned`, #log.codes == 0)
	local fourth = case.codes[4]
	seen[1] = { jack_number = fourth }
	for _, text in case.tell(fourth) do
		at += 2
		say(op, 1, text, at)
	end
	check(
		`{label}: the fourth use is heard as {fourth} ({table.concat(log.heard, ", ")})`,
		log.codes[1] == "jack_number" and log.heard[#log.heard] == `jack_number:{fourth}`
	)
end

-- Teach ways (by their WAYS cases) to one holder, player 1, and return the
-- Operator, its log, the codes each player has seen, and the clock.
local function taught(...: number): (any, any, { [number]: { [string]: string } }, number)
	local seen: { [number]: { [string]: string } } = { [1] = {} }
	local op, log = operator(seen)
	local at = 0
	for _, caseIndex in { ... } do
		local case = WAYS[caseIndex]
		for i = 1, 3 do
			for _, text in case.tell(case.codes[i]) do
				at += 2
				say(op, 1, text, at)
			end
			at += 2
			op:creditCode(case.codes[i], at, 1)
		end
	end
	return op, log, seen, at
end

local function heatOf(op: any, label: string): number
	for _, row in op:methodRows() do
		if row.phrase == label then
			return row.heat
		end
	end
	return 0
end

print("")
print("only the codes the speaker has seen")
do
	local op, log, seen, at = taught(1)
	seen[1] = {}
	seen[2] = { breaker = "93" }
	say(op, 1, "banana 39", at + 1)
	check("a player who has not seen 93 says it turned round: nothing is heard", #log.codes == 0)
	say(op, 2, "banana 39", at + 3)
	check("...the player who has seen it says the same: heard", log.codes[1] == "breaker")
end

print("")
print("the evidence is the holder's newest line, and a way that misreads it loses")
do
	local op, log, _seen, at = taught(1)
	check("(guard) turned round is understood", heatOf(op, "digits turned round") >= Config.ActThreshold)
	say(op, 1, "table 12", at + 2)
	op:creditCode("47", at + 4, 1)
	check(
		`a restore after a pair turned round reads as 21, not 47: it loses a credit ({heatOf(op, "digits turned round")})`,
		heatOf(op, "digits turned round") < Config.ActThreshold
	)
	check("(guard) nothing was heard", #log.codes == 0)
end
do
	local op = operator({ [1] = {} })
	say(op, 1, "banana 39", 1)
	say(op, 1, "wait", 3)
	op:creditCode("93", 5, 1)
	check("a line with no mark after the evidence does not hide it", heatOf(op, "digits turned round") > 0)
	local op2 = operator({ [1] = {} })
	say(op2, 1, "banana 39", 1)
	say(op2, 1, "table 12", 3)
	op2:creditCode("93", 5, 1)
	check("an older line is not evidence: only the newest with a mark", heatOf(op2, "digits turned round") == 0)
	local op3 = operator({ [1] = {} })
	say(op3, 2, "banana 39", 1)
	op3:creditCode("93", 3, 1)
	check("another player's line is not the holder's evidence", heatOf(op3, "digits turned round") == 0)
	local op4 = operator({ [1] = {} })
	say(op4, 1, "banana 39", 1)
	op4:creditCode("93", 1 + Config.CreditWindow + 1, 1)
	check("a line older than the credit window is not evidence", heatOf(op4, "digits turned round") == 0)
	local op5 = operator({ [1] = {} })
	say(op5, 1, "its 93, 39 turned round", 1)
	op5:creditCode("93", 3, 1)
	check("a line that said the code plainly used no way", heatOf(op5, "digits turned round") == 0)
end

-- A fresh Method: `lines` said by player 1 (with the sim's names), then a
-- restore of `code` held by player 1; the heat of each way after it.
local function afterOne(lines: { string }, code: string, others: { [string]: boolean }?): { [string]: number }
	local m = Method.new()
	for i, text in lines do
		local _, line = Method.read(m, 1, text, i, {}, NAMES)
		Method.keep(m, line)
	end
	Method.credit(m, code, 1, #lines + 1, function()
		return false
	end, others or {})
	return m.heat
end

print("")
print("which pairs a line holds")
check('"4 twice": the digit said twice', shape("4 twice") == "d4 d4")
check('"C n E": one joining word, "n"', (afterOne({ "C n E" }, "35").lettersA1 or 0) > 0)
check(
	'"banana 39, 12 left" before 93: the pair that fits is found, not only the last',
	(afterOne({ "banana 39, 12 left" }, "93").turned or 0) > 0
)
check(
	'"ok dee 4", then "6": one digit in each line, whatever else the first holds',
	(afterOne({ "ok dee 4", "6" }, "46").apart or 0) > 0
)
check(
	"(control) two digits in the first line are no piece of a split",
	(afterOne({ "ok 4 or 5", "6" }, "46").apart or 0) == 0
)

print("")
print("a holder of two lines")
do
	-- Both codes passed turned round before either is entered: each line is
	-- that code's evidence, not the other's.
	local seen: { [number]: { [string]: string } } = { [1] = { jack_number = "47", breaker = "38" } }
	local op = operator(seen)
	say(op, 1, "banana 74", 1)
	say(op, 1, "table 83", 3)
	seen[1] = { breaker = "38" }
	op:creditCode("47", 5, 1)
	seen[1] = {}
	op:creditCode("38", 7, 1)
	check(
		`both restores teach the way, neither counts against it ({heatOf(op, "digits turned round")})`,
		heatOf(op, "digits turned round") == 2 * Config.HeatPerCredit
	)
	-- One digit a message: "3", "8", "4", "7" before either is entered. The "4"
	-- belongs with the "7", not with the "8".
	local seen2: { [number]: { [string]: string } } = { [1] = { jack_number = "38", breaker = "47" } }
	local op2 = operator(seen2)
	for i, digit in { "3", "8", "4", "7" } do
		say(op2, 1, digit, i)
	end
	seen2[1] = { breaker = "47" }
	op2:creditCode("38", 5, 1)
	seen2[1] = {}
	op2:creditCode("47", 6, 1)
	check(
		`...and one digit a message, both passed first: both restores teach it ({heatOf(op2, "one digit at a time")})`,
		heatOf(op2, "one digit at a time") == 2 * Config.HeatPerCredit
	)
end
do
	-- A code caught through a way is spent like one said aloud: its line is no
	-- evidence at the holder's next restore.
	local op, log, seen, at = taught(1)
	seen[1] = { jack_number = "57" }
	say(op, 1, "banana 75", at + 1)
	check("(guard) caught turned round", log.codes[1] == "jack_number")
	seen[1] = {}
	op:creditCode("12", at + 3, 1)
	check(
		`a caught line is spent, not weighed at the next restore ({heatOf(op, "digits turned round")})`,
		heatOf(op, "digits turned round") >= Config.ActThreshold
	)
end

print("")
print("what is weighed is used once, and what is heard is spent once")
do
	local op = operator({ [1] = {} })
	say(op, 1, "banana 39", 1)
	op:creditCode("93", 3, 1)
	op:creditCode("57", 5, 1)
	check(
		`a line weighed at one restore is not weighed again at the next ({heatOf(op, "digits turned round")})`,
		heatOf(op, "digits turned round") == Config.HeatPerCredit
	)
end
do
	local op, log, seen, at = taught(2)
	seen[1] = { jack_number = "38" }
	say(op, 1, "3", at + 1)
	say(op, 1, "8", at + 2)
	check("(guard) one digit a message is heard: 38", log.codes[1] == "jack_number")
	seen[1] = { jack_number = "39" }
	say(op, 1, "9", at + 3)
	check("the first half of a heard pair is spent with it: a later 9 is no 39", #log.codes == 1)
end
do
	local op, log, seen, at = taught(1)
	seen[1] = { jack_number = "93" }
	say(op, 1, "93 or 39, whichever", at + 1)
	check(
		`a code said plainly and turned round in one line is heard once ({#log.heard} said, {#log.codes} spent)`,
		#log.heard == 1 and #log.codes == 1
	)
	seen[1] = { jack_number = "57" }
	say(op, 1, "the jack, banana 75", at + 3)
	check(
		`a line whose word already sent it: the code is spent, and it is sent once ({#log.heard} said, {#log.codes} spent)`,
		#log.heard == 2 and #log.codes == 2
	)
end
do
	local m = Method.new()
	for i, text in { "banana 39", "banana 18", "banana 75" } do
		local _, line = Method.read(m, 1, text, i, {}, NAMES)
		Method.keep(m, line)
		Method.credit(m, string.reverse(string.match(text, "%d+") :: string), 1, i, function()
			return false
		end, {})
	end
	local hits = Method.read(m, 1, "banana 64 banana 64", 10, { jack_number = "46" }, NAMES)
	check(`one code in a line twice is one hit ({#hits})`, #hits == 1)
end

do
	-- A code never begins with nought, so a pair a way could only read as one
	-- ("room 90" turned round is 09) is no evidence against that way.
	local op = taught(1)
	say(op, 1, "room 90", 100)
	op:creditCode("47", 102, 1)
	check(
		`"room 90" before 47 does not count against turned round ({heatOf(op, "digits turned round")})`,
		heatOf(op, "digits turned round") >= Config.ActThreshold
	)
	local op2 = taught(4)
	say(op2, 1, "its J then A", 100)
	op2:creditCode("47", 102, 1)
	check(
		`"J then A" (nought, one) before 47 does not count against letters ({heatOf(op2, "letters, a is 1")})`,
		heatOf(op2, "letters, a is 1") >= Config.ActThreshold
	)
end

print("")
print("cooling and forgetting")
do
	local op = taught(1)
	op:cool(Config.CoolPerRound)
	check(
		`the Operator's cooling cools the ways too ({heatOf(op, "digits turned round")})`,
		heatOf(op, "digits turned round") < Config.ActThreshold
	)
end
do
	local op = taught(1)
	op:coolRound(Config.CoolPerRound)
	check("a way understood and credited this round keeps its heat", heatOf(op, "digits turned round") >= 0.75)
	op:coolRound(Config.CoolPerRound)
	check(
		`...and one not used for a round cools under the threshold ({heatOf(op, "digits turned round")})`,
		heatOf(op, "digits turned round") < Config.ActThreshold
	)
	local op2 = operator({ [1] = {} })
	say(op2, 1, "banana 39", 1)
	op2:forgetObservations()
	op2:creditCode("93", 3, 1)
	check("a line said before the round ended is never credited after it", heatOf(op2, "digits turned round") == 0)
end
do
	local op, log, seen, at = taught(1)
	seen[1] = { jack_number = "57" }
	say(op, 1, "banana 75", at + 2)
	check("(guard) heard", #log.codes == 1)
	op:coolRound(Config.CoolPerRound)
	check("a way that heard a code this round is in use: it keeps its heat", heatOf(op, "digits turned round") >= 0.75)
end

print("")
print("a new alphabet is news: the dial's, then the group's switch to A as 1")
do
	-- The dial learns a group's own alphabet (DECISIONS D12): here A is 2, which
	-- no letters way reads. Then the group spells with A as 1, and the Operator
	-- warns and says it has their letters again. (The same alphabet crossing in
	-- both learners is said once: tests/counting.luau.)
	local op, log = operator({ [1] = {} })
	local A_IS_2 = "abcdefgh"
	local function spell(code: string): string
		local x, y = tonumber(string.sub(code, 1, 1)) :: number, tonumber(string.sub(code, 2, 2)) :: number
		return `yours is {string.sub(A_IS_2, x - 1, x - 1)} {string.sub(A_IS_2, y - 1, y - 1)}`
	end
	local at = 0
	for _, deal in { { "23", "45", "67" }, { "89", "32", "54" }, { "76", "98", "25" }, { "37", "49", "68" } } do
		for _, code in deal do
			at += 5
			say(op, 1, spell(code), at)
			op:creditCode(code, at, 1)
		end
		op:coolRound(Config.CoolPerRound)
	end
	check(`(guard) the dial reads the group's own letters ({log.lettered} said)`, next(op:knownLetters()) ~= nil)
	check("(guard) ...said once", log.lettered == 1)
	for _, code in { "21", "34", "56", "78" } do
		local x, y = tonumber(string.sub(code, 1, 1)) :: number, tonumber(string.sub(code, 2, 2)) :: number
		at += 5
		say(op, 1, `yours is {string.sub("abcdefghi", x, x)} {string.sub("abcdefghi", y, y)}`, at)
		op:creditCode(code, at, 1)
	end
	check(
		`(guard) letters, a is 1, is understood too ({heatOf(op, "letters, a is 1")})`,
		heatOf(op, "letters, a is 1") >= Config.ActThreshold
	)
	check(
		`...warned first, then said once more ({log.lettered} said, {table.concat(log.method, "; ")})`,
		log.lettered == 2 and #log.method == 1 and log.method[1] == `noting lettersA1 {Method.NOTING_LINE}`
	)
end

print("")
print("the wall")
do
	local op = taught(1)
	local rows = Round.wallRows({}, {}, op:methodRows())
	check(
		`the way is on the wall under "{Round.METHOD_LEADS}"`,
		#rows == 1 and rows[1].leadsTo == Round.METHOD_LEADS and rows[1].phrase == "digits turned round"
	)
	local texts: { string } = {}
	for _, row in Readout.lexiconRows(rows) do
		table.insert(texts, row.text)
	end
	check(
		`...in the Operator's own words, not quoted ({table.concat(texts, " | ")})`,
		texts[1] == `-> {Round.METHOD_LEADS}` and texts[2] == "digits turned round  75%  understood"
	)
	check(
		"every way's line is one the Operator has",
		(function()
			for _, way in Method.WAYS do
				if (Round.LINES :: any)[way.line] == nil then
					return false
				end
			end
			return (Round.LINES :: any)[Method.NOTING_LINE] ~= nil
		end)()
	)
end

-- THE SCHEME CORPUS (PLAYBOOK TRY): every scheme a group has won with, one
-- group reusing it for six rounds, the holder of station s is player s.
print("")
print("the scheme corpus: every scheme a group has won with")
local TENS = { "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety" }
local ONES = { "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" }
local TEENS =
	{ "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen" }
local function words(n: number): string
	if n < 10 then
		return ONES[n + 1]
	elseif n < 20 then
		return TEENS[n - 9]
	end
	local t, o = n // 10, n % 10
	return if o == 0 then TENS[t] else `{TENS[t]} {ONES[o + 1]}`
end
local LETTER = "abcdefghij"
local NAME =
	{ a = "ay", b = "bee", c = "see", d = "dee", e = "ee", f = "eff", g = "gee", h = "aitch", i = "eye", j = "jay" }
local RADIO = {
	a = "alpha",
	b = "bravo",
	c = "charlie",
	d = "delta",
	e = "echo",
	f = "foxtrot",
	g = "golf",
	h = "hotel",
	i = "india",
	j = "juliett",
}
local function a1(d: number): string
	return if d == 0 then "j" else string.sub(LETTER, d, d)
end
local function a0(d: number): string
	return string.sub(LETTER, d + 1, d + 1)
end
local NICK = { "big desk", "flippy", "door thing" }
local FACTS = { "grandmas age", "the bus route", "my locker", "your jersey", "the pin", "mr k's room" }
local SCHEMES: { { name: string, read: boolean, say: (code: number, i: number, s: number) -> { string } } } = {
	{
		name = "spaced letters",
		read = true,
		say = function(code)
			return { `yours is {NAME[a1(code // 10)]} {NAME[a1(code % 10)]}` }
		end,
	},
	{
		name = "radio words",
		read = true,
		say = function(code)
			return { `yours is {RADIO[a1(code // 10)]} {RADIO[a1(code % 10)]}` }
		end,
	},
	{
		name = "number words",
		read = true,
		say = function(code)
			local k, r = code // 12, code % 12
			return { if r == 0 then `{words(k)} dozen` else `{words(k)} dozen and {words(r)}` }
		end,
	},
	{
		name = "reversed digits",
		read = true,
		say = function(code, _i, s)
			return { `{NICK[s]} {code % 10}{code // 10}` }
		end,
	},
	{
		name = "glued letters",
		read = true,
		say = function(code)
			return { `{string.upper(a1(code // 10) .. a1(code % 10))}, here` }
		end,
	},
	{
		name = "one digit a message",
		read = true,
		say = function(code, _i, s)
			return { `do the {NICK[s]}`, tostring(code // 10), tostring(code % 10) }
		end,
	},
	{
		name = "arithmetic",
		read = true,
		say = function(code)
			return { `{words(code + 13)} minus thirteen` }
		end,
	},
	{
		name = "a word between letters",
		read = true,
		say = function(code, i)
			local join = if i % 2 == 0 then "then" else "and"
			return { `its {string.upper(a1(code // 10))} {join} {string.upper(a1(code % 10))}` }
		end,
	},
	{
		name = "private facts",
		read = false,
		say = function(_code, i)
			return { `its {FACTS[((i - 1) % #FACTS) + 1]}` }
		end,
	},
	{
		name = "shifted alphabet",
		read = true,
		say = function(code)
			return { `yours is {NAME[a0(code // 10)]} {NAME[a0(code % 10)]}` }
		end,
	},
	{
		-- R158 and R159's blind groups and PT5's critic (DECISIONS D15).
		name = "public facts",
		read = true,
		say = function(code, i)
			if code < 52 and i % 2 == 0 then
				return { `a deck of cards minus {words(52 - code)}` }
			end
			return { `a dollar minus {words(100 - code)} cents` }
		end,
	},
}
local DEALS = {
	{ 21, 37, 58 },
	{ 46, 83, 19 },
	{ 72, 35, 64 },
	{ 27, 91, 53 },
	{ 68, 14, 39 },
	{ 85, 42, 76 },
}
local CONCEPTS = { "jack_number", "breaker", "exit" }
local ENTRANT = { "cy", "dee", "ana" }
local read = 0
for _, scheme in SCHEMES do
	local seen: { [number]: { [string]: string } } = {}
	local op, log = operator(seen)
	local at, i, heardRight = 0, 0, 0
	for _, codes in DEALS do
		for s, code in codes do
			seen[s] = { [CONCEPTS[s]] = tostring(code) }
		end
		for s, code in codes do
			i += 1
			local before = #log.codes
			for _, text in scheme.say(code, i, s) do
				at += 2
				say(op, s, `{ENTRANT[s]}, {text}`, at)
			end
			for k = before + 1, #log.codes do
				if log.codes[k] == CONCEPTS[s] then
					heardRight += 1
				end
			end
			at += 2
			seen[s] = {}
			op:creditCode(tostring(code), at, s)
		end
		op:coolRound(Config.CoolPerRound)
		at += 20
	end
	local isRead = heardRight > 0
	if isRead then
		read += 1
	end
	check(
		`{scheme.name}: {if scheme.read then "read" else "not read"} ({heardRight} of 18 codes heard)`,
		isRead == scheme.read
	)
end
check(`10 of the 11 schemes are read ({read})`, read == 10)

-- NULL GATES. The blind corpus: 160 lines by someone who never saw the word
-- lists, told only what a player can see (tests/heuristic.luau).
print("")
print("null gates: ordinary chat")
local corpus: { string } = {}
for line in string.gmatch(fs.readFile("tests/blind_chat.txt"), "[^\r\n]+") do
	table.insert(corpus, line)
end
check(`(guard) read the blind corpus ({#corpus} lines)`, #corpus == 160)
do
	-- A restore after every line, the line's speaker holding the code: the
	-- hardest test there is, three times over and never cooled.
	local op = operator({})
	local at = 0
	for _ = 1, 3 do
		for _, line in corpus do
			at += 1
			say(op, 1, line, at)
			op:creditCode(tostring(math.random(10, 99)), at, 1)
		end
	end
	local learned: { string } = {}
	for _, row in op:methodRows() do
		if row.heat >= Config.ActThreshold then
			table.insert(learned, row.phrase)
		end
	end
	check(`the blind corpus, a restore after every line, teaches no way ({table.concat(learned, ", ")})`, #learned == 0)
end
do
	-- Letter-heavy chat, a restore after every line: letters read as digits
	-- by chance must not teach an alphabet either.
	local LETTERY = {
		"i see it",
		"oh i see",
		"HI GUYS",
		"OK GO",
		"BE CAREFUL",
		"a b testing lol",
		"i c u",
		"gg ez",
		"GG",
		"u r slow",
		"a bee in here",
		"dee and bo go",
		"ID card maybe",
		"AB or BA idk",
		"its C or D",
		"E then F",
		"plan a b c",
		"i am in",
		"DO IT",
		"AH",
	}
	local op = operator({})
	local at = 0
	for _ = 1, 20 do
		for _, line in LETTERY do
			at += 1
			say(op, 1, line, at)
			op:creditCode(tostring(math.random(10, 99)), at, 1)
		end
	end
	local hottest = 0
	for _, row in op:methodRows() do
		hottest = math.max(hottest, row.heat)
	end
	check(
		`letter-heavy chat, a restore after every line, teaches no way (hottest {hottest})`,
		hottest < Config.ActThreshold
	)
end
-- Its own seed: a change earlier in this file must not reshuffle the sample.
math.randomseed(1581)
do
	-- Turned round, one digit a message and letters (A is 1) understood; each
	-- blind line said by a player who has seen 1, 2 or 3 live codes, beside an
	-- Operator that has learned no way (plain digits already spend codes). How
	-- many more does ordinary chat spend through a way? Most of it is turned
	-- round reading a two-digit number backwards; it grows with the codes seen.
	local op, log, seen, at = taught(1, 2, 4)
	local plain, plainLog = operator(seen)
	local understood: { string } = {}
	for _, row in op:methodRows() do
		if row.heat >= Config.ActThreshold then
			table.insert(understood, row.phrase)
		end
	end
	check(`(guard) three ways understood at once ({table.concat(understood, ", ")})`, #understood == 3)
	local CONCEPT = { "jack_number", "breaker", "exit" }
	for held = 1, 3 do
		local added, lines = 0, 1000
		for _ = 1, lines do
			local codes: { [string]: string } = {}
			for c = 1, held do
				codes[CONCEPT[c]] = tostring(math.random(10, 99))
			end
			seen[1] = codes
			local line = corpus[math.random(#corpus)]
			local before, plainBefore = #log.codes, #plainLog.codes
			at += 1
			say(op, 1, line, at)
			say(plain, 1, line, at)
			added += (#log.codes - before) - (#plainLog.codes - plainBefore)
		end
		check(
			`...a player who has seen {held} code(s): the ways add {added} spent codes in {lines} lines (at most {4 * held})`,
			added <= 4 * held
		)
	end
end

Kit.finish()
