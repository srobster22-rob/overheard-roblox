--!strict
-- A word means something only if it is used for one thing. Run: lune run tests/meaning
--
-- What this file guards:
--   - A group's word for one station learns exactly as fast as it always did,
--     and still does when it is also mentioned before another station's
--     restore ("piano done, now the tuba").
--   - A word said before restores of every station (filler: "say", "mine",
--     "then") cancels out instead of being filed for whichever station was
--     restored first: crediting a phrase toward one concept takes the same
--     heat off its other meanings, unless the Operator has more evidence for
--     them (Operator.credit).
--   - The wall shows every understood word, each word once, grouped under
--     where it leads (Round.leadsTo), in rows that fit the panel.
-- Through the public surface: Operator.hear/credit/coolRound/snapshot,
-- Round.leadsTo and withLeads, Readout.lexiconRows, Hud, and the real Heuristic.

local Harness = require("./harness")

local rt = Harness.build()
local Operator = rt.require(rt.systems.Operator)
local Heuristic = rt.require(rt.systems.Heuristic)
local Round = rt.require(rt.systems.Round)
local Readout = rt.require(rt.shared.Readout)
local Config = rt.require(rt.shared.Config)
local Hud = rt.require(rt.shared.Hud)

local Kit = require("./kit")
local check = Kit.check

math.randomseed(143)
local pool = Round.dealSecrets(99)
local function secretOf(concept: string): any
	for _, secret in pool do
		if secret.concept == concept then
			return secret
		end
	end
	error(`no secret '{concept}'`)
end
local JACK, BREAKER = secretOf("jack_number"), secretOf("breaker")

-- Say each line at `at`, then credit `concept` at the same instant (full recency).
local function restore(op: any, lines: { string }, concept: string, at: number)
	for _, line in lines do
		op:hear({ speaker = { UserId = 1 } :: any, text = line, at = at })
	end
	op:credit(concept, at)
end
local function heatOf(op: any, phrase: string, concept: string): number
	for _, c in op:snapshot() do
		if c.phrase == phrase and c.concept == concept then
			return c.heat
		end
	end
	return 0
end

print("a group's word for one station learns as it always did")
do
	local op = Operator.new({ JACK, BREAKER })
	restore(op, { "the piano", "the piano go" }, JACK.concept, 10)
	check(
		`two uses before one restore: {Config.HeatPerCredit * 2} heat, as before`,
		math.abs(heatOf(op, "piano", JACK.concept) - Config.HeatPerCredit * 2) < 1e-9
	)
	restore(op, { "the piano", "the piano go" }, JACK.concept, 40)
	check("...and after two restores it is burned", heatOf(op, "piano", JACK.concept) == 1)
end

-- Four rounds of "piano" said twice before every Exchange Desk restore, and,
-- when `mentioned`, once more before the Cutoff's ("piano done, now the tuba"),
-- first or second. The jack's heat at the end of each round, before cooling.
local function nickname(mentioned: boolean, mentionedFirst: boolean): { number }
	local op = Operator.new({ JACK, BREAKER })
	local trail = {}
	local function cutoff(at: number)
		restore(op, if mentioned then { "piano done, now the tuba" } else {}, BREAKER.concept, at)
	end
	for round = 1, 4 do
		local base = round * 100
		if mentionedFirst then
			cutoff(base + 10)
		end
		restore(op, { "the piano", "the piano go" }, JACK.concept, base + 20)
		if not mentionedFirst then
			cutoff(base + 30)
		end
		table.insert(trail, heatOf(op, "piano", JACK.concept))
		op:coolRound(Config.CoolPerRound)
	end
	return trail
end
local function understoodBy(trail: { number }): number?
	for round, heat in trail do
		if heat >= Config.ActThreshold then
			return round
		end
	end
	return nil
end
do
	local alone = nickname(false, false)
	local after = nickname(true, false)
	local before = nickname(true, true)
	local same = true
	for round = 1, #alone do
		same = same and math.abs(alone[round] - after[round]) < 1e-9
	end
	local trails = `{table.concat(after, " ")} vs {table.concat(alone, " ")} alone`
	check(`a nickname also said before another station's restore learns as fast ({trails})`, same)
	local alsoFirst, aloneAt = understoodBy(before), understoodBy(alone) :: number
	check(
		`...and at most a round later when that restore comes first (round {alsoFirst}, alone {aloneAt})`,
		alsoFirst ~= nil and alsoFirst <= aloneAt + 1
	)
