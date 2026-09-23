--!strict
-- The code has to be said. Run: lune run tests/codes
--
-- What this file guards: a line's code is a secret like its station's words.
--   - It is heard in every form a person types two digits in, and not in a
--     form that needs context only the group has (the bypass list, pinned).
--   - Heard, it is spent: the holder gets a new code, so saying it and typing
--     it before the Operator arrives wins nothing, and a spent code never
--     comes back that round.
--   - The deal is shuffled, so who said a code does not say which station it
--     is for; the holder has to name the station.
--   - Past a player's one free miss a round, a wrong code rings through and
--     the Operator walks to that station's room, so trying a code at every
--     station is a gamble rather than a protocol.
--   - The Operator reads a heard code back, and echoing that line gives
--     nothing away.
-- Everything goes through the public surface: Lexicon.numbersIn,
-- Heuristic.conveyed, Operator.hear, the Objectives board, Round.readBack, and
-- tools/sim.luau (the real server modules in the server's order).

local process = require("@lune/process")

local Harness = require("./harness")
local Sim = require("../tools/sim")

local rt = Harness.build()
local Lexicon = rt.require(rt.shared.Lexicon)
local Heuristic = rt.require(rt.systems.Heuristic)
local Operator = rt.require(rt.systems.Operator)
local Objectives = rt.require(rt.systems.Objectives)
local Round = rt.require(rt.systems.Round)
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

math.randomseed(142)

print("the bypass list, pinned: every form of 47 a person types")
-- Each of these needs no shared context, so each must be heard. A form that
-- slips through here is a protocol a group can use forever.
local HEARD = {
	"47",
	"its 47",
	"4 7",
	"4-7",
	"4.7",
	"four seven",
	"forty seven",
	"forty-seven",
	"fortyseven",
	"forty 7",
	"4 seven",
	"f0rty s3ven",
	"door47",
	"47door",
	"4 then 7",
	"4 and then 7",
	"40 plus 7",
	"40+7",
	"50-3",
	"50 minus 3",
	"7 add 40",
	"74 backwards",
	"reversed 74",
	"047",
	"0047",
	"x47",
	"a47",
	"47a",
	"four7",
	"4seven",
	"fourseven",
	"40 7",
	"40 and 7",
	"7 more than 40",
	"3 less than 50",
	"60 take away 13",
	"7 4 backwards",
	"74 but backwards",
	"the reverse of 74",
	"4 and then a 7",
}
for _, text in HEARD do
	check(`'{text}' is read as 47`, Lexicon.numbersIn(text)["47"] == true)
end

print("")
print("...and what it cannot read")
-- A number only the group knows, a different number, and digits too far apart
-- to be one thought. `Lexicon.DIGIT_GAP` sets the last one.
local UNHEARD = {
	"bo's age plus 34",
	"60 take away the usual",
	"seven four",
	"147",
	"4 and after that its 7",
	"wait 2 more",
}
for _, text in UNHEARD do
	check(`'{text}' is not read as 47`, Lexicon.numbersIn(text)["47"] == nil)
end
check("a teen is read", Lexicon.numbersIn("fifteen")["15"] == true)
check("a tens word alone is read", Lexicon.numbersIn("forty")["40"] == true)

print("")
print("a live code is plain language for its line")
local jack = { concept = "jack_number", plain = { "jack" }, payload = "board" }
local exit = { concept = "exit", plain = { "exit", "door" }, payload = "lobby" }
local secrets = { jack, exit }
local codes = { jack_number = "47", exit = "82" }
local function conveyed(text: string, withCodes: { [string]: string }?, lexicon: { any }?): { any }
	return Heuristic.conveyed(
		{ speaker = { UserId = 1 }, text = text, at = 0 } :: any,
		secrets :: any,
		(lexicon or {}) :: any,
		withCodes
	)
end
local g = conveyed("its 47", codes)
check(
	"a live code said aloud is understood as its line's concept",
	#g == 1 and g[1].concept == "jack_number" and g[1].confidence == 1
)
check("...and marked as the code itself", #g == 1 and g[1].byCode == true and g[1].heard == "47")
check("a number that is no live code conveys nothing", #conveyed("its 52", codes) == 0)
check("with no codes dealt, a number conveys nothing", #conveyed("its 47", nil) == 0)
local w = conveyed("the jack", codes)
check(
	"a plain word is still understood, and is not the code",
	#w == 1 and w[1].byCode == false and w[1].heard == "jack"
)
local both = conveyed("jack 47", codes)
check("a plain word said with the code is the code: it is spent", #both == 1 and both[1].byCode == true)
check("two codes in one line give both lines away", #conveyed("47 and 82", codes) == 2)
local coined = conveyed(
	"the piano",
	codes,
	{ { phrase = Lexicon.stem("piano"), concept = "jack_number", heat = 1, sightings = 4 } }
)
check("a group's own word carries no text to say back", #coined == 1 and coined[1].heard == nil)
local function conveys(text: string, concept: string): boolean
	for _, u in conveyed(text, codes) do
		if u.concept == concept then
			return true
		end
	end
	return false
end
check("a station's word glued to a code is heard", conveys("go to the door48", "exit"))
check("...and a respelled word is still heard, not split", conveys("go to the ex17", "exit"))

print("")
print("every plain word respelled is still heard")
-- The reading that splits a glued code once cost 18 of 56 respellings, the
-- ones with digits at an end ("ex17", "sock37"). Swept over the whole pool.
local LEET_OF: { [string]: string } = { o = "0", i = "1", e = "3", a = "4", s = "5", t = "7" }
local pool = Round.dealSecrets(99)
local tried, lost = 0, {}
for _, secret in pool do
	for _, word in secret.plain do
		if string.find(word, " ", 1, true) then
			continue
		end
		local forms: { string } =
			{ (string.gsub(word, "%a", function(c: string): string
				return LEET_OF[c] or c
			end)) }
		local n = #word
		local a, b = string.sub(word, n - 1, n - 1), string.sub(word, n, n)
		if LEET_OF[a] and LEET_OF[b] then
			table.insert(forms, string.sub(word, 1, n - 2) .. LEET_OF[a] .. LEET_OF[b])
		end
		local c, d = string.sub(word, 1, 1), string.sub(word, 2, 2)
		if LEET_OF[c] and LEET_OF[d] then
			table.insert(forms, LEET_OF[c] .. LEET_OF[d] .. string.sub(word, 3))
		end
		for _, form in forms do
			if form ~= word then
				tried += 1
				local heardIt = false
				for _, u in
					Heuristic.conveyed(
						{ speaker = { UserId = 1 }, text = `the {form} now`, at = 0 } :: any,
						pool :: any,
						{} :: any,
						{}
					)
				do
					heardIt = heardIt or u.concept == secret.concept
				end
				if not heardIt then
					table.insert(lost, `{form} ({word})`)
				end
			end
		end
	end
end
check(`(guard) respellings tried ({tried})`, tried >= 40)
check(`every respelling is heard ({#lost} lost: {table.concat(lost, ", ")})`, #lost == 0)

print("")
print("the Operator asks for the codes when it hears")
local live = { jack_number = "47" }
local op = Operator.new(secrets :: any)
op.liveCodes = function()
	return live
end
local spentConcepts: { string } = {}
local lastHeard: string? = nil
op.onCodeHeard = function(concept: string)
	table.insert(spentConcepts, concept)
end
op.onUnderstood = function(_concept: string, _payload: string, _confidence: number, heard: string?)
	lastHeard = heard
end
local function say(text: string, at: number)
	op:hear({ speaker = { UserId = 1 } :: any, text = text, at = at })
end
say("its 47", 1)
check("hearing a live code reports it spent", #spentConcepts == 1 and spentConcepts[1] == "jack_number")
check("...and says what moved it", lastHeard == "47")
live.jack_number = "19"
say("its 47", 2)
check("a replaced code is not heard: the codes are asked for at the moment of hearing", #spentConcepts == 1)
say("the jack", 3)
check("a plain word is not a spent code", #spentConcepts == 1)

print("")
print("the deal is shuffled, so seat order names no station")
local PLAYERS = { 1, 2, 3, 4 }
local DEALS = 400
local deck = Objectives.new()
deck:add("a", "exit", "p")
deck:add("b", "breaker", "p")
deck:add("c", "jack_number", "p")
local held: { [string]: { [number]: number } } = { a = {}, b = {}, c = {} }
local nextSeat, sameCode = 0, 0
for _ = 1, DEALS do
	deck:reset()
	deck:deal(PLAYERS)
	for _, line in deck.list do
		local h = line.holder :: number
		held[line.id][h] = (held[line.id][h] or 0) + 1
	end
	local first, second = deck.list[1].holder :: number, deck.list[2].holder :: number
	if second == (first % #PLAYERS) + 1 then
		nextSeat += 1
	end
	local answers = {}
	for _, line in deck.list do
		if answers[line.answer] then
			sameCode += 1
		end
		answers[line.answer] = true
	end
end
local least = DEALS
for _, byPlayer in held do
	for _, id in PLAYERS do
		least = math.min(least, byPlayer[id] or 0)
	end
end
check(`every player holds every line in at least 15% of deals (least {least} of {DEALS})`, least >= DEALS * 0.15)
-- Dealt in a rotation, the second line's holder sat right after the first's
-- every time. Shuffled, a quarter to a third of the time.
check(
	`the next seat holds the next line only by chance ({nextSeat} of {DEALS})`,
	nextSeat > DEALS * 0.15 and nextSeat < DEALS * 0.5
)
check(`no two lines are ever on one code ({sameCode} of {DEALS} deals)`, sameCode == 0)

print("")
print("a heard code is spent")
local board = Objectives.new()
board:add("a", "exit", "p")
board:add("b", "breaker", "p")
board:deal({ 1, 2 })
local line = board:get("a") :: any
local before, holder = line.answer, line.holder
local ACTOR = 3
for _ = 1, Config.GuessesBeforeLockout - 1 do
	board:submit("a", ACTOR, "00", 0)
end
check("rerolling a line returns it", board:reroll("exit") == line)
check("...with a new code", line.answer ~= before)
check("...for the same holder", line.holder == holder)
local jam = board:submit("a", ACTOR, "00", 0)
check(
	"...and the actor's misses stay with the actor: the next miss jams",
	string.find(jam.reason or "", "jammed", 1, true) ~= nil
)
check("...and it is no other line's code", line.answer ~= (board:get("b") :: any).answer)
local heardCodes = { [before] = true }
local cameBack = 0
for _ = 1, 40 do
	heardCodes[line.answer] = true
	board:reroll("exit")
	if heardCodes[line.answer] then
		cameBack += 1
	end
end
check(`a code heard this round never comes back this round ({cameBack} came back)`, cameBack == 0)
local endless = true
for _ = 1, 200 do
	local ok = board:reroll("exit") ~= nil and string.match(line.answer, "^%d%d$") ~= nil
	endless = endless and ok
end
check("a holder who says their own code 200 times still gets a code every time", endless)
check("a line with no such concept is not rerolled", board:reroll("hiding") == nil)
local forgotten = Objectives.new()
forgotten:add("a", "exit", "p")
forgotten:deal({ 1 })
local heardOnce = (forgotten:get("a") :: any).answer
forgotten:reroll("exit")
check(
	"(guard) this round, a heard code is refused as overheard",
	forgotten:submit("a", 2, heardOnce, 0).reason == Objectives.OVERHEARD
)
forgotten:reset()
forgotten:deal({ 1 })
local afresh = forgotten:submit("a", 2, heardOnce, 0)
check(
	"a new round forgets which codes were heard: it is an ordinary miss again",
	afresh.reason ~= Objectives.OVERHEARD or afresh.ok
)

print("")
print("one station per concept, so a code read back is the code replaced")
local concepts: { [string]: boolean } = {}
local shared = 0
for _, station in Round.STATIONS do
	if concepts[station.concept] then
		shared += 1
	end
	concepts[station.concept] = true
end
check(`no two stations share a concept ({shared} shared)`, shared == 0)

print("")
print("a restored line's code is no secret any more")
local solving = Objectives.new()
solving:add("a", "exit", "p")
solving:add("b", "breaker", "p")
solving:deal({ 1, 2 })
local a = solving:get("a") :: any
check("(guard) an unsolved line's code is live", solving:liveCodes().exit == a.answer)
local actor = if a.holder == 1 then 2 else 1
check("(guard) the other player restores it", solving:submit("a", actor, a.answer, 0).ok)
check("a restored line's code is not listened for", solving:liveCodes().exit == nil)
check("...while the other line's still is", solving:liveCodes().breaker == (solving:get("b") :: any).answer)

print("")
print("a wrong code past the free one rings through")
local dials = Objectives.new()
dials:add("a", "exit", "p")
dials:add("b", "breaker", "p")
dials:deal({ 1, 2 })
local GUESSER, OTHER = 9, 8
local first = dials:submit("a", GUESSER, "00", 0)
check(
	`a player's first wrong code of the round is free ({Config.FreeWrongDials} free)`,
	not first.ok and not first.ringsThrough
)
local second = dials:submit("b", GUESSER, "00", 0)
check("...the next, at ANY station, rings through", not second.ok and second.ringsThrough == true)
local third = dials:submit("a", GUESSER, "00", 0)
check("...and so does every one after", third.ringsThrough == true)
check("the free miss is each player's own", not dials:submit("a", OTHER, "00", 0).ringsThrough)
local jammer = 7
local last: any = nil
for _ = 1, Config.GuessesBeforeLockout do
	last = dials:submit("b", jammer, "00", 0)
end
check(
	"a wrong code that jams the line rings through too",
	string.find(last.reason, "jammed", 1, true) ~= nil and last.ringsThrough == true
)
dials:reset()
dials:deal({ 1, 2 })
check("a new round gives the free miss back", not dials:submit("a", GUESSER, "00", 0).ringsThrough)

print("")
print("typing a code that was overheard says so, and costs nothing")
local slip = Objectives.new()
slip:add("a", "exit", "p")
slip:deal({ 1 })
local slipLine = slip:get("a") :: any
local said = slipLine.answer
slip:reroll("exit")
local late = slip:submit("a", 2, said, 0)
check("a code that was overheard is refused with its own note", not late.ok and late.reason == Objectives.OVERHEARD)
check("...which is not the dead line a typo gets", late.reason ~= "that line is dead")
check("...and it is no fault, so the Operator says nothing", late.fault == false and not late.ringsThrough)
check("...and costs no miss", slipLine.misses[2] == nil)
check("(control) a real typo is still a miss", slip:submit("a", 2, "00", 0).reason == "that line is dead")
check("(control) ...and the typo after it rings through", slip:submit("a", 2, "01", 0).ringsThrough == true)

print("")
print("it reads a heard code back, and only a code")
check("a heard code is read back digit by digit", Round.readBack("47") == `Four seven. {Round.LINES.understood}`)
check("a plain word is never read back (the owner's answer to R93)", Round.readBack("exit") == Round.LINES.understood)
check("with nothing heard, the line is said bare", Round.readBack(nil) == Round.LINES.understood)

print("")
print("played: saying the code and typing it wins nothing")
-- The whole exchange on the sim, in the server's order.
local sim = Sim.new(7)
sim.trace = function() end
sim:begin()
local desk = sim.board:get("board")
local deskHolder = desk.holder
local told = desk.answer
local deskActor = 0
for _, id in sim.present do
	if id ~= deskHolder and not desk.seenBy[id] then
		deskActor = id
		break
	end
end
check("(guard) somebody else can work the board line", deskActor ~= 0)
sim:say(deskHolder, `its {told}`)
check(
	"a code said aloud sends the Operator to its station's room",
	sim.pursuit.targetName == Sim.Layout.stationRoom("board")
)
check("...and is spent: the holder's panel shows a new code", desk.answer ~= told and desk.holder == deskHolder)
sim:move(deskActor, "board")
local typed = sim:submit(deskActor, "board", told)
check("typing the code that was said is refused", not typed.ok)
local understood = sim.stats.understood
sim:say(deskActor, Sim.Round.readBack(told))
check("a player echoing the read-back gives nothing away", sim.stats.understood == understood)
local hiddenCode = desk.answer
sim:say(deskHolder, `its {(tonumber(hiddenCode) :: number) + 13} take away the usual`)
check("a code hidden in the group's own context is not heard", desk.answer == hiddenCode)
check("...and it opens the line", sim:submit(deskActor, "board", hiddenCode).ok)

print("")
print("played: guessing a station rings the Operator to it")
local guess = Sim.new(11)
guess.trace = function() end
guess:begin()
local latch = guess.board:get("latch")
local guesser = 0
for _, id in guess.present do
	if not latch.seenBy[id] then
		guesser = id
		break
	end
end
guess:move(guesser, "lobby")
guess:submit(guesser, "latch", "00")
check("(control) the first wrong code does not call it", guess.pursuit.targetName ~= "lobby")
local rang = guess:submit(guesser, "latch", "01")
check(
	"the second sends the Operator to that station's room",
	rang.ringsThrough == true and guess.pursuit.targetName == "lobby"
)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
