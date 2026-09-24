--!strict
-- WHAT PLAYERS TYPE, HEARD ON THE SERVER.
--
-- Everything the Operator and the Supervisor hear comes through here. Not
-- `TextChatService.OnIncomingMessage`: Roblox only ever runs that callback on
-- the CLIENT (PLATFORM.md has the doc line). Set on the server it never fires,
-- so no plain word brings the Operator, no codeword is learned, and every
-- player counts as silent, whatever they type. The headless suite cannot tell
-- which side a callback runs on; tests/wiring.luau checks every such API
-- against PLATFORM.md instead.
--
-- `Player.Chatted` fires on the server for text chat. One connection per
-- player, made when they join and dropped when they leave (CLAUDE.md: every
-- connection is disconnected). `follow` does both for a whole Players service,
-- so the server's part is one call and the rest is tested with fake players.

local Guard = require(game:GetService("ReplicatedStorage").Shared.Guard)

local ChatFeed = {}
ChatFeed.__index = ChatFeed

-- The parts of a Player and of the Players service this needs. Tests pass
-- fakes whose signals behave like the real ones.
export type Speaker = {
	UserId: number,
	Chatted: RBXScriptSignal,
}
export type Roster = {
	GetPlayers: (self: any) -> { any },
	PlayerAdded: RBXScriptSignal,
	PlayerRemoving: RBXScriptSignal,
}

export type Feed = typeof(setmetatable(
	{} :: {
		-- Told every message, with who typed it.
		onChat: (speaker: any, text: string) -> (),
		connections: { [number]: RBXScriptConnection },
	},
	ChatFeed
))

function ChatFeed.new(onChat: (speaker: any, text: string) -> ()): Feed
	return setmetatable({ onChat = onChat, connections = {} }, ChatFeed)
end

-- Start hearing a player. Asking twice is harmless: a second connection would
-- hear every message twice.
function ChatFeed.listen(self: Feed, speaker: Speaker)
	if self.connections[speaker.UserId] ~= nil then
		return
	end
	self.connections[speaker.UserId] = speaker.Chatted:Connect(Guard.wrap("ChatFeed.chatted", function(text: string)
		self.onChat(speaker, text)
	end))
end

-- Stop hearing a player who has left.
function ChatFeed.forget(self: Feed, userId: number)
	local connection = self.connections[userId]
	if connection then
		connection:Disconnect()
		self.connections[userId] = nil
	end
end

-- Hear everyone in a Players service: whoever is already there (a Studio test
-- often starts with the player in before the server script runs), everyone
-- who joins, and nobody once they leave.
function ChatFeed.follow(self: Feed, roster: Roster)
	for _, player in roster:GetPlayers() do
		self:listen(player)
	end
	roster.PlayerAdded:Connect(Guard.wrap("ChatFeed.playerAdded", function(player: any)
		self:listen(player)
	end))
	roster.PlayerRemoving:Connect(Guard.wrap("ChatFeed.playerRemoving", function(player: any)
		self:forget(player.UserId)
	end))
end

return ChatFeed