end

print("")
print("a word said before every station's restore means nothing in particular")
do
	local op = Operator.new({ JACK, BREAKER })
	local highest = 0
	for i = 1, 6 do
		local concept = if i % 2 == 1 then JACK.concept else BREAKER.concept
		restore(op, { "ok say when" }, concept, i * 30)
		highest = math.max(highest, heatOf(op, "say", JACK.concept), heatOf(op, "say", BREAKER.concept))
	end
	check(
		`filler used for both stations never reaches understood (highest {highest}, understood at {Config.ActThreshold})`,
		highest < Config.ActThreshold
	)
	check("...and does not pile up on either", highest <= Config.HeatPerCredit + 1e-9)
end
do
	-- Twice before every restore: each station's evidence ties the other's, and
	-- a tie is a debit.
	local op = Operator.new({ JACK, BREAKER })
	local highest = 0
	for i = 1, 6 do
		local concept = if i % 2 == 1 then JACK.concept else BREAKER.concept
		restore(op, { "ok say when", "say it" }, concept, i * 30)
		highest = math.max(highest, heatOf(op, "say", JACK.concept), heatOf(op, "say", BREAKER.concept))
	end
	check(
		`filler said twice before every restore is not filed either (highest {highest})`,
		highest < Config.ActThreshold
	)
end
do
	-- The two together: a nickname said only before its station keeps growing
	-- while the filler said with it everywhere does not.
	local op = Operator.new({ JACK, BREAKER })
	for i = 1, 4 do
		restore(op, { "say piano" }, JACK.concept, i * 30 - 10)
		restore(op, { "say it" }, BREAKER.concept, i * 30)
	end
	check("a nickname beside filler is still learned", heatOf(op, "piano", JACK.concept) >= Config.ActThreshold)
	check(
		"...while the filler is not",
		heatOf(op, "say", JACK.concept) < Config.ActThreshold
			and heatOf(op, "say", BREAKER.concept) < Config.ActThreshold
	)
end
do
	local op = Operator.new({ JACK, BREAKER })
	restore(op, { "the tuba" }, JACK.concept, 10)
	restore(op, { "the tuba" }, BREAKER.concept, 11)
	local rows = 0
	for _, c in op:snapshot() do
		if c.phrase == "tuba" and c.concept == JACK.concept then
			rows += 1
		end
	end
	check("a meaning taken to nothing leaves the register", rows == 0)
	check(
		"...but its evidence stays while the word has another meaning",
		op.evidence["tuba"] ~= nil and op.evidence["tuba"][JACK.concept] ~= nil
	)
	op:coolRound(Config.CoolPerRound)
	check("a word cooled out of every meaning is forgotten whole, evidence and all", op.evidence["tuba"] == nil)
end

print("")
print("a restore learns from the players who passed it (DECISIONS D14)")
-- PT5's repro (playtests/PT5/phone/repro_lexicon_misfile.txt): Ana (1) holds
-- the Cutoff, Bo (2) the Exchange Desk; Dee (4) and Ana enter them a second
-- apart. `seen` is what each player still holds.
local ANA, BO, DEE = 1, 2, 4
local function repro(boardFirst: boolean): any
	local seen: { [number]: { [string]: string } } = { [ANA] = { breaker = "85" }, [BO] = { jack_number = "86" } }
	local op = Operator.new({ JACK, BREAKER })
	op.seenCodes = function(userId: number)
		return seen[userId] or {}
	end
	op.names = function()
		return { ana = true, bo = true, cy = true, dee = true }
	end
	local function say(who: number, text: string, at: number)
		op:hear({ speaker = { UserId = who } :: any, text = text, at = at })
	end
	say(ANA, "dee flippy", 3)
	say(BO, "ana big desk", 5)
	local function breaker(at: number)
		seen[ANA] = {}
		op:credit(BREAKER.concept, at, ANA, DEE)
	end
	local function board(at: number)
		seen[BO] = {}
		op:credit(JACK.concept, at, BO, ANA)
	end
	if boardFirst then
		board(14)
		breaker(15)
	else
		breaker(14)
		board(15)
	end
	return op
