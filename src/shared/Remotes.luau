--!strict
-- Creates/finds the RemoteEvent folder once, so both sides agree on names.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- `Remotes.get` yields forever on a name that is not in this list, so a remote
-- used anywhere in `src/` and missing here is a silently dead wire, not an
-- error. `tests/wiring.luau` sweeps every `Remotes.get("...")` in the source
-- against this table in both directions.
--
-- `Silence` is the SUPERVISOR's channel, and separate for the same reason.
-- Its warning used to go out on `Heard`, which is the Operator's voice, so
-- the only signal the Supervisor gave arrived as the thing that hunts meaning
-- talking to you. R10 split the keypad off `Heard`, R13 split two refusals
-- that meant opposite things, R51 split the hum coming from the hum going --
-- three rounds proving two events must not arrive as one signal. It carries
-- the player's own clock, so it is fired at ONE client, never broadcast: how
-- long everyone else has been quiet is not yours to see.
--
-- `Objectives`, `OpenBoard`, `Rejected` and `Connected` are private for the
-- same reason `Silence` is, and the most serious of the four: `Objectives`
-- carries the actual two-digit ANSWERS players are supposed to relay by
-- talking, not read off someone else's screen (see `Objectives.viewFor`'s own
-- comment -- "the answer is included ONLY for the holder"). A future
-- "simplify pushObjectives into one FireAllClients call" would leak every
-- held answer to every player in the server. `tests/wiring.luau` guards all
-- four against ever being broadcast.
--
-- `Holding` (R144) is where the Operator is waiting, or nil while it walks. It
-- is broadcast on purpose: the room it holds is the one thing every player
-- needs, and a player walking in beside it was the loss nobody could read.
--
-- `Rejected` is deliberately separate from `Heard`. `Heard` is the Operator's
-- voice and is broadcast; `Rejected` is why YOUR submit at THAT station failed
-- and is only ever fired at one client. They were the same remote until R10,
-- which meant one player speaking painted another player's keypad with a red
-- concept id. See `Shared.Keypad`.
local REMOTE_NAMES = {
	"Heard",
	"LexiconUpdated",
	"Objectives",
	"Submit",
	"OpenBoard",
	"Rejected",
	"Connected",
	"Phase",
	"Silence",
	"Holding",
}

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
