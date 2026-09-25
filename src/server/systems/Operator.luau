--!strict
-- The Operator: the listener, and the thing that learns.
--
-- Two responsibilities, and it is worth keeping them straight:
--   1. COMPREHENSION - did that utterance convey a secret right now?
--   2. ACQUISITION   - which unfamiliar phrase is starting to mean something?
--
-- (2) is the game. A monster that only did (1) would be a keyword filter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Lexicon = require(ReplicatedStorage.Shared.Lexicon)
local Numerals = require(ReplicatedStorage.Shared.Numerals)
local Facts = require(ReplicatedStorage.Shared.Facts)
local Heuristic = require(script.Parent.Heuristic)
local Method = require(script.Parent.Method)

type Secret = Types.Secret
type Coinage = Types.Coinage
type Utterance = Types.Utterance
type Understanding = Types.Understanding

type Observation = {
	terms: { string },
	at: number,
	speaker: Player,
}

-- A word the group uses as a number (DECISIONS D11). Each value it has been
-- worked out to have carries its own heat; the strongest is the one on the wall.
type Counting = {
	values: { [number]: number },
	-- The word as it was first typed, and who typed it (the wall's filter).
	said: string,
	coinedBy: number,
}

-- The group's alphabet (DECISIONS D12). How often each letter has spelled each
-- digit, and ONE heat for the whole dial: a letter spells about 0.6 digits a
-- round, too few for a heat of its own to outrun the owner's cooling.
type Dial = {
	evidence: { [string]: { [number]: number } },
	heat: number,
	coinedBy: number?,
}

local Operator = {}
Operator.__index = Operator

export type Operator = typeof(setmetatable(
	{} :: {
		secrets: { Secret },
		lexicon: { Coinage },
		observations: { Observation },
		-- Coinages credited since the last round boundary; see `coolRound`.
		creditedSinceBoundary: { [Coinage]: boolean },
		-- Every credit each meaning of a phrase has had, by phrase then concept;
		-- see `contrast`. Unlike heat it does not cool.
		evidence: { [string]: { [string]: number } },
		-- Every line said since the round began, as said, for `creditCode`;
		-- and the words the group uses as numbers.
		said: { { text: string, at: number, speaker: number } },
		counting: { [string]: Counting },
		countedSinceBoundary: { [string]: boolean },
		-- The letters the group spells codes with; see `creditCode`.
		dial: Dial,
		dialUsed: boolean,
		-- How the group passes its codes (DECISIONS D13).
		method: Method.Method,
		backend: Types.ComprehensionBackend,
		-- Each concept's live code right now, asked for at the moment something
		-- is said, so a code re-dealt or re-rolled is never heard stale.
		liveCodes: (() -> { [string]: string })?,
		-- The live codes one player has seen, by concept: the only codes a way
		-- the group taught it reads in that player's lines (Method).
		seenCodes: ((userId: number) -> { [string]: string })?,
		-- The present players' names, lower case: one that opens a sentence is
		-- who is spoken to, not a letter (Method).
		names: (() -> { [string]: boolean })?,
		-- `heard` is what moved it, when that is the server's own text (Types).
		onUnderstood: (concept: string, payload: string, confidence: number, heard: string?) -> ()?,
		onBurned: (coinage: Coinage) -> ()?,
		-- The live code for `concept` was said aloud.
		onCodeHeard: (concept: string) -> ()?,
		-- A word the group uses as a number has just been understood.
		onCounted: (key: string, value: number) -> ()?,
		-- The group's letters have just been understood.
		onLettered: (() -> ())?,
		-- A way of passing codes is one restore short of understood ("noting"),
		-- or understood; `says` is what it says, a key in Round.LINES.
		onMethod: ((kind: string, way: string, says: string) -> ())?,
		-- A code passed as a fact everyone knows was just heard.
		onKnown: ((concept: string) -> ())?,
	},
	Operator
))

function Operator.new(secrets: { Secret }): Operator
	return setmetatable({
		secrets = secrets,
		lexicon = {},
		observations = {},
		creditedSinceBoundary = {},
		evidence = {},
		said = {},
		counting = {},
		countedSinceBoundary = {},
		dial = { evidence = {}, heat = 0, coinedBy = nil },
		dialUsed = false,
		method = Method.new(),
		backend = Heuristic :: any,
		liveCodes = nil,
		seenCodes = nil,
		names = nil,
		onUnderstood = nil,
		onBurned = nil,
		onCodeHeard = nil,
		onCounted = nil,
		onLettered = nil,
		onMethod = nil,
		onKnown = nil,
	}, Operator)
end

-- What the Operator walks to for a concept: its payload in the secret pool.
local function payloadOf(self: Operator, concept: string): string
	for _, secret in self.secrets do
		if secret.concept == concept then
			return secret.payload
		end
	end
	return ""
end

-- A present player's name is who is spoken to, never a word for a station
-- (DECISIONS D14): "ana you still ok?" must not teach it that "ana" means the
-- breaker. Terms are stems, so each name is matched both as said and stemmed.
local function withoutNames(terms: { string }, names: { [string]: boolean }?): { string }
	if names == nil or next(names) == nil then
		return terms
	end
	local named: { [string]: boolean } = {}
	for name in names do
		named[name] = true
		named[Lexicon.stem(name)] = true
	end
	local out: { string } = {}
	for _, term in terms do
		local holdsName = false
		for word in string.gmatch(term, "%S+") do
			holdsName = holdsName or named[word] == true
		end
		if not holdsName then
			table.insert(out, term)
		end
	end
	return out
end

-- A code heard in a line, by one of the readers that take only the codes the
-- speaker has seen: read back, spent and walked to, like a code said aloud.
-- `understood` holds the concepts this line already moved it for (by code,
-- true; by a word, false): a code is spent once, and the Operator is not sent
-- twice by one line. Returns whether it spent the code.
local function spendHeard(self: Operator, concept: string, code: string, understood: { [string]: boolean }): boolean
	if understood[concept] == true then
		return false
	end
	if understood[concept] == nil and self.onUnderstood then
		(self.onUnderstood :: any)(concept, payloadOf(self, concept), 1, code)
	end
	understood[concept] = true
	if self.onCodeHeard then
		(self.onCodeHeard :: any)(concept)
	end
	return true
end

-- A code passed a way the group has taught it (DECISIONS D13). Returns every
-- hit (for `Method.spend`), the line, and whether it spent a code.
local function hearWays(
	self: Operator,
	utterance: Utterance,
	understood: { [string]: boolean },
	names: { [string]: boolean }?,
	own: { [string]: string }
): ({ Method.Hit }, Method.Line, boolean)
	local hits, line = Method.read(self.method, utterance.speaker.UserId, utterance.text, utterance.at, own, names)
	local spent = false
	for _, hit in hits do
		spent = spendHeard(self, hit.concept, hit.code, understood) or spent
	end
	return hits, line, spent
end

-- A code passed as a fact everyone knows (DECISIONS D15): "heinz ketchup" for
-- 57, "a deck of cards minus one" for 51. Nothing to learn: heard at once, and
-- the Operator says so. Returns whether it spent a code.
local function hearFacts(
	self: Operator,
	utterance: Utterance,
	understood: { [string]: boolean },
	own: { [string]: string }
): boolean
	local known = Facts.read(utterance.text)
	local spent = false
	for concept, code in own do
		if known[code] and spendHeard(self, concept, code, understood) then
			spent = true
			if self.onKnown then
				(self.onKnown :: any)(concept)
			end
		end
	end
	return spent
end

-- Feed it something a player said. Safe to call on every chat message.
function Operator.hear(self: Operator, utterance: Utterance)
	-- EVERY concept the utterance conveyed, not just the strongest. "the jack is
	-- right by the fuse" names two concepts in plain language, and taking only
	-- the best one would leave the other free. Either word alone is understood,
	-- so the combination must not hide one.
	local codes = if self.liveCodes then self.liveCodes() else nil
	local conveyed = (self.backend :: any).conveyed(
		utterance,
		self.secrets,
		self.lexicon,
		codes,
		self:knownValues(),
		self:knownLetters()
	)

	local spentACode = false
	-- What this line moved it for: by its code (true) or by a word (false).
	local understood: { [string]: boolean } = {}
	for _, understanding in conveyed do
		if understanding.concept == nil or understanding.confidence < Config.ActThreshold then
			continue
		end
		spentACode = spentACode or understanding.byCode == true
		understood[understanding.concept] = understanding.byCode == true
		if self.onUnderstood then
			(self.onUnderstood :: any)(
				understanding.concept,
				payloadOf(self, understanding.concept),
				understanding.confidence,
				understanding.heard
			)
		end
		if understanding.byCode and self.onCodeHeard then
			(self.onCodeHeard :: any)(understanding.concept)
		end
	end

	-- Then what only the speaker could be passing: a way the group taught it,
	-- and a fact everyone knows, read against the codes the speaker has seen.
	local names = if self.names then self.names() else nil
	local own = (if self.seenCodes then self.seenCodes(utterance.speaker.UserId) else nil) or {}
	local hits, line, spentByAWay = hearWays(self, utterance, understood, names, own)
	local spentByAFact = hearFacts(self, utterance, understood, own)
	spentACode = spentACode or spentByAWay or spentByAFact

	-- Remember the unfamiliar words for a little while. If the players turn out
	-- to have been coordinating about a concept, we credit these retroactively.
	--
	-- Recorded ONCE per utterance, outside the loop above: a sentence conveying
	-- two concepts still offers its novel terms once, and crediting them twice
	-- would inflate every coinage minted from it.
	local novel = withoutNames((self.backend :: any).novelTerms(utterance, self.secrets), names)
	if #novel > 0 then
		table.insert(self.observations, {
			terms = novel,
			at = utterance.at,
			speaker = utterance.speaker,
		})
	end

	-- Every line, as said, for `creditCode`. Only the last CreditWindow of it is
	-- ever read, so a long round keeps the newest lines. Not a line whose code
	-- was just heard: that code is spent, and kept, the line would be credited
	-- to the holder's NEXT code ("yours: f g" read out, then 38 entered, would
	-- unsettle f and g).
	if spentACode then
		Method.spend(self.method, hits)
		return
	end
	Method.keep(self.method, line)
	table.insert(self.said, { text = utterance.text, at = utterance.at, speaker = utterance.speaker.UserId })
	if #self.said > Operator.SAID_KEPT then
		table.remove(self.said, 1)
	end
