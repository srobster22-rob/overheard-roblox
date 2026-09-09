--!strict
-- What the Your Line panel SAYS, given what the server sent.
--
-- Extracted from the client in R35 because the ordering was wrong and nothing
-- could see it. The panel built its rows with `LayoutOrder = i` for a line and
-- `i + 100` for that line's note, which reads correctly with ONE held line and
-- wrongly with two:
--
--     1  PROMPT board
--     2  PROMPT breaker
--   101  note   only you can see this   <- belongs to board
--   102  note   only you can see this   <- belongs to breaker
--
-- "only you can see this" is a claim about a SPECIFIC line, and it ended up
-- under a different one. Two held lines happen in ordinary play: two players
-- hold one each, one leaves, `redealOrphans` gives the orphan to the survivor.
--
-- The rows come back already in order, so the caller never invents one.

local Readout = {}

export type Row = {
	text: string,
	-- "line" is a fact only you can act on, "note" explains the line above it,
	-- "count" is the progress line, "empty" is the nothing-to-do message.
	kind: string,
}

Readout.PRIVATE_NOTE = "only you can see this"
-- No word here may be plain language for a concept the Operator listens for.
-- This said "someone else has a NUMBER for you" and was shown to exactly the
-- players who hold nothing -- the ones most likely to be talking, with no
-- connection to that concept and no way to link cause to effect when the
-- monster arrived. `tests/readout.luau` checks it against the live pool.
Readout.NOTHING_HELD = "nothing on your line - listen for somebody else's"

-- `entries` is the payload from `Objectives.viewFor`: one row per objective,
-- with `prompt` and `answer` present only on the ones this player holds.
function Readout.lineRows(entries: { any }): { Row }
	local rows: { Row } = {}
	local solved = 0

	for _, entry in entries do
		if entry.solved then
			solved += 1
		end
		if entry.holding and not entry.solved and entry.prompt and entry.answer then
			-- The note follows its own line IMMEDIATELY. That adjacency is the
			-- whole point of the row list being built here instead of being
			-- reassembled from two number series at render time.
			table.insert(rows, { text = string.format(entry.prompt, entry.answer), kind = "line" })
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

	if held == 0 then
		table.insert(rows, { text = Readout.NOTHING_HELD, kind = "empty" })
	end

	return rows
end

return Readout
