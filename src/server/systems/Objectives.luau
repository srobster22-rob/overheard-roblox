--!strict
-- Objectives, and the rule that makes this game a game.
--
-- INVARIANT: the player who can SEE the answer may never be the player who
-- ENTERS it. Enforced server-side, in `submit`. If a single player can ever
-- complete an objective alone, they have no reason to speak, and OVERHEARD
-- stops existing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Round = require(script.Parent.Round)

type ConceptId = Types.ConceptId

export type Objective = {
	id: string,
	concept: ConceptId,
	-- The value the holder can see and the actor must enter.
	answer: string,
	-- UserId of the player who can see the answer. Nobody else may read it.
	holder: number?,
	solved: boolean,
	-- Human-readable, shown to the holder only.
	prompt: string,
	-- Wrong answers this line has taken, per actor, and the time until which
	-- that actor's attempts on it are jammed. Per (line, actor) on purpose: one
	-- player guessing must not lock a line for the player who was actually told
	-- the number, and must not lock them out of the OTHER line either.
	-- Everyone who has been dealt this line THIS ROUND, and therefore had its
	-- answer on their screen. Not the same thing as the current holder: a
	-- mid-round join re-deals the board, and until R38 the previous holder --
	-- who had just read the number out — was free to type it in themselves.
	-- The invariant is about having SEEN the answer, so that is what is stored.
	seenBy: { [number]: boolean },
	misses: { [number]: number },
	jammedUntil: { [number]: number },
}

export type SubmitResult = {
	ok: boolean,
	-- Why it failed, for the client to display. Never leaks the answer.
	reason: string?,
	solved: boolean,
	-- A wrong code past the free one (`Config.FreeWrongDials`): the Operator
	-- walks to this station's room.
	ringsThrough: boolean?,
	-- Did the ACTOR do something wrong? Not the same as `not ok`, and that is
	-- the whole point of the field. Two players at one keypad both enter the
	-- number they were told; the first solves the line and the second arrives
	-- a frame later against `already restored`. Nothing about that is the
	-- second player's doing, but `init.server` used to route every `not ok` to
	-- the Operator's mouth, so at the exact moment the group WON it also said
	-- "That line is busy." to somebody for typing the right answer. The
	-- Operator may only accuse a player this module marks at fault.
	fault: boolean,
}

local Objectives = {}
Objectives.__index = Objectives

export type Board = typeof(setmetatable(
	{} :: {
		list: { Objective },
		onSolved: ((objective: Objective, actor: number) -> ())?,
		-- Wrong codes each player has entered this round, at any station.
		wrongDials: { [number]: number },
		-- Codes the Operator heard this round. Never dealt again before the
		-- round ends, so its read-back of one can never name a live line.
		spent: { [string]: boolean },
	},
	Objectives
))

-- The keypad's note for a code that was said aloud and has been replaced.
Objectives.OVERHEARD = "that code was overheard - its holder has a new one"

function Objectives.new(): Board
	return setmetatable({
		list = {},
		onSolved = nil,
		wrongDials = {},
		spent = {},
	}, Objectives)
end

-- Codes are two digits: said aloud as two words, and a long code would just
-- be tedious.
local FIRST_CODE, LAST_CODE = 10, 99

