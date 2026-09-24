--!strict
-- Guards a whole class of silent bug: a secret whose payload names a room that
-- does not exist. Pursuit refuses the move, so the Operator simply never
-- reacts, and nothing anywhere reports an error.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".

local Harness = require("./harness")

local rt = Harness.build()
local Round = rt.require(rt.systems.Round)
local Config = rt.require(rt.shared.Config)
local Layout = rt.require(rt.shared.Layout)

local Kit = require("./kit")
local check = Kit.check

local known: { [string]: boolean } = {}
for _, name in Config.Rooms do
	known[name] = true
end

print("payloads resolve")
-- Enumerated through `dealSecrets`, which is what the game runs. It was
-- `pickSecrets(99)` until R12 deleted that function: it shuffled 3 of 5 secrets
-- with no regard for the stations, so it was the R5 defect sitting exported.
-- A count past the pool size returns the whole pool either way.
local all = Round.dealSecrets(99)
check("the pool is not empty", #all > 0)
for _, secret in all do
	check(`'{secret.concept}' -> '{secret.payload}' is a real room`, known[secret.payload] == true)
end

print("plain terms")
for _, secret in all do
	check(`'{secret.concept}' has plain giveaway terms`, #secret.plain > 0)
end

print("selection")
check("dealing more than the pool is clamped", #Round.dealSecrets(99) == #all)
check("the retired shuffler is gone", (Round :: any).pickSecrets == nil)

print("lines")
check("the Operator has a greeting", #Round.LINES.greeting > 0)
-- `taken` (the monster arrived) and `completed` (the round was won) are opposite
-- events. They were the SAME string until R12, and since R10 dropped `detail`
-- from the client's `onHeard` there was nothing left on screen to tell them
-- apart. Asserted distinct here because the failure is silent: both still
-- render, they just both say the wrong thing half the time.
check("the round-won line exists", #Round.LINES.completed > 0)
check("arriving and winning are not the same sentence", Round.LINES.completed ~= Round.LINES.taken)
for name, line in Round.LINES do
	check(
		`line '{name}' is unique among the Operator's lines`,
		(function()
			local seen = 0
			for _, other in Round.LINES do
				if other == line then
					seen += 1
				end
			end
			return seen == 1
		end)()
	)
end

-- Stations. The board and the deal used to be two independent lists: the
-- server hardcoded one objective while pickSecrets shuffled 3 of 5 secrets, so
-- on 39.6% of servers the only objective's concept was not something the
-- Operator was listening for. Saying the answer out loud was free. These
-- checks are derived from STATIONS and from World's source, never from a
-- hand-kept list, so a station added later cannot slip past them.
print("")
print("stations")
local fs = require("@lune/fs")

local pool: { [string]: boolean } = {}
for _, secret in all do
	pool[secret.concept] = true
end

check("there is at least one station", #Round.STATIONS > 0)

local seenIds: { [string]: boolean } = {}
local worldSource = fs.readFile("src/server/systems/World.luau")

for _, station in Round.STATIONS do
	check(`station '{station.id}' has a unique id`, seenIds[station.id] == nil)
	seenIds[station.id] = true
	check(`station '{station.id}' wants a concept the secret pool carries`, pool[station.concept] == true)
	check(`station '{station.id}' prompt has a slot for the answer`, string.find(station.prompt, "%%s") ~= nil)
	-- R80. Readout.lineRows renders a held line with `string.format(entry.prompt,
	-- entry.answer)`, and string.format treats every `%` as the start of a
	-- directive -- a literal percent anywhere else in the prompt ("Static at 60%
	-- strength...") throws "invalid option" outright, and Readout has no pcall
	-- around it. The suite's OWN existing check of this text uses string.gsub
	-- (R41, checking what the sentence conveys), which does not share this
	-- failure mode -- so nothing before this actually reproduced the render path.
	local formatted = pcall(string.format, station.prompt, "42")
	check(`station '{station.id}' prompt survives the real render call, string.format`, formatted)
	check(`station '{station.id}' has an action verb`, #station.actionText > 0)
	-- No physical prompt means the objective can never be solved, so
	-- `allSolved` can never be reached and the round cannot end. R137: World
	-- builds one prompt per Round.STATIONS entry at Layout.stationPoint, so a
	-- station with no place is the defect (World would error on load).
	check(`station '{station.id}' has a place in the world`, Layout.stationPoint(station.id) ~= nil)
	check(`station '{station.id}' has a label`, #station.label > 0)
end
check(
	"World builds a prompt for every Round.STATIONS entry, at Layout.stationPoint",
	string.find(worldSource, "for _, s in Round.STATIONS do", 1, true) ~= nil
		and string.find(worldSource, "placeAt(s.id)", 1, true) ~= nil
		and string.find(worldSource, "Layout.stationPoint(id)", 1, true) ~= nil
		and string.find(worldSource, "stations = stationPrompts", 1, true) ~= nil
)

-- The load-bearing one: a station's concept must be dealt EVERY time, at any
-- count, including a count smaller than the number of stations.
for count = 0, #all do
	local dealt = Round.dealSecrets(count)
	local got: { [string]: boolean } = {}
	for _, secret in dealt do
		got[secret.concept] = true
	end
	local allIn = true
	for _, station in Round.STATIONS do
		if not got[station.concept] then
			allIn = false
		end
	end
	check(`dealSecrets({count}) still deals every station's concept`, allIn)
end
check("dealSecrets fills up to the requested count", #Round.dealSecrets(#all) == #all)

-- Rooms. `Config.Rooms` and `World.build`'s `rooms` table are two lists that
-- must agree, and until R6 the only thing keeping them in step was a comment.
-- A name declared in Config with no position in World makes `Pursuit.sendTo`
-- refuse the move: the Operator never arrives, nothing errors, and the checks
-- above still pass because they only ask whether a payload is in Config. A
-- room built but not declared is the mirror — this file would reject a payload
-- that would have worked. Both directions, every name, read out of World's
-- source rather than a hand-kept list. (R137: World builds exactly
-- `Layout.rooms()`, so that is read now.)
print("")
print("rooms")
-- R137: World builds exactly `Layout.rooms()`, so that is the list to compare.
local builtRooms: { [string]: boolean } = {}
for name in Layout.rooms() do
	builtRooms[name] = true
end
check(
	"World builds its rooms from Layout.rooms() and returns that table",
	string.find(worldSource, "local layoutRooms = Layout.rooms()", 1, true) ~= nil
		and string.find(worldSource, "= layoutRooms", 1, true) ~= nil
)
check("Config declares at least one room", #Config.Rooms > 0)
for _, name in Config.Rooms do
	check(`Config declares room '{name}' and World builds it`, builtRooms[name] == true)
end
for name in builtRooms do
	check(`World builds room '{name}' and Config declares it`, known[name] == true)
end

print("")
print("where it is waiting (R144)")
do
	local Escape = rt.require(rt.systems.Escape)
	local named = 0
	for _, station in Round.STATIONS do
		local room = Layout.stationRoom(station.id)
		local where = Round.holding("arrived", room, Escape.ROOM)
		if
			where
			and where.label == station.label
			and where.label == Round.leadsTo(station.concept)
			and where.wayOut == (room == Escape.ROOM)
		then
			named += 1
		end
	end
	check(
		`each room it can wait in is named by its station, as the wall names it ({named} of {#Round.STATIONS})`,
		named == #Round.STATIONS
	)
	local inLobby = Round.holding("arrived", Escape.ROOM, Escape.ROOM)
	local inArchive = Round.holding("arrived", "archive", Escape.ROOM)
	check(
		"only the way out's room is the way out",
		inLobby ~= nil and inLobby.wayOut and inArchive ~= nil and not inArchive.wayOut
	)
	local bound = Round.holding("approaching", Escape.ROOM, Escape.ROOM)
	local near = Round.holding("closing", Escape.ROOM, Escape.ROOM)
	check(
		"walking to the way out, it names no station but flags the way out",
		bound ~= nil and bound.label == nil and bound.wayOut and near ~= nil and near.label == nil and near.wayOut
	)
	check(
		"walking anywhere else, it is nowhere the panel says (the hum is the tell)",
		Round.holding("approaching", "archive", Escape.ROOM) == nil
			and Round.holding("closing", "board", Escape.ROOM) == nil
	)
	check("walking back to its post, it is nowhere", Round.holding("leaving", Escape.ROOM, Escape.ROOM) == nil)
	check(
		"at its post between rounds it is waiting nowhere a player goes",
		Round.holding("arrived", nil, Escape.ROOM) == nil
	)
end

print("")
print("a station's prompt gives no concept away, not even its own")

-- R41. The prompts are free text and nothing checked them against the words the
-- Operator listens for. `board` read *"Line is out. Patch it to jack 47."* and
-- `out` is plain language for `exit`, whose payload was the ARCHIVE (the lobby
-- since R137) — so a holder reading their own board instruction aloud sent
-- the Operator to the other room.
-- That is not a rule anyone can learn: the punishment names a room the prompt
-- was never about, and it lands on a teammate working there.
--
-- R41 left a prompt conveying its OWN concept alone. The owner ruled otherwise
-- (R127 breaker, R128 board): the holder reads the line aloud to a teammate, so
-- a prompt that names its own secret hands the Operator the word. Every prompt
-- must now convey NOTHING.

local Heuristic = rt.require(rt.systems.Heuristic)

-- SEEDED. `Round.dealSecrets` shuffles with `math.random`, and an unseeded test
-- is a different test every run: `tests/soak.luau` stranded 6, 7 and 13 rounds
-- on three runs of identical code, and two log entries argued from single runs
-- of it. Nothing in THIS file's assertions depends on the shuffle today, which
-- is exactly why it would go unnoticed the day one does.
math.randomseed(53)

local livePool = Round.dealSecrets(99)
check(`(guard) the whole pool is in play ({#livePool} concepts)`, #livePool >= 3)

local speaker = { UserId = 1 } :: any
local stationCount = 0
for _, station in Round.STATIONS do
	stationCount += 1
	local spoken = string.gsub(station.prompt, "%%s", "47")

	-- Every concept the sentence conveys, via the same reader the Operator uses.
	local conveyed = Heuristic.conveyed({ speaker = speaker, text = spoken, at = 1 }, livePool, {})
	local given: { string } = {}
	for _, reading in conveyed do
		table.insert(given, reading.concept :: string)
	end
	check(
		`'{station.id}' prompt gives away nothing at all, not even its own ({if #given == 0
			then "none"
			else table.concat(given, ", ")})`,
		#given == 0
	)

	-- The substitution must be exercised, or a prompt whose giveaway sits in the
	-- number would slip through untested.
	check(`(guard) '{station.id}' has a number substituted in`, string.find(spoken, "47", 1, true) ~= nil)
end
check(`(guard) stations were swept ({stationCount})`, stationCount >= 2)

-- Controls: the wordings the owner ruled out really did give their own secret
-- away, so the sweep above is not passing because the reader is deaf to them.
local function conveys(text: string, concept: string): boolean
	for _, reading in Heuristic.conveyed({ speaker = speaker, text = text, at = 1 }, livePool, {}) do
		if reading.concept == concept then
			return true
		end
	end
	return false
end
check(
	"(control) the old breaker wording really did give the breaker away",
	conveys("Breaker 47 tripped. Someone has to throw it.", "breaker")
)
check(
	"(control) the old board wording really did give the jack away",
	conveys("Line is dead. Patch it to jack 47.", "jack_number")
)

-- The control: the words that WERE in that prompt really are dangerous, so the
-- sweep above is not passing because the reader is deaf.
local outLoud = Heuristic.conveyed({ speaker = speaker, text = "the line is out", at = 1 }, livePool, {})
local heardExit = false
for _, reading in outLoud do
	if reading.concept == "exit" then
		heardExit = true
	end
end
check("(control) 'out' on its own really does give away the exit", heardExit)

print("")
print("the ambient-secret shuffle actually mixes the whole pool")

-- R69. A mutation sweep narrowed the deal's Fisher-Yates loop to touch only the
-- last two entries of `rest` (`for i = 2, 2, -1` instead of `for i = #rest, 2,
-- -1`), and nothing in the whole suite noticed -- every existing check asks
-- about the SET dealSecrets returns, never whether the shuffle actually mixes
-- more than a fixed pair of positions.
--
-- Swept across many seeds: the ambient secret(s) chosen must vary, or every
-- server would teach the same "safe" vocabulary regardless of the shuffle.
-- Every ambient secret must be reachable, not merely "more than one". (Until
-- R137 this also caught a narrowed shuffle; with two candidates it cannot, so
-- the shuffle is proven on its own below.)
--
-- The REQUIRED set (one secret per station) is deterministic and does not
-- depend on the shuffle at all, so it is computed once, unseeded, outside the
-- loop -- calling dealSecrets inside the loop just to re-derive it would burn
-- an extra shuffle every iteration for no reason.
local requiredConcepts: { [string]: boolean } = {}
for _, secret in Round.dealSecrets(0) do
	requiredConcepts[secret.concept] = true
end
local ambientPoolSize = #Round.dealSecrets(99) - #Round.dealSecrets(0)
-- R137: three stations of five concepts leave two ambient ones. At two, a
-- narrowed shuffle loop (R69's mutant) cannot be told from the real one here,
-- so the shuffle itself is proven on a longer list just below.
check(`(guard) there is an ambient pool to draw from ({ambientPoolSize})`, ambientPoolSize >= 2)

-- The shuffle, on five items across many seeds: every item must reach every
-- position. Narrowing the loop (stopping it early) strands some item.
local SHUFFLE_ITEMS = 5
local reachedAt: { [string]: boolean } = {}
for seed = 1, 400 do
	math.randomseed(seed * 131)
	local list = {}
	for i = 1, SHUFFLE_ITEMS do
		list[i] = i
	end
	Round.shuffle(list)
	for position, item in list do
		reachedAt[`{item}@{position}`] = true
	end
end
local pairsReached = 0
for _ in reachedAt do
	pairsReached += 1
end
check(
	`the shuffle can put any item anywhere ({pairsReached} of {SHUFFLE_ITEMS * SHUFFLE_ITEMS} item/position pairs)`,
	pairsReached == SHUFFLE_ITEMS * SHUFFLE_ITEMS
)
check(
	"dealSecrets uses that shuffle",
	string.find(fs.readFile("src/server/systems/Round.luau"), "Round.shuffle(rest)", 1, true) ~= nil
)

local askFor = #Round.dealSecrets(0) + 1
local seenAmbient: { [string]: boolean } = {}
for seed = 1, 200 do
	math.randomseed(seed * 97)
	local dealt = Round.dealSecrets(askFor)
	-- The one concept not required by any station is the ambient pick.
	for _, secret in dealt do
		if not requiredConcepts[secret.concept] then
			seenAmbient[secret.concept] = true
		end
	end
end
local reached = 0
for _ in seenAmbient do
	reached += 1
end
check(
	`the shuffle reaches EVERY member of the ambient pool over many seeds ({reached} of {ambientPoolSize})`,
	reached == ambientPoolSize
)
if reached < ambientPoolSize then
	local missing: { string } = {}
	for _, secret in Round.dealSecrets(99) do
		if not requiredConcepts[secret.concept] and not seenAmbient[secret.concept] then
			table.insert(missing, secret.concept)
		end
	end
	print(`        never dealt as ambient: {table.concat(missing, ", ")}`)
end

print("")
print("the Operator's own lines give nothing away")

-- R93/R129. A player echoing the monster is chat like any other, and nothing
-- scanned Round.LINES. R93 found `greeting` ("Number, please.") and `givingUp`
-- ("I'll try that number again later.") conveyed the jack and filed them; the
-- owner ruled they must not, so R129 reworded both and there are NO exemptions.
local Heuristic = rt.require(rt.systems.Heuristic)
local lineCount = 0
for key, line in Round.LINES do
	lineCount += 1
	local gives = Heuristic.conveyed({ speaker = { UserId = 1 }, text = line, at = 0 } :: any, all, {})
	check(`the Operator's '{key}' line gives nothing away`, #gives == 0)
end
check(`(guard) every line was scanned ({lineCount})`, lineCount >= 10)
check(
	"(control) the old greeting really did give the jack away",
	#Heuristic.conveyed({ speaker = { UserId = 1 }, text = "Number, please.", at = 0 } :: any, all, {}) > 0
)

Kit.finish()
