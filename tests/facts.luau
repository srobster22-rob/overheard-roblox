--!strict
-- The numbers everyone knows (DECISIONS D15). Run: lune run tests/facts
--
-- What this file guards:
--   - The riddles unscripted groups passed codes with in PT4, PT5 and the blind
--     sessions, built from public facts, read as their codes: "a deck of cards
--     minus one" is 51, "seven sevens" 49, "the lucky one two times" 77.
--   - A private fact ("how old my cousin jess is") is read as nothing, and a
--     number said plainly is the plain reader's, never a fact's.
--   - The registry is data: every phrase lower case, said once, one value.
--   - Null gate: the 160-line blind chat corpus reads no two-digit number
--     through a fact.
--   - Through the Operator: a code passed as a fact is heard only from a player
--     who has seen it, read back and spent, and the Operator says it is known.
-- Through the public surface: Facts.rewrite/read/KNOWN, Operator.hear.

local fs = require("@lune/fs")

local Harness = require("./harness")

local rt = Harness.build()
local Facts = rt.require(rt.shared.Facts)
local Operator = rt.require(rt.systems.Operator)
local Round = rt.require(rt.systems.Round)

local Kit = require("./kit")
local check = Kit.check

math.randomseed(160)

print("riddles groups passed codes with")
-- Each line as a group said it (PT4, PT5, the R158 and R159 blind sessions),
-- and the code it passed.
local RIDDLES = {
	{ "ana, the lever thing in there = a deck of cards minus one", "51" },
	{ "grandma = days in february, normal year", "28" },
	{ "porch done. dee, toaster = blackjack", "21" },
	{ "ana. grandma = a dollar minus a dime, in cents", "90" },
	{ "grandma = a dollar minus eight cents", "92" },
	{ "dee, front = two weeks, in days", "14" },
	{ "doormat = seven sevens", "49" },
	{ "toaster = three dozen minus four", "32" },
	{ "toaster = a full deck plus a pair", "54" },
	{ "Ana: fingers on one hand, then days in a week", "57" },
	{ "ok dont say it. mine is the lucky one two times", "77" },
	{ "mine reads the same both ways, so: the loneliest number, twice. far room. Dee?", "11" },
	{ "ana. porch = the age you can vote", "18" },
	{ "bo its heinz ketchup", "57" },
	{ "idk it just changed. ok its how many cents is 3 quarters", "75" },
	{ "ok ana mine is for this room. its a high five and then another high five", "55" },
	{ "ok mine is the last one. its nine nines", "81" },
	{ "ok mine is for the switch room. ana its how many states there are", "50" },
	{ "bo, the answer to life the universe and everything", "42" },
	{ "cy the breaker thing is how many players on a soccer team", "11" },
	{ "ok last one. the latch is seven squared", "49" },
	{ "keys on a piano minus two", "86" },
	{ "dee the back one is double 43", "86" },
	{ "ugh fine. dee, a hundred minus five. the one in your room", "95" },
	{ "ugh. ok bo, half of seventy four", "37" },
	{ "cy the flippy switch thing near you. five dozen", "60" },
	{ "toaster, six dozen and five. cy you're next to it", "77" },
	{ "biggest dice number two times", "66" },
	{ "humming. dee move. bouncer is a dozen and seven, you take it", "19" },
	{ "cy mine is for ur room. how many letters in the alphabet", "26" },
	{ "nice. bo my turn. the lever thing. octopus legs, then fingers on one hand", "85" },
}
local unread: { string } = {}
for _, riddle in RIDDLES do
	if not Facts.read(riddle[1])[riddle[2]] then
		table.insert(unread, `"{riddle[1]}" ({Facts.rewrite(riddle[1])})`)
	end
end
check(
	`every riddle reads as its code ({#RIDDLES - #unread} of {#RIDDLES}; unread: {table.concat(unread, "; ")})`,
	#unread == 0
)

check(
	`a sum after a fact reads a two-word number whole ("a dollar minus sixty three cents": {Facts.rewrite(
		"a dollar minus sixty three cents"
	)})`,
	Facts.read("a dollar minus sixty three cents")["37"] == true
		and Facts.read("a dollar minus sixty three cents")["40"] == nil
)