end

Operator.SAID_KEPT = 200

-- Defined below `creditCode`, which calls them.
local creditLetters: (self: Operator, code: string, now: number, holder: number?) -> ()
local creditMethod: (self: Operator, code: string, now: number, holder: number?) -> ()

-- The value a counting word stands for and its heat: the strongest.
local function strongestValue(c: Counting): (number?, number)
	local best, bestHeat = nil, 0
	for value, heat in c.values do
		if heat > bestHeat or (heat == bestHeat and best ~= nil and value < best) then
			best, bestHeat = value, heat
		end
	end
	return best, bestHeat
end

-- IT LEARNS TO COUNT (DECISIONS D11). Called with the code a player just
-- entered. Every line said in the credit window that works out as that code
-- with one word the Operator does not know ("five dozen minus two" before 58:
-- dozen = 12, Numerals.explain) credits that value, at the rates station words
-- learn by: `HeatPerCredit`, weighted for recency, cooled by `coolRound`. A word
-- worked out to two values loses on the other, so a nickname that meets a new
-- code every time ("toaster" before 58, then before 37) never settles, and a
-- line that uses a learned word to say the code exactly keeps it warm.
--
-- Without this, a group saying its codes with schemes like these beats the
-- listener within a round or two, and the station learner cannot see them: a
-- word said before every station's restore cancels out there (see `contrast`).
function Operator.creditCode(self: Operator, code: string, now: number, holder: number?)
	local target = tonumber(code)
	if target == nil then
		return
	end
	local known = self:knownValues()
	-- A line that explained this code is spent, as station observations are:
	-- read again at the next restore it would count twice. A line that did not
	-- explain it stays, for the other codes said in the same breath.
	for i = #self.said, 1, -1 do
		local line = self.said[i]
		local age = now - line.at
		if age < 0 or age > Config.CreditWindow then
			continue
		end
		local explained = Numerals.explain(line.text, target, known)
		if explained == nil then
			continue
		end
		table.remove(self.said, i)
		local credit = Config.HeatPerCredit * (1 - age / Config.CreditWindow)
		local counting = self.counting[explained.key]
		if counting == nil then
			counting = { values = {}, said = explained.said, coinedBy = line.speaker }
			self.counting[explained.key] = counting
		end
		local c = counting :: Counting
		c.values[explained.value] = math.clamp((c.values[explained.value] or 0) + credit, 0, 1)
		for value, heat in c.values do
			if value ~= explained.value then
				c.values[value] = if heat - credit > 0 then heat - credit else nil
			end
		end
		self.countedSinceBoundary[explained.key] = true
		-- Said once, as it crosses: the moment a group's trick stops working.
		local value, heat = strongestValue(c)
		if known[explained.key] == nil and value ~= nil and heat >= Config.ActThreshold then
			known[explained.key] = value
			if self.onCounted then
				(self.onCounted :: any)(explained.key, value)
			end
		end
	end
	creditLetters(self, code, now, holder)
	creditMethod(self, code, now, holder)
