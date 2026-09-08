--!strict
-- Entry point. Runs once per player on their own machine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

print(`[client] {Config.GameName} ready`)
