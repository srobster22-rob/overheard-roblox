--!strict
-- WHAT OTHER PLAYERS MAY READ (R139, COACH.md C2).
--
-- The Lexicon panel shows every client the phrases the Operator is learning,
-- and those are words a PLAYER typed. Roblox requires text one user creates to
-- pass its filter before any other user sees it: TextService:FilterStringAsync,
-- then GetNonChatStringForBroadcastAsync for text everyone can see (Creator
-- Hub, "Text filtering"; PLATFORM.md). Until R139 the raw phrases went to
-- every client.
--
-- Pure: the filter and the thread it runs on are passed in. The server passes
-- TextService and task.spawn; the tests pass fakes. A phrase that could not be
-- filtered -- the call failed, came back empty, or nobody is known to have
-- typed it -- is LEFT OUT of the panel, never shown raw.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local Censor = {}
Censor.__index = Censor

-- The text as every player may see it, or nil when it could not be filtered.
export type Filter = (text: string, authorId: number) -> string?

export type Censor = typeof(setmetatable(
	{} :: {
		filter: Filter,
		-- What each (author, phrase) filtered to, for the phrases the panel
		-- still shows. Failures are not remembered, so they are asked again.
		shown: { [string]: string },
	},
	Censor
))

function Censor.new(filter: Filter): Censor
	return setmetatable({ filter = filter, shown = {} }, Censor)
end

-- The panel's rows as every client may see them: each phrase filtered for the
-- player who typed it, anything that could not be filtered left out, the rest
-- of each row passed through. The rows given are not changed: the Operator
-- keeps hearing the raw words. Each phrase goes to the filter once while it
-- stays on the panel (it is a web call with a rate limit, and the panel is sent
-- often); a phrase that has left the panel is forgotten. When two calls overlap,
-- the one that finishes last decides what is remembered, so a phrase may be
-- asked again -- never shown raw.
function Censor.rows(self: Censor, rows: { Types.Coinage }): { Types.Coinage }
	local out: { Types.Coinage } = {}
	local shown: { [string]: string } = {}
	for _, row in rows do
		local author = row.coinedBy
		if author ~= nil then
			local key = `{author}:{row.phrase}`
			local text = self.shown[key] or self.filter(row.phrase, author)
			if text ~= nil and text ~= "" then
				shown[key] = text
				local visible = table.clone(row)
				visible.phrase = text
				table.insert(out, visible)
			end
		end
	end
	self.shown = shown
	return out
end

-- How the panel is sent. Filtering yields, so each send runs on its own thread
-- (`spawn`: task.spawn on the server), and only the NEWEST request is sent: an
-- older one that finishes filtering later must not overwrite a newer panel.
-- Returns the function to call whenever the panel changes.
function Censor.sender(
	self: Censor,
	snapshot: () -> { Types.Coinage },
	send: (rows: { Types.Coinage }) -> (),
	spawn: (work: () -> ()) -> any
): () -> ()
	local requests = 0
	return function()
		requests += 1
		local request = requests
		spawn(function()
			local visible = self:rows(snapshot())
			if request == requests then
				send(visible)
			end
		end)
	end
end

return Censor
