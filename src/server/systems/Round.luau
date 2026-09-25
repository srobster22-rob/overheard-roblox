--!strict
-- Round flow and the objectives.
--
-- Design rule for every objective: ONE player can see the answer, ANOTHER must
-- act on it, and they are never in the same room. That is what makes players
-- audible. An objective a single player can solve alone is a bug in this game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Lexicon = require(ReplicatedStorage.Shared.Lexicon)
local Types = require(ReplicatedStorage.Shared.Types)

type Secret = Types.Secret

local Round = {}

-- The seed pool. `plain` is everything the Operator already understands for
-- that concept; players must get the idea across without any of it.
-- `payload` MUST name a room that World.build actually returns, or Pursuit
-- refuses the move and understanding has no visible effect. The rooms are
-- `Layout.rooms()` (board, archive, lobby); add a room there before a payload.
--
-- The owner's "middle net" (OWNER.md): the words and whole compounds players
-- reach for when the plain ones are forbidden are plain too: "cable",
-- "phone line", "circuit", "electrical", "doorway", "stairwell", "backdoor",
-- "phonebook", "take cover", "crouch", "underneath". Left out on purpose:
-- "run away", "wire" and a bare "line", the commonest panic chat, and any
-- prefix/suffix matching ("support" is not the port). New words go at the END
-- of a list: tests take `plain[1]` and `plain[2]` as each secret's own.
local SECRET_POOL: { Secret } = {
	{
		concept = "jack_number",
		plain = { "jack", "number", "socket", "port", "plug", "board", "switchboard", "cable", "phone line" },
		payload = "board",
	},
	{
		concept = "breaker",
		plain = { "breaker", "fuse", "fusebox", "power", "electric", "switch", "lever", "circuit", "electrical" },
		-- The Operator goes where the thing IS. The breaker panel is in the
		-- records room, so understanding "breaker" sends it there — which is
		-- also the room the reader is standing in.
		payload = "archive",
	},
	{
		concept = "exit",
		plain = {
			"exit",
			"door",
			"out",
			"outside",
			"street",
			"leave",
			"escape",
			"stair",
			"doorway",
			"stairwell",
			"backdoor",
		},
		-- The street door is in the lobby, so that is where it goes (DECISIONS D4).
		payload = "lobby",
	},
	{
		concept = "directory",
		plain = { "directory", "address", "book", "listing", "ledger", "name", "phonebook" },
		payload = "archive",
	},
	{
		concept = "hiding",
		plain = {
			"hide",
			"hiding",
			"closet",
			"locker",
			"cabinet",
			"under",
			"behind",
			"take cover",
			"crouch",
			"underneath",
		},
		payload = "archive",
	},
}

-- THE STATIONS. A physical place an objective can be solved, and the concept
-- players have to get across to solve it.
--
-- This table is the source of truth for a round. The secrets dealt to the
-- Operator are DERIVED from it (see `dealSecrets`), so every objective's
-- concept is one the Operator is listening for. Chosen apart, some rounds
-- would run an objective the Operator ignores: saying its answer out loud
-- would be free, and the monster would never move for the one thing players
-- have to discuss.
-- Never add a station without a secret whose `concept` matches; never add an
-- objective without a station. `tests/round.luau` enforces both.
export type Station = {
	id: string,
	concept: Types.ConceptId,
	-- Shown to the holder only. Takes the answer via string.format.
	prompt: string,
	-- The ProximityPrompt verb at the physical station.
	actionText: string,
	-- The ProximityPrompt name over it. Shown to everyone near it, so it may
	-- give no concept away (tests/wiring.luau checks every one).
	label: string,
}

local STATIONS: { Station } = {
	{
		id = "board",
		concept = "jack_number",
		-- No word here may give away any concept, this station's own included:
		-- the holder reads it aloud. "out" is plain language for `exit`, so it
		-- would send the Operator to the lobby, a room this prompt is not about,
		-- and that is not a rule anyone can learn. "jack" would hand the Operator
		-- this station's own concept. `tests/round.luau` asserts it against the
		-- live pool rather than trusting this comment.
		prompt = "A caller is waiting. Patch them through to %s.",
		actionText = "Patch",
		label = "Exchange Desk",
	},
	{
		id = "breaker",
		concept = "breaker",
		-- Not even this station's own concept: the holder reads this aloud to
		-- whoever throws it, so "breaker" would hand the Operator the word. It
		-- says "Cutoff", the station's label, instead.
		prompt = "Cutoff %s dropped. Someone has to throw it back.",
		actionText = "Throw",
		label = "Cutoff",
	},
	{
		-- The third line, in the third room (DECISIONS D4). The street door's
		-- night latch, on the lobby's far wall, off the passage from the
		-- corridor's midpoint. No word here conveys a concept (tests/round.luau).
		id = "latch",
		concept = "exit",
		prompt = "The night latch wants %s. Someone has to turn it.",
		actionText = "Turn",
		label = "Night Latch",
	},
}