end

Operator.DIAL_SEEN = 2

-- The letters the dial has settled: a digit a letter has spelled at least
-- DIAL_SEEN times, and at least twice as often as every other digit together.
local function dialMap(self: Operator): { [string]: number }
	local out: { [string]: number } = {}
	for letter, digits in self.dial.evidence do
		local best, bestCount, total = nil, 0, 0
		for digit, count in digits do
			total += count
			if count > bestCount or (count == bestCount and best ~= nil and digit < best) then
				best, bestCount = digit, count
			end
		end
		if best ~= nil and bestCount >= Operator.DIAL_SEEN and bestCount >= 2 * (total - bestCount) then
			out[letter] = best
		end
	end
	return out
end

-- IT LEARNS YOUR ALPHABET (DECISIONS D12). The holder's last line before the
-- code, when it has exactly one pair of letters side by side ("bee ay" before
-- 21), teaches each letter its digit, whatever the spelling ("b", "bee" and
-- "bravo" are one letter to it, Numerals.letterOf). Only the HOLDER's: unlike a
-- sum, a pair of letters fits any code, and a group says all three codes in one
-- breath, so every letter line in the window would be credited to whichever
-- code was entered first. When the pair agrees with what the dial has settled
-- (one letter at least is known and neither is contradicted), the dial gains
-- `HeatPerCredit`. Understood, it reads a pair of settled letters as a code
-- (Numerals.readLetters).
--
-- Without this, a group spelling its codes in letters and radio words wins
-- round after round with the Operator never moving. A group that changes what
-- its letters stand for has its old evidence against it: a letter is settled
-- only while one digit clearly leads.
function creditLetters(self: Operator, code: string, now: number, holder: number?)
	local first, second = tonumber(string.sub(code, 1, 1)), tonumber(string.sub(code, 2, 2))
	if #code ~= 2 or first == nil or second == nil or holder == nil then
		return
	end
	local map = dialMap(self)
	-- Letters are said to be understood once, whichever learner gets there first.
	local wasKnown = self.dial.heat >= Config.ActThreshold or Method.lettersUnderstood(self.method)
	local function note(letter: string, digit: number)
		local digits = self.dial.evidence[letter] or {}
		digits[digit] = (digits[digit] or 0) + 1
		self.dial.evidence[letter] = digits
	end
	for i = #self.said, 1, -1 do
		local line = self.said[i]
		local age = now - line.at
		if age < 0 or age > Config.CreditWindow or line.speaker ~= holder then
			continue
		end
		local pairs = Numerals.letterPairs(line.text)
		if #pairs ~= 1 then
			continue
		end
		local a, b = pairs[1][1], pairs[1][2]
		local agrees = (map[a] == first or map[b] == second)
			and (map[a] == nil or map[a] == first)
			and (map[b] == nil or map[b] == second)
		note(a, first)
		note(b, second)
		table.remove(self.said, i)
		if self.dial.coinedBy == nil then
			self.dial.coinedBy = line.speaker
		end
		if agrees then
			-- A whole credit: recency is how the station learner guesses which
			-- words belonged to a restore, and this line is known to be the one.
			self.dial.heat = math.clamp(self.dial.heat + Config.HeatPerCredit, 0, 1)
			self.dialUsed = true
		end
		-- The newest such line is the one that carried this code.
		break
	end
	if not wasKnown and self.dial.heat >= Config.ActThreshold and self.onLettered then
		(self.onLettered :: any)()
	end
