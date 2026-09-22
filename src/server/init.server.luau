--!strict
-- OVERHEARD - server entry point.
--
-- Wires chat into the Operator, objectives into the world, and success back
-- into the Operator's learning. Deliberately thin: thinking lives in systems/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Silence = require(ReplicatedStorage.Shared.Silence)
local Objectives = require(script.systems.Objectives)
local Operator = require(script.systems.Operator)
local Presence = require(script.systems.Presence)
local Pursuit = require(script.systems.Pursuit)
local Round = require(script.systems.Round)
local Connected = require(script.systems.Connected)
local Lifecycle = require(script.systems.Lifecycle)
local Escape = require(script.systems.Escape)
local ChatFeed = require(script.systems.ChatFeed)
local Censor = require(script.systems.Censor)
local Keypad = require(ReplicatedStorage.Shared.Keypad)
local Station = require(script.systems.Station)
local Supervisor = require(script.systems.Supervisor)
local World = require(script.systems.World)

local heardRemote = Remotes.get("Heard")
local lexiconRemote = Remotes.get("LexiconUpdated")
local objectivesRemote = Remotes.get("Objectives")
local submitRemote = Remotes.get("Submit")
local openBoardRemote = Remotes.get("OpenBoard")
-- The SUPERVISOR's own channel. Its warning used to go out on `heardRemote`,
-- which is the Operator's voice, so the only signal it gave arrived as the
-- thing that hunts meaning talking to you. R10, R13 and R51 were each spent
-- proving two events must not arrive as one signal; this is the fourth.
-- Fired at one client only: how long everybody else has been quiet is not
-- yours to see.
local silenceRemote = Remotes.get("Silence")
-- Keypad feedback. Separate from `heardRemote` on purpose: `Heard` is the
-- Operator's voice and goes to everyone, and while the keypad read its detail
-- field, a broadcast about one player's speech landed in another player's
-- error line. FireClient only, and it names its station. See Shared.Keypad.
local rejectedRemote = Remotes.get("Rejected")
local connectedRemote = Remotes.get("Connected")
-- Whether a round is being played, and how the last one ended. The client had
-- no idea a round could END until R33.
local phaseRemote = Remotes.get("Phase")

