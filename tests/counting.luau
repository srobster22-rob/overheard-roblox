--!strict
-- It learns to count (R147). Run: lune run tests/counting
--
-- What this file guards:
--   - Numerals.explain works out the one word a line needs to say the code
--     that was entered, from PT4's own lines, and nothing from lines that do
--     not pin it down ("a quarter" alone, two unknowns, "2/3").
--   - The Operator learns a scheme word at the rates station words learn by,
--     cools it the same way, and never settles a nickname that meets a new
--     code every time.
--   - A code said with a learned word is heard like a code said in digits.
--   - The wall shows each learned word with its value under its own header.
--   - Null gate: the 160-line blind chat corpus learns no number word, and
--     read with every PT4 scheme word learned it decodes almost no live code.
-- Through the public surface: Numerals, Operator.hear/creditCode/coolRound/
-- knownValues/countingRows, Heuristic.conveyed, Round.wallRows, Readout.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Numerals = rt.require(rt.shared.Numerals)
local Operator = rt.require(rt.systems.Operator)
local Heuristic = rt.require(rt.systems.Heuristic)
local Round = rt.require(rt.systems.Round)
local Readout = rt.require(rt.shared.Readout)
local Config = rt.require(rt.shared.Config)

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

math.randomseed(147)

print("working out one word from a line and the code entered after it")
local SOLVED = {
	-- PT4's lines, word for word, and the code each came before.
	{ "toaster. five dozen minus two", 58, "dozen", 12 },
	{ "toaster five dozen minus two", 58, "dozen", 12 },
	{ "three dozen and one", 37, "dozen", 12 },
	{ "cy dee, five dozen", 60, "dozen", 12 },
	{ "two less than two dozen", 22, "dozen", 12 },
	{ "bo spaghetti is four dozen and three", 51, "dozen", 12 },
	{ "grandma minus 13", 58, "grandma", 71 },
	{ "jordan's jersey plus 3", 26, "jordan jersey", 23 },
	{ "sixty take away the usual", 47, "usual", 13 },
	{ "ok its how many cents is 3 quarters", 75, Numerals.key({ "quarters" }), 25 },
	{ "four dozen and cy do it", 48, "dozen", 12 },
}
for _, case in SOLVED do
	local text, code, key, value = case[1] :: string, case[2] :: number, case[3] :: string, case[4] :: number
	local explained = Numerals.explain(text, code, {})
	check(
		`"{text}" before {code}: {key} = {value}`,
		explained ~= nil and explained.key == key and explained.value == value and not explained.confirmed
	)
end
local UNSOLVED = {
	{ "a quarter", 25, "an unknown alone is no evidence" },
	{ "two hours minus a minute", 59, "two unknowns" },
	{ "did it!! 2/3", 23, "a word before a number is not a sum" },
	{ "the big hair decade then shoes", 82, "no number in it" },
	{ "one less than the big hair decade", 40, "an unknown of three words" },
}
for _, case in UNSOLVED do
	local text, code, why = case[1] :: string, case[2] :: number, case[3] :: string
	check(`"{text}" before {code} works out nothing ({why})`, Numerals.explain(text, code, {}) == nil)
end
check(
	"a line two phrases explain differently explains nothing",
	Numerals.explain("five dozen, no wait two grandma", 60, {}) == nil
)
check("a value outside 1-99 is no value", Numerals.explain("two dozen", 1, {}) == nil)
local confirmed = Numerals.explain("six dozen and five", 77, { dozen = 12 })
check(
	"a line that says the code with a learned word confirms it",
	confirmed ~= nil and confirmed.key == "dozen" and confirmed.confirmed
)
local function has(set: { [string]: boolean }, n: string): boolean
	return set[n] == true
