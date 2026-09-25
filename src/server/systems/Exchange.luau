--!strict
-- The server's game flow: chat into the Operator, restores into its learning,
-- capture, the Supervisor, the way out, and each round's start and end. It
-- reaches Roblox only through the host it is built with, so init.server runs
-- it with the real services and tests/exchange.luau runs it with fakes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(ReplicatedStorage.Shared.Guard)
local Keypad = require(ReplicatedStorage.Shared.Keypad)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Silence = require(ReplicatedStorage.Shared.Silence)
local Censor = require(script.Parent.Censor)
local Connected = require(script.Parent.Connected)
local Escape = require(script.Parent.Escape)
local Lifecycle = require(script.Parent.Lifecycle)
local Objectives = require(script.Parent.Objectives)
local Operator = require(script.Parent.Operator)
local Pursuit = require(script.Parent.Pursuit)
local Round = require(script.Parent.Round)
local Station = require(script.Parent.Station)
local Supervisor = require(script.Parent.Supervisor)

local Exchange = {}

-- What the flow needs from Roblox. `remotes` holds the RemoteEvents it fires,
-- by their Remotes names; `built` is World.build's result.
export type Host = {
	Players: any,
	TextService: any,
	remotes: { [string]: any },
	built: any,
	spawnTask: (work: () -> ()) -> any,
	deferTask: (work: () -> ()) -> any,
	-- Seconds, rising: os.clock on the server, a stepped clock in tests.
	clock: () -> number,
}

-- What a host connects, and the state tests read.
export type Flow = {
	hearChat: (player: any, text: string) -> (),
	readerPrompt: (player: any) -> (),
	openStation: (player: any, station: Round.Station) -> (),
	submit: (player: any, id: unknown, value: unknown) -> (),
	playerAdded: (player: any) -> (),
	playerRemoving: (player: any) -> (),
	beat: () -> (),
	secrets: { any },
	operator: any,
	board: any,
	pursuit: any,
	round: any,
	line: any,
	escape: any,
	supervisor: any,
	desk: any,
}

-- Every present player's name as a player types it, Name and DisplayName in
-- lower case: "dee, ay aitch" speaks to Dee, and is not "d a" (Method).
local function namesOf(Players: any): { [string]: boolean }
	local names: { [string]: boolean } = {}
	for _, p in Players:GetPlayers() do
		names[string.lower(p.Name)] = true
		names[string.lower(p.DisplayName)] = true
	end
	return names
end