-- Stations are the source of truth: the board and the Operator's secrets are
-- both derived from `Round.STATIONS`, so an objective can never exist for a
-- concept the Operator was not dealt (it used to, on 39.6% of servers).
local secrets = Round.dealSecrets(Round.secretsPerRound())
local operator = Operator.new(secrets)
local board = Objectives.new()
-- Which keypad each player has actually walked up to. This used to be a local
-- in the CLIENT and the server took its word for the station id on every
-- submit. See systems/Station.
local desk = Station.new()
-- THE SUPERVISOR (GAME.md #4). Watches who has NOT spoken, which is the one
-- thing the Operator cannot see. Until this existed, four silent players won
-- 20 rounds in 600 simulated seconds with zero captures and the Operator
-- never leaving its post: saying nothing was not merely safe, it won more
-- than talking did, and a group on a voice call outside Roblox played an
-- unopposed fetch quest. It decides WHO; the dispatch below decides what.
local supervisor = Supervisor.new()
-- Who the Operator has taken. Being connected costs you the ability to ACT;
-- it does not cost you your voice. See systems/Connected.
local line = Connected.new()
-- Whether a round is being played. See systems/Lifecycle.
local round = Lifecycle.new()
-- The way out, opened when the last line is restored (R138). See systems/Escape.
local escape = Escape.new()

for _, station in Round.STATIONS do
	board:add(station.id, station.concept, station.prompt)
end

local built = World.build()

-- `built.spawn` was computed by World and read by nobody for twenty-one
-- rounds, so players landed wherever Roblox decided rather than in the
-- corridor between the rooms. Placed here rather than in World because it
-- is a game-flow decision, not geometry.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "Exchange"
spawnPad.Anchored = true
spawnPad.CanCollide = false
spawnPad.Transparency = 1
spawnPad.Size = Vector3.new(12, 1, 8)
spawnPad.Position = built.spawn
spawnPad.Parent = workspace

-- R137: with a room off the corridor, the Operator turns at the junction.
local pursuit = Pursuit.new(built.rooms, built.operatorStart, Layout.route)
local body = Presence.spawn(pursuit)

local function pushObjectives(player: Player?)
	if player then
		objectivesRemote:FireClient(player, board:viewFor(player.UserId))
		return
	end
	for _, p in Players:GetPlayers() do
		objectivesRemote:FireClient(p, board:viewFor(p.UserId))
	end
end

local function pushPhase(player: Player?)
	local payload = {
		playing = round:isPlaying(),
		outcome = round.outcome,
		number = round.number,
	}
	if player then
		phaseRemote:FireClient(player, payload)
		return
	end
	phaseRemote:FireAllClients(payload)
end

-- The phrases on the Lexicon panel are words players typed, so each one goes
-- through Roblox's text filter, for the player who typed it, before any client
-- sees it (R139, COACH.md C2; PLATFORM.md). A phrase that cannot be filtered is
-- left off the panel (Censor); the failure is reported, never hidden.
local function filterForEveryone(text: string, authorId: number): string?
	local ok, result = pcall(function(): string
		return TextService:FilterStringAsync(text, authorId):GetNonChatStringForBroadcastAsync()
	end)
	-- An empty result is a failure too: Roblox's forum reports the broadcast
	-- filter returning "" often, and Censor leaves such a phrase out.
	if not ok or result == "" then
		warn(`[lexicon] a phrase could not be filtered and is not shown: {if ok then "empty result" else result}`)
		return nil
	end
	return result
end
local broadcastLexicon = Censor.new(filterForEveryone):sender(function()
	return operator:snapshot()
end, function(visible)
	lexiconRemote:FireAllClients(visible)
end, task.spawn)

-- Everyone in the server right now, by user id.
local function presentUserIds(): { number }
	local present: { number } = {}
	for _, p in Players:GetPlayers() do
		table.insert(present, p.UserId)
	end
	return present
end

-- Where each player's body actually is, server-side. Never the client's word
-- for it: the whole point of being caught is that you cannot talk your way out
-- of having been in the room.
local function livePositions(): { [number]: Connected.Point }
	local out: { [number]: Connected.Point } = {}
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			out[p.UserId] = { x = root.Position.X, z = root.Position.Z }
		end
	end
	return out
end

-- Has the group lost? Two ways, and they mean the same thing.
--
-- Everyone taken is the obvious one. The other is that nobody LEFT can finish
-- anything: R23 made the Operator take everyone in a room at once, so three of
-- four caught in one arrival strands a line with its reader, and the survivor
-- can then neither win nor be forced to lose.
--
-- ASKED ON THE TICK, not only when the Operator arrives. R48 put this check in
-- the capture path alone, and the R49 soak measured what that costs: 134 ticks
-- — about half a minute — of a stranded round still running after the Operator
-- had walked away, because nothing looked again until it came back.
--
-- The `line:count() > 0` clause is what keeps a solo server from losing
-- instantly and looping: a board nobody can finish with NOBODY connected is the
-- dealing problem, which is the owner's filed solo question, not a round that
-- play has stranded.
--
-- R108: the rule itself lives in `Lifecycle.nobodyCanWin`, where the headless
-- suite can RUN it. Here it could only be grepped, and a mutation sweep of this
-- file flipped every clause of the game's loss condition without one failure.
local function endTheRoundIfNobodyCanWin(present: { number }): boolean
	return Lifecycle.nobodyCanWin(present, board, line)
end

-- The round is over: finish it, say so, tell every panel and stop the
-- Operator. Nothing is said twice: a round already over is left alone. A win
-- says `completed`, not `taken`: `taken` is what it says when the MONSTER
-- arrives, and firing the same string for winning made the two opposite events
-- render as one sentence on the client. It STOPS either way: until R29 winning
-- left the Operator hunting, so a group could finish and then be taken by a
-- monster that had no idea the round was over, and a loss that left it
-- travelling kept the hum going over a finished round.
local function endTheRound(outcome: Lifecycle.Outcome)
	if not round:finish(outcome, os.clock()) then
		return
	end
	heardRemote:FireAllClients(if outcome == "won" then Round.LINES.completed else Round.LINES.lost, "", 1)
	pushPhase(nil)
	pursuit:stop()
end

local function takeWhoeverIsHere()
	-- The ROOM it arrived in, not a circle around it. See Connected.reachedInRoom:
	-- a circle big enough to cover the square also covers 9.94 studs of corridor
	-- outside every wall, so running out of the door did not save you.
	-- R112: connect-and-forget lives in Connected.takeInRoom (RUN by the
	-- suite, and called by the soak); only the telling is left here.
	local caught, newly = line:takeInRoom(pursuit.position, livePositions(), Layout.halfRoom(), os.clock(), supervisor)
	for _, userId in newly do
		-- A caught player cannot act -- Objectives.submit refuses anyone
		-- isConnected -- and nothing in this round releases them again, so
		-- there is no more silence left to punish. Without this the
		-- Supervisor kept chasing them anyway: measured, roughly HALF of
		-- every dispatch and every audible "putting you through" went to a
		-- player who could not possibly benefit from the visit, taken
		-- directly from whoever the mechanic still has a reason to reach.
		local victim = Players:GetPlayerByUserId(userId)
		if victim then
			heardRemote:FireClient(victim, Round.LINES.onTheLine, "", 1)
			connectedRemote:FireClient(victim, true)
		end
	end

	if #caught > 0 then
		-- Everyone sees who is on the line: a caught player is still useful, and
		-- the others need to know to start listening to them rather than
		-- waiting for them to act.
		pushObjectives(nil)
	end

	-- The loss. R16 wrote `allTaken` and never called it, so the round could be
	-- WON but never LOST: the Operator could take every player and the game
	-- would sit there, the board still open, nothing said. Checked against who
	-- is actually present, so a player leaving cannot strand the round.
	if endTheRoundIfNobodyCanWin(presentUserIds()) then
		endTheRound("lost")
	end
end

pursuit.onStateChanged = function(state: string, targetName: string?)
	print(`[operator] {state}{if targetName then ` -> {targetName}` else ""}`)
	if state == "arrived" then
		heardRemote:FireAllClients(Round.LINES.taken, targetName or "", 1)
		takeWhoeverIsHere()
	end
end

-- THE SUPERVISOR'S CALL. Runs on the tick, like capture and the loss check.
--
-- The Supervisor names who has gone quiet; this is what happens to them. It
-- does not build a second monster: in the fiction the supervisor of an exchange
-- does not come for you, it puts your line through to an operator, and that is
-- exactly the mechanic. Everything the group says to keep its clocks down still
-- feeds the thing that hunts meaning.
--
-- ONE call at a time, to the player who has been quiet longest, because
-- `Pursuit` is committed to one room at a time anyway -- dispatching all four
-- overdue players would queue three rooms behind each other and the last would
-- arrive a minute after the silence that caused it.
local function putThroughTheSilentLine()
	-- R110: the dispatch lives in Supervisor.putThrough, where the suite RUNS
	-- it and the soak calls the same function. All that is left here is the
	-- one thing the module cannot do: say the line.
	local called, announce = supervisor:putThrough(pursuit, built.rooms, Config.Rooms, livePositions(), os.clock())
	if called and announce then
		heardRemote:FireAllClients(Round.LINES.traced, "", 1)
	end
end

-- Nearly out of time, privately, so the player can still do something about it.
-- Separate from the call itself for the reason R10 and R13 each had to unpick:
-- two different events must not arrive as one sentence.
-- The last band each player was TOLD, so the push happens on change rather than
-- four times a second. R11's lesson: an event that should announce itself once
-- announcing itself continuously is its own bug, and this one would also
-- replicate to every client on every tick.
local function showEveryoneTheirClock()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		-- R115: "on change" is remembered by the Supervisor, which forgets it on
		-- reset and on leave by construction.
		local band, quiet = supervisor:bandNews(player.UserId, now)
		if band then
			-- Band, how full the bar is, and the words. The client is told the
			-- PRESSURE rather than the seconds, so the dial can move without the
			-- client knowing it exists -- `Silence.pressure` was written for
			-- exactly this and had no reader until now.
			-- Band, how full the bar is, the words, and HOW LONG IS LEFT. The
			-- last one is what lets the client fill the bar between pushes
			-- without knowing `SpeakEvery` -- pressure and seconds-left
			-- together give the rate. Without it the bar showed three
			-- positions in a countdown and stood still for 29.5s of 45.
			silenceRemote:FireClient(
				player,
				band,
				Silence.pressure(quiet),
				Silence.note(band),
				Silence.secondsLeft(quiet)
			)
		end
	end
end

-- Rate limiting: Station.tryPace (R116).

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
	-- R138: the last line opens the way out rather than winning. The outside
	-- call rings, and once it has the Operator comes for the lobby; see
	-- `workTheWayOut`, which the tick asks.
	if board:allSolved() and escape:open(os.clock()) then
		heardRemote:FireAllClients(Round.LINES.ringing, "", 1)
	end
end

-- Everything a player says is evidence, heard on the server through ChatFeed
-- (`Player.Chatted`). Until R139 this was `TextChatService.OnIncomingMessage`,
-- a callback Roblox runs only on the client, so on a live server nothing
-- reached either listener (COACH.md C1).
local function hearChat(player: Player, text: string)
	-- It is only listening while a round is being played. R29 gated CAPTURE on
	-- this and nothing else, so during the intermission a plain giveaway still
	-- made the Operator announce itself and walk audibly toward a room it could
	-- take nobody in -- and then `beginRound` teleported it home mid-walk.
	-- The whole game rests on the hum meaning something; a hum that sometimes
	-- means nothing is worse than no hum. Gating the FEED also keeps lobby
	-- chatter out of the observation buffer.
	if not round:isPlaying() then
		return
	end

	-- Both listeners, from the one utterance. The Supervisor does not care
	-- WHAT was said -- its demand is that you speak, and the trap is that
	-- everything you say to satisfy it is still heard by the Operator.
	-- `GAME.md`: babble continuously, convey nothing.
	supervisor:hear(player.UserId, os.clock())
	operator:hear({
		speaker = player,
		text = text,
		at = os.clock(),
	})
end
ChatFeed.new(hearChat):follow(Players)

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
		-- Record it FIRST. This is the server's own copy of which station this
		-- player reached, and `submit` is gated on it -- the client's
		-- `openStation` is now a view, not the authority.
		desk:open(player.UserId, station.id)
		-- The client needs to know WHICH keypad it opened, or it submits every
		-- answer against the switchboard.
		openBoardRemote:FireClient(player, station.id, station.actionText)
	end)
