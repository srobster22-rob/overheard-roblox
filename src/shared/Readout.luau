--!strict
-- What the panels SAY, given what the server sent: the Your Line rows, the
-- Lexicon wall and the round-over screen. Kept out of the client so the suite
-- can run it (tests/readout.luau).
--
-- The rows come back already in order, so the caller never invents one. The
-- order matters: "only you can see this" is a claim about a SPECIFIC line and
-- must sit directly under it. Numbering lines `i` and notes `i + 100` would
-- put every note below every line once a player holds two, which happens in
-- ordinary play: two players hold one each, one leaves, `redealOrphans` gives
-- the orphan to the survivor.

local Heat = require(script.Parent.Heat)
local Types = require(script.Parent.Types)

local Readout = {}

export type Row = {
	text: string,
	-- "line" is a fact only you can act on, "note" explains the line above it,
	-- "count" is the progress line, "empty" is the nothing-to-do message,
	-- "escape" says every line is through and where to go, "holding" where
	-- the Operator is waiting.
	kind: string,
}

Readout.PRIVATE_NOTE = "only you can see this"
-- No word here may be plain language for a concept the Operator listens for.
-- It is shown to exactly the players who hold nothing -- the ones most likely
-- to be talking, with no connection to any concept and no way to link cause
-- to effect when the monster arrives. `tests/readout.luau` checks it against
-- the live pool.
Readout.NOTHING_HELD = "nothing on your line - listen for somebody else's"
-- Shown to everyone once every line is restored. Derived from the board
-- the client already receives, so no second message can disagree with it.
-- Like every string here it may give no concept away (tests/wiring checks).
Readout.ESCAPE_NOTE = "every line is through - everyone to the lobby"
-- The same moment with the Operator in the lobby or on its way there, when
-- "everyone to the lobby" would walk a whole group into it. It leaves
-- `Config.LingerSeconds` after it arrives, well inside the way out's time.
Readout.ESCAPE_WAIT = "every line is through - but the lobby is not safe yet: wait for it to walk off"
-- Where it has stopped, by the station the wall's headers name.
Readout.WAITING = "the Operator is waiting by the %s"

-- `entries` is the payload from `Objectives.viewFor`: one row per objective,
-- with `prompt` and `answer` present only on the ones this player holds.
-- `holding` is where the Operator is waiting, if anywhere (`Round.holding`).
function Readout.lineRows(entries: { any }, holding: Types.Holding?): { Row }
	local rows: { Row } = {}
	local solved = 0

	for _, entry in entries do
		if entry.solved then
			solved += 1
		end
		if entry.holding and not entry.solved and entry.prompt and entry.answer then
			-- `string.format` can be made to throw outright: a literal `%`
			-- anywhere in a station's prompt besides its own `%s` slot is not
			-- escaped, and `string.format` treats every `%` as the start of a
			-- directive. tests/round.luau catches that for every prompt in
			-- Round.STATIONS, but a gate only helps if it is run -- a translation,
			-- or a typo that slips past it some other way, would still crash this
			-- call and take the whole panel down for whoever holds that line.
			--
			-- `pcall` here means a broken prompt degrades to plain concatenation
			-- (still names the actual number, just without the sentence around
			-- it) instead of erroring the reader's line out of existence. THE
			-- ANSWER is the one piece of information this row exists to carry;
			-- losing the sentence is a cosmetic failure, losing the number is a
			-- broken round.
			local ok, formatted = pcall(string.format, entry.prompt, entry.answer)
			table.insert(rows, { text = if ok then formatted else `{entry.prompt} ({entry.answer})`, kind = "line" })
			table.insert(rows, { text = Readout.PRIVATE_NOTE, kind = "note" })
		end
	end

	local held = 0
	for _, row in rows do
		if row.kind == "line" then
			held += 1
		end
	end

	table.insert(rows, { text = `restored {solved}/{#entries}`, kind = "count" })
	if holding and holding.label then
		table.insert(rows, { text = string.format(Readout.WAITING, holding.label), kind = "holding" })
	end
	-- With every line restored there is nothing left to hold, and "listen for
	-- somebody else's" would be the wrong advice: the note says where to go.
	if #entries > 0 and solved == #entries then
		local wait = holding ~= nil and holding.wayOut
		table.insert(rows, { text = if wait then Readout.ESCAPE_WAIT else Readout.ESCAPE_NOTE, kind = "escape" })
	elseif held == 0 then
		table.insert(rows, { text = Readout.NOTHING_HELD, kind = "empty" })
	end

	return rows
end

