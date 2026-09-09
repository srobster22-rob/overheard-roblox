--!strict
-- Objectives, and the rule that makes this game a game.
--
-- INVARIANT: the player who can SEE the answer may never be the player who
-- ENTERS it. Enforced server-side, in `submit`. If a single player can ever
-- complete an objective alone, they have no reason to speak, and OVERHEARD
-- stops existing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
}

export type SubmitResult = {
	ok: boolean,
	-- Why it failed, for the client to display. Never leaks the answer.
	reason: string?,
	solved: boolean,
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
function Objectives.submit(self: Board, id: string, actorUserId: number, value: string): SubmitResult
	local objective = self:get(id)
	if not objective then
		return { ok = false, reason = "no such objective", solved = false }
	end
	if objective.solved then
		return { ok = false, reason = "already restored", solved = true }
	end

	-- The invariant. The holder cannot solve their own objective.
	if objective.holder == actorUserId then
		return { ok = false, reason = "someone else has to patch this", solved = false }
	end

	local cleaned = string.gsub(value, "%D", "")
	if cleaned ~= objective.answer then
		return { ok = false, reason = "that line is dead", solved = false }
	end

	objective.solved = true
	if self.onSolved then
		(self.onSolved :: any)(objective, actorUserId)
	end
	return { ok = true, solved = true }
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
