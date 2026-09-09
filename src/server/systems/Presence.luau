--!strict
-- The Operator's body. Does no thinking — Pursuit decides, this renders.
--
-- Deliberately not a humanoid or a mesh yet. It is a dark mass and a sound,
-- because at this stage the sound is the entire performance and a placeholder
-- model would only distract us from tuning it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Pursuit = require(script.Parent.Pursuit)

local Presence = {}

export type Body = {
	part: Part,
	hum: Sound,
	tracker: Pursuit.Tracker,
	stop: () -> (),
}

local HEIGHT = 7

function Presence.spawn(tracker: Pursuit.Tracker): Body
	local existing = Workspace:FindFirstChild("Operator")
	if existing then
		existing:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = "Operator"
	part.Size = Vector3.new(3, HEIGHT, 3)
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(8, 8, 9)
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(tracker.position.x, HEIGHT / 2, tracker.position.z)
	part.Parent = Workspace

	-- It carries its own darkness rather than being lit by the room.
	local gloom = Instance.new("PointLight")
	gloom.Brightness = 0
	gloom.Range = 18
	gloom.Color = Color3.fromRGB(40, 30, 60)
	gloom.Parent = part

	-- The hum of a live switchboard. Audible while it crosses the building,
	-- cut dead once it is close. Volume is set from Pursuit every frame.
	local hum = Instance.new("Sound")
	hum.Name = "Hum"
	hum.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	hum.Looped = true
	hum.Volume = 0
	hum.RollOffMaxDistance = 140
	hum.RollOffMinDistance = 12
	hum.Parent = part
	hum:Play()

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		tracker:step(dt)
		part.CFrame = CFrame.new(tracker.position.x, HEIGHT / 2, tracker.position.z)

		-- The silence rule, made audible. Fade rather than cut, or it reads as
		-- a bug instead of a decision.
		local wanted = if tracker:isAudible() then 0.35 else 0
		hum.Volume += (wanted - hum.Volume) * math.min(dt * 3, 1)
	end)

	return {
		part = part,
		hum = hum,
		tracker = tracker,
		stop = function()
			connection:Disconnect()
			part:Destroy()
		end,
	}
end

return Presence