print("")
print("the forms people put facts together in")
-- Each form, and what the player meant; a form it cannot read reads nothing
-- wrong ("half of seventy five" is not 37).
for _, form in
	{
		{ "a dollar minus twenty-one cents", "79", "80" },
		{ "double seven", "77", "14" },
		{ "double 43", "86", nil },
		{ "half a deck", "26", "52" },
		{ "half of a deck", "26", "52" },
		{ "a dozen twice", "24", nil },
		{ "twice a dozen", "24", nil },
		{ "a deck - 1", "51", nil },
		{ "a dozen*2", "24", nil },
	}
do
	local read = Facts.read(form[1])
	check(
		`"{form[1]}" reads as {form[2]}{if form[3] then `, not {form[3]}` else ""} ({Facts.rewrite(form[1])})`,
		read[form[2]] == true and (form[3] == nil or read[form[3]] == nil)
	)
end
check("half of an odd number is no whole number: nothing is read", next(Facts.read("half of seventy five")) == nil)

print("")
print("everyday chat is no riddle")
-- Lines a group says in passing, with words a riddle also uses (R160's second
-- review found each of these read as a code before the list was cut to phrases
-- nobody says in passing, and units to after a number). Each reads as nothing.
local EVERYDAY = {
	"ok that one was lucky lol",
	"lucky us, one left",
	"gg that was a lucky one",
	"gimme a hand, two of them are here",
	"i need a hand with this one",
	"a week ago i would have won this",
	"we need a quarter more time",
	"whats the score now, one to zero?",
	"ive been stuck for an hour lol",
	"brb one sec, dinner in half an hour",
	"i had covid one time",
	"no one is in the states room",
	"the decade of big hair",
	"fingers crossed",
	"grab the nice one",
	"high five! one down",
	"its a pair of doors, go through one",
	"i have 2. dozens of them",
	"we need 4. a pair of us go left",
	"hundreds of doors in here",
	"99999999999999 squared squared squared",
}
local everydayReads: { string } = {}
for _, line in EVERYDAY do
	for number in Facts.read(line) do
		if string.match(number, "^%d%d$") then
			table.insert(everydayReads, `"{line}" as {number}`)
		end
	end
