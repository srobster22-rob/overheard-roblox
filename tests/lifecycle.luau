--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: a game that cannot be played twice.
--
-- Until R29 there was no round lifecycle at all. `allSolved()` fired the win
-- line and returned; `allTaken()` fired the loss line and stopped the Operator.
-- Nothing reset anything. So a WIN left the monster hunting — you finished the
-- board and were then taken by something that had no idea the round was over —
-- and either ending left the server a dead lobby with the objectives still
-- solved and the connected still connected.

local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local Lifecycle = rt.require(rt.systems.Lifecycle)
type Lifecycle_Round = Lifecycle.Round
local Objectives = rt.require(rt.systems.Objectives)
local Connected = rt.require(rt.systems.Connected)

local failures = 0
local checks = 0
local function check(name: string, condition: boolean)
	checks += 1
	if not condition then
		failures += 1
		print(`  FAIL  {name}`)
	else
		print(`  ok    {name}`)
	end
end

print("a round starts playable")
local round = Lifecycle.new()
check("it begins in play", round:isPlaying())
check("and is not over", round:isOver() == false)
check("it is round one", round.number == 1)
check("a round still being played cannot restart", round:restart() == false)
check("nor is it ready to", round:readyToRestart(1000, 0) == false)

print("")
print("ending it is a transition, and only happens once")
-- Both endings are checked on a repeating tick: `allSolved` stays true forever
-- once the board is done, and `allTaken` stays true while everyone is caught.
-- Without the once-only guarantee the server announces the ending four times a
-- second, which is the shape of the bug this returns `false` to prevent.
check("finishing reports the transition", round:finish("won", 100) == true)
check("it is over", round:isOver() and round:isPlaying() == false)
check("the outcome is recorded", round.outcome == "won")
check("finishing again reports nothing", round:finish("won", 101) == false)
check("even with a different outcome", round:finish("lost", 102) == false)
check("and the first outcome stands", round.outcome == "won")

print("")
print("the intermission is waited out")
check("not ready immediately", round:readyToRestart(100, 8) == false)
check("not ready part way", round:readyToRestart(107.9, 8) == false)
check("ready exactly on time", round:readyToRestart(108, 8) == true)
check("and after", round:readyToRestart(200, 8) == true)

print("")
print("restarting")
check("restarting works once the round is over", round:restart() == true)
check("it is playable again", round:isPlaying())
check("the outcome is cleared", round.outcome == nil)
check("the round number advances", round.number == 2)
check("restarting again is refused", round:restart() == false)
check("and it is not ready to restart mid-play", round:readyToRestart(9999, 0) == false)

print("")
print("what a new round resets, and what it must NOT")
-- The lexicon surviving between rounds is the retention mechanic GAME.md is
-- built on. Resetting it would make every round a first round with strangers.
local board = Objectives.new()
local objective = board:add("board", "jack_number", "jack %s")
objective.holder = 1
local firstAnswer = objective.answer
board:submit("board", 2, firstAnswer, 0)
check("(guard) the board was finished", board:allSolved())

board:reset()
check("a new round is unsolved", board:allSolved() == false)
check("and has no holder until it is dealt", objective.holder == nil)

-- Fresh answers, or a group could retype last round's numbers.
local changed = false
for _ = 1, 40 do
	board:reset()
	if objective.answer ~= firstAnswer then
		changed = true
		break
	end
end
check("the answers are re-rolled, not reused", changed)

local line = Connected.new()
line:connect(1, 0)
line:connect(2, 0)
check("(guard) players were on the line", line:count() == 2)
line:clear()
check("a new round takes everyone off the line", line:count() == 0)
check("and they are not still connected", line:isConnected(1) == false)

print("")
print("per-round state does not cross the boundary")

-- R31. `beginRound` reset the board, the line and the Operator's position, and
-- nothing else. Two things crossed:

local Station = rt.require(rt.systems.Station)
local Operator = rt.require(rt.systems.Operator)
local Config = rt.require(rt.shared.Config)
local Round = rt.require(rt.systems.Round)

-- 1. Where each player is standing. R12 added this gate so the SERVER owns it;
--    surviving the boundary handed every player one free station.
local desk = Station.new()
desk:open(1, "breaker")
check("(guard) walking up to a station opens it", desk:accepts(1, "breaker"))
desk:clear()
check("a new round forgets where everyone was standing", desk:accepts(1, "breaker") == false)
check("...for every station, not just the one", desk:accepts(1, "board") == false)
check("...and for every player", desk:accepts(2, "breaker") == false)