end

-- IT LEARNS HOW YOU PASS IT (DECISIONS D13): the holder's newest line against
-- the code entered (Method). A line that already said the code in words it
-- reads used no way. A letters way understood is said with the dial's
-- `onLettered`: letters have one line, and the dial stays quiet when it crosses
-- after a letters way already reads them (`creditLetters`).
function creditMethod(self: Operator, code: string, now: number, holder: number?)
	if holder == nil then
		return
	end
	local known, letters = self:knownValues(), self:knownLetters()
	local function plainly(text: string): boolean
		return Lexicon.numbersIn(text)[code] == true
			or Numerals.read(text, known)[code] == true
			or Numerals.readLetters(text, letters)[code] == true
	end
	-- The holder's other live codes: a line that carried one of those is theirs.
	local others: { [string]: boolean } = {}
	for _, other in (if self.seenCodes then self.seenCodes(holder) else nil) or {} do
		others[other] = true
	end
	others[code] = nil
	for _, event in Method.credit(self.method, code, holder, now, plainly, others) do
		if event.way.kind == "letter" and event.kind == "understood" then
			if self.onLettered then
				(self.onLettered :: any)()
			end
		elseif self.onMethod then
			local says = if event.kind == "understood" then event.way.line else Method.NOTING_LINE
			local onMethod = self.onMethod :: any
			onMethod(event.kind, event.way.id, says)
		end
	end
