--!strict
-- HOW A GROUP PASSES ITS CODES (DECISIONS D13).
--
-- A group that cannot say its codes aloud finds a way to carry two digits that
-- the Operator does not read: the digits turned round ("banana 39" for 93), one
-- digit a message ("3", then "8"), letters for digits ("GF", "C then E"). A
-- listener that learns one spelling at a time loses to the next spelling. This
-- module learns the WAY instead. At every restore it takes what the holder told
-- the entrant and the code that was entered, and credits whichever way turns
-- the one into the other.
--
--   * A way gains a whole `HeatPerCredit` a restore: the holder's newest line
--     is known to be the one that carried the code (DECISIONS D12). At
--     `ActThreshold`, the third restore, it is understood and reads that way
--     from then on. It cools by `CoolPerRound` like everything the Operator
--     learns, except a way understood and used since the last round boundary
--     (DECISIONS D3).
--   * Only the holder's NEWEST line with a mark in it is evidence, and a way
--     that reads it as some other number loses a credit. Without both rules
--     ordinary chat teaches "turned round" by chance (tests/method.luau).
--   * A player's lines are read only against the codes that player has seen.
--     Only someone who knows a code can say it, and a reading that could match
--     anyone's code would spend codes on chat that happens to hold two digits.
--   * A player's name that opens a sentence is who is being spoken to, not a
--     letter: "dee, ay aitch" is 18, not "d a".
--
-- Pure: the Operator feeds it lines and restores and asks what it heard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Lexicon = require(ReplicatedStorage.Shared.Lexicon)
local Numerals = require(ReplicatedStorage.Shared.Numerals)

type Coinage = Types.Coinage

-- One digit or one letter, where it stands in its line: the sentence, the word
-- (two marks glued into one word, "39" or "GF", share it), and the word just
-- before it in the sentence.
export type Mark = {
	kind: string,
	value: string?,
	sentence: number,
	word: number,
	before: string?,
	-- "again" or "twice": the mark before it, said once more. With no mark
	-- before it in the line, it repeats the speaker's previous line.
	repeats: boolean?,
}

export type Line = { speaker: number, at: number, text: string, marks: { Mark } }

-- Two marks that may carry one code, and how they were put together: "glued"
-- in one word, "side" by side, "joined" by one word ("C then E"), "again" (a
-- mark and its repeat), or "split" across two of the speaker's lines.
export type Pair = { first: string, second: string, kind: string, joining: string, lines: { Line } }

export type Way = {
	id: string,
	-- How the wall names it.
	label: string,
	kind: string,
	-- The key in Round.LINES said when it is understood. The letters ways share
	-- the dial's line, said once for both (Operator.onLettered).
	line: string,
	-- The code this way reads the pair as, or nil if it does not read it.
	read: (pair: Pair) -> string?,
}

export type Event = { kind: string, way: Way }
export type Hit = { concept: string, code: string, way: Way, lines: { Line } }

export type Method = {
	heat: { [string]: number },
	-- Credited or heard since the last round boundary (the cooling exemption).
	used: { [string]: boolean },
	-- Who first taught each way: the wall's filter needs an author (Censor).
	coinedBy: { [string]: number },
	-- Every speaker's lines, oldest first; only the last CreditWindow is read.
	lines: { Line },
}

local Method = {}

Method.LINES_KEPT = 200
-- What it says when a way is one restore short (a key in Round.LINES).
Method.NOTING_LINE = "noting"

local DIGIT_OF: { [string]: string } = {}
for index, word in Lexicon.DIGIT_WORDS do
	DIGIT_OF[word] = tostring(index - 1)
end
local REPEATS: { [string]: boolean } = { again = true, twice = true }
-- The one word that may stand between two marks of a pair.
local JOINERS: { [string]: boolean } = { ["then"] = true, ["and"] = true, n = true }

-- Letters for digits, the two ways groups have used: A is 1 (J, the tenth, is
-- nought) and A is 0. A code never begins with nought.
local A_IS_1: { [string]: string } =
	{ a = "1", b = "2", c = "3", d = "4", e = "5", f = "6", g = "7", h = "8", i = "9", j = "0" }
local A_IS_0: { [string]: string } =
	{ a = "0", b = "1", c = "2", d = "3", e = "4", f = "5", g = "6", h = "7", i = "8", j = "9" }

