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
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Heat = require(ReplicatedStorage.Shared.Heat)
local Hud = require(ReplicatedStorage.Shared.Hud)
local Readout = require(ReplicatedStorage.Shared.Readout)
local Keypad = require(ReplicatedStorage.Shared.Keypad)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Silence = require(ReplicatedStorage.Shared.Silence)

-- Named up front rather than fetched inline, so both sides read the same way
-- and `tests/wiring.luau` can tell which handler belongs to which remote.
local heardRemote = Remotes.get("Heard")
local lexiconRemote = Remotes.get("LexiconUpdated")
local objectivesRemote = Remotes.get("Objectives")
local submitRemote = Remotes.get("Submit")
local openBoardRemote = Remotes.get("OpenBoard")
local rejectedRemote = Remotes.get("Rejected")
local phaseRemote = Remotes.get("Phase")
local connectedRemote = Remotes.get("Connected")
local silenceRemote = Remotes.get("Silence")

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

-- Placed from Shared.Hud, never from numbers typed here. Every panel used to
-- carry its own hand-picked mix of scale and offset, and nothing checked the
-- result: five overlapping pairs at 800x480, six at 480x270, with the Lexicon
-- buried under the centre panels on exactly the screens most players use.
-- `tests/hud.luau` sweeps every viewport; it can only do that if this reads
-- from the same table.
local function panel(name: string): Frame
	local spec = Hud.get(name)
	-- R90: "named" now reads as "name" (a directory word), and the
	-- wiring leak scan counts every client template -- so not "named".
	assert(spec, `no Hud panel called '{name}'`)

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(spec.anchorX, spec.anchorY)
	frame.Position = UDim2.new(spec.scaleX, spec.offsetX, spec.scaleY, spec.offsetY)
	frame.Size = UDim2.fromOffset(spec.width, spec.height)
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

local lexPanel = panel("Lexicon")

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

-- The breakpoint is DERIVED from the threshold the Operator actually uses, not
-- restated here. It used to be a hard-coded 0.5 reaching red at 1.0, so a
-- coinage at 60% — already being understood — looked mid-amber with headroom
-- left. See Shared.Heat.
local AMBER = Color3.fromRGB(226, 176, 82)
local RED = Color3.fromRGB(206, 62, 52)

local function heatColor(heat: number): Color3
	if Heat.isUnderstood(heat) then
		-- No gradient above the threshold: there is no "partly understood".
		return RED
	end
	return INK:Lerp(AMBER, Heat.safeProgress(heat))
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
	-- R119: the rows (order, percent, "understood") are Readout.lexiconRows,
	-- run by tests/readout; only the drawing is left here.
	for i, entry in Readout.lexiconRows(entries) do
		local row = label(lexList, entry.text, 12, heatColor(entry.heat))
		row.LayoutOrder = i
	end
end

-- THE SUPERVISOR'S CLOCK ------------------------------------------------------
--
-- R54 built a monster that takes you on a timer. R55 measured its real
-- dispatches going from 20 to 74 once it stopped announcing calls it never
-- placed. Nothing on screen said the timer existed: the only signal was one
-- sentence 15 seconds before, sent down the OPERATOR's voice channel, so the
-- Supervisor's warning arrived as the thing that hunts meaning talking to you.
--
-- `CLAUDE.md`: the monster must be legible, or the scare reads as unfair. A
-- monster on a clock you cannot see is what that rule is about.
--
-- The server sends the BAND, the PRESSURE and the WORDS. This file draws them
-- and decides nothing: the thresholds live in `Shared.Silence` beside the dials
-- they are derived from, for the reason the Lexicon's breakpoint does.

local silencePanel = panel("Supervisor")
silencePanel.Visible = false

local silenceNote = Instance.new("TextLabel")
silenceNote.Name = "Note"
silenceNote.Position = UDim2.fromOffset(8, 26)
silenceNote.Size = UDim2.new(1, -16, 0, 16)
silenceNote.BackgroundTransparency = 1
silenceNote.Font = Enum.Font.Code
silenceNote.TextSize = 12
silenceNote.TextXAlignment = Enum.TextXAlignment.Left
silenceNote.TextColor3 = Color3.fromRGB(196, 196, 200)
silenceNote.Text = ""
silenceNote.Parent = silencePanel