end
check("a learned word is read in a line", has(Numerals.read("spaghetti. six dozen and five", { dozen = 12 }), "77"))
check("...and in a comparison", has(Numerals.read("two less than seven dozen", { dozen = 12 }), "82"))
check("nothing is read without learned words", next(Numerals.read("six dozen and five", {})) == nil)
-- The review's cases: chatter after the sum, and sentences, must not hide it.
local dozen = { dozen = 12 }
check(
	'chatter after the sum is dropped ("...minus two pls")',
	has(Numerals.read("five dozen minus two pls", dozen), "58")
)
check(
	'...and a comma ends the sum ("...minus two, hurry")',
	has(Numerals.read("five dozen minus two, hurry", dozen), "58")
)
check(
	'a full stop ends it too (PT4: "eight dozen plus two. dont say the room name")',
	has(Numerals.read("eight dozen plus two. dont say the room name", dozen), "98")
)
local both = Numerals.read("five dozen minus two, three dozen and one", dozen)
check("two codes in one line, a comma apart, are both read", has(both, "58") and has(both, "37"))
check('PT4\'s "toaster. a dozen even" reads as 12', has(Numerals.read("toaster. a dozen even", dozen), "12"))
local porch = Numerals.explain("bouncer four dozen minus one. whoever gets to the porch first", 47, {})
check(
	'PT4\'s "bouncer four dozen minus one. whoever gets to the porch first" before 47: dozen = 12',
	porch ~= nil and porch.key == "dozen" and porch.value == 12
)

print("")
print("the Operator learns a scheme word, at the station words' rates")
local pool = Round.dealSecrets(99)
local function playerOf(id: number): any
	return { UserId = id }
end
local function say(op: any, text: string, at: number, who: number?)
	op:hear({ speaker = playerOf(who or 1), text = text, at = at })
end
local function words(phrase: string): { string }
	local out = {}
	for word in string.gmatch(phrase, "%S+") do
		table.insert(out, word)
	end
	return out
end
local function heatOf(op: any, key: string): number
	for _, row in op:countingRows() do
		if Numerals.key(words(row.phrase)) == key then
			return row.heat
		end
	end
	return 0
