--!strict
-- OVERHEARD - server entry point.
--
-- Wires chat into the Operator, and the Operator's reactions back out to
-- clients. Deliberately thin: the thinking lives in systems/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Operator = require(script.systems.Operator)
local Round = require(script.systems.Round)

local heardRemote = Remotes.get("Heard")
local lexiconRemote = Remotes.get("LexiconUpdated")

local secrets = Round.pickSecrets(3)
local operator = Operator.new(secrets)

local function broadcastLexicon()
	lexiconRemote:FireAllClients(operator:snapshot())
end

operator.onUnderstood = function(concept: string, payload: string, confidence: number)
	-- The Operator has understood something. In the full game this drives its
	-- movement; for now it announces, which is what we need to feel the loop.
	print(`[operator] understood '{concept}' ({string.format("%.2f", confidence)}) -> {payload}`)
	heardRemote:FireAllClients(Round.LINES.understood, concept, confidence)
end

operator.onBurned = function(coinage)
	print(`[operator] BURNED '{coinage.phrase}' = {coinage.concept}`)
	heardRemote:FireAllClients(Round.LINES.connecting, coinage.concept, 1)
	broadcastLexicon()
end

-- Everything a player says is evidence. TextChatService is the modern path;
-- this callback sees every message before it is delivered.
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local source = message.TextSource
	if not source then
		return nil
	end
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player then
		return nil
	end

	operator:hear({
		speaker = player,
		text = message.Text,
		at = os.clock(),
	})
	return nil
end

-- Temporary: a player firing this stands in for "the group demonstrably acted
-- on a concept". Real objectives will call operator:credit directly.
Remotes.get("Acted").OnServerEvent:Connect(function(_player: Player, concept: unknown)
	if typeof(concept) ~= "string" then
		return -- never trust the client
	end
	operator:credit(concept :: string, os.clock())
	broadcastLexicon()
end)

Players.PlayerAdded:Connect(function(player: Player)
	print(`[server] {player.Name} connected to the exchange`)
	task.defer(broadcastLexicon)
end)

print(`[server] {Config.GameName} - {#secrets} secrets this round`)
for _, secret in secrets do
	print(`  secret: {secret.concept} -> {secret.payload}`)
end