local silenceTrack = Instance.new("Frame")
silenceTrack.Name = "Track"
silenceTrack.Position = UDim2.fromOffset(8, 44)
silenceTrack.Size = UDim2.new(1, -16, 0, 4)
silenceTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
silenceTrack.BorderSizePixel = 0
silenceTrack.Parent = silencePanel

local silenceBar = Instance.new("Frame")
silenceBar.Name = "Bar"
silenceBar.Size = UDim2.fromScale(0, 1)
silenceBar.BackgroundColor3 = Color3.fromRGB(120, 200, 140)
silenceBar.BorderSizePixel = 0
silenceBar.Parent = silenceTrack

-- Colour is per BAND, not a gradient across the whole bar, because `Silence`
-- says the band above the deadline is flat: above it there is no "partly", and
-- a ramp there implies headroom that does not exist. Same reason the Lexicon
-- draws two bands rather than lerping across its threshold.
local BAND_COLOUR: { [string]: Color3 } = {
	clear = Color3.fromRGB(120, 200, 140),
	warned = Color3.fromRGB(220, 180, 90),
	overdue = Color3.fromRGB(220, 90, 90),
}

-- What the last push said, and when it arrived. The bar is filled in between
-- pushes from these three numbers.
--
-- The server speaks only when the BAND changes -- 4 times in 600 ticks -- so
-- drawing only what it says gave three bar positions in a whole countdown, still
-- for 29.5 of the 45 seconds. The arithmetic lives in `Shared.Silence` so this
-- file still decides nothing: it holds what it was told and the clock.
local lastPressure = 0
local lastSecondsLeft = 0
local lastPushAt = os.clock()

silenceRemote.OnClientEvent:Connect(function(band: string, pressure: number, note: string, secondsLeft: number)
	silencePanel.Visible = true
	silenceNote.Text = note
	lastPressure = pressure
	lastSecondsLeft = secondsLeft or 0
	lastPushAt = os.clock()
	silenceBar.Size = UDim2.fromScale(math.clamp(pressure, 0, 1), 1)
	silenceBar.BackgroundColor3 = BAND_COLOUR[band] or BAND_COLOUR.clear
	silenceNote.TextColor3 = BAND_COLOUR[band] or silenceNote.TextColor3
end)

-- The COLOUR is not touched here: it belongs to the band, and the band only
-- changes when the server says so. Only the fill moves between pushes.
RunService.RenderStepped:Connect(function()
	if not silencePanel.Visible then
		return
	end
	silenceBar.Size = UDim2.fromScale(Silence.fill(lastPressure, lastSecondsLeft, os.clock() - lastPushAt), 1)
end)

-- YOUR LINE ----------------------------------------------------------------

local linePanel = panel("Your line")

local lineList = Instance.new("Frame")
lineList.Position = UDim2.fromOffset(8, 32)
lineList.Size = UDim2.new(1, -16, 1, -40)
lineList.BackgroundTransparency = 1
lineList.Parent = linePanel

local lineLayout = Instance.new("UIListLayout")
lineLayout.Padding = UDim.new(0, 4)
lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
lineLayout.Parent = lineList

local ROW_STYLE: { [string]: { size: number, color: Color3 } } = {
	line = { size = 13, color = INK },
	note = { size = 10, color = DIM },
	count = { size = 11, color = BRASS },
	empty = { size = 11, color = DIM },
}

local function renderObjectives(entries: { any })
	for _, child in lineList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	-- Rows arrive already ordered from Shared.Readout. This used to build them
	-- from two number series -- `i` for a line and `i + 100` for its note --
	-- which put every note below every line once a player held two of them, so
	-- "only you can see this" sat under a line it was not about.
	for index, row in Readout.lineRows(entries) do
		local style = ROW_STYLE[row.kind] or ROW_STYLE.note
		label(lineList, row.text, style.size, style.color).LayoutOrder = index
	end
end

-- THE BOARD ----------------------------------------------------------------

local boardPanel = panel("The board")
boardPanel.Visible = false

local hint = label(boardPanel, "enter what you were told", 11, DIM)
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
	-- R120: Keypad.sends, run by the suite.
	if not Keypad.sends(value, openStation) then
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
		title.Text = string.upper(actionText or "keypad")
	end
	-- No plain language, and no raw station id. This read "enter the NUMBER you
	-- were told for the {stationId}", which conveyed `jack_number` at every
	-- station including the breaker -- a concept that keypad is not about, in
	-- front of the player working it. The id is the giveaway word too; the
	-- title above already says which keypad this is, in the station's own verb.
	hint.Text = "enter what you were told"
	local _ = stationId
	status.Text = ""
	input:CaptureFocus()