-- 2. Novel terms waiting to be credited. CreditWindow (20s) is longer than the
--    intermission (8s), so a phrase said just before a round ended was credited
--    by a success in the NEXT one: 6 coinages minted across the boundary.
check(
	`(guard) the window really is longer than the intermission ({Config.CreditWindow} > {Config.IntermissionSeconds})`,
	Config.CreditWindow > Config.IntermissionSeconds
)

local secrets = { { concept = "exit", plain = { "exit" }, payload = "archive" } }
local speaker = { UserId = 1 } :: any

local leaky = Operator.new(secrets)
leaky:hear({ speaker = speaker, text = "meet me at the purple lantern", at = 100 })
leaky:credit("exit", 112)
check("(guard) a same-window success does credit it", #leaky:snapshot() > 0)

local clean = Operator.new(secrets)
clean:hear({ speaker = speaker, text = "meet me at the purple lantern", at = 100 })
clean:forgetObservations()
clean:credit("exit", 112)
check("a phrase from last round is not credited by this round's success", #clean:snapshot() == 0)

-- And the thing that must NOT be forgotten: the Lexicon itself. Carrying a
-- group's vocabulary between rounds is the retention mechanic.
local kept = Operator.new(secrets)
for i = 1, 6 do
	kept:hear({ speaker = speaker, text = "head for the purple lantern", at = i })
	kept:credit("exit", i + 0.5)
end
local before = #kept:snapshot()
check(`(guard) the group coined something ({before})`, before > 0)
kept:forgetObservations()
check("forgetting observations does not wipe the Lexicon", #kept:snapshot() == before)

print("")
print("a finished round is not listened to either")

-- R32. R29 gated CAPTURE on the round being live and nothing else, so during
-- the intermission a plain giveaway still made the Operator announce itself and
-- walk audibly at a room it could take nobody in. The whole game rests on the
-- hum meaning something; a hum that sometimes means nothing is worse than none.
--
-- Modelled against the real Operator, Pursuit and Lifecycle, wired the way the
-- server wires them, because `init.server` cannot be loaded headlessly.

local Pursuit = rt.require(rt.systems.Pursuit)
local Layout = rt.require(rt.shared.Layout)
local RoundModule = rt.require(rt.systems.Round)

local hunted = { board = Layout.boardCentre(), archive = Layout.archiveCentre() }
local dealt = RoundModule.dealSecrets(3)

-- The plain giveaway for a room that exists, taken from the real pool.
local giveaway: string? = nil
for _, secret in dealt do
	if secret.payload == "board" then
		giveaway = secret.plain[1]
	end
end
check("(guard) the real pool gave us a plain term for the board room", giveaway ~= nil)

local function serverLike(live: Lifecycle_Round)
	local op = Operator.new(dealt)
	local chase = Pursuit.new(hunted, Layout.operatorPost())
	local broadcasts = 0
	op.onUnderstood = function(_concept: string, payload: string)
		broadcasts += 1
		chase:sendTo(payload)
	end
	-- THE GATE, exactly as the server states it.
	local function feed(text: string, at: number)
		if not live:isPlaying() then
			return
		end
		op:hear({ speaker = { UserId = 1 } :: any, text = text, at = at })
	end
	return feed, chase, function()
		return broadcasts
	end
end

local playing = Lifecycle.new()
local feedLive, chaseLive, countLive = serverLike(playing)
feedLive(`patch the {giveaway}`, 1)
check("(control) while the round is live it DOES hunt", chaseLive.targetName == "board")
check("(control) and it announces", countLive() > 0)
check("(control) and you hear it", chaseLive:isAudible())

local finished = Lifecycle.new()
finished:finish("won", 100)
local feedOver, chaseOver, countOver = serverLike(finished)
feedOver(`patch the {giveaway}`, 101)
check("a finished round does not start a hunt", chaseOver.targetName == nil)
check("...and says nothing to anyone", countOver() == 0)
check("...and stays silent", chaseOver:isAudible() == false)
check("...and does not move", chaseOver.state == "idle")

-- And it starts listening again once the next round begins.
finished:restart()
feedOver(`patch the {giveaway}`, 200)
check("the next round is listened to again", chaseOver.targetName == "board")

print("")
print("a reset is COMPLETE, not merely called")

-- R37, and this is the limitation of R31's guard. That one derives the
-- per-round holders from the server source and requires `beginRound` to reset
-- each of them. `board:reset()` WAS called, so it passed — while `reset` itself
-- left the jam ledger behind, and a player who jammed a line in one round was
-- refused the CORRECT answer in the next. A guard that checks a reset HAPPENS
-- says nothing about whether it is COMPLETE.
--
-- So the field list is derived from the `Objective` type in the source, and
-- every per-round field must be named inside `reset`.

local fs = require("@lune/fs")
local LuauCode = require("./luaucode")

-- SEEDED. `Round.dealSecrets` shuffles with `math.random`, and an unseeded test
-- is a different test every run: `tests/soak.luau` stranded 6, 7 and 13 rounds
-- on three runs of identical code, and two log entries argued from single runs
-- of it. Nothing in THIS file's assertions depends on the shuffle today, which
-- is exactly why it would go unnoticed the day one does.
math.randomseed(23)

local NEWLINE = string.char(10)
local objectivesSource = fs.readFile("src/server/systems/Objectives.luau")
-- Fields are read from STRIPPED code. The first version read the raw type block
-- and picked up `purpose` -- from the words "on purpose:" in a comment inside
-- it. A comment that can invent a required field is the same class of defect
-- this project keeps meeting from the other direction, where a comment
-- satisfies a check.
local objectivesCode = LuauCode.stripNonCode(objectivesSource)
-- `stripNonCode` also removes braces (it treats them as interpolation spans),
-- so the block cannot be anchored on `{`...`}`. Slice from this type to the
-- next one instead, and read fields as tab-indented `name:` at line starts --
-- which also skips the `[number]:` inside a map type.
local typeStart = string.find(objectivesCode, "export type Objective =", 1, true)
local typeBlock = ""
if typeStart then
	local after = string.find(objectivesCode, "export type", typeStart + 20, true)
	typeBlock = string.sub(objectivesCode, typeStart, if after then after - 1 else #objectivesCode)
end
local fields: { string } = {}
for field in string.gmatch(typeBlock, NEWLINE .. "	([%a][%w_]*):") do
	table.insert(fields, field)
end
check(`(guard) read the Objective fields from source ({table.concat(fields, ", ")})`, #fields >= 6)

-- Fields that describe the objective ITSELF rather than a round's progress.
-- Each is named with its reason; the sweep requires everything else.
local STATIC: { [string]: string } = {
	id = "the station's name, fixed for the life of the board",
	concept = "what the Operator listens for, fixed with the station",
	prompt = "the sentence shown to the holder, fixed with the station",
}

local resetBody = string.match(objectivesCode, "function Objectives.reset%(.-" .. NEWLINE .. "end") or ""
check("(guard) found the reset body in live code", #resetBody > 0)

for _, field in fields do
	if STATIC[field] then
		continue
	end
	check(`reset clears '{field}'`, string.find(resetBody, field, 1, true) ~= nil)
end

-- And the behaviour, because a mention is not a clearing.
local jammed = Objectives.new()
local jammedLine = jammed:add("board", "jack_number", "jack %s")
jammedLine.holder = 1
local at = 0
for _ = 1, Config.GuessesBeforeLockout do
	at += 1
	jammed:submit("board", 2, "00", at)
end
check("(guard) the line really is jammed", (jammedLine.jammedUntil[2] or 0) > at)
check("(guard) and the misses were counted", (jammedLine.misses[2] or 0) > 0)

jammed:reset()
jammedLine.holder = 1
check("a new round forgets the jam", (jammedLine.jammedUntil[2] or 0) == 0)
check("...and the miss count", (jammedLine.misses[2] or 0) == 0)
check("...so the right answer is accepted again", jammed:submit("board", 2, jammedLine.answer, at + 1).ok == true)

print("")
print("the numbers the comments quote are measured, not asserted")

-- R45. Two dial comments made arithmetic claims that nothing checked.
-- `HeatPerCredit` said "roughly four uses burns a term" -- true only when
-- success is instant; the credit is recency-weighted, so a real group needs 5
-- to 8. `CoolPerSecond` quoted 40s to fall under the threshold and 100s to go
-- cold, which turned out to be exactly right -- but it was arithmetic in a
-- comment, and R21, R41 and R44 have all now found a promise in prose about a
-- number nothing derives.
--
-- These are measured through the real Operator so the comments cannot drift.

local secrets = { { concept = "exit", plain = { "exit" }, payload = "archive" } }
local talker = { UserId = 1 } :: any

local function usesToBurn(gap: number): number
	local op = Operator.new(secrets)
	for use = 1, 40 do
		op:hear({ speaker = talker, text = "head for the purple lantern", at = use })
		op:credit("exit", use + gap)
		for _, coinage in op:snapshot() do
			if coinage.heat >= 1 then
				return use
			end
		end
	end
	return -1
end

local instant = usesToBurn(0)
check(`(guard) a term burns at all when success is instant ({instant} uses)`, instant > 0)
check(`instant success burns in 1/HeatPerCredit uses ({instant})`, instant == math.ceil(1 / Config.HeatPerCredit))

-- The claim the comment used to get wrong: a delay costs MORE uses, and the
-- cost rises with the delay.
local slow = usesToBurn(5)
local slower = usesToBurn(10)
check(`(guard) a delayed group still burns terms ({slow}, {slower})`, slow > 0 and slower > 0)
check(`a five-second gap costs more uses than none ({slow} > {instant})`, slow > instant)
check(`and ten seconds costs more still ({slower} > {slow})`, slower > slow)

-- Cooling, measured rather than divided in a comment.
local hot = Operator.new(secrets)
for use = 1, 8 do
	hot:hear({ speaker = talker, text = "head for the purple lantern", at = use })
	hot:credit("exit", use + 0.1)
end
local peak = 0
for _, coinage in hot:snapshot() do
	if coinage.heat > peak then
		peak = coinage.heat
	end
end
check(`(guard) something is fully burned to start from ({string.format("%.2f", peak)})`, peak >= 1)

-- The BOUNDARY, measured. 1.0 - 40 * 0.01 lands exactly ON the threshold, and
-- `Heat.isUnderstood` is `>=`, so at exactly 40 seconds the term is still
-- understood. The comment said it "falls back under ActThreshold after 40s of
-- disuse"; it does so a moment later. That is the whole point of measuring a
-- number instead of dividing it in prose.
hot:cool(40 * Config.CoolPerSecond)
local atForty = 0
for _, coinage in hot:snapshot() do
	if coinage.heat > atForty then
		atForty = coinage.heat
	end
end
check(
	`at exactly 40s it is ON the threshold, still understood ({string.format("%.2f", atForty)})`,
	atForty >= Config.ActThreshold
)

hot:cool(Config.CoolPerSecond)
local pastForty = 0
for _, coinage in hot:snapshot() do
	if coinage.heat > pastForty then
		pastForty = coinage.heat
	end
end
check(
	`one second later it is under it ({string.format("%.2f", pastForty)} < {Config.ActThreshold})`,
	pastForty < Config.ActThreshold
)

hot:cool(59 * Config.CoolPerSecond)
local afterHundred = 0
for _, coinage in hot:snapshot() do
	if coinage.heat > afterHundred then
		afterHundred = coinage.heat
	end
end
check(`100s of disuse leaves nothing at all ({string.format("%.2f", afterHundred)})`, afterHundred <= 0)

-- The relationship the comment rests on, stated so a dial change moves both.
check(
	`a burned term outlives one intermission ({Config.IntermissionSeconds * Config.CoolPerSecond} lost)`,
	Config.IntermissionSeconds * Config.CoolPerSecond < 1
)

print("")
print("the learning gap, pinned")

-- R46. The Operator can never learn a coinage. Measured over a simulated
-- session — twelve sentences a minute, an objective solved every twenty seconds
-- — nothing ever reaches ActThreshold, and by minute three the whole vocabulary
-- has cooled to nothing. The structure behind it:
--
--   credits a round supplies    = one per objective = 2
--   credited uses to burn       = 4 at best, 5-8 in practice
--   heat fully cold after       = 100 seconds, shorter than a round
--
-- So the red state is unreachable and "your language decaying under you" — the
-- mechanic on GAME.md's first page — never happens.
--
-- THESE CHECKS PIN THE GAP RATHER THAN ASSERT IT IS FINE. Closing it is a
-- design decision (more credits, more heat, or slower cooling — three different
-- games) and belongs to the owner. If one of these fails, the numbers have
-- moved: re-read this entry rather than adjusting the check.

local serverSource = fs.readFile("src/server/init.server.luau")
local serverCode = LuauCode.stripNonCode(serverSource)

local creditSites = 0
local from = 1
while true do
	local first, last = string.find(serverCode, "operator:credit", from, true)
	if not first then
		break
	end
	from = last + 1
	creditSites += 1
end
check(`(pinned) the Operator is credited from exactly one place ({creditSites})`, creditSites == 1)

local stations = 0
for _ in RoundModule.STATIONS do
	stations += 1
end
check(`(pinned) a round offers one credit per station ({stations} stations)`, stations == 2)

-- The other side of the gap, measured through the real Operator rather than
-- divided from the dial.
local gapSecrets = { { concept = "exit", plain = { "exit" }, payload = "archive" } }
local gapTalker = { UserId = 1 } :: any
local function burnCost(gap: number): number
	local op = Operator.new(gapSecrets)
	for use = 1, 40 do
		op:hear({ speaker = gapTalker, text = "head for the purple lantern", at = use })
		op:credit("exit", use + gap)
		for _, coinage in op:snapshot() do
			if coinage.heat >= 1 then
				return use
			end
		end
	end
	return -1
end
local best = burnCost(0)
check(`(pinned) burning a coinage takes {best} credited uses at best`, best == 4)
check(`(pinned) which is more than a round supplies ({best} > {stations})`, best > stations)

-- And the heat that IS gained does not survive to the next round's credits.
local roundish = 100
check(
	`(pinned) heat is fully cold after {roundish}s, and a round is longer than that`,
	1 / Config.CoolPerSecond <= roundish
)

-- A session's worth of ordinary talk reaches nothing. This is the finding in one
-- line, run against the real modules.
local session = Operator.new(gapSecrets)
local clock = 0
for minute = 1, 3 do
	for i = 1, 12 do
		clock += 5
		session:hear({ speaker = gapTalker, text = "meet me by the purple lantern", at = clock })
		if i % 4 == 0 then
			session:credit("exit", clock + 1)
		end
	end
	session:decay(clock)
	local _ = minute
end
local hottest = 0
for _, coinage in session:snapshot() do
	if coinage.heat > hottest then
		hottest = coinage.heat
	end
end
check(
	`(pinned) three minutes of ordinary talk leaves nothing understood ({string.format("%.2f", hottest)} < {Config.ActThreshold})`,
	hottest < Config.ActThreshold
)

print("")
print("a lost round says it was lost")

-- R64. A mutation sweep broke twelve rules in `src/` one at a time and ran the
-- whole suite after each. Eleven were caught. This one was not: making
-- `finish("lost")` record NO outcome passed all ~1,200 checks.
--
-- This file pins the won outcome twice and pins nil after a restart, and never
-- once pins the lost one -- while R18's whole round was "the round can now be
-- lost, not only won". The client picks its sentence from this field, so a lost
-- round would have told players "The round is over." instead of "Everyone was
-- put on the line.": the fact that the monster took everybody, dropped.

local ended = Lifecycle.new()
check("(guard) it starts playing", ended:isPlaying())
check("it can be lost", ended:finish("lost", 10))
check("...and stops playing", not ended:isPlaying())
check("...and RECORDS that it was lost", ended.outcome == "lost")
check("...which is not the won outcome", ended.outcome ~= "won")

-- Both outcomes are reachable from a fresh round and each records its own name.
-- Swept from the type rather than typed twice, so a third outcome cannot be
-- added and left unrecorded.
local OUTCOMES = { "won", "lost" }
for _, outcome in OUTCOMES do
	local fresh = Lifecycle.new()
	check(`(guard) a fresh round can finish '{outcome}'`, fresh:finish(outcome :: any, 5))
	check(`'{outcome}' is recorded as itself`, fresh.outcome == outcome)
end

-- And a restart clears it, whichever way the round went. R31's boundary: an
-- outcome that outlives its round is a panel telling the next round's players
-- how the last one ended.
for _, outcome in OUTCOMES do
	local cycled = Lifecycle.new()
	cycled:finish(outcome :: any, 5)
	check(
		`(guard) '{outcome}' is ready to restart`,
		cycled:readyToRestart(5 + Config.IntermissionSeconds + 1, Config.IntermissionSeconds)
	)
	check(`the round restarts after '{outcome}'`, cycled:restart())
	check(`...and '{outcome}' is forgotten`, cycled.outcome == nil)
end

print("")
print("the Operator's signals fire when, and only when, something changed (R99)")

-- R99 mutation sweep. Four survivors in Operator, all player-facing:
-- `onBurned` makes it say "I'm connecting you now." to everyone and rebroadcast
-- the Lexicon; `decay`'s return drives the Lexicon broadcast every DecaySeconds;
-- and Config documents a burned term cooling to EXACTLY ActThreshold.
do
	local pool = Round.dealSecrets(99)
	local secret = pool[1]
	local op = Operator.new({ secret })
	local burnsOf: { [string]: number } = {}
	op.onBurned = function(c)
		burnsOf[c.phrase] = (burnsOf[c.phrase] or 0) + 1
	end
	for t = 1, 7 do
		op:hear({ speaker = { UserId = 1 } :: any, text = "zorp glimmer", at = t * 100 })
		op:credit(secret.concept, t * 100)
	end
	local zorp = nil
	for _, c in op.lexicon do
		if c.phrase == "zorp" then
			zorp = c
		end
	end
	check("(guard) the codeword burned", zorp ~= nil and zorp.heat >= 1)
	local burned, repeats = 0, 0
	for _, c in op.lexicon do
		if c.heat >= 1 then
			burned += 1
			if burnsOf[c.phrase] ~= 1 then
				repeats += 1
			end
		end
	end
	check(`every burned phrase announced exactly ONCE ({burned} burned, {repeats} wrong)`, burned >= 1 and repeats == 0)

	check("cooling by nothing reports no change", op:cool(0) == false)
	check("cooling an empty lexicon reports no change", Operator.new({ secret }):cool(1) == false)
	check("(control) cooling a hot lexicon reports a change", op:cool(0.1) == true)

	local edge = Operator.new({ secret })
	table.insert(
		edge.lexicon,
		{ phrase = "zorp", concept = secret.concept, heat = Config.ActThreshold, sightings = 4, coinedBy = 1 } :: any
	)
	local acted = 0
	edge.onUnderstood = function()
		acted += 1
	end
	edge:hear({ speaker = { UserId = 1 } :: any, text = "zorp", at = 0 })
	check("a codeword sitting EXACTLY on ActThreshold is still understood", acted == 1)
end

print("")
print("the loss condition, RUN rather than grepped (R108)")

-- R108. This rule lived in init.server, where the suite could only grep it; a
-- sweep flipped every clause of the game's loss condition without a failure.
do
	local function setup(seenBy: { number })
		local b = Objectives.new()
		local o = b:add("board", "jack_number", "Patch line to jack %s")
		o.holder = seenBy[1]
		for _, id in seenBy do
			o.seenBy[id] = true
		end
		return b, o, Connected.new()
	end

	local b, _, l = setup({ 1 })
	check("nobody present is not a loss", Lifecycle.nobodyCanWin({}, b, l) == false)

	b, _, l = setup({ 1 })
	l:connect(1, 0)
	l:connect(2, 0)
	check("everyone present taken is a loss", Lifecycle.nobodyCanWin({ 1, 2 }, b, l) == true)

	local o
	b, o, l = setup({ 1 })
	o.solved = true
	l:connect(1, 0)
	l:connect(2, 0)
	check("...unless the board is already won", Lifecycle.nobodyCanWin({ 1, 2 }, b, l) == false)

	b, _, l = setup({ 1 })
	l:connect(2, 0)
	check("a survivor who has SEEN the only line is stranded: a loss", Lifecycle.nobodyCanWin({ 1, 2 }, b, l) == true)

	b, _, l = setup({ 1 })
	l:connect(2, 0)
	check(
		"(control) with someone able who has NOT seen it, play goes on",
		Lifecycle.nobodyCanWin({ 1, 2, 3 }, b, l) == false
	)

	b, _, l = setup({ 1 })
	check("a solo server nobody has touched does not lose and loop", Lifecycle.nobodyCanWin({ 1 }, b, l) == false)
end

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
