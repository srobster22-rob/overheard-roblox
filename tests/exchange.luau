--!strict
-- The server's game flow, run headlessly on a fake host. Run: lune run tests/exchange
--
-- What this file guards:
--   - Exchange.build runs with nothing from Roblox but the host it is given:
--     players join and are dealt lines, the card index shows a player their
--     own line, a station prompt opens that keypad, a right code at the
--     station restores the line, a code from elsewhere is refused privately,
--     plain talk sends the Operator, the beat runs, and a player leaving
--     hands their lines on.
--   - None of it throws (the flow's callbacks run under Guard).

local Harness = require("./harness")
local Kit = require("./kit")
local check = Kit.check

local rt = Harness.build()
local Exchange = rt.require(rt.systems.Exchange)
local Round = rt.require(rt.systems.Round)
local Layout = rt.require(rt.shared.Layout)
local Config = rt.require(rt.shared.Config)
local Guard = rt.require(rt.shared.Guard)

-- A RemoteEvent that records what the flow sent through it.
type Sent = { to: any, args: { any } }
local function recorder(): any
	local remote = { sent = {} :: { Sent } }
	function remote.FireClient(self: any, player: any, ...: any)
		table.insert(self.sent, { to = player.UserId, args = { ... } })
	end
	function remote.FireAllClients(self: any, ...: any)
		table.insert(self.sent, { to = "all", args = { ... } })
	end
	return remote
end

local function sentTo(remote: any, to: any): { Sent }
	local out = {}
	for _, s in remote.sent do
		if s.to == to then
			table.insert(out, s)
		end
	end
	return out
end

-- Players with a body the flow can find, standing where the test puts them.
local roster: { any } = {}
local function newPlayer(id: number, name: string, at: { x: number, z: number }): any
	local root = { Position = { X = at.x, Z = at.z } }
	return {
		UserId = id,
		Name = name,
		Character = {
			FindFirstChild = function(_self: any, child: string): any
				return if child == "HumanoidRootPart" then root else nil
			end,
		},
		stand = function(point: { x: number, z: number })
			root.Position = { X = point.x, Z = point.z }
		end,
	}
end

local remotes = {}
for _, name in
	{ "Heard", "LexiconUpdated", "Objectives", "OpenBoard", "Silence", "Rejected", "Connected", "Phase", "Holding" }
do
	remotes[name] = recorder()
end

local stationAt = {}
local stationById = {}
for _, station in Round.STATIONS do
	stationAt[station.id] = Layout.stationPoint(station.id)
	stationById[station.id] = station
end
local rooms = Layout.rooms()

local now = 100
local flow = Exchange.build({
	Players = {
		GetPlayers = function(_self: any)
			return table.clone(roster)
		end,
		GetPlayerByUserId = function(_self: any, id: number): any
			for _, p in roster do
				if p.UserId == id then
					return p
				end
			end
			return nil
		end,
	},
	TextService = {
		FilterStringAsync = function(_self: any, text: string, _authorId: number): any
			return {
				GetNonChatStringForBroadcastAsync = function(_result: any): string
					return text
				end,
			}
		end,
	},
	remotes = remotes,
	built = { rooms = rooms, stationAt = stationAt, operatorStart = Layout.operatorPost() },
	spawnTask = function(work: () -> ())
		work()
	end,
	deferTask = function(work: () -> ())
		work()
	end,
	clock = function(): number
		return now
	end,
})
check("(guard) the flow builds on a fake host", flow ~= nil and flow.beat ~= nil)

print("")
print("players join and are dealt lines")
local players = {
	newPlayer(1, "Ana", rooms.board),
	newPlayer(2, "Bo", rooms.board),
	newPlayer(3, "Cy", rooms.archive),
	newPlayer(4, "Dee", rooms.archive),
}
for _, p in players do
	table.insert(roster, p)
	flow.playerAdded(p)
end
local everyoneSeen = true
for _, p in players do
	everyoneSeen = everyoneSeen and #sentTo(remotes.Objectives, p.UserId) > 0
end
check("every player who joins is sent their own panel", everyoneSeen)
local held = true
for _, station in Round.STATIONS do
	local holder = (flow.board:get(station.id) :: any).holder
	held = held and holder ~= nil and holder >= 1 and holder <= 4
end
check("every line has a holder among them", held)

print("")
print("the card index shows a player their own line, privately")
local greeted = #sentTo(remotes.Heard, 1)
flow.readerPrompt(players[1])
local toAna = sentTo(remotes.Heard, 1)
check(
	"reading it says the greeting to that player only",
	#toAna == greeted + 1 and toAna[#toAna].args[1] == Round.LINES.greeting
)

print("")
print("a right code at the station restores its line")
local line = flow.board:get("breaker") :: any
local entrant = if line.holder == 3 then players[4] else players[3]
entrant.stand(stationAt.breaker)
flow.openStation(entrant, stationById.breaker)
local opened = sentTo(remotes.OpenBoard, entrant.UserId)
check(
	"the prompt opens that keypad for that player",
	#opened == 1 and opened[1].args[1] == "breaker" and opened[1].args[2] == stationById.breaker.actionText
)
now += 1
flow.submit(entrant, "breaker", line.answer)
check("the right code restores the line", line.solved == true)

print("")
print("a code from somewhere else is refused on that player's own channel")
local board = flow.board:get("board") :: any
local stranger = if board.holder == 3 then players[4] else players[3]
stranger.stand(rooms.archive)
now += 1
flow.submit(stranger, "board", board.answer)
local refused = sentTo(remotes.Rejected, stranger.UserId)
check("the line is not restored", board.solved == false)
check("the refusal goes to that player, about that station", #refused >= 1 and refused[#refused].args[1] == "board")
check("...and to nobody else", #sentTo(remotes.Rejected, "all") == 0)

print("")
print("plain talk about a station sends the Operator")
flow.hearChat(players[1], "the jack on the switchboard")
check("it heads for the board room", flow.pursuit.targetName == "board")
check("...and says so to everyone", #sentTo(remotes.Heard, "all") > 0)

print("")
print("the beat runs")
local beaten, why = pcall(function()
	for _ = 1, 40 do
		now += Config.TickSeconds
		flow.beat()
	end
end)
check("forty beats run without an error", beaten)
if not beaten then
	print(`  {why}`)
end

print("")
print("a player who leaves hands their lines on")
local leaver = players[4]
flow.playerRemoving(leaver)
table.remove(roster, 4)
local orphaned = false
for _, station in Round.STATIONS do
	local l = flow.board:get(station.id) :: any
	orphaned = orphaned or (not l.solved and l.holder == leaver.UserId)
end
check("no unrestored line is left with the player who left", not orphaned)

print("")
local failures = Guard.failures()
check(`nothing the flow ran threw ({#failures})`, #failures == 0)
for _, f in failures do
	print(`  [{f.tag}] {f.message}`)
end

Kit.finish()
