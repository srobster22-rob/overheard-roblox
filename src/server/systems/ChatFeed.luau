--!strict
-- WHAT PLAYERS TYPE, HEARD ON THE SERVER (R139, COACH.md C1).
--
-- Everything the Operator and the Supervisor hear comes through here. Until
-- R139 the server set `TextChatService.OnIncomingMessage`, a callback Roblox
-- only ever runs on the CLIENT (PLATFORM.md has the doc line). On a live
-- server it never fired: no plain word brought the Operator, no codeword was
-- learned, and every player counted as silent, so the Supervisor sent it after
-- them whatever they typed. The suite called that hook by hand, so it never
-- noticed.
--
-- `Player.Chatted` fires on the server for text chat. One connection per
-- player, made when they join and dropped when they leave (CLAUDE.md: every
-- connection is disconnected). `follow` does both for a whole Players service,
-- so the server's part is one call and the rest is tested with fake players.

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
	self.connections[speaker.UserId] = speaker.Chatted:Connect(function(text: string)
		self.onChat(speaker, text)
	end)
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
	roster.PlayerAdded:Connect(function(player: any)
		self:listen(player)
	end)
	roster.PlayerRemoving:Connect(function(player: any)
		self:forget(player.UserId)
	end)
end

return ChatFeed