local function pieces(pair: Pair): boolean
	return pair.joining == "split" or pair.joining == "again"
end

local function alphabet(map: { [string]: string }): (pair: Pair) -> string?
	return function(pair: Pair): string?
		local x, y = map[pair.first], map[pair.second]
		if x == nil or y == nil or x == "0" then
			return nil
		end
		return x .. y
	end
end

-- Every way a group has been seen to pass a code. A new way is an entry here.
Method.WAYS = {
	{
		id = "turned",
		label = "digits turned round",
		kind = "digit",
		line = "turned",
		read = function(pair: Pair): string?
			if pieces(pair) or pair.second == "0" then
				return nil
			end
			return pair.second .. pair.first
		end,
	},
	{
		id = "apart",
		label = "one digit at a time",
		kind = "digit",
		line = "apart",
		read = function(pair: Pair): string?
			if not pieces(pair) or pair.first == "0" then
				return nil
			end
			return pair.first .. pair.second
		end,
	},
	{ id = "lettersA1", label = "letters, a is 1", kind = "letter", line = "lettered", read = alphabet(A_IS_1) },
	{ id = "lettersA0", label = "letters, a is 0", kind = "letter", line = "lettered", read = alphabet(A_IS_0) },
} :: { Way }

function Method.new(): Method
	return { heat = {}, used = {}, coinedBy = {}, lines = {} }
end

-- The marks in a line, in order. `names` (lower case) are the players present:
-- one that opens a sentence is an address and marks nothing.
function Method.marks(text: string, names: { [string]: boolean }?): { Mark }
	local out: { Mark } = {}
	local sentence = 0
	for piece in string.gmatch(text, "[^%.,!%?;:]+") do
		sentence += 1
		local word = 0
		local lastInSentence: Mark? = nil
		local previousToken: string? = nil
		for raw in string.gmatch(piece, "[%w']+") do
			word += 1
			local token = string.lower((string.gsub(raw, "'", "")))
			local before = previousToken
			previousToken = token
			local function add(kind: string, value: string?, repeats: boolean?)
				local mark =
					{ kind = kind, value = value, sentence = sentence, word = word, before = before, repeats = repeats }
				table.insert(out, mark)
				lastInSentence = mark
			end
			if word == 1 and names and names[token] then
				continue
			end
			if string.match(token, "^%d$") then
				add("digit", token)
			elseif string.match(token, "^%d%d$") then
				add("digit", string.sub(token, 1, 1))
				add("digit", string.sub(token, 2, 2))
			elseif DIGIT_OF[token] then
				add("digit", DIGIT_OF[token])
			elseif string.match(raw, "^%u%u$") then
				-- Two capitals are two letters glued ("GF"); "go" and "hi" in
				-- lower case are words.
				add("letter", string.lower(string.sub(raw, 1, 1)))
				add("letter", string.lower(string.sub(raw, 2, 2)))
			elseif JOINERS[token] then
				-- A joining word, never a letter: the "n" in "C n E".
				continue
			elseif Numerals.letterOf(token) then
				add("letter", Numerals.letterOf(token))
			elseif REPEATS[token] then
				local repeated = lastInSentence
				if repeated then
					add(repeated.kind, repeated.value, true)
				elseif #out == 0 then
					-- A repeat with nothing before it in the line repeats the
					-- speaker's previous line ("4", then "again").
					add("repeat", nil, true)
				end
			end
		end
	end
	return out
end

-- Whether the words between two marks leave them a pair: glued, side by side,
-- or one joining word between.
local function joining(a: Mark, b: Mark): string?
	if a.sentence ~= b.sentence then
		return nil
	elseif a.word == b.word then
		return "glued"
	elseif b.word == a.word + 1 then
		return if b.repeats then "again" else "side"
	elseif b.word == a.word + 2 and not b.repeats and b.before and JOINERS[b.before] then
		return "joined"
	end
	return nil
end

-- The one mark of `kind` in a line, or nil when it has none or several.
local function onlyMark(line: Line, kind: string): Mark?
	local found: Mark? = nil
	for _, mark in line.marks do
		if mark.kind == kind then
			if found then
				return nil
			end
			found = mark
		end
	end
	return found
end