-- THE LEXICON PANEL, the wall everyone reads mid-round. Each word is shown as
-- the phrase, its heat as a whole percent, and the word "understood" once it
-- has crossed the threshold -- said in words as well as colour, because that
-- crossing is the single fact the panel exists to convey. Here rather than in
-- init.client, where no test can run it. Works on a COPY: the caller's list is
-- left as it came.
--
-- The Operator notices far more phrases than a group can read, often one word
-- under several meanings, and a bare phrase does not say where it leads. So
-- the wall shows (DECISIONS D10):
--   * one row per word, its strongest meaning;
--   * a phrase with a shorter one of the same meaning inside it, at least as
--     hot, is left to the shorter row: any sentence with "the tin" has "tin" in
--     it. A two-word codeword noticed as five phrases is one or two rows;
--   * EVERY understood word is shown, however many; the rest are the ones it
--     is closest to learning, up to `WALL_ROWS` words in all. A plain row cap
--     would hide understood words below the cut;
--   * words are grouped under where they lead ("-> Exchange Desk", a header
--     row), so no row carries the station's name and each fits the panel's
--     width (tests/meaning.luau measures it against Hud).
Readout.WALL_ROWS = 12

-- Whether `long` holds `short` as whole words: "the tin" holds "tin".
local function holds(long: string, short: string): boolean
	return long ~= short and string.find(` {long} `, ` {short} `, 1, true) ~= nil
end

local function hotterFirst(a: any, b: any): boolean
	if a.heat ~= b.heat then
		return a.heat > b.heat
	end
	return a.phrase < b.phrase
end

function Readout.lexiconRows(entries: { any }): { { text: string, heat: number?, kind: string } }
	-- A word the group uses as a number (DECISIONS D11) is its own row, apart
	-- from the same word's station meaning.
	local strongest: { [string]: any } = {}
	for _, entry in entries do
		local key = if entry.value then `{entry.phrase} = {entry.value}` else entry.phrase
		local held = strongest[key]
		if held == nil or entry.heat > held.heat then
			strongest[key] = entry
		end
	end
	local words = {}
	for _, entry in strongest do
		local covered = false
		for _, other in strongest do
			if
				other.concept == entry.concept
				and other.heat >= entry.heat
				and other.value == entry.value
				and holds(entry.phrase, other.phrase)
			then
				covered = true
				break
			end
		end
		if not covered then
			table.insert(words, entry)
		end
	end
	table.sort(words, hotterFirst)
	-- Hottest first, so every understood word comes before the first that is not.
	local shown = {}
	for _, entry in words do
		if Heat.isUnderstood(entry.heat) or #shown < Readout.WALL_ROWS then
			table.insert(shown, entry)
		end
	end
	-- Grouped by where they lead, the group with the hottest word first.
	local order: { string } = {}
	local groups: { [string]: { any } } = {}
	for _, entry in shown do
		local key = entry.leadsTo or ""
		if groups[key] == nil then
			groups[key] = {}
			table.insert(order, key)
		end
		table.insert(groups[key], entry)
	end
	local rows = {}
	for _, key in order do
		if key ~= "" then
			table.insert(rows, { text = `-> {key}`, kind = "header" })
		end
		for _, entry in groups[key] do
			table.insert(rows, {
				-- A counting row with no value is the letter dial's (DECISIONS D12):
				-- the Operator's own words, so not in quotes like a phrase someone
				-- said.
				text = string.format(
					if entry.concept == "counting" and entry.value == nil then "%s%s  %d%%%s" else '"%s"%s  %d%%%s',
					entry.phrase,
					if entry.value then ` = {entry.value}` else "",
					math.floor(entry.heat * 100 + 0.5),
					if Heat.isUnderstood(entry.heat) then "  understood" else ""
				),
				heat = entry.heat,
				kind = "word",
			})
		end
	end
	return rows
end

-- The round-over screen: its title, whether it reads as a win, and the line
-- promising the next round. Here rather than in init.client, where flipping
-- "won" to "not won" -- a lost round titled ROUND RESTORED -- would fail no
-- test. Anything but "won" is a loss: the server sends only "won" or "lost",
-- and a round that ended any other way was not restored.
Readout.TITLE_WON = "ROUND RESTORED"
Readout.TITLE_LOST = "ROUND LOST"

function Readout.roundOver(outcome: string?, number: number): { title: string, won: boolean, next: string }
	local won = outcome == "won"
	return {
		title = if won then Readout.TITLE_WON else Readout.TITLE_LOST,
		won = won,
		next = `round {number + 1} begins shortly`,
	}
end

return Readout