end

-- The letters the dial has settled, understood or not (the wall and the tests).
function Operator.settledLetters(self: Operator): { [string]: number }
	return dialMap(self)
end

-- The letters it reads as digits: the settled ones, once the dial is understood.
function Operator.knownLetters(self: Operator): { [string]: number }
	if self.dial.heat >= Config.ActThreshold then
		return dialMap(self)
	end
	return {}
end

-- The words it understands as numbers, and what each stands for: those whose
-- strongest value has crossed the act threshold, the line every learned word
-- is judged by.
function Operator.knownValues(self: Operator): { [string]: number }
	local out: { [string]: number } = {}
	for key, c in self.counting do
		local value, heat = strongestValue(c)
		if value ~= nil and heat >= Config.ActThreshold then
			out[key] = value
		end
	end
	return out
end

-- The wall's rows for the ways it is learning a group passes codes (Method).
function Operator.methodRows(self: Operator): { Coinage }
	return Method.rows(self.method)
end

-- The wall's rows for the words it is learning as numbers (Readout).
function Operator.countingRows(self: Operator): { Coinage }
	local out: { Coinage } = {}
	for _, c in self.counting do
		local value, heat = strongestValue(c)
		if value ~= nil and heat > 0 then
			table.insert(out, {
				phrase = c.said,
				concept = "counting",
				heat = heat,
				sightings = 0,
				coinedBy = c.coinedBy,
				value = value,
			})
		end
	end
	-- The dial, as the letters it has settled.
	local settled = {}
	for letter in dialMap(self) do
		table.insert(settled, letter)
	end
	table.sort(settled)
	if self.dial.heat > 0 and #settled > 0 and self.dial.coinedBy ~= nil then
		table.insert(out, {
			phrase = `letters {table.concat(settled, " ")}`,
			concept = "counting",
			heat = self.dial.heat,
			sightings = 0,
			coinedBy = self.dial.coinedBy :: number,
		})
	end
	return out
end

-- Counting words cool like station words: `amount` a round, except one that is
-- understood and was used again since the last boundary (DECISIONS D3).
local function coolCounting(self: Operator, amount: number, keepUsed: boolean): boolean
	local changed = false
	for key, c in self.counting do
		local _, heat = strongestValue(c)
		if keepUsed and self.countedSinceBoundary[key] and heat >= Config.ActThreshold then
			continue
		end
		for value, h in c.values do
			local cooled = h - amount
			c.values[value] = if cooled > 0 then cooled else nil
			changed = true
		end
		if next(c.values) == nil then
			self.counting[key] = nil
		end
	end
	-- The dial cools the same way; what each letter has spelled is kept.
	if self.dial.heat > 0 and not (keepUsed and self.dialUsed and self.dial.heat >= Config.ActThreshold) then
		self.dial.heat = math.max(0, self.dial.heat - amount)
		changed = true
	end
	return changed
