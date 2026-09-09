--!strict
-- Creates/finds the RemoteEvent folder once, so both sides agree on names.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- `Remotes.get` yields forever on a name that is not in this list, so a remote
-- used anywhere in `src/` and missing here is a silently dead wire, not an
-- error. `tests/wiring.luau` sweeps every `Remotes.get("...")` in the source
-- against this table in both directions.
--
-- `Rejected` is deliberately separate from `Heard`. `Heard` is the Operator's
-- voice and is broadcast; `Rejected` is why YOUR submit at THAT station failed
-- and is only ever fired at one client. They were the same remote until R10,
-- which meant one player speaking painted another player's keypad with a red
-- concept id. See `Shared.Keypad`.
local REMOTE_NAMES = { "Heard", "LexiconUpdated", "Objectives", "Submit", "OpenBoard", "Rejected" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in REMOTE_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