end
check(`none of {#EVERYDAY} everyday lines reads as a code ({table.concat(everydayReads, "; ")})`, #everydayReads == 0)

print("")
print("what stays the group's own")
for _, line in
	{
		"bo its how old my cousin jess is. u know her",
		"cy ok new one. its bos football jersey. the one he wears to school every day",
		"dee take the first number you ever typed tonight and knock seventy off it",
		"ana when we get there, yours is the one straight after what dee just fixed",
	}
do
	check(`a private fact is read as nothing: "{line}"`, next(Facts.read(line)) == nil)
end
check("a number said plainly is not a fact's (the plain reader hears it)", next(Facts.read("its 47, go")) == nil)
check("...nor a sum said plainly", next(Facts.read("forty plus seven")) == nil)

print("")
print("the registry is data")
local seen: { [string]: number } = {}
local clash: { string } = {}
local unclean: { string } = {}
for _, fact in Facts.KNOWN do
	for _, said in fact.says do
		if said ~= string.lower(said) or string.find(said, "'", 1, true) or string.find(said, "  ", 1, true) then
			table.insert(unclean, said)
		end
		if seen[said] ~= nil and seen[said] ~= fact.value then
			table.insert(clash, said)
		end
		seen[said] = fact.value
	end
end
check(`every phrase is lower case, no apostrophe ({table.concat(unclean, ", ")})`, #unclean == 0)
check(`no phrase has two values ({table.concat(clash, ", ")})`, #clash == 0)

print("")
print("null gate: ordinary chat")
-- The blind corpus (tests/heuristic.luau): 160 lines by someone who never saw
-- the word lists. A CEILING: a fact added later that makes ordinary chat read
-- as a code fails here, so it has to be chosen, not stumbled into.
local FALSE_CEILING = 0
local lines, falseReads = 0, {}
for line in string.gmatch(fs.readFile("tests/blind_chat.txt"), "[^\r\n]+") do
	lines += 1
	for number in Facts.read(line) do
		if string.match(number, "^%d%d$") then
			table.insert(falseReads, `"{line}" as {number}`)
		end
	end
end
check(`(guard) read the blind corpus ({lines} lines)`, lines == 160)
check(
	`no line of ordinary chat reads as a code through a fact ({#falseReads}: {table.concat(falseReads, "; ")})`,
	#falseReads <= FALSE_CEILING
)

print("")
print("through the Operator")
local pool = Round.dealSecrets(99)
local function operator(seen: { [number]: { [string]: string } })
	local op = Operator.new(pool)
	local log = { heard = {} :: { string }, spent = 0, known = 0 }
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
	op.onUnderstood = function(concept: string, _payload: string, _confidence: number, heard: string?)
		table.insert(log.heard, `{concept}:{heard or ""}`)
	end
	op.onCodeHeard = function()
		log.spent += 1
	end
	op.onKnown = function()
		log.known += 1
	end
	return op, log
end
do
	local seen = { [1] = { jack_number = "57" }, [2] = {} }
	local op, log = operator(seen)
	op:hear({ speaker = { UserId = 2 }, text = "bo its heinz ketchup", at = 1 } :: any)
	check("a player who has not seen 57 says heinz ketchup: nothing is heard", #log.heard == 0 and log.spent == 0)
	op:hear({ speaker = { UserId = 1 }, text = "bo its heinz ketchup", at = 2 } :: any)
	check(
		`its holder says it: read back as 57 and spent ({table.concat(log.heard, ", ")})`,
		log.heard[1] == "jack_number:57" and log.spent == 1
	)
	check("...and the Operator says everyone knows that one", log.known == 1)
end
do
	local seen = { [1] = { jack_number = "57" } }
	local op, log = operator(seen)
	op:hear({ speaker = { UserId = 1 }, text = "57, like heinz ketchup", at = 1 } :: any)
	check(
		`a code said plainly and as a fact is heard once, as said ({#log.heard} heard, {log.spent} spent, {log.known} known)`,
		#log.heard == 1 and log.spent == 1 and log.known == 0
	)
end
do
	-- The counting learner (DECISIONS D11) works "dozen" out from three restores,
	-- and then hears "five dozen" itself: that code is not also a known fact.
	local seen: { [number]: { [string]: string } } = { [1] = {} }
	local op, log = operator(seen)
	for i, taught in
		{ { "five dozen minus two", "58" }, { "two dozen and three", "27" }, { "four dozen and one", "49" } }
	do
		op:hear({ speaker = { UserId = 1 }, text = taught[1], at = i * 10 } :: any)
		op:creditCode(taught[2], i * 10, 1)
	end
	check(`(guard) it counts a dozen as 12 now ({op:knownValues().dozen})`, op:knownValues().dozen == 12)
	seen[1] = { jack_number = "60" }
	op:hear({ speaker = { UserId = 1 }, text = "five dozen", at = 100 } :: any)
	check(
		`a code heard through a learned word is spent once and not said to be known ({log.spent} spent, {log.known} known)`,
		log.spent == 1 and log.known == 0
	)
end
do
	-- A line whose code was heard as a fact is spent: kept, the counting learner
	-- would weigh it against the holder's next code ("five dozen minus two"
	-- before 48 would teach it that a dozen is 10).
	local seen: { [number]: { [string]: string } } = { [1] = { jack_number = "58" } }
	local op, log = operator(seen)
	op:hear({ speaker = { UserId = 1 }, text = "five dozen minus two", at = 1 } :: any)
	check("(guard) heard as a fact", log.known == 1)
	seen[1] = {}
	op:creditCode("48", 3, 1)
	local misread = false
	for _, row in op:countingRows() do
		misread = misread or row.value == 10
	end
	check("a line spent as a fact is not weighed at the holder's next restore", not misread)
end

Kit.finish()
