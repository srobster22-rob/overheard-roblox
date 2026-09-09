--!strict
-- A blockout of the exchange. Deliberately code-generated rather than modelled:
-- the layout is a design variable we will tune every round, and geometry in
-- code is diffable, reviewable and testable. Art passes come later.
--
-- The layout rule that matters: the room you READ in and the room you PATCH in
-- must never be within earshot by walking. Distance is the mechanic.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local World = {}

local FLOOR_Y = 0
local ROOM = 48 -- room footprint, studs
local SEPARATION = 120 -- distance between the two work rooms

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function room(name: string, origin: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local half = ROOM / 2
	local wallH = 14
	local floorColor = Color3.fromRGB(48, 44, 40)
	local wallColor = Color3.fromRGB(62, 56, 48)

	part("Floor", Vector3.new(ROOM, 1, ROOM), CFrame.new(origin + Vector3.new(0, FLOOR_Y, 0)), floorColor, model)
	part(
		"Ceiling",
		Vector3.new(ROOM, 1, ROOM),
		CFrame.new(origin + Vector3.new(0, wallH, 0)),
		Color3.fromRGB(30, 28, 26),
		model
	)

	local offsets = {
		{ Vector3.new(0, wallH / 2, -half), Vector3.new(ROOM, wallH, 1) },
		{ Vector3.new(0, wallH / 2, half), Vector3.new(ROOM, wallH, 1) },
		{ Vector3.new(-half, wallH / 2, 0), Vector3.new(1, wallH, ROOM) },
		{ Vector3.new(half, wallH / 2, 0), Vector3.new(1, wallH, ROOM) },
	}
	for i, spec in offsets do
		part(`Wall{i}`, spec[2], CFrame.new(origin + spec[1]), wallColor, model)
	end

	-- One weak light per room. Never enough; that is the point.
	local lampPart = part(
		"Lamp",
		Vector3.new(2, 0.4, 2),
		CFrame.new(origin + Vector3.new(0, wallH - 1, 0)),
		Color3.fromRGB(120, 108, 84),
		model
	)
	lampPart.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Brightness = 1.6
	light.Range = 34
	light.Color = Color3.fromRGB(255, 214, 152)
	light.Parent = lampPart

	return model
end

-- A thing a player walks up to and uses. Returns the prompt so callers can
-- connect behaviour without knowing how it was built.
local function station(name: string, label: string, position: Vector3, parent: Instance): ProximityPrompt
	local p = part(name, Vector3.new(6, 7, 2), CFrame.new(position), Color3.fromRGB(78, 62, 38), parent)
	p.Material = Enum.Material.Wood

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = label
	prompt.ObjectText = name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = p

	return prompt
end

export type Built = {
	readerPrompt: ProximityPrompt,
	boardPrompt: ProximityPrompt,
	spawn: Vector3,
}

function World.build(): Built
	local existing = Workspace:FindFirstChild("Exchange")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Model")
	folder.Name = "Exchange"
	folder.Parent = Workspace

	-- Two rooms, far apart. You cannot see one from the other.
	local recordsOrigin = Vector3.new(-SEPARATION / 2, 0, 0)
	local boardOrigin = Vector3.new(SEPARATION / 2, 0, 0)

	room("RecordsRoom", recordsOrigin, folder)
	room("BoardRoom", boardOrigin, folder)

	-- A corridor so the two rooms are connected but the walk is long enough to
	-- make shouting the answer feel like the wrong idea.
	part(
		"Corridor",
		Vector3.new(SEPARATION, 1, 8),
		CFrame.new(Vector3.new(0, FLOOR_Y, 0)),
		Color3.fromRGB(44, 40, 36),
		folder
	)

	local readerPrompt = station("Directory", "Read", recordsOrigin + Vector3.new(0, 4, -18), folder)
	local boardPrompt = station("Switchboard", "Patch", boardOrigin + Vector3.new(0, 4, -18), folder)

	-- The exchange is dark. Players get just enough to move.
	Lighting.Ambient = Color3.fromRGB(18, 16, 14)
	Lighting.OutdoorAmbient = Color3.fromRGB(18, 16, 14)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.FogEnd = 90
	Lighting.FogColor = Color3.fromRGB(10, 9, 8)

	return {
		readerPrompt = readerPrompt,
		boardPrompt = boardPrompt,
		spawn = Vector3.new(0, FLOOR_Y + 4, 0),
	}
end

return World
