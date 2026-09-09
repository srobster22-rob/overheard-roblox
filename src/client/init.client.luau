--!strict
-- OVERHEARD - client entry point.
--
-- Three pieces of UI, all of them about information:
--   LEXICON  - the words your group invented, and how close it is to knowing them
--   YOUR LINE - the fact only you can see, which someone else has to act on
--   THE BOARD - where you enter what someone else told you
--
-- The client renders and inputs. It decides nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Keypad = require(ReplicatedStorage.Shared.Keypad)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Named up front rather than fetched inline, so both sides read the same way
-- and `tests/wiring.luau` can tell which handler belongs to which remote.
local heardRemote = Remotes.get("Heard")
local lexiconRemote = Remotes.get("LexiconUpdated")
local objectivesRemote = Remotes.get("Objectives")
local submitRemote = Remotes.get("Submit")
local openBoardRemote = Remotes.get("OpenBoard")
local rejectedRemote = Remotes.get("Rejected")
local connectedRemote = Remotes.get("Connected")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "OverheardHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(226, 226, 226)
local BRASS = Color3.fromRGB(198, 176, 124)
local DIM = Color3.fromRGB(110, 106, 100)
local PANEL_BG = Color3.fromRGB(14, 13, 12)

local function panel(name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = PANEL_BG
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.RobotoMono
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = BRASS
	title.Text = string.upper(name)
	title.Parent = frame

	return frame
end

local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.RobotoMono
	l.TextSize = size
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

-- LEXICON ------------------------------------------------------------------

local lexPanel = panel("Lexicon", UDim2.fromOffset(260, 200), UDim2.new(1, -16, 0, 16), Vector2.new(1, 0))

local lexList = Instance.new("ScrollingFrame")
lexList.Position = UDim2.fromOffset(8, 32)
lexList.Size = UDim2.new(1, -16, 1, -40)
lexList.BackgroundTransparency = 1
lexList.BorderSizePixel = 0
lexList.ScrollBarThickness = 2
lexList.CanvasSize = UDim2.new()
lexList.AutomaticCanvasSize = Enum.AutomaticSize.Y
lexList.Parent = lexPanel

local lexLayout = Instance.new("UIListLayout")
lexLayout.Padding = UDim.new(0, 2)
lexLayout.SortOrder = Enum.SortOrder.LayoutOrder
lexLayout.Parent = lexList

local function heatColor(heat: number): Color3
	if heat < 0.5 then
		return INK:Lerp(Color3.fromRGB(226, 176, 82), heat / 0.5)
	end
	return Color3.fromRGB(226, 176, 82):Lerp(Color3.fromRGB(206, 62, 52), (heat - 0.5) / 0.5)
end

local function renderLexicon(entries: { any })
	for _, child in lexList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #entries == 0 then
		label(lexList, "no coinages yet", 11, DIM)
		return
	end
	table.sort(entries, function(a, b)
		return a.heat > b.heat
	end)
	for i, entry in entries do
		local row = label(
			lexList,
			string.format('"%s"  %d%%', entry.phrase, math.floor(entry.heat * 100 + 0.5)),
			12,
			heatColor(entry.heat)
		)
		row.LayoutOrder = i
	end
end

-- YOUR LINE ----------------------------------------------------------------

local linePanel = panel("Your line", UDim2.fromOffset(300, 120), UDim2.fromOffset(16, 16), Vector2.new(0, 0))

local lineList = Instance.new("Frame")
lineList.Position = UDim2.fromOffset(8, 32)
lineList.Size = UDim2.new(1, -16, 1, -40)
lineList.BackgroundTransparency = 1
lineList.Parent = linePanel

local lineLayout = Instance.new("UIListLayout")
lineLayout.Padding = UDim.new(0, 4)
lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
lineLayout.Parent = lineList

local function renderObjectives(entries: { any })
	for _, child in lineList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local holdingAny = false
	for i, entry in entries do
		if entry.holding and not entry.solved and entry.prompt and entry.answer then
			holdingAny = true
			local text = string.format(entry.prompt, entry.answer)
			label(lineList, text, 13, INK).LayoutOrder = i
			label(lineList, "only you can see this", 10, DIM).LayoutOrder = i + 100
		end
	end

	local solved, total = 0, #entries
	for _, entry in entries do
		if entry.solved then
			solved += 1
		end
	end
	label(lineList, `restored {solved}/{total}`, 11, BRASS).LayoutOrder = 900

	if not holdingAny then
		label(lineList, "nothing on your line - someone else has a number for you", 11, DIM).LayoutOrder = 950
	end
end

-- THE BOARD ----------------------------------------------------------------

local boardPanel = panel("The board", UDim2.fromOffset(280, 130), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
boardPanel.Visible = false

local hint = label(boardPanel, "enter the jack number you were told", 11, DIM)
hint.Position = UDim2.fromOffset(8, 34)
hint.Size = UDim2.new(1, -16, 0, 16)

local input = Instance.new("TextBox")
input.Position = UDim2.fromOffset(8, 58)
input.Size = UDim2.new(1, -16, 0, 34)
input.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
input.BorderSizePixel = 0
input.Font = Enum.Font.RobotoMono
input.TextSize = 20
input.TextColor3 = INK
input.PlaceholderText = "--"
input.Text = ""
input.ClearTextOnFocus = false
input.Parent = boardPanel

local status = label(boardPanel, "", 11, Color3.fromRGB(206, 62, 52))
status.Position = UDim2.fromOffset(8, 96)
status.Size = UDim2.new(1, -16, 0, 16)

-- Which station this keypad is currently standing in for. There is more than
-- one now (switchboard, breaker), and submitting a breaker code against the
-- switchboard fails silently as a wrong answer, which reads as a bug.
local openStation: string? = nil

local function closeBoard()
	boardPanel.Visible = false
	openStation = nil
	input.Text = ""
	status.Text = ""
end

input.FocusLost:Connect(function(enterPressed: boolean)
	if not enterPressed then
		return
	end
	local value = input.Text
	if #value == 0 or not openStation then
		closeBoard()
		return
	end
	submitRemote:FireServer(openStation, value)
	input.Text = ""
end)

local function onOpenBoard(stationId: string, actionText: string?)
	openStation = stationId
	boardPanel.Visible = true
	local title = boardPanel:FindFirstChild("Title") :: TextLabel?
	if title then
		title.Text = string.upper(actionText or "the board")
	end
	hint.Text = `enter the number you were told for the {stationId}`
	status.Text = ""
	input:CaptureFocus()
end
openBoardRemote.OnClientEvent:Connect(onOpenBoard)

-- ON THE LINE ---------------------------------------------------------------
-- Being caught does not remove you. It removes your ability to ACT, and says so
-- plainly, because a player who thinks they are dead stops talking -- and their
-- voice is the only thing they have left, and the thing their team still needs.

local onLine = panel("On the line", UDim2.fromOffset(300, 74), UDim2.fromScale(0.5, 0.12), Vector2.new(0.5, 0))
onLine.Visible = false
onLine.BackgroundColor3 = Color3.fromRGB(38, 14, 14)

local onLineBody = label(onLine, "you can still be heard. you cannot patch.", 12, INK)
onLineBody.Position = UDim2.fromOffset(8, 34)
onLineBody.Size = UDim2.new(1, -16, 0, 32)

connectedRemote.OnClientEvent:Connect(function(caught: boolean)
	onLine.Visible = caught == true
	if caught then
		closeBoard()
	end
end)

-- THE OPERATOR'S VOICE -----------------------------------------------------

local said = Instance.new("TextLabel")
said.AnchorPoint = Vector2.new(0.5, 1)
said.Position = UDim2.fromScale(0.5, 0.86)
said.Size = UDim2.fromOffset(620, 28)
said.BackgroundTransparency = 1
said.Font = Enum.Font.RobotoMono
said.TextSize = 18
said.TextColor3 = INK
said.TextTransparency = 1
said.Text = ""
said.Parent = gui

-- The Operator's voice, and ONLY the voice. This handler used to also write the
-- keypad's error line from its detail field, which is broadcast: one player
-- speaking painted a red `jack_number` into another player's keypad, in the
-- slot that says "that line is jammed". Keypad feedback arrives on `Rejected`.
local function onHeard(line: string)
	said.Text = line
	said.TextTransparency = 0
	task.delay(2.5, function()
		if said.Text == line then
			said.TextTransparency = 1
		end
	end)
end
heardRemote.OnClientEvent:Connect(onHeard)

local function onObjectives(entries: { any })
	renderObjectives(entries)
	-- A solved station closes its own keypad rather than leaving a stale one
	-- open. Only the station actually in front of the player, now that there
	-- is more than one.
	for _, entry in entries do
		if entry.id == openStation and entry.solved then
			closeBoard()
		end
	end
end
objectivesRemote.OnClientEvent:Connect(onObjectives)

-- Why YOUR submit at THAT station failed. Private, and dropped unless the
-- player is still looking at the keypad it is about — `Keypad.accepts` owns
-- that rule so it can be tested without a running client.
local function onRejected(stationId: string, reason: string)
	if Keypad.accepts(openStation, stationId) then
		status.Text = reason
	end
end
rejectedRemote.OnClientEvent:Connect(onRejected)

lexiconRemote.OnClientEvent:Connect(renderLexicon)

renderLexicon({})
renderObjectives({})
print(`[client] {Config.GameName} ready`)
