--!strict
-- OVERHEARD - client entry point.
--
-- Renders the Lexicon: the words your group invented, and how close the
-- Operator is to understanding each one. This panel IS the game's tension, so
-- it stays on screen permanently rather than hiding in a menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "OverheardHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Lexicon"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 16)
panel.Size = UDim2.fromOffset(260, 220)
panel.BackgroundColor3 = Color3.fromRGB(14, 13, 12)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.RobotoMono
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(198, 176, 124)
title.Text = "LEXICON"
title.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(8, 32)
list.Size = UDim2.new(1, -16, 1, -40)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 2
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

-- White -> amber -> red as the Operator closes in on a phrase.
local function heatColor(heat: number): Color3
	if heat < 0.5 then
		return Color3.fromRGB(226, 226, 226):Lerp(Color3.fromRGB(226, 176, 82), heat / 0.5)
	end
	return Color3.fromRGB(226, 176, 82):Lerp(Color3.fromRGB(206, 62, 52), (heat - 0.5) / 0.5)
end

local function render(entries: { any })
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	if #entries == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 18)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.RobotoMono
		empty.TextSize = 11
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.TextColor3 = Color3.fromRGB(110, 106, 100)
		empty.Text = "no coinages yet"
		empty.Parent = list
		return
	end

	table.sort(entries, function(a, b)
		return a.heat > b.heat
	end)

	for i, entry in entries do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 18)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.RobotoMono
		row.TextSize = 12
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = heatColor(entry.heat)
		row.LayoutOrder = i
		row.Text = string.format('"%s"  %d%%', entry.phrase, math.floor(entry.heat * 100 + 0.5))
		row.Parent = list
	end
end

Remotes.get("LexiconUpdated").OnClientEvent:Connect(render)

-- The Operator's voice. Centre screen, brief, no styling flourish.
local said = Instance.new("TextLabel")
said.AnchorPoint = Vector2.new(0.5, 1)
said.Position = UDim2.fromScale(0.5, 0.82)
said.Size = UDim2.fromOffset(600, 28)
said.BackgroundTransparency = 1
said.Font = Enum.Font.RobotoMono
said.TextSize = 18
said.TextColor3 = Color3.fromRGB(226, 226, 226)
said.TextTransparency = 1
said.Text = ""
said.Parent = gui

Remotes.get("Heard").OnClientEvent:Connect(function(line: string)
	said.Text = line
	said.TextTransparency = 0
	task.delay(2.5, function()
		if said.Text == line then
			said.TextTransparency = 1
		end
	end)
end)

render({})
print(`[client] {Config.GameName} ready`)