end
do
	local op = Operator.new(pool)
	-- PT4 critic s1, round 1: two dozens lines, each said right before its code.
	say(op, "cy the flippy switch thing near you. five dozen", 8)
	op:creditCode("60", 8)
	say(op, "dee when you get there, mine is three dozen and one", 15)
	op:creditCode("37", 15)
	local afterOne = heatOf(op, "dozen")
	check(
		`two uses in a round: {Config.HeatPerCredit * 2} heat, not yet understood`,
		math.abs(afterOne - Config.HeatPerCredit * 2) < 1e-9 and op:knownValues().dozen == nil
	)
	op:coolRound(Config.CoolPerRound)
	say(op, "toaster, six dozen and five. cy you're next to it", 34)
	op:creditCode("77", 34)
	say(op, "humming. dee move. bouncer is a dozen and seven, you take it", 35)
	op:creditCode("19", 35)
	check("...understood in the second round, after two more uses", op:knownValues().dozen == 12)
	-- Round 2, said with the live code 66 on the board.
	local heard = Heuristic.conveyed(
		{ speaker = playerOf(2), text = "ana spaghetti. five dozen and six", at = 42 } :: any,
		pool :: any,
		{} :: any,
		{ jack_number = "66" },
		op:knownValues()
	)
	local byCode = false
	for _, understanding in heard do
		byCode = byCode or (understanding.byCode == true and understanding.heard == "66")
	end
	check("a code said with it is heard like a code said in digits", byCode)
	local unheard = Heuristic.conveyed(
		{ speaker = playerOf(2), text = "ana spaghetti. five dozen and six", at = 42 } :: any,
		pool :: any,
		{} :: any,
		{ jack_number = "66" }
	)
	check("(control) not before it is learned", #unheard == 0)
	local rows = Readout.lexiconRows(Round.wallRows(op:snapshot(), op:countingRows()))
	local header, row = false, false
	for _, r in rows do
		header = header or r.text == `-> {Round.COUNTING_LEADS}`
		row = row
			or (
				string.find(r.text, '"dozen" = 12', 1, true) ~= nil
				and string.find(r.text, "understood", 1, true) ~= nil
			)
	end
	check(`the wall shows it under "-> {Round.COUNTING_LEADS}", with its value`, header and row)
end
do
	-- A nickname used as the unknown meets a different code each time.
	local op = Operator.new(pool)
	local codes = { 58, 37, 77, 66, 24, 91 }
	for i, code in codes do
		say(op, `toaster plus {i}`, i * 10)
		op:creditCode(tostring(code), i * 10)
	end
	check("a word worked out to a new value every time never settles", op:knownValues().toaster == nil)
end
do
	-- Worked out to two values in turn: each credit takes the other back off.
	local op = Operator.new(pool)
	for i = 1, 6 do
		local code = if i % 2 == 1 then "84" else "63"
		say(op, "grandma plus 13", i * 10)
		op:creditCode(code, i * 10)
	end
	check("a word that alternates between two values never settles", op:knownValues().grandma == nil)
end
do
	-- Through the Operator's own ear: learned, then a code said with it.
	local op = Operator.new(pool)
	for i = 1, 3 do
		say(op, "five dozen", i)
		op:creditCode("60", i)
	end
	local heardCodes = {}
	op.liveCodes = function()
		return { jack_number = "66" }
	end
	op.onCodeHeard = function(concept: string)
		table.insert(heardCodes, concept)
	end
	say(op, "ana spaghetti. five dozen and six", 40)
	check("the Operator hears a code said with a learned word", heardCodes[1] == "jack_number")
end
do
	-- It says so once, as a word crosses into understood; never again after.
	local op = Operator.new(pool)
	local told: { string } = {}
	op.onCounted = function(key: string, value: number)
		table.insert(told, `{key}={value}`)
	end
	for i = 1, 5 do
		say(op, "five dozen", i)
		op:creditCode("60", i)
	end
	check(
		`it announces a counting word once, as it is understood ({table.concat(told, ", ")})`,
		#told == 1 and told[1] == "dozen=12"
	)
end
do
	-- The same word as a station's nickname and as a number: two rows.
	local rows = Readout.lexiconRows(Round.wallRows(
		{
			{ phrase = "dozen", concept = "breaker", heat = 0.3, sightings = 1 },
		} :: any,
		{
			{ phrase = "dozen", concept = "counting", heat = 0.7, sightings = 0, value = 12 },
		} :: any
	))
	local asNumber, asStation = false, false
	for _, r in rows do
		asNumber = asNumber or string.find(r.text, '"dozen" = 12', 1, true) ~= nil
		asStation = asStation or r.text == '"dozen"  30%'
	end
	check("a word the group uses as a number is its own row, beside its station row", asNumber and asStation)
end
do
	local op = Operator.new(pool)
	for i = 1, 3 do
		say(op, "five dozen", i)
		op:creditCode("60", i)
	end
	check("(control) three uses in a round: understood", op:knownValues().dozen == 12)
	op:coolRound(Config.CoolPerRound)
	check("...and kept through the boundary while it is still being used", op:knownValues().dozen == 12)
	op:coolRound(Config.CoolPerRound)
	check("a round of disuse cools it under the line", op:knownValues().dozen == nil)
end
do
	local op = Operator.new(pool)
	say(op, "five dozen", 1)
	op:creditCode("60", 1 + Config.CreditWindow + 1)
	check("a line older than the credit window teaches nothing", heatOf(op, "dozen") == 0)
	say(op, "five dozen", 100)
	op:forgetObservations()
	op:creditCode("60", 100)
	check("the round's lines are forgotten with its observations", heatOf(op, "dozen") == 0)
end

print("")
print("null gate: ordinary chat")
local corpus: { string } = {}
for line in string.gmatch(fs.readFile("tests/blind_chat.txt"), "[^\r\n]+") do
	table.insert(corpus, line)
end
do
	-- Every blind line said just before a random code is entered, three times over.
	local op = Operator.new(pool)
	local at = 0
	for _ = 1, 3 do
		for _, line in corpus do
			at += 1
			say(op, line, at)
			op:creditCode(tostring(math.random(10, 99)), at)
		end
	end
	local learned = {}
	for key in op:knownValues() do
		table.insert(learned, key)
	end
	check(
		`the blind corpus, each line before a random code, learns no number word ({table.concat(learned, ", ")})`,
		#learned == 0
	)
	-- Read with every PT4 scheme word learned, against three random live codes a deal.
	local known = { dozen = 12, usual = 13, [Numerals.key({ "quarters" })] = 25, grandma = 71 }
	local false_ = 0
	local deals = 1000
	for _ = 1, deals do
		local live: { [string]: boolean } = {}
		for _ = 1, 3 do
			live[tostring(math.random(10, 99))] = true
		end
		local line = corpus[math.random(#corpus)]
		for n in Numerals.read(line, known) do
			if live[n] then
				false_ += 1
			end
		end
	end
	check(
		`...and read with PT4's scheme words learned, decodes a live code in {false_} of {deals} lines`,
		false_ * 500 < deals
	)
end

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