end

-- An exact match wins; otherwise an existing coinage that is the SAME PHRASE
-- by reading. Without the second pass, a group alternating "blue wire" and
-- "blue wires" would mint two coinages, each at half the heat, and the reader
-- -- which already treats them as one phrase -- would take the weaker, under
-- the act threshold: varying the plural would keep a codeword unlearned for
-- free, and the Lexicon panel would show the same word twice. The first-minted
-- spelling is kept, so the panel's row does not change its name under the
-- players.
local function findCoinage(self: Operator, phrase: string, concept: string): Coinage?
	for _, c in self.lexicon do
		if c.phrase == phrase and c.concept == concept then
			return c
		end
	end
	for _, c in self.lexicon do
		if c.concept == concept and Lexicon.samePhrase(c.phrase, phrase) then
			return c
		end
	end
	return nil
end

-- A WORD USED BEFORE EVERY RESTORE MEANS NOTHING IN PARTICULAR (DECISIONS D10).
-- Crediting a phrase toward one concept takes the same heat off that phrase's
-- other meanings -- unless the Operator has more evidence for the other
-- meaning. Evidence is every credit a meaning has ever had here, and it does
-- not cool, so it says which station a word has been used for MOST.
--   * Filler said as often before one station's restore as before another's
--     ("say", "mine", "then") cancels itself out instead of being filed for
--     whichever station was restored first.
--   * A word said MORE before one station is that station's word, filler or
--     not: three mentions before the first restore still file it at once (the
--     rate the owner's cooling rule in OWNER.md assumes), and it moves to
--     another station only once said at least as often before that one.
--   * The cost: a group that recites ALL its codewords before every restore,
--     equally often, teaches none of them. Each is filler by this rule.
--   * A group's nickname keeps its heat when it is also mentioned before
--     another station's restore ("piano done, now the tuba"). Debited, a
--     nickname said twice before its own station and once before another
--     would never burn, and saying a codeword once near another restore would
--     be a free way to stop it being learned.
-- A tie is a debit: filler said twice before every restore ties every time.
-- No rate changes: `HeatPerCredit` and `CoolPerRound` are the rates the
-- owner's cooling rule (OWNER.md) was measured with.
local function evidenceFor(self: Operator, c: Coinage): number
	local byConcept = self.evidence[c.phrase]
	-- A meaning with no record counts what it holds. Every credit records one,
	-- so only a coinage made some other way (LexiconSave, not yet wired) can
	-- lack it.
	return if byConcept and byConcept[c.concept] then byConcept[c.concept] else c.heat
end

local function contrast(self: Operator, credited: Coinage, amount: number)
	local byConcept = self.evidence[credited.phrase] or {}
	byConcept[credited.concept] = (byConcept[credited.concept] or 0) + amount
	self.evidence[credited.phrase] = byConcept
	local mine = byConcept[credited.concept]
	for i = #self.lexicon, 1, -1 do
		local other = self.lexicon[i]
		if
			other ~= credited
			and other.concept ~= credited.concept
			and Lexicon.samePhrase(other.phrase, credited.phrase)
			and evidenceFor(self, other) <= mine
		then
			other.heat = math.max(0, other.heat - amount)
			if other.heat <= 0 then
				table.remove(self.lexicon, i)
			end
		end
	end
end

-- A word cooled out of every meaning is forgotten whole, its evidence with it
-- (the Operator keeps no file on a word it no longer knows; see `cool`). A
-- meaning debited to nothing keeps its evidence while the word has another
-- meaning.
local function forgetLostWords(self: Operator)
	local known: { [string]: boolean } = {}
	for _, c in self.lexicon do
		known[c.phrase] = true
	end
	for phrase in self.evidence do
		if not known[phrase] then
			self.evidence[phrase] = nil
		end
	end
end

-- Called when players demonstrably ACTED on a concept (patched the right jack,
-- opened the right door). Anything unfamiliar said shortly before that is now
-- suspected of meaning it.
--
-- This is the acquisition rule, and it is deliberately behavioural rather than
-- linguistic: the Operator learns from consequences, not from grammar. That is
-- why it cannot be fooled by simply using a weird word - the word has to
-- actually precede the group succeeding.
--
-- An utterance is credited to at most ONE concept: what you said just before
-- the lights came back on taught the Operator about the lights, not about
-- everything else the group happened to finish in the same twenty seconds.
-- Observations are therefore CONSUMED here: otherwise solving two stations
-- inside the credit window would burn every word said beforehand twice, into
-- two different concepts, at double speed.
--
-- Given the line's `holder` and the `entrant` who restored it, only what those
-- two said is this line's (DECISIONS D14): the holder told the entrant, and the
-- entrant asked. What anyone else said in the window is about another line, or
-- nothing, and is kept for the restore it belongs to: two lines restored a
-- second apart would otherwise file both stations' words under the first. An
-- entrant who still holds a line of their own is talking about that one, so
-- then only the holder's words count.
function Operator.credit(self: Operator, concept: string, now: number, holder: number?, entrant: number?)
	local onlyTheirs = holder ~= nil or entrant ~= nil
	if entrant ~= nil and entrant ~= holder and self.seenCodes then
		local own = self.seenCodes(entrant)
		if own ~= nil and next(own) ~= nil then
			entrant = nil
		end
	end
	local gained: { [Coinage]: number } = {}
	local credited: { Coinage } = {}
	local kept: { Observation } = {}
	for _, obs in self.observations do
		local age = now - obs.at
		if age > Config.CreditWindow then
			continue -- too old to be related; drop it
		end
		local who = obs.speaker.UserId
		if onlyTheirs and who ~= holder and who ~= entrant then
			table.insert(kept, obs)
			continue
		end

		-- Recency weighting: something said one second before the action is far
		-- more suspicious than something said fifteen seconds before.
		local recency = 1 - (age / Config.CreditWindow)

		for _, term in obs.terms do
			local coinage = findCoinage(self, term, concept)
			if not coinage then
				coinage = {
					phrase = term,
					concept = concept,
					heat = 0,
					sightings = 0,
					coinedBy = obs.speaker.UserId,
				}
				table.insert(self.lexicon, coinage :: Coinage)
			end

			local c = coinage :: Coinage
			local wasBurned = c.heat >= 1
			local credit = Config.HeatPerCredit * recency
			self.creditedSinceBoundary[c] = true
			c.sightings += 1
			c.heat = math.clamp(c.heat + credit, 0, 1)
			if gained[c] == nil then
				table.insert(credited, c)
			end
			gained[c] = (gained[c] or 0) + credit

			if not wasBurned and c.heat >= 1 and self.onBurned then
				(self.onBurned :: any)(c)
			end
		end
	end

	-- Weighed once the whole window is counted, so a word said twice before
	-- this restore has both sightings as evidence whichever came first.
	for _, c in credited do
		contrast(self, c, gained[c])
	end

	-- What this line's players said was just spent on `concept`, and what was
	-- older than the window was too old to matter. Only the others' recent
	-- lines survive, for their own restore.
	self.observations = kept
end

-- Drop novel terms that are still waiting to be credited. Called when a round
-- ends: `CreditWindow` is 20 seconds against an 8-second intermission, so
-- without this a phrase said just before one round finished would be credited
-- by a success in the NEXT one.
--
-- The acquisition rule is "the group said it and then succeeded". Crediting
-- across a reset turns that into "said last round, succeeded this one", which
-- is a different claim and not a true one. The LEXICON itself is untouched:
-- burned terms carry over on purpose, and that is the retention mechanic.
function Operator.forgetObservations(self: Operator)
	self.observations = {}
	self.said = {}
	Method.forget(self.method)
end

-- Terms cool off. It forgets, a little, which is what keeps a long-running
-- group from being permanently mute. Returns whether anything actually moved,
-- so callers can avoid replicating an unchanged lexicon.
--
-- A TERM THAT REACHES ZERO IS DROPPED, not left sitting at zero, so "it
-- forgets" is true of the register and not only of the heat:
--
--   * `snapshot` ships every entry to every client on every change, and
--     `renderLexicon` draws every entry it is given with no heat floor. A dead
--     entry would list a word at "0%" -- a word the Operator does not know at
--     all, and by this module's own rule cannot act on -- in the same list, in
--     the same shape, as the words that will get players killed. What the
--     player SEES must match what the server believes.
--   * `Heuristic.conveyed` walks the whole register once per secret per
--     utterance, re-tokenising each phrase, so a dead entry would be paid
--     for on every line of chat forever.
--   * And the register only grows. One 230-character message -- inside
--     Roblox's chat cap -- offers 79 candidate terms, and one solve inside the
--     credit window writes all 79 in. Kept at zero, they would permanently
--     enlarge the panel and the per-utterance scan.
--
-- Dropping at zero is observationally neutral for COMPREHENSION, which is why
-- it is safe: `Heuristic.conveyed` scores a coinage as `heat / BURNED_AT` and
-- reports a concept only when its confidence is above 0, so a zero-heat
-- coinage can never be the concept it picks. `tests/operator.luau` asserts that
-- directly rather than leaving it as an argument. What DOES change is that a
-- phrase which comes back after being fully forgotten comes back fresh, with
-- `sightings` at 1 and a new `coinedBy`. That is the correct reading of
-- forgetting: the Operator is not keeping a file on a word it no longer knows.
--
-- Removal is NOT conditional on the heat having moved this tick. A term already
-- resting at zero cools to zero, so an "only if it changed" test would leave
-- exactly the entries this is meant to clear.
function Operator.cool(self: Operator, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local changed = false
	-- Backwards: `table.remove` shifts everything after the index.
	for i = #self.lexicon, 1, -1 do
		local c = self.lexicon[i]
		local cooled = math.max(0, c.heat - amount)
		if cooled ~= c.heat then
			c.heat = cooled
			changed = true
		end
		if c.heat <= 0 then
			table.remove(self.lexicon, i)
			changed = true
		end
	end
	forgetLostWords(self)
	changed = coolCounting(self, amount, false) or changed
	changed = Method.cool(self.method, amount) or changed
	return changed
end

-- The round boundary's forgetting (DECISIONS D3). Everything cools by `amount`
-- EXCEPT a coinage that is already understood and was credited again since the
-- last boundary: a word the group is still succeeding with stays understood.
--
-- Cooling everything lets a codeword cross the threshold at a solve, fall back
-- under it seconds later at the restart, and so be safe every time it is
-- actually SAID: the panel shows it red for rounds before the Operator first
-- comes for it. Red has to mean it is coming.
--
-- A word the group retires is not credited, so it cools like anything else and
-- is safe again after a round of disuse. That is still the way back.
function Operator.coolRound(self: Operator, amount: number): boolean
	if amount <= 0 then
		self.creditedSinceBoundary = {}
		self.countedSinceBoundary = {}
		self.dialUsed = false
		Method.coolRound(self.method, 0)
		return false
	end
	local changed = false
	for i = #self.lexicon, 1, -1 do
		local c = self.lexicon[i]
		if self.creditedSinceBoundary[c] and c.heat >= Config.ActThreshold then
			continue
		end
		local cooled = math.max(0, c.heat - amount)
		if cooled ~= c.heat then
			c.heat = cooled
			changed = true
		end
		if c.heat <= 0 then
			table.remove(self.lexicon, i)
			changed = true
		end
	end
	self.creditedSinceBoundary = {}
	forgetLostWords(self)
	changed = coolCounting(self, amount, true) or changed
	changed = Method.coolRound(self.method, amount) or changed
	self.countedSinceBoundary = {}
	self.dialUsed = false
	return changed
end

-- There is no per-second forgetting on the server's clock: the server cools
-- once per round with `Config.CoolPerRound`, and a second clock would cool
-- everything twice (DECISIONS D1).

-- What the client needs to render the Lexicon panel.
function Operator.snapshot(self: Operator): { Coinage }
	local out: { Coinage } = {}
	for _, c in self.lexicon do
		table.insert(out, {
			phrase = c.phrase,
			concept = c.concept,
			heat = c.heat,
			sightings = c.sightings,
			coinedBy = c.coinedBy,
		})
	end
	return out
end

return Operator