end
for _, boardFirst in { false, true } do
	local op = repro(boardFirst)
	local order = if boardFirst then "the board first" else "the Cutoff first"
	check(
		`{order}: the board's word is the board's ("big" {heatOf(op, "big", JACK.concept)}, under the Cutoff {heatOf(
			op,
			"big",
			BREAKER.concept
		)})`,
		heatOf(op, "big", JACK.concept) > 0 and heatOf(op, "big", BREAKER.concept) == 0
	)
	check(
		`{order}: ...and the Cutoff's is the Cutoff's ("flippy" {heatOf(op, "flippy", BREAKER.concept)}, under the board {heatOf(
			op,
			"flippy",
			JACK.concept
		)})`,
		heatOf(op, "flippy", BREAKER.concept) > 0 and heatOf(op, "flippy", JACK.concept) == 0
	)
	check(
		`{order}: nobody's name is a word for either`,
		heatOf(op, "ana", BREAKER.concept) + heatOf(op, "ana", JACK.concept) + heatOf(op, "dee", BREAKER.concept) == 0
	)
end
do
	-- Without a holder or an entrant (a caller that cannot say), every line in
	-- the window is credited, as it always was.
	local op = Operator.new({ JACK, BREAKER })
	op:hear({ speaker = { UserId = 2 } :: any, text = "the piano", at = 1 })
	op:credit(JACK.concept, 2)
	check("(control) a restore with no holder named credits every line", heatOf(op, "piano", JACK.concept) > 0)
	local named = Operator.new({ JACK, BREAKER })
	named:hear({ speaker = { UserId = 1 } :: any, text = "ana, the piano", at = 1 })
	named:credit(JACK.concept, 2)
	check("(control) with no names to hand, a name can be learned", heatOf(named, "ana", JACK.concept) > 0)
	-- Words are kept as stems, and "chris" is kept as "chri": still a name.
	local stemmed = Operator.new({ JACK, BREAKER })
	stemmed.names = function()
		return { chris = true }
	end
	stemmed:hear({ speaker = { UserId = 1 } :: any, text = "chris, the piano", at = 1 })
	stemmed:credit(JACK.concept, 2)
	local chrisRows = 0
	for _, c in stemmed:snapshot() do
		if string.find(c.phrase, "chri", 1, true) then
			chrisRows += 1
		end
	end
	check(
		`a name whose stem differs ("chris") is still no word ({chrisRows} rows, "piano" {heatOf(
			stemmed,
			"piano",
			JACK.concept
		)})`,
		chrisRows == 0 and heatOf(stemmed, "piano", JACK.concept) > 0
	)
end

print("")
print("where each word leads")
check("a station's concept is named by its label", Round.leadsTo("jack_number") == "Exchange Desk")
check("...each station its own", Round.leadsTo("breaker") == "Cutoff" and Round.leadsTo("exit") == "Night Latch")
check("a concept with no station is never credited, and leads nowhere", Round.leadsTo("directory") == nil)
local giveaways: { string } = {}
for _, secret in pool do
	local label = Round.leadsTo(secret.concept)
	if label then
		local heard =
			Heuristic.conveyed({ speaker = { UserId = 1 }, text = label, at = 0 } :: any, pool :: any, {} :: any)
		if #heard > 0 then
			table.insert(giveaways, label)
		end
	end