end

submitRemote.OnServerEvent:Connect(function(player: Player, id: unknown, value: unknown)
	-- Never trust the client.
	-- R109: types and lengths, in Shared.Keypad where the suite runs them.
	if not Keypad.validSubmission(id, value) then
		return
	end

	local now = os.clock()
	if not desk:tryPace(player.UserId, now) then
		return
	end

	-- You must have reached that station. Checked here rather than inside
	-- `submit` because it is about the player's body, not about the line: a
	-- station id the client made up now fails on the same private channel as a
	-- wrong code, and never touches `misses`, so a probe cannot cost the honest
	-- actor a jam.
	-- A finished round takes no more answers. R29 gated capture on the phase and
	-- R32 gated listening; this is the last place that takes player input, and
	-- without it a player types the number they were told into a keypad the game
	-- still draws and it vanishes into a round that is over.
	-- R114: the gates -- round over, on the line, not at the station, a keypad
	-- never opened -- live in Station.gate, in that order, where the suite runs
	-- them. Only the telling is left here.
	local refused = desk:gate(
		player.UserId,
		id :: string,
		round:isPlaying(),
		line:isConnected(player.UserId),
		livePositions()[player.UserId],
		built.stationAt[id :: string]
	)
	if refused then
		if refused.busy then
			heardRemote:FireClient(player, Round.LINES.busy, "", 0)
		end
		rejectedRemote:FireClient(player, id :: string, refused.reason)
		return
	end

	local result = board:submit(id :: string, player.UserId, value :: string, now)
	if not result.ok and result.reason then
		-- Two channels, on purpose. The Operator says its line to this player
		-- and says nothing that identifies the station; the REASON goes down
		-- the private keypad channel tagged with the station it is about, so it
		-- cannot paint the other keypad and cannot be confused with narration.
		--
		-- THE VOICE IS GATED ON `fault`, the keypad note is not. Two players at
		-- one keypad both enter the number they were told and the loser of the
		-- frame lands on `already restored` -- a refusal that is nobody's doing.
		-- Firing `busy` for it meant the Operator said "That line is busy." to a
		-- player for typing the RIGHT answer, in the same breath as it told
		-- everyone the call had been completed. Two contradictory lines, one
		-- tick apart, and only ever with two players. The station-tagged note
		-- still goes, because "already restored" is information; the accusation
		-- does not.
		if result.fault then
			heardRemote:FireClient(player, Round.LINES.busy, "", 0)
		end
		rejectedRemote:FireClient(player, id :: string, result.reason)
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	print(`[server] {player.Name} connected to the exchange`)
	-- From NOW, not from the start of the round: somebody who has just loaded
	-- in has not been silent, and a clock starting at zero would call them
	-- before they could type.
	supervisor:watch(player.UserId, os.clock())
	-- Re-deal across everyone present, so holders stay spread as people join.
	local userIds: { number } = {}
	for _, p in Players:GetPlayers() do
		table.insert(userIds, p.UserId)
	end
	board:deal(userIds)
	task.defer(function()
		pushPhase(nil)
		pushObjectives(nil)
		broadcastLexicon()
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	-- Per-player slots. `lastSubmit` and the desk are session state and go;
	-- `misses`/`jammedUntil` deliberately DO NOT (see Objectives), because a jam
	-- a player can shed by reconnecting is not a jam.
	supervisor:forget(player.UserId)
	line:forget(player.UserId)
	desk:forget(player.UserId)
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

-- THE WAY OUT (R138). Asked on the tick, AFTER capture and the loss, like
-- them: one beat of `Escape.step`, the rule the soak and the bots also run.
-- It sends the Operator for the lobby once the call has rung, and says when the
-- round is settled -- won when everyone still free is in the lobby, or at the
-- escape's time limit.
local function workTheWayOut()
	if not (round:isPlaying() and escape:isOpen()) then
		return
	end
	local outcome = escape:step(os.clock(), pursuit, presentUserIds(), line, livePositions(), built.rooms)
	if outcome then
		endTheRound(outcome)
	end
end

-- The server's clock. Two jobs at two rates.
--
-- CAPTURE runs every tick, because until R24 it ran ONCE — from
-- `pursuit.onStateChanged` on the transition to `arrived`, and `setState`
-- returns early when the state has not changed. The Operator took whoever
-- happened to be in the room at that single instant and then stood there
-- permanently harmless: a player could walk in beside it and stay for a minute
-- untouched. Occupancy is a continuous fact, so it has to be asked continuously.
--
-- FORGETTING is not on this clock any more. R131: heat cools once per round, in
-- `beginRound`, so how long a codeword lasts is counted in rounds and does not
-- depend on how fast the group plays.
-- Begin the next round. The LEXICON deliberately survives: a group's shared
-- vocabulary carrying between rounds is the retention mechanic GAME.md is built
-- on, and resetting it would make every round a first round with strangers.
-- Everything else starts over.
local function beginRound()
	board:reset()
	line:clear()
	-- Per-round state. Anything declared at the top of this file that carries a
	-- round's worth of state has to be listed here; tests/wiring.luau derives
	-- that list from the source rather than trusting this comment.
	desk:clear()
	operator:forgetObservations()
	-- R131: the Operator forgets a little, once per round. The Lexicon goes out
	-- to everyone at the end of this function either way.
	operator:coolRound(Config.CoolPerRound)
	-- R138: the way out shuts again until the new board is done.
	escape:reset()
	-- Every clock starts again. R31: a player quiet through the eight-second
	-- intermission must not be called in the first seconds of the round.
	supervisor:reset(os.clock())
	-- (R115: `supervisor:reset` above also clears what each panel was last told.)

	local userIds: { number } = {}
	for _, p in Players:GetPlayers() do
		table.insert(userIds, p.UserId)
		supervisor:watch(p.UserId, os.clock())
		connectedRemote:FireClient(p, false)
	end
	board:deal(userIds)

	-- Back to its post, not merely stopped. `stop()` leaves it standing wherever
	-- the last round ended, so round two began with it inside a room and the
	-- next understanding of that room arrived instantly and silently.
	pursuit:sendHome(built.operatorStart)
	heardRemote:FireAllClients(Round.LINES.greeting, "", 0)
	pushPhase(nil)
	pushObjectives(nil)
	broadcastLexicon()
	print(`[server] round {round.number} begins`)
end

local running = true
task.spawn(function()
	while running do
		task.wait(Config.TickSeconds)
		if not running then
			break
		end

		-- A finished round is not a hunting ground. Without this the Operator
		-- keeps taking people during the intermission, after the line that told
		-- them it was over.
		if round:isPlaying() and pursuit.state == "arrived" then
			takeWhoeverIsHere()
		end

		if round:readyToRestart(os.clock(), Config.IntermissionSeconds) and round:restart() then
			beginRound()
		end

		-- ...but not forever. Nothing except the loss ever released it before
		-- R25, so a single plain word parked it on an objective for the rest of
		-- the round and nobody could ever finish that station.
		-- Losing is checked every beat, not only when the Operator arrives: a
		-- round stranded by a capture stayed live until it came back.
		if round:isPlaying() and endTheRoundIfNobodyCanWin(presentUserIds()) then
			endTheRound("lost")
		end

		-- Silence, which is the one thing the Operator cannot hear. Asked every
		-- beat for the same reason capture is: it is a continuous fact, not an
		-- event, and R24 is the round that learned what asking once costs.
		if round:isPlaying() then
			showEveryoneTheirClock()
			putThroughTheSilentLine()
		end

		workTheWayOut()

		-- A room it heard about while it was busy. Taken up only once it is idle
		-- again, so it finishes one call before answering the next -- see
		-- Pursuit.sendTo, and the livelock that made commitment necessary.
		pursuit:takePending()

		if pursuit:shouldLeave(Config.LingerSeconds) then
			-- It WALKS out, audibly, rather than switching off where it stands.
			-- `stop()` released the room in silence with the body motionless, so
			-- nothing told players it was safe -- and a monster whose rule cannot
			-- be learned reads as unfair. It also says so, in its own register.
			pursuit:withdrawTo(built.operatorStart)
			heardRemote:FireAllClients(Round.LINES.givingUp, "", 0)
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
