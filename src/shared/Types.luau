--!strict
-- Shared type vocabulary. Kept in one place so server and client cannot drift.

export type ConceptId = string

-- A fact the Operator wants. Players must transmit it to each other to win,
-- which is exactly what makes them audible.
export type Secret = {
	concept: ConceptId,
	-- Words that plainly denote the concept. Saying any of these is a giveaway.
	plain: { string },
	-- Where the Operator goes / what it does once it understands.
	payload: string,
}

-- A phrase the players coined themselves. The Operator does not know it yet.
export type Coinage = {
	phrase: string,
	concept: ConceptId,
	-- 0 = fresh, 1 = fully burned (understood).
	heat: number,
	-- How many times we have seen it used near this concept.
	sightings: number,
	coinedBy: number?,
	-- Where this word would bring the Operator, as the wall names it: the
	-- station's label (Round.leadsTo). Set for the wall only (Round.withLeads);
	-- never saved.
	leadsTo: string?,
	-- R147: for a word the group uses as a NUMBER, the value it stands for
	-- (Operator.countingRows); nil for a station's word.
	value: number?,
}

-- Where the Operator is (R144), for every client's Your Line panel: the label
-- of the station in the room it is WAITING in (nil while it walks), and whether
-- the room it is in or walking to is the way out.
export type Holding = {
	label: string?,
	wayOut: boolean,
}

export type Utterance = {
	speaker: Player,
	text: string,
	at: number,
}

-- What a comprehension backend returns for one utterance.
export type Understanding = {
	concept: ConceptId?,
	-- 0..1 how sure the listener is that the utterance conveyed the concept.
	confidence: number,
	-- Tokens that were NOT plain language for the concept. These are candidate
	-- coinages: the listener does not understand them yet, but it noticed them.
	novelTerms: { string },
	-- Which backend produced this, for logging and A/B.
	source: string,
	-- What moved it, when that is the server's own text: a word from the pool
	-- or a live code. Nil for a group's codeword, which is a player's text and
	-- would need the chat filter before anyone else saw it.
	heard: string?,
	-- The live code itself was said. A code said aloud is spent: the line gets
	-- a new one, so saying it and typing it before the Operator arrives wins
	-- nothing.
	byCode: boolean?,
}

export type ComprehensionBackend = {
	name: string,
	-- Must be safe to call often; may yield.
	understand: (utterance: Utterance, secrets: { Secret }, lexicon: { Coinage }) -> Understanding,
}

return {}