-- A code no line holds right now, none the Operator heard this round, and never
-- the one being replaced. Two lines on one code would let a single slip give
-- both away, and a code said aloud must not come back.
--
-- Picked from the codes still open, never by drawing until one is free: a
-- holder who says their own code over and over spends one code each time, and
-- a draw-until-free loop hangs the server once all ninety are spent. Past that
-- point any code no line holds will do.
local function freshAnswer(self: Board, replacing: string?): string
	local live: { [string]: boolean } = {}
	for _, o in self.list do
		live[o.answer] = true
	end
	if replacing then
		live[replacing] = true
	end
	local open: { string } = {}
	local unspent: { string } = {}
	for n = FIRST_CODE, LAST_CODE do
		local code = tostring(n)
		if not live[code] then
			table.insert(open, code)
			if not self.spent[code] then
				table.insert(unspent, code)
			end
		end
	end
	local pool = if #unspent > 0 then unspent else open
	return pool[math.random(#pool)]
end

function Objectives.add(self: Board, id: string, concept: ConceptId, prompt: string): Objective
	local objective: Objective = {
		id = id,
		concept = concept,
		answer = freshAnswer(self),
		holder = nil,
		solved = false,
		prompt = prompt,
		seenBy = {},
		misses = {},
		jammedUntil = {},
	}
	table.insert(self.list, objective)
	return objective
end

function Objectives.get(self: Board, id: string): Objective?
	for _, o in self.list do
		if o.id == id then
			return o
		end
	end
	return nil
end

-- Deal each unsolved objective to a holder. Spread across players so no single
-- player holds everything, which would collapse the transfer problem.
--
-- IN A SHUFFLED ORDER, NOT A ROTATION. Dealing consecutive seats from a random
-- start gave four players only four deals, and the station order never
-- changed, so a group could read which station a code was for from who said
-- it, and pass codes with nothing the Operator could hear. Shuffled, the holder
-- has to say which station, and that is what the Operator listens for.
function Objectives.deal(self: Board, userIds: { number })
	if #userIds == 0 then
		return
	end
	local order = table.clone(userIds)
	Round.shuffle(order)
	local i = 1
	for _, o in self.list do
		if not o.solved then
			local to = order[((i - 1) % #order) + 1]

			-- PREFER SOMEBODY WHO HAS ALREADY SEEN IT. Showing a line again to a
			-- player who has already read it costs nothing, and it stops the seen
			-- set growing every time somebody joins.
			--
			-- Without this the round deadlocks. `PlayerAdded` re-deals the whole
			-- board, so a player rejoining marks one more reader per line; after
			-- five deals over four players every line had been seen by everybody,
			-- nobody could patch anything, `allSolved` could never become true --
			-- and since only a finished round calls `reset`, `seenBy` was never
			-- cleared. Four players sat in a server that could not be finished.
			--
			-- This does not touch whether a join SHOULD re-deal at all, which is
			-- the owner's filed question: the board still reshuffles exactly as
			-- before, it just stops burning a fresh reader each time.
			local repeatReader: number? = nil
			for _, candidate in userIds do
				if o.seenBy[candidate] then
					repeatReader = candidate
					break
				end
			end
			if repeatReader ~= nil then
				to = repeatReader
			end

			o.holder = to
			-- Being dealt a line is what puts its answer on your screen.
			o.seenBy[to] = true
			i += 1
		end
	end
end

-- A holder who disconnects takes the answer out of the server with them:
-- `viewFor` shows it only to `o.holder`, so once that userId is gone nobody can
-- read the line, `submit` can never match it, and `allSolved` can never become
-- true. The station stays live as a thing nobody in the room can act on and the
-- round is unwinnable for everyone still playing.
--
-- Re-deal only the objectives whose holder is no longer present. Deliberately
-- NOT a full re-deal: whether JOINING should reshuffle everyone's lines is an
-- open design question for the owner, and moving only orphans does not answer
-- it. Derived from who is present rather than from who just left, so it also
-- repairs a holder that was never set. Returns how many lines moved.
function Objectives.redealOrphans(self: Board, userIds: { number }): number
	if #userIds == 0 then
		return 0
	end
	local present: { [number]: boolean } = {}
	for _, id in userIds do
		present[id] = true
	end

	local moved = 0
	local i = math.random(#userIds)
	for _, o in self.list do
		local holder = o.holder
		if not o.solved and (holder == nil or not present[holder]) then
			local to = userIds[((i - 1) % #userIds) + 1]
			o.holder = to
			o.seenBy[to] = true
			i += 1
			moved += 1
		end
	end
	return moved
end

-- A code said aloud is spent: the Operator heard it. The holder keeps the line
-- and gets a new code. Misses and jams stay, because they belong to the actor
-- who earned them, not to the code. Returns the line, or nil if `concept` has
-- no unsolved line.
function Objectives.reroll(self: Board, concept: ConceptId): Objective?
	for _, o in self.list do
		if o.concept == concept and not o.solved then
			self.spent[o.answer] = true
			o.answer = freshAnswer(self, o.answer)
			return o
		end
	end
	return nil
end

-- Each unsolved line's code, by concept: what the Operator listens for. A
-- restored line's code opens nothing, so it is not a secret any more.
function Objectives.liveCodes(self: Board): { [ConceptId]: string }
	local codes: { [ConceptId]: string } = {}
	for _, o in self.list do
		if not o.solved then
			codes[o.concept] = o.answer
		end
	end
	return codes
end

-- What a given player is allowed to know. The answer is included ONLY for the
-- holder; everyone else gets the same shape with the answer withheld.
function Objectives.viewFor(self: Board, userId: number): { any }
	local out: { any } = {}
	for _, o in self.list do
		table.insert(out, {
			id = o.id,
			concept = o.concept,
			solved = o.solved,
			holding = o.holder == userId,
			prompt = if o.holder == userId then o.prompt else nil,
			answer = if o.holder == userId then o.answer else nil,
		})
	end
	return out
end

-- The actor submits a value. This is the only place an objective can be solved.
--
-- `now` is passed in rather than read from the clock, so the jam is testable
-- headlessly and the module stays pure (same reason `Operator.hear` takes `at`).
--
-- GUESSING IS THE HOLE THIS CLOSES. The invariant at the top of this file said
-- a single player can never solve a line alone, and the only thing enforcing it
-- was `holder ~= actor`. But the answer is two digits: 90 values, median 45
-- guesses, one attempt every 0.75s at the remote's rate limit -- about 34
-- seconds of holding Enter to clear a line without anybody speaking, which is
-- the entire game. A wrong answer now jams that line for the player who gave
-- it, and the jams escalate, so the cost of guessing grows quadratically while
-- the cost of a typo does not.
function Objectives.submit(self: Board, id: string, actorUserId: number, value: string, now: number): SubmitResult
	local objective = self:get(id)
	if not objective then
		return { ok = false, reason = "no such objective", solved = false, fault = true }
	end
	if objective.solved then
		-- Somebody else got there first. NOT this player's fault; see `fault`.
		return { ok = false, reason = "already restored", solved = true, fault = false }
	end

	-- The invariant, stated as what it actually is: you may not enter an answer
	-- you have SEEN. Checking only the current holder let a mid-round re-deal
	-- move the line off the person who had just read the number, after which
	-- the keypad accepted it from them.
	if objective.seenBy[actorUserId] then
		return { ok = false, reason = "you were told this one - somebody else has to patch it", solved = false }
	end

	-- The invariant. The holder cannot solve their own objective.
	if objective.holder == actorUserId then
		return { ok = false, reason = "someone else has to patch this", solved = false, fault = true }
	end

	-- Jammed. Checked AFTER the holder rule and BEFORE the answer is compared,
	-- so a jammed player cannot use the reply to test a candidate answer.
	local jammedUntil = objective.jammedUntil[actorUserId]
	if jammedUntil and now < jammedUntil then
		return {
			ok = false,
			reason = `that line is jammed - wait {math.ceil(jammedUntil - now)}s`,
			solved = false,
			fault = true,
		}
	end

	local cleaned = string.gsub(value, "%D", "")
	-- A code the Operator heard this round is not a guess: it was said aloud and
	-- its holder already has a new one. A blind group read "that line is dead"
	-- for it and for a typo alike and could not tell which had happened, so it
	-- says so and charges nothing: no miss, no wrong dial, no voice.
	if cleaned ~= objective.answer and self.spent[cleaned] then
		return { ok = false, reason = Objectives.OVERHEARD, solved = false, fault = false }
	end
	if cleaned ~= objective.answer then
		local misses = (objective.misses[actorUserId] or 0) + 1
		objective.misses[actorUserId] = misses
		local dials = (self.wrongDials[actorUserId] or 0) + 1
		self.wrongDials[actorUserId] = dials
		local ringsThrough = dials > Config.FreeWrongDials
		-- Misses are never reset by serving a jam, so the n-th jam is n times
		-- as long as the first. That is what makes guessing hopeless rather
		-- than merely slow.
		if misses % Config.GuessesBeforeLockout == 0 then
			local seconds = Config.LockoutSeconds * (misses // Config.GuessesBeforeLockout)
			objective.jammedUntil[actorUserId] = now + seconds
			return {
				ok = false,
				reason = `that line is jammed - wait {seconds}s`,
				solved = false,
				fault = true,
				ringsThrough = ringsThrough,
			}
		end
		return { ok = false, reason = "that line is dead", solved = false, fault = true, ringsThrough = ringsThrough }
	end

	-- Right answer: this player was told the number, so forgive the fumbling.
	objective.misses[actorUserId] = nil
	objective.jammedUntil[actorUserId] = nil

	objective.solved = true
	if self.onSolved then
		(self.onSolved :: any)(objective, actorUserId)
	end
	return { ok = true, solved = true, fault = false }
end

-- NOT CLEANED ON PlayerRemoving, ON PURPOSE. R10 filed `misses`/`jammedUntil`
-- as a leak against CLAUDE.md's per-player cleanup rule, and R12 started to fix
-- it before noticing that the "fix" hands a guesser a way out: UserId is stable
-- across a rejoin and this board lives for the life of the SERVER, so clearing
-- these on departure means anyone jammed can reconnect and come back clean,
-- which is R9's entire round undone by a tidiness change. The leak is two
-- integers per departed player per line. `tests/objectives.luau` asserts the
-- survival, so this is a guarded decision rather than an oversight.
-- Start the board over for a new round: nothing solved, fresh answers, no
-- holders. New answers matter — reusing them would let a group that finished a
-- round simply retype last round's numbers.
function Objectives.reset(self: Board)
	self.wrongDials = {}
	self.spent = {}
	for _, objective in self.list do
		objective.solved = false
		objective.holder = nil
		objective.answer = freshAnswer(self, objective.answer)
		-- The jam ledger is per-ROUND. Leaving it meant a player who jammed a
		-- line in one round was refused the CORRECT answer in the next -- and
		-- since the answers are re-rolled here, the jam punished them for
		-- guesses at a number that no longer exists.
		objective.seenBy = {}
		objective.misses = {}
		objective.jammedUntil = {}
	end
end

-- Can anybody still finish an unsolved line? `able` is the players who can act:
-- present, and not on the line.
--
-- The round's loss condition used to ask whether everyone had been TAKEN, and
-- that is not the same question. R23 made the Operator take everyone in a room
-- at once; three of four players caught in one arrival leaves a survivor who is
-- always the reader of one of the two lines, so that line can be patched by
-- nobody -- `allSolved` unreachable -- while `allTaken` needs the survivor
-- caught too, which they can simply avoid. The round then ended neither way and
-- ran forever, with no timer to rescue it.
--
-- Re-dealing the stranded line does not help: handing it to the survivor marks
-- them as having seen it, so they can patch neither. With one player able to
-- act the round is unwinnable however the cards fall, which is the owner's solo
-- question. What is fixable here is that it should END.
function Objectives.anyFinishable(self: Board, able: { number }): boolean
	for _, objective in self.list do
		if objective.solved then
			continue
		end
		for _, userId in able do
			if not objective.seenBy[userId] then
				return true
			end
		end
	end
	return false
end

function Objectives.allSolved(self: Board): boolean
	for _, o in self.list do
		if not o.solved then
			return false
		end
	end
	return #self.list > 0
end

return Objectives