Round.STATIONS = STATIONS

-- Secrets dealt beyond the stations' own: things the Operator understands that
-- no objective needs, so the safe vocabulary is never simply "everything except
-- the station words". One: three stations leave two concepts over, so which
-- one is dealt still varies from round to round.
local AMBIENT_SECRETS = 1

-- How many secrets a round deals: every station's, plus the ambient ones. The
-- server, the soak and the playtest bots all deal this, so they play one game.
function Round.secretsPerRound(): number
	return #STATIONS + AMBIENT_SECRETS
end

-- Fisher-Yates, in place. Exported so tests can prove every element reaches
-- every position on a list longer than the ambient pool: that pool is two
-- long, where a narrowed loop would be indistinguishable.
function Round.shuffle<T>(list: { T })
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
end

-- What the Operator is listening for this round. Every station's concept is
-- guaranteed in; `count` is a FLOOR that ambient extras are shuffled up to, not
-- a cap that can squeeze a station's concept out.
function Round.dealSecrets(count: number): { Secret }
	local byConcept: { [string]: Secret } = {}
	for _, secret in SECRET_POOL do
		byConcept[secret.concept] = secret
	end

	local out: { Secret } = {}
	local taken: { [string]: boolean } = {}
	for _, station in STATIONS do
		local secret = byConcept[station.concept]
		if not secret then
			error(`station '{station.id}' wants concept '{station.concept}', which no secret carries`)
		end
		table.insert(out, secret)
		taken[station.concept] = true
	end

	-- Then ambient secrets: things it understands that no objective needs, so
	-- the safe vocabulary is not simply "everything except the station words".
	local rest: { Secret } = {}
	for _, secret in SECRET_POOL do
		if not taken[secret.concept] then
			table.insert(rest, secret)
		end
	end
	Round.shuffle(rest)
	for _, secret in rest do
		if #out >= count then
			break
		end
		table.insert(out, secret)
	end
	return out
end