end
openBoardRemote.OnClientEvent:Connect(onOpenBoard)

-- ON THE LINE ---------------------------------------------------------------
-- Being caught does not remove you. It removes your ability to ACT, and says so
-- plainly, because a player who thinks they are dead stops talking -- and their
-- voice is the only thing they have left, and the thing their team still needs.

local onLine = panel("On the line")
onLine.Visible = false
onLine.BackgroundColor3 = Color3.fromRGB(38, 14, 14)

local onLineBody = label(onLine, "you can still be heard. you cannot patch.", 12, INK)
onLineBody.Position = UDim2.fromOffset(8, 34)
onLineBody.Size = UDim2.new(1, -16, 0, 32)

connectedRemote.OnClientEvent:Connect(function(caught: boolean)
	onLine.Visible = caught == true
	if caught then
		closeBoard()
		-- R70. The server stops watching a caught player's silence the instant
		-- they are connected (Supervisor.forget, see R67), so Supervisor.band
		-- returns nil for them from that tick on and showEveryoneTheirClock
		-- simply stops sending them anything -- it never tells THIS client the
		-- clock is gone. Without this the panel kept showing whatever band was
		-- last pushed, which could be the red "SILENT LINE - TRACED" state, for
		-- the rest of the round: a stale alarm about something that can no
		-- longer happen to you. CLAUDE.md: the monster must be legible.
		silencePanel.Visible = false
	end
end)

-- BETWEEN ROUNDS -------------------------------------------------------------
--
-- The client had no idea a round could end until R33. The win or loss was one
-- sentence that faded after 2.5 seconds; the keypad stayed open and
-- usable-looking; "restored 1/1" sat there and then silently became
-- "restored 0/1" when the next round began, with nothing saying why.
--
-- This panel is PERSISTENT for the whole intermission on purpose: an outcome
-- you can miss by looking away is not an outcome.

local overPanel = panel("Round over")
overPanel.Visible = false

local overWhat = label(overPanel, "", 13, INK)
overWhat.Position = UDim2.fromOffset(8, 34)
overWhat.Size = UDim2.new(1, -16, 0, 18)

local overNext = label(overPanel, "", 11, DIM)
overNext.Position = UDim2.fromOffset(8, 56)
overNext.Size = UDim2.new(1, -16, 0, 28)

local OUTCOME_TEXT = {
	won = "The board was restored.",
	-- R118: true of BOTH losses. Since R48 a round is also lost when nobody
	-- still free can finish, with players not on the line, and "Everyone was
	-- put on the line" told them something false. The server sends only
	-- "lost", so this must not claim which kind. Kept free of secret words so
	-- the displayed-text leak scan needs no exemption for it.
	lost = "Nobody left free could finish it.",
}

local function onPhase(state: { playing: boolean, outcome: string?, number: number })
	if state.playing then
		overPanel.Visible = false
		return
	end

	-- The Supervisor's clock stops with the round, so its panel goes with it.
	--
	-- `Hud.exclusions()` says these two are never on screen together, and R56 used
	-- that claim to justify where the clock sits: at MinWidth `Round over` spans
	-- x 160..480 and the clock spans x 16..166, and they share the bottom of the
	-- window. The claim was true of the SERVER (the Supervisor only runs while
	-- the round is played) and false of this file, which showed the panel on
	-- every push and never hid it again. An exclusion is a promise the client
	-- has to keep; `tests/wiring.luau` now checks that every pair on that list
	-- has one.
	silencePanel.Visible = false

	overPanel.Visible = true
	-- R123: title, win/loss and the next-round line are Readout.roundOver.
	local over = Readout.roundOver(state.outcome, state.number)
	local title = overPanel:FindFirstChild("Title") :: TextLabel?
	if title then
		title.Text = over.title
	end
	overWhat.Text = OUTCOME_TEXT[state.outcome or ""] or "The round is over."
	overWhat.TextColor3 = if over.won then BRASS else Color3.fromRGB(206, 62, 52)
	overNext.Text = over.next
	-- A keypad you can still type into is a keypad that lies about being usable.
	closeBoard()
end

phaseRemote.OnClientEvent:Connect(onPhase)

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
	-- R120: Keypad.closesOn, run by the suite.
	if Keypad.closesOn(openStation, entries) then
		closeBoard()
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
