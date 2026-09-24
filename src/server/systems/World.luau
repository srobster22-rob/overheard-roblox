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
local Round = require(script.Parent.Round)

local World = {}

-- Dimensions live in Shared.Layout so they can be swept headlessly and so
-- everything that follows from them is DERIVED rather than restated. This file
-- needs Roblox instances to load, so no test can reach a number kept here.
local FLOOR_Y = Layout.Floor
local ROOM = Layout.Room
local SEPARATION = Layout.Separation
local WALL_H = 14

local ROOM_FLOOR = Color3.fromRGB(48, 44, 40)
local ROOM_WALL = Color3.fromRGB(62, 56, 48)
local CEILING = Color3.fromRGB(30, 28, 26)
local HALL_FLOOR = Color3.fromRGB(44, 40, 36)
local HALL_WALL = Color3.fromRGB(52, 47, 41)

-- What each room is called in the Explorer. Keys are `Layout.rooms()` names;
-- `World.build` refuses to run if a room has no entry here.
local ROOM_MODELS: { [string]: string } = {
	board = "BoardRoom",
	archive = "RecordsRoom",
	lobby = "Lobby",
}

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

-- One wall from a Layout rect: rects are one stud thick, so the degenerate span
-- is built a stud wide.
local function wallPart(name: string, wall: Layout.Rect, color: Color3, parent: Instance): Part
	return part(
		name,
		Vector3.new(math.max(wall.maxX - wall.minX, 1), WALL_H, math.max(wall.maxZ - wall.minZ, 1)),
		CFrame.new((wall.minX + wall.maxX) / 2, FLOOR_Y + WALL_H / 2, (wall.minZ + wall.maxZ) / 2),
		color,
		parent
	)
end

-- A floor slab under a Layout rect.
local function floorPart(name: string, area: Layout.Rect, color: Color3, parent: Instance): Part
	return part(
		name,
		Vector3.new(area.maxX - area.minX, 1, area.maxZ - area.minZ),
		CFrame.new((area.minX + area.maxX) / 2, FLOOR_Y, (area.minZ + area.maxZ) / 2),
		color,
		parent
	)
end

