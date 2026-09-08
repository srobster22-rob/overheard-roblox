--!strict
-- Entry point. Runs once on the server when the place starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)

print(`[server] {Config.GameName} booting`)

Players.PlayerAdded:Connect(function(player: Player)
	print(`[server] {player.Name} joined`)
end)