-- The Operator's whole vocabulary of spoken lines. It is never threatening.
-- Politeness is the instrument.
Round.LINES = {
	-- Neither this nor `givingUp` may say "number": a player quoting the
	-- Operator would hand it the jack. The owner's rule (OWNER.md).
	greeting = "Operator. Go ahead, please.",
	-- Said to the player it just took. Polite, procedural, and the worst thing
	-- it could say: you are on the line now, and it is holding it.
	onTheLine = "Hold the line, please.",
	-- It has lost interest and is walking back out. A DISTINCT sentence: `busy`
	-- is the keypad's private rejection, and reusing it here would make two
	-- unrelated events render as one line.
	givingUp = "I'll try that call again later.",
	-- Everyone present is on the line: the round is LOST. Distinct from
	-- `completed` (won) and `taken` (it arrived): three different events must
	-- not share one sentence.
	lost = "I'm sorry, your call cannot be completed as dialled.",
	understood = "I have that party for you.",
	-- And the call going through, said to everyone: the Operator has been
	-- given a name and a room. Distinct from `connecting`, which is what it
	-- says when it understood something SAID -- the whole point of the
	-- Supervisor is that this one is for saying nothing.
	traced = "I have a silent line. Putting you through.",
	connecting = "I'm connecting you now.",
	busy = "That line is busy.",
	-- It reached the room it understood. Said to everyone, because everyone
	-- needs to know it is here.
	taken = "Go ahead, caller.",
	-- The round is WON. Not `taken`: the client's `onHeard` gets only the
	-- sentence, so the monster arriving in your room and the group winning must
	-- not share one. Kept in register -- every line here is real switchboard
	-- phrasing, and the operator's sign-off for a call that went through is
	-- exactly this.
	completed = "Your call has been completed.",
	-- Every line is restored and the outside call is ringing. Polite, and a
	-- clock: when the moment is over it comes for the lobby. Kept clear of
	-- "the line", which is what being caught is called.
	ringing = "Ringing your party now. One moment, please.",
	-- A wrong code that rang through: said to everyone, because the Operator is
	-- now walking to that station's room.
	wrongParty = "The party you have dialled is not in service.",
	-- The Operator has worked out a word the group uses as a number (DECISIONS
	-- D11). It names no word (the owner's rule, OWNER.md): the wall shows which.
	-- No "from now on": an unused word cools like any other.
	counted = "Thank you, caller. I will count it that way.",
	-- The group's letters are understood (DECISIONS D12); the wall shows which.
	lettered = "Thank you, caller. I have your letters.",
	-- A way of passing codes is one restore short of understood (DECISIONS
	-- D13): the warning, said to everyone, before it can read that way.
	noting = "One moment, caller. Let me write that down.",
	-- Understood: codes said with the digits turned round, and one digit a
	-- message. Each says which way, so a group knows what stopped working.
	turned = "Thank you, caller. I will take it the other way round.",
	apart = "Take your time, caller. I will wait for the other half.",
}

-- Where a concept brings the Operator, as the wall names it: the station's own
-- label, the name players see on its prompt. Only a station's concept is ever
-- credited (a restore credits its objective's concept), so a concept with no
-- station leads nowhere the wall could show.
function Round.leadsTo(concept: string): string?
	for _, station in STATIONS do
		if station.concept == concept then
			return station.label
		end
	end
	return nil
end

-- Where the Operator is, as the Your Line panel tells it:
--   * waiting in a room: the label of that room's station, the name the wall's
--     headers use;
--   * in the way out's room, or walking to it: `wayOut`, so the way-out note
--     does not send everyone there to be taken.
-- Walking anywhere else it is nowhere the panel says: the hum is the tell. At
-- its post between rounds, or walking back to it, it is in no room at all.
function Round.holding(state: string, room: string?, wayOutRoom: string): Types.Holding?
	if room == nil or not (state == "arrived" or state == "approaching" or state == "closing") then
		return nil
	end
	local label: string? = nil
	if state == "arrived" then
		for _, station in STATIONS do
			if Layout.stationRoom(station.id) == room then
				label = station.label
			end
		end
	end
	local wayOut = room == wayOutRoom
	if label == nil and not wayOut then
		return nil
	end
	return { label = label, wayOut = wayOut }
end

-- The wall's header for the words the group uses as numbers. Such a word
-- brings the Operator to whichever station's code it is used to say.
Round.COUNTING_LEADS = "counts as a number"
-- And for the ways the group passes its codes (Operator.methodRows).
Round.METHOD_LEADS = "how you pass codes"

-- Everything the wall shows: the station words, each told where it leads; the
-- words the group uses as numbers (Operator.countingRows); and the ways it
-- passes codes (Operator.methodRows), each under its own header. The server
-- and tools/sim both send this.
function Round.wallRows(
	stationWords: { Types.Coinage },
	counting: { Types.Coinage },
	methods: { Types.Coinage }?
): { Types.Coinage }
	local rows = Round.withLeads(stationWords)
	local function under(header: string, group: { Types.Coinage })
		for _, row in group do
			local labelled = table.clone(row)
			labelled.leadsTo = header
			table.insert(rows, labelled)
		end
	end
	under(Round.COUNTING_LEADS, counting)
	under(Round.METHOD_LEADS, methods or {})
	return rows
end

-- The wall's rows, each told where it leads. Copies, so the Operator's own
-- register is never written by the display.
function Round.withLeads(rows: { Types.Coinage }): { Types.Coinage }
	local out: { Types.Coinage } = {}
	for _, row in rows do
		local labelled = table.clone(row)
		labelled.leadsTo = Round.leadsTo(row.concept)
		table.insert(out, labelled)
	end
	return out
end

-- What the Operator says when it understood something. When a CODE moved it,
-- it reads the code back first, digit by digit the way an operator reads a
-- number ("Four seven. I have that party for you."), so a group learns that
-- the number itself was heard. Only a code: it is spent the moment it is heard
-- and not dealt again that round while any other code is left, so a player
-- echoing the read-back gives nothing away. A plain word is never read back
-- (DECISIONS D9): the owner's rule (OWNER.md) is that no line of the
-- Operator's may hand a player a live word to echo.
function Round.readBack(heard: string?): string
	if heard == nil or not string.match(heard, "^%d+$") then
		return Round.LINES.understood
	end
	local digits: { string } = {}
	for digit in string.gmatch(heard, "%d") do
		table.insert(digits, Lexicon.DIGIT_WORDS[(tonumber(digit) :: number) + 1])
	end
	local spoken = table.concat(digits, " ")
	return `{string.upper(string.sub(spoken, 1, 1))}{string.sub(spoken, 2)}. {Round.LINES.understood}`
end

return Round