local function room(name: string, origin: Vector3, openOn: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	part("Floor", Vector3.new(ROOM, 1, ROOM), CFrame.new(origin + Vector3.new(0, FLOOR_Y, 0)), ROOM_FLOOR, model)
	part("Ceiling", Vector3.new(ROOM, 1, ROOM), CFrame.new(origin + Vector3.new(0, WALL_H, 0)), CEILING, model)

	-- Built from Layout.walls so the geometry a player walks through is the same
	-- geometry tests/layout.luau sweeps, doorway included. Walls built here by
	-- hand could seal a room and no test would see it.
	for i, wall in Layout.walls({ x = origin.X, z = origin.Z }, openOn) do
		wallPart(`Wall{i}`, wall, ROOM_WALL, model)
	end

	-- One weak light per room. Never enough; that is the point.
	local lampPart = part(
		"Lamp",
		Vector3.new(2, 0.4, 2),
		CFrame.new(origin + Vector3.new(0, WALL_H - 1, 0)),
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
	-- DERIVED, not typed. `Config.StationReach` must stay wider than this, and a
	-- literal here would be a promise about a number in another file with
	-- nothing between them. tests/layout.luau checks that World reads the dial.
	prompt.MaxActivationDistance = Config.PromptReach
	prompt.RequiresLineOfSight = false
	prompt.Parent = p

	return prompt
end

-- Where a named place stands, at station height. Errors on a name Layout does
-- not place: a station with no position can never be solved.
local function placeAt(id: string): (Vector3, { x: number, z: number })
	local at = Layout.stationPoint(id)
	if not at then
		error(`'{id}' has no place in Layout, so World cannot build it`)
	end
	return Vector3.new(at.x, 4, at.z), at
end

export type Built = {
	readerPrompt: ProximityPrompt,
	-- One prompt per Round.STATIONS entry, keyed by station id. Every station
	-- MUST appear here or its objective can never be solved; tests/round.luau
	-- checks every station has a place and that this file builds them all.
	stations: { [string]: ProximityPrompt },
	-- Where each station stands, so the server can check that a player is
	-- actually at one when they submit rather than trusting a remembered
	-- trigger. See Config.StationReach.
	stationAt: { [string]: { x: number, z: number } },
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

	-- The rooms, far apart. You cannot see one from another. Their centres come
	-- from the one registry, `Layout.rooms()`, the same centres every headless
	-- capture and walk test uses: nothing in this file runs outside Studio, so
	-- a centre computed here could drift and still pass the whole suite.
	local layoutRooms = Layout.rooms()
	for name, centre in layoutRooms do
		local modelName = ROOM_MODELS[name]
		if not modelName then
			error(`Layout.rooms() has room '{name}', which World gives no model name`)
		end
		room(modelName, Vector3.new(centre.x, 0, centre.z), Layout.corridorSide(centre), folder)
	end

	-- A corridor so the corridor-end rooms are connected but the walk is long
	-- enough to make shouting the answer feel like the wrong idea.
	-- Width DERIVED from the doorway: a corridor narrower than the door it
	-- serves leaves part of every approach unfloored, and this is the only floor
	-- for the span between the rooms.
	part(
		"Corridor",
		Vector3.new(SEPARATION, 1, Layout.corridorWidth()),
		CFrame.new(Vector3.new(0, FLOOR_Y, 0)),
		HALL_FLOOR,
		folder
	)

	-- Edges, so fleeing in the dark does not drop you out of the world. Built
	-- from Layout.corridorWalls, which stops them at the room walls and leaves
	-- the doorways and the passage mouth open.
	for i, wall in Layout.corridorWalls() do
		wallPart(`CorridorWall{i}`, wall, HALL_WALL, folder)
	end

	-- The passage from the corridor's midpoint up to the lobby door. Floor and
	-- walls both from Layout, where tests/layout.luau checks them.
	floorPart("Passage", Layout.passageFloor(), HALL_FLOOR, folder)
	for i, wall in Layout.passageWalls() do
		wallPart(`PassageWall{i}`, wall, HALL_WALL, folder)
	end

	-- The reader is not an objective station, so it keeps its literal label
	-- (tests/wiring reads it). Labels are shown over each station, so none may
	-- name a secret: the owner's rule (OWNER.md). A label like "Switchboard" or
	-- "Breaker" gives its station's words away.
	local readerAt = placeAt("reader")
	local readerPrompt = station("Card Index", "Read", readerAt, folder)

	-- Every objective station, from Round.STATIONS (the label and verb) and
	-- Layout.stationPoint (where it stands), with no literal offsets here
	-- (DECISIONS D5). The breaker sits in the records room, opposite the board,
	-- so the group cannot camp one room; the latch is in the lobby, a third
	-- direction.
	local stationPrompts: { [string]: ProximityPrompt } = {}
	local stationAt: { [string]: { x: number, z: number } } = {}
	for _, s in Round.STATIONS do
		local position, at = placeAt(s.id)
		stationPrompts[s.id] = station(s.label, s.actionText, position, folder)
		stationAt[s.id] = at
	end

	-- The exchange is dark. Players get just enough to move.
	Lighting.Ambient = Color3.fromRGB(18, 16, 14)
	Lighting.OutdoorAmbient = Color3.fromRGB(18, 16, 14)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.FogEnd = 90
	Lighting.FogColor = Color3.fromRGB(10, 9, 8)

	-- Payload name -> room centre. `Config.Rooms` is the CONTRACT this must
	-- satisfy: it is the list `tests/round.luau` validates every secret payload
	-- against. A comment is not a mechanism for keeping the two in step: a name
	-- declared in Config with no position here makes `Pursuit.sendTo` refuse
	-- the move, so the Operator simply never comes and nothing anywhere errors.
	-- Checked in both directions, loudly, because a silent monster reads as a
	-- dead game.
	local rooms: { [string]: { x: number, z: number } } = layoutRooms

	-- The comparison lives in Layout so the headless suite can run it; nothing
	-- in this file can run outside Studio.
	local mismatch = Layout.roomMismatch(rooms, Config.Rooms)
	if mismatch then
		error(mismatch)
	end

	return {
		readerPrompt = readerPrompt,
		stations = stationPrompts,
		stationAt = stationAt,
		-- Layout.spawn, where every route test starts walking from.
		spawn = Vector3.new(Layout.spawn().x, FLOOR_Y + 4, Layout.spawn().z),
		rooms = rooms,
		-- Out in the corridor, far enough from every room that each approach
		-- begins outside the silence radius. A start inside a room's silence
		-- radius would reach that room silently every time.
		operatorStart = Layout.operatorPost(),
	}
end

return World