-- The pairs that end in `line`, the last first: inside it, and across from the
-- speaker's `previous` line when each holds one mark of a kind ("ok dee 4"
-- holds one digit). A line that is only "again" repeats the previous line's.
local function pairsEndingIn(line: Line, previous: Line?): { Pair }
	local out: { Pair } = {}
	local marks = line.marks
	for i = #marks, 2, -1 do
		local a, b = marks[i - 1], marks[i]
		if a.kind == b.kind and a.value ~= nil and b.value ~= nil then
			local how = joining(a, b)
			if how then
				table.insert(out, { first = a.value, second = b.value, kind = a.kind, joining = how, lines = { line } })
			end
		end
	end
	if previous == nil then
		return out
	end
	local onlyRepeat = #marks == 1 and marks[1].kind == "repeat"
	for _, kind in { "digit", "letter" } do
		local a = onlyMark(previous, kind)
		local b = if onlyRepeat then a else onlyMark(line, kind)
		if a and b and a.value ~= nil and b.value ~= nil then
			table.insert(
				out,
				{ first = a.value, second = b.value, kind = kind, joining = "split", lines = { previous, line } }
			)
		end
	end
	return out
end

-- The speaker's kept lines in the credit window before `now`, oldest first.
local function linesOf(self: Method, speaker: number, now: number): { Line }
	local out: { Line } = {}
	for _, line in self.lines do
		local age = now - line.at
		if line.speaker == speaker and age >= 0 and age <= Config.CreditWindow then
			table.insert(out, line)
		end
	end
	return out
end

local function drop(self: Method, gone: { Line })
	for i = #self.lines, 1, -1 do
		if table.find(gone, self.lines[i]) then
			table.remove(self.lines, i)
		end
	end
end

function Method.understood(self: Method, way: Way): boolean
	return (self.heat[way.id] or 0) >= Config.ActThreshold
end