end
check(`no label gives a concept away ({table.concat(giveaways, ", ")})`, #giveaways == 0)
local given = { { phrase = "piano", concept = "jack_number", heat = 0.5, sightings = 2 } }
local labelled = Round.withLeads(given :: any)
check(
	"the wall's copy is labelled and the register is not",
	labelled[1].leadsTo == "Exchange Desk" and (given[1] :: any).leadsTo == nil
)

print("")
print("the wall")
local function words(rows: { any }): { any }
	local out = {}
	for _, row in rows do
		if row.kind == "word" then
			table.insert(out, row)
		end
	end
	return out
end
local function shows(rows: { any }, phrase: string): boolean
	for _, row in rows do
		if row.kind == "word" and string.find(row.text, `"{phrase}"`, 1, true) then
			return true
		end
	end
	return false
end
do
	local entries = {}
	for i = 1, 20 do
		table.insert(entries, { phrase = `word{i}`, concept = "jack_number", heat = i / 40, leadsTo = "Exchange Desk" })
	end
	-- The same word for a second meaning, strong enough to make the list.
	table.insert(entries, { phrase = "word20", concept = "breaker", heat = 0.4, leadsTo = "Cutoff" })
	local shown = words(Readout.lexiconRows(entries))
	check(
		`at most {Readout.WALL_ROWS} words when none is understood (got {#shown} from 20)`,
		#shown == Readout.WALL_ROWS
	)
	check("...the strongest", shown[1].heat == 0.5 and shown[#shown].heat == 9 / 40)
	local word20 = 0
	for _, row in shown do
		if string.find(row.text, '"word20"', 1, true) then
			word20 += 1
		end
	end
	check("one row per word, the stronger meaning", word20 == 1 and shown[1].heat == 0.5)
end
do
	local entries = {}
	for i = 1, 15 do
		table.insert(entries, { phrase = `known{i}`, concept = "breaker", heat = 0.9, leadsTo = "Cutoff" })
	end
	table.insert(entries, { phrase = "cold", concept = "breaker", heat = 0.1, leadsTo = "Cutoff" })
	local shown = words(Readout.lexiconRows(entries))
	check(
		`every understood word is shown, however many ({#shown} of 15)`,
		#shown == 15 and not shows(Readout.lexiconRows(entries), "cold")
	)
end
do
	-- A two-word codeword, noticed as the phrases a sentence offers.
	local entries = {
		{ phrase = "tin", concept = "breaker", heat = 1, leadsTo = "Cutoff" },
		{ phrase = "the tin", concept = "breaker", heat = 1, leadsTo = "Cutoff" },
		{ phrase = "tin whistl", concept = "breaker", heat = 1, leadsTo = "Cutoff" },
		{ phrase = "whistl", concept = "breaker", heat = 0.64, leadsTo = "Cutoff" },
		{ phrase = "whistl is", concept = "breaker", heat = 0.64, leadsTo = "Cutoff" },
	}
	local rows = Readout.lexiconRows(entries)
	check(
		"a phrase holding a shorter one as hot is left to the shorter row",
		shows(rows, "tin") and shows(rows, "whistl") and not shows(rows, "the tin") and not shows(rows, "whistl is")
	)
	check("...so the codeword is two rows, both understood", #words(rows) == 2)
	check(
		"(control) a longer phrase HOTTER than the shorter one keeps its row",
		shows(Readout.lexiconRows({ entries[4], entries[3] }), "tin whistl")
	)
end
do
	local entries = {
		{ phrase = "kettl", concept = "jack_number", heat = 0.5, leadsTo = "Exchange Desk" },
		{ phrase = "tin", concept = "breaker", heat = 1, leadsTo = "Cutoff" },
		{ phrase = "blue kettl", concept = "jack_number", heat = 1, leadsTo = "Exchange Desk" },
	}
	local rows = Readout.lexiconRows(entries)
	local texts = {}
	for _, row in rows do
		table.insert(texts, row.text)
	end
	check(
		`words are grouped under where they lead, hottest group first ({table.concat(texts, " | ")})`,
		#rows == 5
			and rows[1].kind == "header"
			and rows[1].text == "-> Exchange Desk"
			and string.find(rows[2].text, '"blue kettl"', 1, true) ~= nil
			and string.find(rows[3].text, '"kettl"', 1, true) ~= nil
			and rows[4].text == "-> Cutoff"
	)
	-- The panel's list is its width less 8 px padding each side and the 2 px
	-- scrollbar; RobotoMono at 12 px is about 7.2 px a character.
	local fits = math.floor(((Hud.get("Lexicon") :: any).width - 18) / 7.2)
	local widest = 0
	local sample = Readout.lexiconRows({
		{ phrase = "kettl whistl", concept = "jack_number", heat = 1, leadsTo = "Exchange Desk" },
	})
	for _, row in sample do
		widest = math.max(widest, #row.text)
	end
	check(`an understood two-word row fits the panel ({widest} of {fits} characters)`, widest <= fits)
end

Kit.finish()
