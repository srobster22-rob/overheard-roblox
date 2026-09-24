--!strict
-- OVERHEARD - server entry point.
--
-- Builds the world, hands the game flow its Roblox host (systems/Exchange), and
-- connects the flow to Roblox: chat, prompts, remotes, players and the clock.
-- Every connection runs under Guard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(ReplicatedStorage.Shared.Guard)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ChatFeed = require(script.systems.ChatFeed)
local Exchange = require(script.systems.Exchange)
local Presence = require(script.systems.Presence)
local Round = require(script.systems.Round)
local World = require(script.systems.World)

local heardRemote = Remotes.get("Heard")
local lexiconRemote = Remotes.get("LexiconUpdated")
local objectivesRemote = Remotes.get("Objectives")
local submitRemote = Remotes.get("Submit")
local openBoardRemote = Remotes.get("OpenBoard")
-- The SUPERVISOR's own channel. Its warning used to go out on `heardRemote`,
-- which is the Operator's voice, so the only signal it gave arrived as the
-- thing that hunts meaning talking to you. R10, R13 and R51 were each spent
-- proving two events must not arrive as one signal; this is the fourth.
-- Fired at one client only: how long everybody else has been quiet is not
-- yours to see.
local silenceRemote = Remotes.get("Silence")
-- Keypad feedback. Separate from `heardRemote` on purpose: `Heard` is the
-- Operator's voice and goes to everyone, and while the keypad read its detail
-- field, a broadcast about one player's speech landed in another player's
-- error line. FireClient only, and it names its station. See Shared.Keypad.
local rejectedRemote = Remotes.get("Rejected")
local connectedRemote = Remotes.get("Connected")
-- Whether a round is being played, and how the last one ended. The client had
-- no idea a round could END until R33.
local phaseRemote = Remotes.get("Phase")
local holdingRemote = Remotes.get("Holding")

local built = World.build()

-- `built.spawn` was computed by World and read by nobody for twenty-one
-- rounds, so players landed wherever Roblox decided rather than in the
-- corridor between the rooms. Placed here rather than in World because it
-- is a game-flow decision, not geometry.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "Exchange"
spawnPad.Anchored = true
spawnPad.CanCollide = false
spawnPad.Transparency = 1
spawnPad.Size = Vector3.new(12, 1, 8)
spawnPad.Position = built.spawn
spawnPad.Parent = workspace

local exchange = Exchange.build({
	Players = Players,
	TextService = TextService,
	remotes = {
		Heard = heardRemote,
		LexiconUpdated = lexiconRemote,
		Objectives = objectivesRemote,
		OpenBoard = openBoardRemote,
		Silence = silenceRemote,
		Rejected = rejectedRemote,
		Connected = connectedRemote,
		Phase = phaseRemote,
		Holding = holdingRemote,
	},
	built = built,
	spawnTask = task.spawn,
	deferTask = task.defer,
})
local body = Presence.spawn(exchange.pursuit)

ChatFeed.new(Guard.wrap("server.hearChat", exchange.hearChat)):follow(Players)

built.readerPrompt.Triggered:Connect(Guard.wrap("server.readerPrompt", exchange.readerPrompt))

for _, station in Round.STATIONS do
	local prompt = built.stations[station.id]
	if not prompt then
		-- A station with no physical prompt is an objective nobody can reach,
		-- which makes `allSolved` unreachable. Fail loudly rather than ship a
		-- round that cannot end.
		error(`World built no prompt for station '{station.id}'`)
	end
	prompt.Triggered:Connect(Guard.wrap("server.stationPrompt", function(player: Player)
		exchange.openStation(player, station)
	end))
end

submitRemote.OnServerEvent:Connect(Guard.wrap("server.submit", exchange.submit))
Players.PlayerAdded:Connect(Guard.wrap("server.playerAdded", exchange.playerAdded))
Players.PlayerRemoving:Connect(Guard.wrap("server.playerRemoving", exchange.playerRemoving))

local running = true
task.spawn(Guard.wrap("server.loop", function()
	while running do
		task.wait(Config.TickSeconds)
		if not running then
			break
		end
		Guard.run("server.beat", exchange.beat)
	end
end))

game:BindToClose(Guard.wrap("server.close", function()
	running = false
	body.stop()
end))

print(`[server] {Config.GameName} - {#exchange.secrets} secrets this round`)
for _, secret in exchange.secrets do
	print(`  secret: {secret.concept} -> {secret.payload}`)
end