-- Whether any letters way is understood (the Operator's letters are said once).
function Method.lettersUnderstood(self: Method): boolean
	for _, way in Method.WAYS do
		if way.kind == "letter" and Method.understood(self, way) then
			return true
		end
	end
	return false
end

-- A line said now: the codes it passes a way the group has taught it, among
-- the codes `speaker` has seen (`own`, by concept). Returns them and the line,
-- which the Operator keeps unless a code in it was heard (`keep`).
function Method.read(
	self: Method,
	speaker: number,
	text: string,
	at: number,
	own: { [string]: string },
	names: { [string]: boolean }?
): ({ Hit }, Line)
	local line: Line = { speaker = speaker, at = at, text = text, marks = Method.marks(text, names) }
	local hits: { Hit } = {}
	local conceptOf: { [string]: string } = {}
	for concept, code in own do
		conceptOf[code] = concept
	end
	if next(conceptOf) == nil or #line.marks == 0 then
		return hits, line
	end
	local mine = linesOf(self, speaker, at)
	local taken: { [string]: boolean } = {}
	for _, pair in pairsEndingIn(line, mine[#mine]) do
		for _, way in Method.WAYS do
			if way.kind ~= pair.kind or not Method.understood(self, way) then
				continue
			end
			local code = way.read(pair)
			local concept = if code then conceptOf[code] else nil
			if code and concept and not taken[concept] then
				taken[concept] = true
				self.used[way.id] = true
				table.insert(hits, { concept = concept, code = code, way = way, lines = pair.lines })
			end
		end
	end
	return hits, line
end

function Method.keep(self: Method, line: Line)
	table.insert(self.lines, line)
	if #self.lines > Method.LINES_KEPT then
		table.remove(self.lines, 1)
	end
end

-- The lines whose codes were just heard are spent, as the Operator's are.
function Method.spend(self: Method, hits: { Hit })
	for _, hit in hits do
		drop(self, hit.lines)
	end
end

local function lose(self: Method, way: Way)
	local cooled = (self.heat[way.id] or 0) - Config.HeatPerCredit
	self.heat[way.id] = if cooled > 0 then cooled else nil
end

-- One credit short of understood: the warning.
local function oneShort(heat: number): boolean
	return heat < Config.ActThreshold and heat + Config.HeatPerCredit >= Config.ActThreshold
end

local function gain(self: Method, way: Way, holder: number, events: { Event })
	local before = self.heat[way.id] or 0
	local after = math.min(1, before + Config.HeatPerCredit)
	self.heat[way.id] = after
	self.used[way.id] = true
	if self.coinedBy[way.id] == nil then
		self.coinedBy[way.id] = holder
	end
	if before < Config.ActThreshold and after >= Config.ActThreshold then
		table.insert(events, { kind = "understood", way = way })
	elseif oneShort(after) and not oneShort(before) then
		table.insert(events, { kind = "noting", way = way })
	end
end

-- The lines of a pair that a way reads as a code in `others`: they carried
-- that code, not the one just entered. Nil when none does.
local function carrierOf(line: Line, previous: Line?, others: { [string]: boolean }): { Line }?
	for _, pair in pairsEndingIn(line, previous) do
		for _, way in Method.WAYS do
			local read = if way.kind == pair.kind then way.read(pair) else nil
			if read and others[read] then
				return pair.lines
			end
		end
	end
	return nil
end

-- A restore: `code` was entered, and `holder` held it. The holder's newest line
-- with a mark in it is the evidence, passing over the lines that carried one of
-- the holder's `others` (the codes they still hold: a holder of two lines
-- passes both before either is entered, "3", "8", "4", "7"). The ways that
-- read one of its pairs as the code gain; the ways that read that pair as
-- another number lose. A line that already said the code in words the
-- Operator reads (`plainly`) used no way. Returns what crossed a line: a way
-- one credit short, or understood.
function Method.credit(
	self: Method,
	code: string,
	holder: number,
	now: number,
	plainly: (text: string) -> boolean,
	others: { [string]: boolean }
): { Event }
	local events: { Event } = {}
	local mine = linesOf(self, holder, now)
	local passed: { [Line]: boolean } = {}
	local newest: number? = nil
	for i = #mine, 1, -1 do
		if #mine[i].marks == 0 or passed[mine[i]] then
			continue
		end
		local carried = carrierOf(mine[i], mine[i - 1], others)
		if carried == nil then
			newest = i
			break
		end
		for _, other in carried do
			passed[other] = true
		end
	end
	if newest == nil then
		return events
	end
	local line = mine[newest]
	if plainly(line.text) then
		return events
	end
	local previous = mine[newest - 1]
	if previous and passed[previous] then
		previous = nil
	end
	local candidates = pairsEndingIn(line, previous)
	local evidence: Pair? = nil
	for _, pair in candidates do
		for _, way in Method.WAYS do
			if way.kind == pair.kind and way.read(pair) == code then
				evidence = pair
				break
			end
		end
		if evidence then
			break
		end
	end
	local weighed = evidence or candidates[1]
	if weighed == nil then
		return events
	end
	for _, way in Method.WAYS do
		if way.kind ~= weighed.kind then
			continue
		end
		local read = way.read(weighed)
		if read == code then
			gain(self, way, holder, events)
		elseif read ~= nil then
			lose(self, way)
		end
	end
	-- Weighed once: read again at the next restore it would count twice.
	drop(self, weighed.lines)
	return events
end

-- Every way cools by `amount`, except one understood and used since the last
-- boundary when `keepUsed` (the round boundary, DECISIONS D3).
local function cool(self: Method, amount: number, keepUsed: boolean): boolean
	local changed = false
	for id, heat in self.heat do
		if keepUsed and self.used[id] and heat >= Config.ActThreshold then
			continue
		end
		local cooled = heat - amount
		self.heat[id] = if cooled > 0 then cooled else nil
		changed = true
	end
	return changed
end

function Method.cool(self: Method, amount: number): boolean
	return cool(self, amount, false)
end

-- The round boundary: cool, and start counting use again.
function Method.coolRound(self: Method, amount: number): boolean
	local changed = if amount > 0 then cool(self, amount, true) else false
	self.used = {}
	return changed
end

-- A round ended: nothing said in it may be credited by the next one.
function Method.forget(self: Method)
	self.lines = {}
end

-- The wall's rows: every way it is learning, in its own words.
function Method.rows(self: Method): { Coinage }
	local out: { Coinage } = {}
	for _, way in Method.WAYS do
		local heat = self.heat[way.id]
		local author = self.coinedBy[way.id]
		if heat and heat > 0 and author then
			table.insert(out, {
				phrase = way.label,
				concept = "counting",
				heat = heat,
				sightings = 0,
				coinedBy = author,
			})
		end
	end
	return out
end

return Method
