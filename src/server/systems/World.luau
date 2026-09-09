--!strict
-- A blockout of the exchange. Deliberately code-generated rather than modelled:
-- the layout is a design variable we will tune every round, and geometry in
-- code is diffable, reviewable and testable. Art passes come later.
--
-- The layout rule that matters: the room you READ in and the room you PATCH in
-- must never be within earshot by walking. Distance is the mechanic.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Layout = require(game:GetService("ReplicatedStorage").Shared.Layout)

local World = {}

-- Dimensions live in Shared.Layout so they can be swept headlessly and so the
-- Operator's reach can be DERIVED from the room rather than restated. This file
-- needs Roblox instances to load, which is what put those numbers out of reach
-- of every test until R21.
local FLOOR_Y = Layout.Floor
local ROOM = Layout.Room
local SEPARATION = Layout.Separation

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

local function room(name: string, origin: Vector3, openOn: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

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

	-- Built from Layout.walls so the geometry a player walks through is the same
	-- geometry tests/layout.luau sweeps. Until R22 this was four full-span walls
	-- with no gap, and both work rooms were sealed boxes nobody could enter.
	local centre = { x = origin.X, z = origin.Z }
	for i, wall in Layout.walls(centre, openOn) do
		local spanX = math.max(wall.maxX - wall.minX, 1)
		local spanZ = math.max(wall.maxZ - wall.minZ, 1)
		local midX = (wall.minX + wall.maxX) / 2
		local midZ = (wall.minZ + wall.maxZ) / 2
		part(
			`Wall{i}`,
			Vector3.new(spanX, wallH, spanZ),
			CFrame.new(midX, origin.Y + wallH / 2, midZ),
			wallColor,
			model
		)
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
	-- One prompt per Round.STATIONS entry, keyed by station id. Every station
	-- MUST appear here or its objective can never be solved; tests/round.luau
	-- reads this file and fails if one is missing.
	stations: { [string]: ProximityPrompt },
	spawn: Vector3,
	-- Payload name -> room centre, for Pursuit. Payloads with no room here are
	-- refused rather than guessed at; see Pursuit.sendTo.
	rooms: { [string]: { x: number, z: number } },
	operatorStart: { x: number, z: number },
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

	room("RecordsRoom", recordsOrigin, Layout.corridorSide({ x = recordsOrigin.X, z = recordsOrigin.Z }), folder)
	room("BoardRoom", boardOrigin, Layout.corridorSide({ x = boardOrigin.X, z = boardOrigin.Z }), folder)

	-- A corridor so the two rooms are connected but the walk is long enough to
	-- make shouting the answer feel like the wrong idea.
	-- Width DERIVED from the doorway: a corridor narrower than the door it
	-- serves leaves part of every approach unfloored. It was 8 against a 12-stud
	-- door until R28, and it is the only floor for the span between the rooms.
	part(
		"Corridor",
		Vector3.new(SEPARATION, 1, Layout.corridorWidth()),
		CFrame.new(Vector3.new(0, FLOOR_Y, 0)),
		Color3.fromRGB(44, 40, 36),
		folder
	)

	-- Edges, so fleeing in the dark does not drop you out of the world. Built
	-- from Layout.corridorWalls, which stops them at the room walls and leaves
	-- the doorways open.
	local wallH = 14
	for i, wall in Layout.corridorWalls() do
		part(
			`CorridorWall{i}`,
			Vector3.new(math.max(wall.maxX - wall.minX, 1), wallH, math.max(wall.maxZ - wall.minZ, 1)),
			CFrame.new((wall.minX + wall.maxX) / 2, FLOOR_Y + wallH / 2, (wall.minZ + wall.maxZ) / 2),
			Color3.fromRGB(52, 47, 41),
			folder
		)
	end

	local readerPrompt = station("Directory", "Read", recordsOrigin + Vector3.new(0, 4, -18), folder)
	local boardPrompt = station("Switchboard", "Patch", boardOrigin + Vector3.new(0, 4, -18), folder)
	-- The breaker sits in the RECORDS room, deliberately opposite the board.
	-- With both act-stations in one room the whole group just camps there and
	-- the corridor stops being a cost; one at each end forces the walk.
	local breakerPrompt = station("Breaker", "Throw", recordsOrigin + Vector3.new(18, 4, 0), folder)

	-- The exchange is dark. Players get just enough to move.
	Lighting.Ambient = Color3.fromRGB(18, 16, 14)
	Lighting.OutdoorAmbient = Color3.fromRGB(18, 16, 14)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.FogEnd = 90
	Lighting.FogColor = Color3.fromRGB(10, 9, 8)

	-- Payload name -> room centre. `Config.Rooms` is the CONTRACT this must
	-- satisfy: it is the list `tests/round.luau` validates every secret payload
	-- against. The two used to be kept in step by a comment sitting exactly
	-- here, which is not a mechanism — a name declared in Config with no
	-- position here makes `Pursuit.sendTo` refuse the move, so the Operator
	-- simply never comes and nothing anywhere errors. Checked in both
	-- directions, loudly, because a silent monster reads as a dead game.
	-- (R6 had to write "the config" in these messages instead of naming the
	-- dial, because the guard could not tell a string from a read and the
	-- message would have certified it. R7's scanner can, so they say it.)
	local rooms: { [string]: { x: number, z: number } } = {
		board = { x = boardOrigin.X, z = boardOrigin.Z },
		archive = { x = recordsOrigin.X, z = recordsOrigin.Z },
	}

	local declared: { [string]: boolean } = {}
	for _, name in Config.Rooms do
		declared[name] = true
		if not rooms[name] then
			error(`Config.Rooms declares room '{name}', which World.build gives no position for`)
		end
	end
	for name in rooms do
		if not declared[name] then
			error(`World.build builds room '{name}', which Config.Rooms does not declare`)
		end
	end

	return {
		readerPrompt = readerPrompt,
		stations = {
			board = boardPrompt,
			breaker = breakerPrompt,
		},
		spawn = Vector3.new(0, FLOOR_Y + 4, 0),
		rooms = rooms,
		-- Out in the corridor, far enough from BOTH rooms that every approach
		-- begins outside the silence radius. Standing 20 studs from the board
		-- room's centre meant it reached that room silently every time.
		operatorStart = Layout.operatorPost(),
	}
end

return World
