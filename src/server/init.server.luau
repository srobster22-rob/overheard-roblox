--!strict
-- OVERHEARD - server entry point.
--
-- Wires chat into the Operator, objectives into the world, and success back
-- into the Operator's learning. Deliberately thin: thinking lives in systems/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Objectives = require(script.systems.Objectives)
local Operator = require(script.systems.Operator)
local Presence = require(script.systems.Presence)
local Pursuit = require(script.systems.Pursuit)
local Round = require(script.systems.Round)
local World = require(script.systems.World)

local heardRemote = Remotes.get("Heard")
local lexiconRemote = Remotes.get("LexiconUpdated")
local objectivesRemote = Remotes.get("Objectives")
local submitRemote = Remotes.get("Submit")
local openBoardRemote = Remotes.get("OpenBoard")

-- Stations are the source of truth: the board and the Operator's secrets are
-- both derived from `Round.STATIONS`, so an objective can never exist for a
-- concept the Operator was not dealt (it used to, on 39.6% of servers).
local secrets = Round.dealSecrets(3)
local operator = Operator.new(secrets)
local board = Objectives.new()

for _, station in Round.STATIONS do
	board:add(station.id, station.concept, station.prompt)
end

local built = World.build()

local pursuit = Pursuit.new(built.rooms, built.operatorStart)
local body = Presence.spawn(pursuit)

pursuit.onStateChanged = function(state: string, targetName: string?)
	print(`[operator] {state}{if targetName then ` -> {targetName}` else ""}`)
	if state == "arrived" then
		-- It reached what it understood. For now it announces and settles;
		-- catching players is R10 (being "connected").
		heardRemote:FireAllClients(Round.LINES.taken, targetName or "", 1)
	end
end

-- Rate limiting. Every remote the client can fire needs one, or an exploiter
-- brute-forces two-digit answers instantly.
local lastSubmit: { [number]: number } = {}
local SUBMIT_COOLDOWN = 0.75

local function pushObjectives(player: Player?)
	if player then
		objectivesRemote:FireClient(player, board:viewFor(player.UserId))
		return
	end
	for _, p in Players:GetPlayers() do
		objectivesRemote:FireClient(p, board:viewFor(p.UserId))
	end
end

local function broadcastLexicon()
	lexiconRemote:FireAllClients(operator:snapshot())
end

operator.onUnderstood = function(concept: string, payload: string, confidence: number)
	print(`[operator] understood '{concept}' ({string.format("%.2f", confidence)}) -> {payload}`)
	heardRemote:FireAllClients(Round.LINES.understood, concept, confidence)
	-- Understanding is what moves it. An unknown payload is refused inside
	-- Pursuit rather than sending it somewhere arbitrary.
	pursuit:sendTo(payload)
end

operator.onBurned = function(coinage)
	print(`[operator] BURNED '{coinage.phrase}' = {coinage.concept}`)
	heardRemote:FireAllClients(Round.LINES.connecting, coinage.concept, 1)
	broadcastLexicon()
end

-- Success is what teaches the Operator. Solving an objective credits whatever
-- unfamiliar phrases were said just beforehand.
board.onSolved = function(objective, _actor: number)
	print(`[objective] {objective.id} restored`)
	operator:credit(objective.concept, os.clock())
	pushObjectives(nil)
	broadcastLexicon()
	if board:allSolved() then
		heardRemote:FireAllClients(Round.LINES.taken, "", 1)
	end
end

-- Everything a player says is evidence.
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local source = message.TextSource
	if not source then
		return nil
	end
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player then
		return nil
	end
	operator:hear({
		speaker = player,
		text = message.Text,
		at = os.clock(),
	})
	return nil
end

built.readerPrompt.Triggered:Connect(function(player: Player)
	-- Reading is private. The holder sees their own line; nobody else does.
	pushObjectives(player)
	heardRemote:FireClient(player, Round.LINES.greeting, "", 0)
end)

for _, station in Round.STATIONS do
	local prompt = built.stations[station.id]
	if not prompt then
		-- A station with no physical prompt is an objective nobody can reach,
		-- which makes `allSolved` unreachable. Fail loudly rather than ship a
		-- round that cannot end.
		error(`World built no prompt for station '{station.id}'`)
	end
	prompt.Triggered:Connect(function(player: Player)
		-- The client needs to know WHICH keypad it opened, or it submits every
		-- answer against the switchboard.
		openBoardRemote:FireClient(player, station.id, station.actionText)
	end)
end

submitRemote.OnServerEvent:Connect(function(player: Player, id: unknown, value: unknown)
	-- Never trust the client.
	if typeof(id) ~= "string" or typeof(value) ~= "string" then
		return
	end
	if #(value :: string) > 8 then
		return
	end

	local now = os.clock()
	if now - (lastSubmit[player.UserId] or 0) < SUBMIT_COOLDOWN then
		return
	end
	lastSubmit[player.UserId] = now

	-- The same `now` the cooldown used. The cooldown only paces attempts; the
	-- jam inside `submit` is what makes guessing the answer not worth doing.
	local result = board:submit(id :: string, player.UserId, value :: string, now)
	if not result.ok and result.reason then
		heardRemote:FireClient(player, Round.LINES.busy, result.reason, 0)
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	print(`[server] {player.Name} connected to the exchange`)
	-- Re-deal across everyone present, so holders stay spread as people join.
	local userIds: { number } = {}
	for _, p in Players:GetPlayers() do
		table.insert(userIds, p.UserId)
	end
	board:deal(userIds)
	task.defer(function()
		pushObjectives(nil)
		broadcastLexicon()
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastSubmit[player.UserId] = nil
	-- The leaver may have been holding a line. Nobody else was ever shown that
	-- answer, so without this the objective is unsolvable and the round can
	-- never end for the players still here. Only orphaned lines move.
	local userIds: { number } = {}
	for _, p in Players:GetPlayers() do
		-- GetPlayers still contains the leaver during PlayerRemoving; dealing
		-- an orphan straight back to them would re-strand it.
		if p ~= player then
			table.insert(userIds, p.UserId)
		end
	end
	if board:redealOrphans(userIds) > 0 then
		pushObjectives(nil)
	end
end)

-- The Operator forgets, in real time. Ticked here rather than inside Operator
-- so the module stays pure and headlessly testable. Rebroadcast only when heat
-- actually moved, or this replicates the whole lexicon once a second forever.
local running = true
task.spawn(function()
	while running do
		task.wait(1)
		if running and operator:decay(os.clock()) then
			broadcastLexicon()
		end
	end
end)

game:BindToClose(function()
	running = false
	body.stop()
end)

print(`[server] {Config.GameName} - {#secrets} secrets this round`)
for _, secret in secrets do
	print(`  secret: {secret.concept} -> {secret.payload}`)
end
