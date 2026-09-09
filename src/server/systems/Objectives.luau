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
	misses: { [number]: number },
	jammedUntil: { [number]: number },
}

export type SubmitResult = {
	ok: boolean,
	-- Why it failed, for the client to display. Never leaks the answer.
	reason: string?,
	solved: boolean,
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
	},
	Objectives
))

function Objectives.new(): Board
	return setmetatable({
		list = {},
		onSolved = nil,
	}, Objectives)
end

local function randomJack(): string
	-- Two digits, spoken aloud as two words. "Forty seven" is easy to
	-- circumlocute; a long code would just be tedious.
	return string.format("%02d", math.random(10, 99))
end

function Objectives.add(self: Board, id: string, concept: ConceptId, prompt: string): Objective
	local objective: Objective = {
		id = id,
		concept = concept,
		answer = randomJack(),
		holder = nil,
		solved = false,
		prompt = prompt,
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
function Objectives.deal(self: Board, userIds: { number })
	if #userIds == 0 then
		return
	end
	local i = math.random(#userIds)
	for _, o in self.list do
		if not o.solved then
			o.holder = userIds[((i - 1) % #userIds) + 1]
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
			o.holder = userIds[((i - 1) % #userIds) + 1]
			i += 1
			moved += 1
		end
	end
	return moved
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
	if cleaned ~= objective.answer then
		local misses = (objective.misses[actorUserId] or 0) + 1
		objective.misses[actorUserId] = misses
		-- Misses are never reset by serving a jam, so the n-th jam is n times
		-- as long as the first. That is what makes guessing hopeless rather
		-- than merely slow.
		if misses % Config.GuessesBeforeLockout == 0 then
			local seconds = Config.LockoutSeconds * (misses // Config.GuessesBeforeLockout)
			objective.jammedUntil[actorUserId] = now + seconds
			return { ok = false, reason = `that line is jammed - wait {seconds}s`, solved = false, fault = true }
		end
		return { ok = false, reason = "that line is dead", solved = false, fault = true }
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
function Objectives.allSolved(self: Board): boolean
	for _, o in self.list do
		if not o.solved then
			return false
		end
	end
	return #self.list > 0
end

return Objectives