function Exchange.build(host: Host): Flow
	local Players = host.Players
	local TextService = host.TextService
	local built = host.built
	local spawnTask = host.spawnTask
	local deferTask = host.deferTask
	local clock = host.clock
	local heardRemote = host.remotes.Heard
	local lexiconRemote = host.remotes.LexiconUpdated
	local objectivesRemote = host.remotes.Objectives
	local openBoardRemote = host.remotes.OpenBoard
	local silenceRemote = host.remotes.Silence
	local rejectedRemote = host.remotes.Rejected
	local connectedRemote = host.remotes.Connected
	local phaseRemote = host.remotes.Phase
	local holdingRemote = host.remotes.Holding

	-- Stations are the source of truth: the board and the Operator's secrets are
	-- both derived from `Round.STATIONS`, so an objective can never exist for a
	-- concept the Operator was not dealt.
	local secrets = Round.dealSecrets(Round.secretsPerRound())
	local operator = Operator.new(secrets)
	local board = Objectives.new()
	-- Which keypad each player has actually walked up to, kept on the server so
	-- no submit takes the client's word for its station id. See systems/Station.
	local desk = Station.new()
	-- THE SUPERVISOR (GAME.md #4). Watches who has NOT spoken, which is the one
	-- thing the Operator cannot see. Without it, saying nothing is not merely
	-- safe, it wins more than talking does, and a group on a voice call outside
	-- Roblox plays an unopposed fetch quest (see systems/Supervisor).
	-- It decides WHO; the dispatch below decides what.
	local supervisor = Supervisor.new()
	-- Who the Operator has taken. Being connected costs you the ability to ACT;
	-- it does not cost you your voice. See systems/Connected.
	local line = Connected.new()
	-- Whether a round is being played. See systems/Lifecycle.
	local round = Lifecycle.new()
	-- The way out, opened when the last line is restored (DECISIONS D6). See systems/Escape.
	local escape = Escape.new()

	for _, station in Round.STATIONS do
		board:add(station.id, station.concept, station.prompt)
	end
	-- The codes are secrets too: the Operator asks the board for the live ones each
	-- time it hears something.
	operator.liveCodes = Guard.wrap("server.liveCodes", function()
		return board:liveCodes()
	end)
	-- A way the group taught it reads a player's lines only against the codes
	-- that player has seen (DECISIONS D13).
	operator.seenCodes = Guard.wrap("server.seenCodes", function(userId: number)
		return board:codesSeenBy(userId)
	end)
	operator.names = Guard.wrap("server.names", function()
		return namesOf(Players)
	end)

	-- With a room off the corridor, the Operator turns at the junction (DECISIONS D5).
	local pursuit = Pursuit.new(built.rooms, built.operatorStart, Layout.route)
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
	-- sees it (PLATFORM.md). A phrase that cannot be filtered is left off the
	-- panel (Censor, DECISIONS D8); the failure is reported, never hidden.
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
		return Round.wallRows(operator:snapshot(), operator:countingRows(), operator:methodRows())
	end, function(visible)
		lexiconRemote:FireAllClients(visible)
	end, function(work)
		return spawnTask(Guard.wrap("server.lexiconBroadcast", work))
	end)

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
	-- anything: the Operator takes everyone in a room at once, so three of four
	-- caught in one arrival can strand a line with its reader, and the survivor
	-- can then neither win nor be forced to lose.
	--
	-- ASKED ON THE TICK, not only when the Operator arrives. Checked on capture
	-- alone, a stranded round keeps running after the Operator walks away --
	-- about half a minute in the soak -- because nothing looks again until it
	-- comes back.
	--
	-- The `line:count() > 0` clause is what keeps a solo server from losing
	-- instantly and looping: a board nobody can finish with NOBODY connected is the
	-- dealing problem, which is the owner's parked solo-play question (OWNER.md),
	-- not a round that play has stranded.
	--
	-- The rule itself lives in `Lifecycle.nobodyCanWin`, where the headless suite
	-- RUNS it: a check that only reads this file's text cannot catch a flipped
	-- clause of the game's loss condition.
	local function endTheRoundIfNobodyCanWin(present: { number }): boolean
		return Lifecycle.nobodyCanWin(present, board, line)
	end

	-- The round is over: finish it, say so, tell every panel and stop the
	-- Operator. Nothing is said twice: a round already over is left alone. A win
	-- says `completed`, not `taken`: `taken` is what it says when the MONSTER
	-- arrives, and the same string for winning would render the two opposite
	-- events as one sentence on the client. It STOPS either way: a round that is
	-- over must not leave it hunting, where a group that finished could still be
	-- taken, or travelling, where the hum goes on over a finished round.
	local function endTheRound(outcome: Lifecycle.Outcome)
		if not round:finish(outcome, clock()) then
			return
		end
		heardRemote:FireAllClients(if outcome == "won" then Round.LINES.completed else Round.LINES.lost, "", 1)
		pushPhase(nil)
		pursuit:stop()
	end

	local function takeWhoeverIsHere()
		-- The ROOM it arrived in, not a circle around it. See Connected.reachedInRoom:
		-- a circle big enough to cover the square also covers 9.94 studs of corridor
		-- outside every wall, so running out of the door would not save you.
		-- Connect-and-forget lives in Connected.takeInRoom (RUN by the suite, and
		-- called by the soak); only the telling is left here.
		local caught, newly = line:takeInRoom(pursuit.position, livePositions(), Layout.halfRoom(), clock(), supervisor)
		for _, userId in newly do
			-- Each newly caught player is told, and takeInRoom has already made
			-- the Supervisor forget them. A caught player cannot act -- Station.gate
			-- refuses anyone on the line -- and nothing in this round releases
			-- them again, so there is no more silence left to punish. Chasing them
			-- would spend roughly HALF of every dispatch and every audible
			-- "putting you through" on a player who cannot benefit from the visit,
			-- taken directly from whoever the mechanic still has a reason to reach.
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

		-- The loss. Without it the round could be WON but never LOST: the Operator
		-- could take every player and the game would sit there, the board still
		-- open, nothing said. Checked against who is actually present, so a player
		-- leaving cannot strand the round.
		if endTheRoundIfNobodyCanWin(presentUserIds()) then
			endTheRound("lost")
		end
	end

	-- Where the Operator is, to every Your Line panel (`Round.holding`).
	-- Asked every beat and sent when it changes, not from `onStateChanged`: a new
	-- destination at the same state (the outside call's `sendNow`) and `sendHome`
	-- from a room (arrived to arrived) change no state and fire nothing.
	local lastHolding = ""
	local function pushHolding(always: boolean?)
		local holding = Round.holding(pursuit.state, pursuit.targetName, Escape.ROOM)
		local key = if holding then `{holding.label or ""}|{holding.wayOut}` else ""
		if always or key ~= lastHolding then
			lastHolding = key
			holdingRemote:FireAllClients(holding)
		end
	end

	pursuit.onStateChanged = Guard.wrap("server.onStateChanged", function(state: string, targetName: string?)
		print(`[operator] {state}{if targetName then ` -> {targetName}` else ""}`)
		if state == "arrived" then
			heardRemote:FireAllClients(Round.LINES.taken, targetName or "", 1)
			takeWhoeverIsHere()
		end
	end)

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
		-- The dispatch lives in Supervisor.putThrough, where the suite RUNS it and
		-- the soak calls the same function. All that is left here is the one
		-- thing the module cannot do: say the line.
		local called, announce = supervisor:putThrough(pursuit, built.rooms, Config.Rooms, livePositions(), clock())
		if called and announce then
			heardRemote:FireAllClients(Round.LINES.traced, "", 1)
		end
	end

	-- Nearly out of time, privately, so the player can still do something about it.
	-- Separate from the call itself: two different events must not arrive as one
	-- sentence. Pushed when a player's band changes rather than four times a
	-- second: an event that should announce itself once must not announce itself
	-- continuously, and this one would also replicate to every client on every
	-- tick.
	local function showEveryoneTheirClock()
		local now = clock()
		for _, player in Players:GetPlayers() do
			-- "On change" is remembered by the Supervisor, which forgets it on
			-- reset and on leave by construction.
			local band, quiet = supervisor:bandNews(player.UserId, now)
			if band then
				-- Band, how full the bar is, the words, and HOW LONG IS LEFT. The
				-- client is told the PRESSURE rather than the seconds, so the dial
				-- can move without the client knowing it exists. Seconds-left is
				-- what lets the client fill the bar between pushes without knowing
				-- `SpeakEvery` -- pressure and seconds-left together give the rate.
				-- Without it the bar would show three positions in a countdown and
				-- stand still for most of it.
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

	-- Rate limiting: Station.tryPace.

	operator.onUnderstood = Guard.wrap(
		"server.onUnderstood",
		function(concept: string, payload: string, confidence: number, heard: string?)
			print(`[operator] understood '{concept}' ({string.format("%.2f", confidence)}) -> {payload}`)
			-- A code that moved it is read back (Round.readBack).
			heardRemote:FireAllClients(Round.readBack(heard), concept, confidence)
			-- Understanding is what moves it. An unknown payload is refused inside
			-- Pursuit rather than sending it somewhere arbitrary.
			pursuit:sendTo(payload)
		end
	)

	-- A word the group uses as a number is understood (DECISIONS D11). Said to
	-- everyone, and the wall shows the word under "counts as a number".
	operator.onCounted = Guard.wrap("server.onCounted", function(key: string, value: number)
		print(`[operator] counts '{key}' as {value}`)
		heardRemote:FireAllClients(Round.LINES.counted, "", 1)
		broadcastLexicon()
	end)

	-- The group's letters are understood (DECISIONS D12).
	operator.onLettered = Guard.wrap("server.onLettered", function()
		print("[operator] reads the group's letters")
		heardRemote:FireAllClients(Round.LINES.lettered, "", 1)
		broadcastLexicon()
	end)

	-- A way of passing codes is one restore short, or understood (DECISIONS
	-- D13). Said to everyone; the wall shows which way under "how you pass codes".
	operator.onMethod = Guard.wrap("server.onMethod", function(kind: string, way: string, says: string)
		print(`[operator] {kind} the way '{way}'`)
		heardRemote:FireAllClients((Round.LINES :: { [string]: string })[says], "", 1)
		broadcastLexicon()
	end)

	-- A code said aloud is spent: its holder gets a new one on their panel.
	operator.onCodeHeard = Guard.wrap("server.onCodeHeard", function(concept: string)
		if board:reroll(concept) then
			pushObjectives(nil)
		end
	end)

	operator.onBurned = Guard.wrap("server.onBurned", function(coinage)
		print(`[operator] BURNED '{coinage.phrase}' = {coinage.concept}`)
		heardRemote:FireAllClients(Round.LINES.connecting, coinage.concept, 1)
		broadcastLexicon()
	end)

	-- Success is what teaches the Operator. Solving an objective credits the
	-- unfamiliar phrases its holder and its entrant said just beforehand.
	board.onSolved = Guard.wrap("server.onSolved", function(objective, actor: number)
		print(`[objective] {objective.id} restored`)
		operator:credit(objective.concept, clock(), objective.holder, actor)
		-- And whatever was said that works out as the code just entered.
		operator:creditCode(objective.answer, clock(), objective.holder)
		pushObjectives(nil)
		broadcastLexicon()
		-- The last line opens the way out rather than winning (DECISIONS D6). The
		-- outside call rings, and once it has the Operator comes for the lobby;
		-- see `workTheWayOut`, which the tick asks.
		if board:allSolved() and escape:open(clock()) then
			heardRemote:FireAllClients(Round.LINES.ringing, "", 1)
		end
	end)

	-- Everything a player says is evidence, heard on the server through ChatFeed
	-- (`Player.Chatted`). Not `TextChatService.OnIncomingMessage`: Roblox runs
	-- that callback only on the client, so on a live server nothing would reach
	-- either listener (PLATFORM.md).
	local function hearChat(player: Player, text: string)
		-- It is only listening while a round is being played. Gating capture alone
		-- is not enough: during the intermission a plain giveaway would still make
		-- the Operator announce itself and walk audibly toward a room it can take
		-- nobody in -- and then `beginRound` teleports it home mid-walk.
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
		supervisor:hear(player.UserId, clock())
		operator:hear({
			speaker = player,
			text = text,
			at = clock(),
		})
	end
	local function readerPrompt(player: Player)
		-- Reading is private. The holder sees their own line; nobody else does.
		pushObjectives(player)
		heardRemote:FireClient(player, Round.LINES.greeting, "", 0)
	end

	local function openStation(player: Player, station: Round.Station)
		-- Record it FIRST. This is the server's own copy of which station this
		-- player reached, and `submit` is gated on it -- the client's
		-- `openStation` is a view, not the authority.
		desk:open(player.UserId, station.id)
		-- The client needs to know WHICH keypad it opened, or it submits every
		-- answer against the switchboard.
		openBoardRemote:FireClient(player, station.id, station.actionText)
	end

	local function submit(player: Player, id: unknown, value: unknown)
		-- Never trust the client.
		-- Types and lengths, in Shared.Keypad where the suite runs them.
		if not Keypad.validSubmission(id, value) then
			return
		end

		local now = clock()
		if not desk:tryPace(player.UserId, now) then
			return
		end

		-- You must have reached that station. Checked here rather than inside
		-- `board:submit` because it is about the player's body, not about the line:
		-- a station id the client made up fails on the same private channel as a
		-- wrong code, and never touches `misses`, so a probe cannot cost the honest
		-- actor a jam.
		-- A finished round takes no more answers. Capture and listening are gated
		-- on the phase too; this is the last place that takes player input, and
		-- without it a player types the number they were told into a keypad the
		-- game still draws and it vanishes into a round that is over.
		-- The gates -- round over, on the line, not at the station, a keypad never
		-- opened -- live in Station.gate, in that order, where the suite runs them.
		-- Only the telling is left here.
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
			-- Firing `busy` for it would have the Operator say "That line is busy."
			-- to a player for typing the RIGHT answer, in the same breath as it tells
			-- everyone the call has been completed: two contradictory lines, one
			-- tick apart, and only ever with two players. The station-tagged note
			-- still goes, because "already restored" is information; the accusation
			-- does not.
			if result.ringsThrough then
				-- Past the free miss, a wrong code rings through: said to everyone,
				-- and the Operator walks to that station's room.
				heardRemote:FireAllClients(Round.LINES.wrongParty, "", 1)
				local room = Layout.stationRoom(id :: string)
				if room then
					pursuit:sendTo(room)
				end
			elseif result.fault then
				heardRemote:FireClient(player, Round.LINES.busy, "", 0)
			end
			rejectedRemote:FireClient(player, id :: string, result.reason)
		end
	end

	local function playerAdded(player: Player)
		print(`[server] {player.Name} connected to the exchange`)
		-- From NOW, not from the start of the round: somebody who has just loaded
		-- in has not been silent, and a clock starting at zero would call them
		-- before they could type.
		supervisor:watch(player.UserId, clock())
		-- Re-deal across everyone present, so holders stay spread as people join.
		local userIds: { number } = {}
		for _, p in Players:GetPlayers() do
			table.insert(userIds, p.UserId)
		end
		board:deal(userIds)
		deferTask(Guard.wrap("server.playerAddedPush", function()
			pushPhase(nil)
			pushObjectives(nil)
			pushHolding(true)
			broadcastLexicon()
		end))
	end

	local function playerRemoving(player: Player)
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
	end

	-- THE WAY OUT (DECISIONS D6, D7). Asked on the tick, AFTER capture and the
	-- loss, like them: one beat of `Escape.step`, the rule the soak and the bots
	-- also run. It sends the Operator for the lobby once the call has rung, and
	-- says when the round is settled -- won when everyone still free is in the
	-- lobby, or at the escape's time limit.
	local function workTheWayOut()
		if not (round:isPlaying() and escape:isOpen()) then
			return
		end
		local outcome = escape:step(clock(), pursuit, presentUserIds(), line, livePositions(), built.rooms)
		if outcome then
			endTheRound(outcome)
		end
	end

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
		-- The Operator forgets a little, once per round. The Lexicon goes out
		-- to everyone at the end of this function either way.
		operator:coolRound(Config.CoolPerRound)
		-- The way out shuts again until the new board is done.
		escape:reset()
		-- Every clock starts again: a player quiet through the eight-second
		-- intermission must not be called in the first seconds of the round.
		supervisor:reset(clock())
		-- (`supervisor:reset` above also clears what each panel was last told.)

		local userIds: { number } = {}
		for _, p in Players:GetPlayers() do
			table.insert(userIds, p.UserId)
			supervisor:watch(p.UserId, clock())
			connectedRemote:FireClient(p, false)
		end
		board:deal(userIds)

		-- Back to its post, not merely stopped. `stop()` leaves it standing wherever
		-- the last round ended, so the next round would begin with it inside a room
		-- and the next understanding of that room would arrive instantly and
		-- silently.
		pursuit:sendHome(built.operatorStart)
		heardRemote:FireAllClients(Round.LINES.greeting, "", 0)
		pushPhase(nil)
		pushObjectives(nil)
		broadcastLexicon()
		print(`[server] round {round.number} begins`)
	end

	-- One beat of the server's clock: capture, the restart, the loss, the silent
	-- line, the way out, a queued room, the linger, the panels.
	--
	-- CAPTURE runs every beat, not only on the transition to `arrived`:
	-- `setState` returns early when the state has not changed, so a capture
	-- fired from `pursuit.onStateChanged` alone takes whoever is in the room at
	-- that single instant, and then the Operator stands there harmless while a
	-- player walks in beside it. Occupancy is a continuous fact, so it has to be
	-- asked continuously.
	--
	-- FORGETTING is not on this clock: heat cools once per round, in
	-- `beginRound`, so how long a codeword lasts is counted in rounds and does
	-- not depend on how fast the group plays.
	local function beat()
		-- A finished round is not a hunting ground. Without this the Operator
		-- keeps taking people during the intermission, after the line that told
		-- them it was over.
		if round:isPlaying() and pursuit.state == "arrived" then
			takeWhoeverIsHere()
		end

		if round:readyToRestart(clock(), Config.IntermissionSeconds) and round:restart() then
			beginRound()
		end

		-- Losing is checked every beat, not only when the Operator arrives: a
		-- round stranded by a capture would stay live until it came back.
		if round:isPlaying() and endTheRoundIfNobodyCanWin(presentUserIds()) then
			endTheRound("lost")
		end

		-- Silence, which is the one thing the Operator cannot hear. Asked every
		-- beat for the same reason capture is: it is a continuous fact, not an
		-- event.
		if round:isPlaying() then
			showEveryoneTheirClock()
			putThroughTheSilentLine()
		end

		workTheWayOut()

		-- A room it heard about while it was busy. Taken up only once it is idle
		-- again, so it finishes one call before answering the next -- see
		-- Pursuit.sendTo, and the livelock that commitment prevents.
		pursuit:takePending()

		-- It lingers in a room, but not forever: if only the loss released it, a
		-- single plain word would park it on an objective for the rest of the
		-- round and nobody could ever finish that station.
		if pursuit:shouldLeave(Config.LingerSeconds) then
			-- It WALKS out, audibly, rather than switching off where it stands.
			-- `stop()` would release the room in silence with the body motionless,
			-- so nothing would tell players it was safe -- and a monster whose
			-- rule cannot be learned reads as unfair. It also says so, in its own
			-- register.
			pursuit:withdrawTo(built.operatorStart)
			heardRemote:FireAllClients(Round.LINES.givingUp, "", 0)
		end

		-- Last in the beat, after everything that can move it.
		pushHolding()
	end

	return {
		hearChat = hearChat,
		readerPrompt = readerPrompt,
		openStation = openStation,
		submit = submit,
		playerAdded = playerAdded,
		playerRemoving = playerRemoving,
		beat = beat,
		secrets = secrets,
		operator = operator,
		board = board,
		pursuit = pursuit,
		round = round,
		line = line,
		escape = escape,
		supervisor = supervisor,
		desk = desk,
	}
end

return Exchange
