--!strict
-- The Lexicon's SAVE FORMAT, built and proved before any `DataStoreService`
-- call exists.
--
-- A Lexicon that persists across sessions, per group, is the retention
-- mechanic `GAME.md`'s escalation section is written around. It has two
-- separable problems, and only one of them belongs in this file: WHAT COUNTS
-- AS A GROUP that persists is a design decision with real cost trade-offs
-- (private servers? a shared code? Roblox's friends graph?) and is an open
-- question for the owner (OWNER.md), not guessed at here. WHETHER THE SAVED
-- DATA ROUND-TRIPS HONESTLY needs no such decision and is pure data, so it is
-- built and tested headlessly first, as `Hum.smooth` and `Silence` are: prove
-- the arithmetic where a test can reach it, then wire the Roblox-only part
-- thin.
--
-- A DataStore read can return nothing (nobody has saved yet), something from
-- an OLDER version of this format, or something outright corrupted by a bug
-- elsewhere. None of those may crash the server, so `decode` never errors —
-- it validates every field and drops what it cannot trust, returning an empty
-- Lexicon in the worst case rather than taking the round down with it.

local LexiconSave = {}

-- Bumped whenever the shape below changes incompatibly. `decode` refuses
-- anything that does not match, rather than guess at a shape it was not built
-- to read — a silent misread here would not error, it would quietly hand
-- players back the WRONG words for the wrong concepts.
LexiconSave.VERSION = 1

-- A generous backstop, not a design number. A simulated session's Lexicon
-- peaks at about 43 coinages, and ~170 for a very chatty group, because
-- cooling prunes the dead ones. This exists only so a bug that stops pruning
-- cannot also grow the saved payload without limit.
LexiconSave.MAX_SAVED = 200

export type SavedCoinage = {
	phrase: string,
	concept: string,
	heat: number,
	sightings: number,
	coinedBy: number?,
}

export type SaveData = {
	v: number,
	coinages: { SavedCoinage },
}

-- Coinages in -> a plain, DataStore-safe table out.
--
-- Cold coinages (heat <= 0) are dropped rather than saved: they carry nothing
-- the group has not already fully forgotten, which is also why the live
-- Lexicon panel drops a phrase that cools all the way to zero. Saving them
-- anyway would mean every session's save grows even though nothing
-- meaningful survived it.
--
-- Sorted by heat, strongest first, so if `MAX_SAVED` ever actually binds it is
-- the WEAKEST coinages that are dropped, not an arbitrary prefix of whatever
-- table order the caller happened to hold.
function LexiconSave.encode(coinages: { any }): SaveData
	local keep: { SavedCoinage } = {}
	for _, c in coinages do
		if type(c) == "table" and type(c.heat) == "number" and c.heat > 0 then
			table.insert(keep, {
				phrase = c.phrase,
				concept = c.concept,
				heat = math.clamp(c.heat, 0, 1),
				sightings = math.max(0, math.floor(c.sightings or 0)),
				coinedBy = c.coinedBy,
			})
		end
	end

	table.sort(keep, function(a, b)
		if a.heat ~= b.heat then
			return a.heat > b.heat
		end
		-- Stable tie-break, the same reason Heuristic.conveyed has one: two
		-- saves of an identical Lexicon must produce an identical file, not one
		-- that depends on which order a table iterated in.
		return a.phrase < b.phrase
	end)

	if #keep > LexiconSave.MAX_SAVED then
		local trimmed: { SavedCoinage } = {}
		for i = 1, LexiconSave.MAX_SAVED do
			trimmed[i] = keep[i]
		end
		keep = trimmed
	end

	return { v = LexiconSave.VERSION, coinages = keep }
end

-- Is this one entry trustworthy enough to hand back to `Operator.new`'s
-- caller? Every field checked; nothing here assumes the shape is right just
-- because the outer table's `v` matched.
local function validCoinage(c: any): SavedCoinage?
	if type(c) ~= "table" then
		return nil
	end
	if type(c.phrase) ~= "string" or #c.phrase == 0 or #c.phrase > 64 then
		return nil
	end
	if type(c.concept) ~= "string" or #c.concept == 0 then
		return nil
	end
	if type(c.heat) ~= "number" or c.heat ~= c.heat or c.heat < 0 or c.heat > 1 then
		-- `c.heat ~= c.heat` catches NaN, which is a number but satisfies no
		-- ordering comparison -- a plain `c.heat < 0 or c.heat > 1` lets it
		-- through silently.
		return nil
	end
	if type(c.sightings) ~= "number" or c.sightings ~= math.floor(c.sightings) or c.sightings < 0 then
		return nil
	end
	if c.coinedBy ~= nil and type(c.coinedBy) ~= "number" then
		return nil
	end
	return {
		phrase = c.phrase,
		concept = c.concept,
		heat = c.heat,
		sightings = c.sightings,
		coinedBy = c.coinedBy,
	}
end

-- A plain table in -> coinages out, or an empty Lexicon if the input cannot be
-- trusted. NEVER errors: a DataStore read handing this something nil,
-- foreign, or a future version must not take the round down with it.
function LexiconSave.decode(data: any): { SavedCoinage }
	if type(data) ~= "table" then
		return {}
	end
	if data.v ~= LexiconSave.VERSION then
		return {}
	end
	if type(data.coinages) ~= "table" then
		return {}
	end

	local out: { SavedCoinage } = {}
	for _, c in data.coinages do
		local valid = validCoinage(c)
		if valid then
			table.insert(out, valid)
		end
		if #out >= LexiconSave.MAX_SAVED then
			break
		end
	end
	return out
end

return LexiconSave
