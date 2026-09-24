--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: a message that is addressed to everybody
-- being rendered as if it were addressed to you.
--
-- The keypad has one red line under its input. Until R10 the only writer of it
-- was the `Heard` remote's detail field â€” and `Heard` is the Operator's voice,
-- broadcast to the whole server with the concept id or room name in `detail`.
-- So a player standing at a keypad saw a red `jack_number` in the slot that
-- says "that line is jammed - wait 20s", because somebody ELSE had spoken.
--
-- Every existing suite passed, because every existing suite exercises the path
-- a single player takes, and with one player this is unreachable: you cannot be
-- typing at a keypad and be the one talking. With two it is the main path.
--
-- These checks are therefore about WIRING, and they read the real source rather
-- than a hand-kept list, through the same lexer `tests/config.luau` uses so a
-- comment or a string that mentions a name cannot satisfy them.

local fs = require("@lune/fs")

local Harness = require("./harness")
local LuauCode = require("./luaucode")
local Sources = require("./sources")

local rt = Harness.build()

local Kit = require("./kit")
local check = Kit.check

local clientSource = fs.readFile("src/client/init.client.luau")
local serverSource = Sources.server()
local remotesSource = fs.readFile("src/shared/Remotes.luau")

local clientCode = LuauCode.stripNonCode(clientSource)
local serverCode = LuauCode.stripNonCode(serverSource)

-- The rule itself ----------------------------------------------------------
-- Pure, so it can be swept exhaustively rather than sampled.

-- Loaded through pcall on purpose. A shared module the harness has not adopted
-- makes `require` throw, which aborts this file with a runtime error instead of
-- a named failure -- and a crash reads like a broken test, not a broken game.
print("Keypad.accepts")
local loaded, Keypad = pcall(function()
	return rt.require(rt.shared.Keypad)
end)
check("Shared.Keypad loads (the harness adopts it)", loaded == true)
if not loaded then
	print(`  (require said: {Keypad})`)

	Kit.finish()
end

check("a rejection for the open station is shown", Keypad.accepts("board", "board") == true)
check("a rejection for the other station is dropped", Keypad.accepts("board", "breaker") == false)
check("no keypad open and no station named is dropped (R102)", Keypad.accepts(nil, nil) == false)

-- R109: the Submit remote's payload check, run rather than grepped.
check("a real submission is valid", Keypad.validSubmission("board", "42"))
check("a non-string id is refused", not Keypad.validSubmission(7, "42"))
check("a non-string value is refused", not Keypad.validSubmission("board", 42))
check("nil is refused", not Keypad.validSubmission(nil, nil))
check("a value over the cap is refused", not Keypad.validSubmission("board", string.rep("4", Keypad.MAX_VALUE + 1)))
check("(control) a value AT the cap is valid", Keypad.validSubmission("board", string.rep("4", Keypad.MAX_VALUE)))
check(
	"an id over the cap is refused (it had none before R109)",
	not Keypad.validSubmission(string.rep("b", Keypad.MAX_ID + 1), "42")
)
check("(control) an id AT the cap is valid", Keypad.validSubmission(string.rep("b", Keypad.MAX_ID), "42"))
check("an empty id is refused", not Keypad.validSubmission("", "42"))

-- R120: the client's two keypad decisions, run rather than grepped.
local solvedHere = { { id = "board", solved = true }, { id = "breaker", solved = false } }
check("solving the open station closes its keypad", Keypad.closesOn("board", solvedHere))
check("solving the OTHER station does not", not Keypad.closesOn("breaker", solvedHere))
check("an unsolved open station stays open", not Keypad.closesOn("breaker", { { id = "breaker", solved = false } }))
check("no keypad open, nothing to close", not Keypad.closesOn(nil, solvedHere))
check("a typed code at an open keypad is sent", Keypad.sends("42", "board"))
check("an empty box is not sent", not Keypad.sends("", "board"))
check("nothing is sent with no keypad open", not Keypad.sends("42", nil))
check(
	"the client asks Keypad.sends before firing",
	string.find(clientSource, "Keypad.sends(value, openStation)", 1, true) ~= nil
)
check(
	"the client asks Keypad.closesOn on every board push",
	string.find(clientSource, "Keypad.closesOn(openStation, entries)", 1, true) ~= nil
)
check("nothing is shown when no keypad is open", Keypad.accepts(nil, "board") == false)
check("a rejection naming no station is dropped", Keypad.accepts("board", nil) == false)
check("both nil is dropped", Keypad.accepts(nil, nil) == false)

-- Sweep the whole matrix rather than the four cases above, so a future
-- implementation that special-cases one pair cannot slip through. The guard is
-- the accepted count: if `accepts` were rewritten to return false always, the
-- per-cell checks would all still pass and only this would fail.
local names = { "board", "breaker", "vault" }
local accepted = 0
for _, open in names do
	for _, msg in names do
		check(`accepts('{open}','{msg}') is exactly (open == msg)`, Keypad.accepts(open, msg) == (open == msg))
		if Keypad.accepts(open, msg) then
			accepted += 1
		end
	end
	check(`accepts('{open}', nil) is false`, Keypad.accepts(open, nil) == false)
	check(`accepts(nil,'{open}') is false`, Keypad.accepts(nil, open) == false)
end
check("the sweep actually accepted something", accepted == #names)

-- Remote names -------------------------------------------------------------
-- `Remotes.get` yields forever on an undeclared name: the wire is silently dead
-- and nothing errors. Both directions, off the real source.

print("")
print("remote names")
local declared: { [string]: boolean } = {}
local declaredCount = 0
-- Whitespace-tolerant: stylua wraps this declaration onto two lines as soon as
-- the list gets long enough, and a pattern that demanded `= {` on one line
-- failed the whole block the moment an eighth remote was added. A guard that
-- breaks on reformatting is a guard someone loosens later.
local nameList = string.match(remotesSource, "local REMOTE_NAMES%s*=%s*{(.-)}") or ""
for name in string.gmatch(nameList, '"([%a][%w_]*)"') do
	declared[name] = true
	declaredCount += 1
end
check("REMOTE_NAMES was found in Remotes.luau", declaredCount > 0)

-- Read from RAW source: the lexer strips string bodies, and these names ARE
-- string bodies. A commented-out call would produce a loud false failure here,
-- never a false pass.
local used: { [string]: boolean } = {}
local usedCount = 0
for _, source in { clientSource, serverSource } do
	for name in string.gmatch(source, 'Remotes%.get%("([%a][%w_]*)"%)') do
		used[name] = true
		usedCount += 1
	end
end
check("Remotes.get call sites were found", usedCount >= 6)
for name in used do
	check(`remote '{name}' is used and REMOTE_NAMES declares it`, declared[name] == true)
end
for name in declared do
	check(`remote '{name}' is declared and something in src/ uses it`, used[name] == true)
end
check("'Rejected' exists at all", declared["Rejected"] == true and used["Rejected"] == true)

-- The channel separation ---------------------------------------------------
-- Extracted from LIVE CODE. Each block is anchored on a top-level `local
-- function` and its column-0 `end`, and each has a control the block is known
-- to contain, so a pattern that stops matching fails rather than passing empty.

print("")
print("the keypad is not painted by a broadcast")
local function body(code: string, fn: string): string
	return string.match(code, `\nlocal function {fn}%(.-\nend`) or ""
end

local heardBody = body(clientCode, "onHeard")
check("the Heard handler was found in live code", #heardBody > 0)
check("...and it is the one that speaks (control)", string.find(heardBody, "said", 1, true) ~= nil)
-- The defect, stated: the Operator's voice must not be able to write the keypad.
check("the Heard handler never touches the keypad status", string.find(heardBody, "status", 1, true) == nil)

local rejectedBody = body(clientCode, "onRejected")
check("the Rejected handler was found in live code", #rejectedBody > 0)
check("...and it writes the keypad (control)", string.find(rejectedBody, "status.Text", 1, true) ~= nil)
check(
	"...and it is gated on Keypad.accepts, so a stale station cannot paint",
	string.find(rejectedBody, "Keypad.accepts", 1, true) ~= nil
)
check(
	"the client actually requires Keypad",
	string.find(clientCode, "require(ReplicatedStorage.Shared.Keypad)", 1, true) ~= nil
)

-- Sweep EVERY write to the keypad status line, not just the ones above, and
-- require each to sit inside a block allowed to write it. A fourth writer added
-- later - from a broadcast handler, say - fails here by position.
local allowed: { { first: number, last: number, name: string } } = {}
for _, fn in { "closeBoard", "onOpenBoard", "onRejected" } do
	local b = body(clientCode, fn)
	if #b > 0 then
		local first = string.find(clientCode, b, 1, true)
		if first then
			table.insert(allowed, { first = first, last = first + #b, name = fn })
		end
	end
end
check("all three allowed writers were located", #allowed == 3)

local writes = 0
local strays = 0
local from = 1
while true do
	local first, last = string.find(clientCode, "status.Text", from, true)
	if not first then
		break
	end
	from = last + 1
	writes += 1
	local inside = false
	for _, range in allowed do
		if first >= range.first and first < range.last then
			inside = true
		end
	end
	if not inside then
		strays += 1
	end
end
check("keypad writes were found to sweep (guard)", writes >= 3)
check(`every write to the keypad status sits in an allowed handler ({writes} found)`, strays == 0)

-- Shared modules -----------------------------------------------------------
-- A shared module the harness does not adopt cannot be required by any test.

print("")
print("every module is reachable from tests")
-- The harness adopts every module in src/shared and src/server/systems from the
-- folders themselves, so none can ship unhammered by being left off a list.
local reachable = 0
for _, dir in { { "src/shared", rt.shared }, { "src/server/systems", rt.systems } } do
	for _, entry in fs.readDir(dir[1]) do
		local name = string.match(entry, "^([%a][%w_]*)%.luau$")
		if name then
			reachable += 1
			check(
				`{dir[1]}/{name} is reachable from tests`,
				pcall(function()
					return (dir[2] :: any)[name]
				end)
			)
		end
	end
end
check(`modules were found on disk (guard: {reachable})`, reachable >= 20)

-- THE STATION A PLAYER IS AT ------------------------------------------------
-- Second instance of this file's class, and the one that was on the wrong
-- MACHINE rather than the wrong channel: `openStation` was a local in the
-- client, and the server accepted whatever station id came back on `Submit`.

print("")
print("Station: the server's own copy of where you are")
local sLoaded, Station = pcall(function()
	return rt.require(rt.systems.Station)
end)
check("Server.systems.Station loads (the harness adopts it)", sLoaded == true)
if not sLoaded then
	print(`  (require said: {Station})`)
	Kit.finish()
end

local A, B = 100, 200
local desk = Station.new()
check("a player who has reached nothing is at nothing", desk:openedBy(A) == nil)
check("and is accepted at no station", desk:accepts(A, "board") == false)
desk:open(A, "board")
check("reaching a station records it", desk:openedBy(A) == "board")
check("and that station is accepted", desk:accepts(A, "board") == true)
check("but the other one is not", desk:accepts(A, "breaker") == false)
-- The whole point: one player walking up to a keypad must not seat ANOTHER
-- player at it. This is the shape the round is about.
check("it does not seat a different player", desk:accepts(B, "board") == false)
desk:open(B, "breaker")
check("two players hold two different stations", desk:openedBy(A) == "board" and desk:openedBy(B) == "breaker")
check("and neither can act at the other's", desk:accepts(A, "breaker") == false and desk:accepts(B, "board") == false)
-- One slot per player: walking to the breaker gives up the switchboard, so the
-- corridor still costs something. Without this a player could touch both prompts
-- once and then clear the whole board from one room.
desk:open(A, "breaker")
check("reaching a second station gives up the first", desk:accepts(A, "board") == false)
check("and seats them at the new one", desk:accepts(A, "breaker") == true)
desk:forget(A)
check("forgetting a player clears their station", desk:openedBy(A) == nil)
check("and leaves everyone else seated", desk:openedBy(B) == "breaker")

-- Exhaustive, with a count guard: `accepts` rewritten to return false always
-- would pass every per-cell check above and only this would catch it.
local sweepDesk = Station.new()
local stationNames = { "board", "breaker", "vault" }
local players = { 1, 2, 3 }
for i, uid in players do
	sweepDesk:open(uid, stationNames[i])
end
local seated = 0
for i, uid in players do
	for j, name in stationNames do
		check(`accepts(player {i}, '{name}') is exactly (i == j)`, sweepDesk:accepts(uid, name) == (i == j))
		if sweepDesk:accepts(uid, name) then
			seated += 1
		end
	end
end
check(`the sweep accepted exactly one station per player (guard, {seated})`, seated == #players)

-- WHAT THE OPERATOR STILL HAS ON FILE --------------------------------------
--
-- Third of the same family, and the one that reached the player's eyes rather
-- than their ear. `snapshot` is replicated to every client on every lexicon
-- change and `renderLexicon` draws EVERY entry it is handed, with no heat
-- floor. So while `cool` left a fully-forgotten coinage sitting in the register
-- at zero, the Lexicon panel listed words at "0%" -- words the Operator cannot
-- act on, by its own rule -- in the same list as the words that get you caught.
-- The server had forgotten and the player's screen had not. It only ever grew:
-- one 230-character message offers 79 candidate terms and one solve wrote them
-- all in.
--
-- Behavioural proof is in `TestOperator` (9-12). These are the two structural
-- properties a rewrite of that loop would silently lose.
print("")
print("a forgotten coinage leaves the register")

local operatorCode = LuauCode.stripNonCode(fs.readFile("src/server/systems/Operator.luau"))
local coolBody = string.match(operatorCode, "function Operator%.cool.-\nend")
check("the cool function was found (guard)", coolBody ~= nil)
check(
	"cooling removes a coinage from the lexicon",
	coolBody ~= nil and string.find(coolBody :: string, "table.remove(self.lexicon", 1, true) ~= nil
)
-- Backwards, or `table.remove` shifts the tail and the loop steps over the
-- entry after each one it drops -- half the dead terms would survive.
check(
	"and walks the register backwards so removal cannot skip an entry",
	coolBody ~= nil and string.find(coolBody :: string, "for i = #self.lexicon, 1, -1 do", 1, true) ~= nil
)
-- THE ONE A CARELESS REWRITE GETS WRONG: an entry already resting at zero
-- cools to zero, so `cooled ~= c.heat` is false for it. Tucking the removal
-- inside that branch leaves behind exactly the entries this exists to clear,
-- and every behavioural check that starts from a WARM coinage still passes.
local movedBranch = coolBody and string.match(coolBody :: string, "if cooled ~= c%.heat then.-\n\t\tend")
check("the heat-moved branch was found (guard)", movedBranch ~= nil)
check(
	"the removal is NOT gated on the heat having moved this tick",
	movedBranch ~= nil and string.find(movedBranch :: string, "table.remove", 1, true) == nil
)

-- A suite file that is never run ships unchecked while the check still passes.
-- tools/check runs every file in tests/ that no other test requires, so the one
-- way left to lose a suite is for another test to require it, which files it
-- as a helper. The helpers are therefore named here.
print("every test file is actually run")
local Suites = require("../tools/suites")
local suites = Suites.list()
local helpers = Suites.helpers()
check(`the check command finds the suites (guard: {#suites})`, #suites > 20)
local helperNames = {}
for name in helpers do
	table.insert(helperNames, name)
end
table.sort(helperNames)
check(
	`the only helpers are the harness, the checker, luaucode and sources ({table.concat(helperNames, ", ")})`,
	table.concat(helperNames, ",") == "harness,kit,luaucode,sources"
)
for _, entry in fs.readDir("tests") do
	local stem = string.match(entry, "^(.+)%.luau$")
	if stem and not helpers[stem] then
		check(`tests/{stem}.luau is run by tools/check`, table.find(suites, stem) ~= nil)
	end
end

print("")
print("the round can be LOST, not only won")

-- R16 wrote `Connected.allTaken` and nothing ever called it, so the Operator
-- could take every player and the round would just sit there: board still open,
-- nothing said, no way to finish. A capability written and never wired reads as
-- a shipped feature in the log and is invisible to every other test, so the
-- wiring itself is asserted here rather than the logic (which tests/connected
-- already covers).

local serverSource = Sources.server()
local serverCode = LuauCode.stripNonCode(serverSource)

-- Three opposite events must not share one sentence. `completed` and `taken`
-- were already split for exactly this reason; `lost` must not undo it.
-- Read from Round.LINES, the table the server says them from.
local said: { [string]: string } = rt.require(rt.systems.Round).LINES
check("`lost` exists as a line", said.lost ~= nil and #said.lost > 0)
check("`lost` is not the same sentence as `completed`", said.lost ~= said.completed)
check("`lost` is not the same sentence as `taken`", said.lost ~= said.taken)
check("`lost` is not the same sentence as `onTheLine`", said.lost ~= said.onTheLine)

-- R26 added a fifth. Reusing `busy` -- the keypad's private rejection -- would
-- have repeated exactly the collision R10 and R13 each had to unpick.
check("`givingUp` exists as a line", said.givingUp ~= nil and #said.givingUp > 0)
for _, other in { "busy", "taken", "completed", "lost", "onTheLine", "understood", "connecting", "greeting" } do
	check(`\`givingUp\` is not the same sentence as \`{other}\``, said.givingUp ~= said[other])
end

-- Newline built with string.char rather than an escape: this repo's tooling has
-- twice collapsed a backslash in a patch and turned "\n" inside a Luau string
-- into a real line break, producing "Malformed string".
local NL = string.char(10)

print("")
print("the entry script's glue, and what a new round resets")

-- The entry script's glue cannot run headlessly (tests/exchange runs the flow
-- it connects), so these facts about it are read from its source.
local entry = LuauCode.stripNonCode(fs.readFile("src/server/init.server.luau"))
check("each beat runs under a guard", string.find(entry, "Guard.run( , exchange.beat)", 1, true) ~= nil)
check("the tick is paced by a dial, not a literal", string.find(entry, "task.wait(Config.TickSeconds)", 1, true) ~= nil)
check(
	"every player's chat reaches the flow through ChatFeed",
	string.find(entry, "ChatFeed.new(Guard.wrap( , exchange.hearChat)):follow(Players)", 1, true) ~= nil
)

local beginBody = string.match(serverCode, "local function beginRound%(%).-" .. NL .. "end") or ""
check("(guard) found beginRound", #beginBody > 0)

-- R31, and this is the CLASS rather than the instances. `beginRound` reset
-- `board`, `line` and `pursuit` and nothing else, so two pieces of per-round
-- state crossed the boundary: `desk` (which keypad each player walked up to)
-- let a player submit to a station from the corridor a round later, bypassing
-- R12's gate; and the Operator's pending observations were credited by a
-- success in the NEXT round, because CreditWindow is 20s against an 8s
-- intermission.
--
-- The list of holders is DERIVED from the server source, not restated here, so
-- the next `local x = Module.new()` added to this file has to be handled or
-- this fails. A hand-kept list would have passed while the new one leaked.
-- `Instance.new` is excluded: an Instance is a world object, not a round's
-- worth of state. The first draft of this guard swept it in and failed on
-- `spawnPad`, which is a SpawnLocation and has nothing to reset.
local holders: { string } = {}
for name, module in string.gmatch(serverCode, "local ([%a][%w_]*) = (%u[%w_]*)%.new%(") do
	if module ~= "Instance" then
		table.insert(holders, name)
	end
end
check(`(guard) found the per-round holders ({table.concat(holders, ", ")})`, #holders >= 4)

-- Two exemptions, each named with its reason.
-- `round` is the lifecycle itself: the TICK restarts it, and beginRound runs
-- after that, so it is handled by construction rather than reset here.
-- `broadcastLexicon` (R139) is a sender, not a round's state: it remembers what
-- the phrases on the Lexicon panel filtered to, and the Lexicon deliberately
-- outlives the round (GAME.md's retention engine). Clearing it each round would
-- only send every phrase back through the filter.
local EXEMPT: { [string]: boolean } = { round = true, broadcastLexicon = true }

for _, name in holders do
	if EXEMPT[name] then
		continue
	end
	check(`a new round resets '{name}'`, string.find(beginBody, name .. ":", 1, true) ~= nil)
end

-- R55, and this is the CLASS rather than the instance. `CLAUDE.md` requires
-- per-player state to be cleaned on `PlayerRemoving` or it leaks across rounds.
-- R53 swept `init.server.luau` against that rule BY HAND and found it clean --
-- and R54, the very next round, added `warned` beside `lastSubmit` with no
-- cleanup at all. A rule checked by reading is a rule checked once.
--
-- The list is DERIVED from the server source, so the next per-player table
-- added has to be handled or this fails. A hand-kept list would have passed
-- while the new one leaked, which is exactly what happened.
print("")
print("every per-player table is cleaned when a player leaves")

-- Read from the comment-stripped source, line by line. `stripNonCode` blanks
-- table braces, so the declaration reads `local warned:   [number]: boolean`
-- there. Anchored at the start of a line so locals INSIDE a function -- the
-- `out` accumulator in `livePositions`, which is a temporary and has nothing to
-- clean -- are not swept in.
local perPlayer: { string } = {}
for line in string.gmatch(serverCode, "[^" .. NL .. "]+") do
	local name = string.match(line, "^local ([%a][%w_]*):%s+%[number%]:")
	if name then
		table.insert(perPlayer, name)
	end
end
-- R115: `shown` moved into the Supervisor (its forget clears it; run in
-- tests/silence); R116 moved `lastSubmit` into the Station desk. The server
-- now keeps NO per-player table of its own -- that state lives in modules whose
-- `forget` clears it (run in tests/silence and tests/objectives; tests/exchange
-- runs the leave path). A per-player table added to the flow fails the check
-- below, and the parser is proven on a synthetic line so an empty list cannot
-- mean "blind".
check(
	"(guard) the per-player table reader recognises one",
	string.match(
		LuauCode.stripNonCode("local probe: { [number]: number } = {}" .. NL),
		"^local ([%a][%w_]*):%s+%[number%]:"
	) == "probe"
)
check(`the server keeps no per-player table of its own ({table.concat(perPlayer, ", ")})`, #perPlayer == 0)

-- R55's fix, checked in the PRODUCT rather than in the module.
--
-- `tests/pursuit.luau` proves `sendTo` reports whether the call really went
-- through. That is not the same as the server ASKING. R48 and R49 were both
-- this exact mistake -- a guard that checked the call existed, not that its
-- answer was used -- and the first version of this round's proof repeated it:
-- disabling the early return in the dispatch left the whole suite green.
--
-- So this reads the dispatch and requires the ORDER: ask, bail out if the call
-- was only queued, and only then forgive the player and say the line.
print("")
print("the Supervisor only speaks when the call really went through")

-- R110: the dispatch moved to Supervisor.putThrough (RUN in tests/silence);
-- the order is still read there, and the line is still said by the server.
local supervisorCode = LuauCode.stripNonCode(fs.readFile("src/server/systems/Supervisor.luau"))
local dispatchBody = string.match(supervisorCode, "function Supervisor.putThrough%(.-" .. NL .. "end") or ""
check("(guard) found the dispatch", #dispatchBody > 0)

local askedAt = string.find(dispatchBody, "onItsWay = pursuit:sendTo", 1, true)
check("it asks whether the call went through", askedAt ~= nil)

local bailedAt = string.find(dispatchBody, "if not onItsWay then", 1, true)
check("...and bails out when it did not", bailedAt ~= nil)

local forgaveAt = string.find(dispatchBody, "self:called", 1, true)
local saidAt = string.find(dispatchBody, "not alreadyComing", 1, true)
check("(guard) it does forgive the player somewhere", forgaveAt ~= nil)
check("(guard) ...and does say the line somewhere", saidAt ~= nil)

if askedAt and bailedAt and forgaveAt and saidAt then
	check("the bail-out comes after the question", bailedAt > askedAt)
	check("a queued call never forgives the player", forgaveAt > bailedAt)
	check("...and is never announced", saidAt > bailedAt)
	-- And the announcement is gated a second time, so a trip already under way
	-- to that room punishes the silence without saying it twice.
	-- R110: read BEFORE sendTo retargets, or every call would look like news.
	local alreadyAt = string.find(dispatchBody, "local alreadyComing = pursuit.targetName == room", 1, true)
	check("a trip already under way is not announced again", alreadyAt ~= nil and alreadyAt < askedAt)
end

-- (control) the reader must be able to fail: a phrase that is not in the
-- dispatch must not be found in it.
check(
	"(control) the reader is not matching everything",
	string.find(dispatchBody, "if not neverWritten then", 1, true) == nil
)

-- R56, and this is the CLASS. `Round.LINES` is the Operator's script; a line in
-- it that nothing ever says is a dead string, the same shape as the dead config
-- dials R6 built its guard for. This round moved the Supervisor's warning off
-- the Operator's channel and left `stillThere` behind, and the suite passed at
-- 264/264 with it sitting there unsaid.
--
-- Swept from the source in both directions, never from a list here.
print("")
print("every line the Operator has is a line it can say")

-- The KEYS are read from the raw source, because `stripNonCode` drops string
-- bodies by design -- a line's text is a string, so the table is invisible in
-- the stripped copy. Comment lines are skipped explicitly instead, which is the
-- part stripping was buying.
local roundSource = fs.readFile("src/server/systems/Round.luau")
local inLines = false
local named, unsaid = 0, {}
-- And `Round.readBack`, which is what says `understood` now, with a heard code
-- in front. Only that function, not the whole module: anything else in Round
-- naming a line would be counted as saying it.
local readBackBody = string.match(LuauCode.stripNonCode(roundSource), "function Round%.readBack%(.-\nend") or ""
check("(guard) Round.readBack was found", #readBackBody > 0)
local everything = serverCode .. LuauCode.stripNonCode(fs.readFile("src/client/init.client.luau")) .. readBackBody
for line in string.gmatch(roundSource, "[^" .. NL .. "]+") do
	if string.find(line, "Round.LINES = {", 1, true) then
		inLines = true
	elseif inLines and string.match(line, "^}") then
		inLines = false
	elseif inLines and not string.match(line, "^%s*%-%-") then
		local key = string.match(line, '^%s*([%a][%w_]*) = "')
		if key then
			named += 1
			-- Whether it is SAID is asked of the stripped code, where a comment
			-- naming a line cannot answer for it. R4, R6 and R8 each shipped a
			-- guard a mention could satisfy.
			if not string.find(everything, "LINES." .. key, 1, true) then
				table.insert(unsaid, key)
			end
		end
	end
end
check(`(guard) the Operator has a script ({named} lines)`, named >= 6)
check(`every line is said somewhere ({#unsaid} unsaid)`, #unsaid == 0)
if #unsaid > 0 then
	print(`        never said: {table.concat(unsaid, ", ")}`)
end
-- R75, and this is the CLASS. Three of these eleven lines carry a comment
-- stating, by hand, that they must not collide with one specific other line:
-- `givingUp` vs `busy` ("reusing it here would repeat exactly the collision
-- R10 and R13 each had to unpick"), `lost` vs `completed`/`taken` ("three
-- different events must not share one sentence"), and `traced` vs
-- `connecting` ("the whole point of the Supervisor is that this one is for
-- saying nothing"). R64 built a guard for exactly ONE pair of these eleven --
-- the two Lifecycle outcome texts -- after a mutation sweep found a lost round
-- could go unannounced. Nothing swept the other nine against each other, or
-- against those two, all at once.
--
-- Every value in Round.LINES, read straight from the source, pairwise.
print("")
print("no two of the Operator's own lines read the same")

local allLines: { [string]: string } = {}
local inLinesBlock = false
for line in string.gmatch(roundSource, "[^" .. NL .. "]+") do
	if string.find(line, "Round.LINES = {", 1, true) then
		inLinesBlock = true
	elseif inLinesBlock and string.match(line, "^}") then
		inLinesBlock = false
	elseif inLinesBlock and not string.match(line, "^%s*%-%-") then
		local key, text = string.match(line, '^%s*([%a][%w_]*) = "([^"]*)"')
		if key then
			allLines[key] = text
		end
	end
end
local lineCount = 0
for _ in allLines do
	lineCount += 1
end
check(`(guard) the Operator's whole script was read ({lineCount} lines)`, lineCount >= 8)

local byText: { [string]: string } = {}
local collidingPairs: { string } = {}
for key, text in allLines do
	local earlier = byText[text]
	if earlier then
		table.insert(collidingPairs, `{earlier} = {key}`)
	else
		byText[text] = key
	end
end
check(`no two lines share a sentence ({#collidingPairs} collisions)`, #collidingPairs == 0)
if #collidingPairs > 0 then
	print(`        colliding: {table.concat(collidingPairs, ", ")}`)
end

-- (control) the reader must be able to tell TWO real lines apart, or it is
-- reporting zero collisions because it read nothing.
check(
	"(control) two lines this round knows are distinct really do read as distinct",
	allLines.busy ~= nil and allLines.givingUp ~= nil and allLines.busy ~= allLines.givingUp
)
check("(control) a line that does not exist is not found", not string.find(everything, "LINES.neverWritten", 1, true))

-- And the Supervisor's channel is consumed by the client, not merely declared.
-- A remote nobody listens to is the same dead wire in a different costume.
print("")
print("the Supervisor's clock reaches the screen")
local clientSource = fs.readFile("src/client/init.client.luau")
local clientCode = LuauCode.stripNonCode(clientSource)
check(
	"the client takes a Silence remote",
	string.find(clientCode, "local silenceRemote = Remotes.get(", 1, true) ~= nil
)
check("...and listens on it", string.find(clientCode, "silenceRemote.OnClientEvent", 1, true) ~= nil)
-- The NAME has to be compared, and a name is a string, so this one reads the
-- raw source. A wrong name is not silent anyway -- `panel()` asserts on it --
-- but the panel Hud reserves and the panel the client builds must be the same
-- one, and that is worth stating rather than leaving to a runtime assert.
check("...and draws the panel Hud names", string.find(clientSource, 'panel("Supervisor")', 1, true) ~= nil)
check("(guard) ...which Hud really reserves", rt.require(rt.shared.Hud).get("Supervisor") ~= nil)
-- R58. The server speaks only on a band change, so a client that draws only what
-- it was told shows three bar positions in a whole countdown. The fill between
-- pushes must come from `Shared.Silence`, not from arithmetic restated here --
-- R20's defect, and the thing this client's own comment already claimed.
check("the client fills the bar from Shared.Silence", string.find(clientCode, "Silence.fill(", 1, true) ~= nil)
check("...every frame, not only on a push", string.find(clientCode, "RunService.RenderStepped", 1, true) ~= nil)
-- The client must not work the deadline out for itself: that is the dial the
-- push exists to keep out of this file.
check("the client never reads the speaking deadline", string.find(clientCode, "Config.SpeakEvery", 1, true) == nil)
check(
	"(control) ...and it does read other Config dials, so that is not vacuous",
	string.find(clientCode, "Config.", 1, true) ~= nil
)

-- R61, and this is the CLASS. `Round.dealSecrets` shuffles with `math.random`
-- and nothing seeded it, so every run of `tests/soak.luau` was a different game:
-- 6, 7 and 13 stranded rounds on three runs of IDENTICAL code. Two log entries
-- argued from single runs of it, and R60'''s headline table was noise.
--
-- A wired-wrong model gives the same wrong answer every time and can be caught.
-- A seedless one gives a different answer every time and lets you keep the run
-- that agrees with you.
--
-- Four other suites consume the same randomness. None of their assertions
-- depended on the shuffle, which is exactly why it would go unnoticed the day
-- one did.
print("")
print("a test that rolls dice says which dice")

local unseeded: { string } = {}
local rolled = 0
for _, entry in fs.readDir("tests") do
	if not string.match(entry, "%.luau$") then
		continue
	end
	local body = LuauCode.stripNonCode(fs.readFile(`tests/{entry}`))
	local rolls = string.find(body, "dealSecrets", 1, true) or string.find(body, "math.random(", 1, true)
	if not rolls then
		continue
	end
	rolled += 1
	if not string.find(body, "math.randomseed", 1, true) then
		table.insert(unseeded, entry)
	end
end
check(`(guard) some suites do roll dice ({rolled})`, rolled >= 3)
check(`every suite that rolls dice seeds them ({#unseeded} unseeded)`, #unseeded == 0)
if #unseeded > 0 then
	print(`        unseeded: {table.concat(unseeded, ", ")}`)
end
check("(control) the reader is not matching every file", rolled < 20)

-- R64, and this is the CLASS. The mutation sweep's one survivor was a lost round
-- recording no outcome, which nothing noticed -- and the reason it MATTERS is
-- here: the client picks the sentence it shows from that field. An outcome the
-- server can record and the client has no words for renders as the fallback,
-- so two different endings arrive as one sentence. That is R10's, R13's and
-- R51's defect for the fourth time.
--
-- The outcomes are derived from `Lifecycle`'s own type, never typed here.
print("")
print("every outcome the round can have has its own words")

local lifecycleSource = fs.readFile("src/server/systems/Lifecycle.luau")
local outcomeType = string.match(lifecycleSource, "export type Outcome = ([^" .. NL .. "]+)") or ""
check(`(guard) found the Outcome type ({outcomeType})`, #outcomeType > 0)

local outcomes: { string } = {}
for name in string.gmatch(outcomeType, '"([%a]+)"') do
	table.insert(outcomes, name)
end
check(`(guard) it names some outcomes ({table.concat(outcomes, ", ")})`, #outcomes >= 2)

local said: { [string]: string } = {}
local textBlock = string.match(clientSource, "local OUTCOME_TEXT = {(.-)}") or ""
check("(guard) found the client's outcome text", #textBlock > 0)
for key, text in string.gmatch(textBlock, '([%a]+) = "([^"]+)"') do
	said[key] = text
end

local mute: { string } = {}
for _, outcome in outcomes do
	if not said[outcome] then
		table.insert(mute, outcome)
	end
end
check(`every outcome has words ({#mute} without any)`, #mute == 0)
if #mute > 0 then
	print(`        no words for: {table.concat(mute, ", ")}`)
end

-- ...and they must be DIFFERENT words, or the two endings arrive as one.
local heardText: { [string]: string } = {}
local collisions = 0
for _, outcome in outcomes do
	local text = said[outcome]
	if text then
		if heardText[text] then
			collisions += 1
		end
		heardText[text] = outcome
	end
end
check(`no two outcomes read the same ({collisions} collisions)`, collisions == 0)

-- (control) an outcome the type does not name must not be found to have words.
check("(control) the reader does not invent outcomes", said["abandoned"] == nil)

-- R67, checked in the PRODUCT's own file. A caught player cannot act and is
-- never released mid-round, so once takeWhoeverIsHere connects them there is
-- no more silence left for the Supervisor to punish -- and nothing joined the
-- two systems, so it kept chasing them. Measured: roughly half of every
-- dispatch and every audible announcement was wasted on a player who could not
-- benefit from it.
print("")
print("a captured player stops being chased for silence")

local connectedCode = LuauCode.stripNonCode(fs.readFile("src/server/systems/Connected.luau"))
local takeBody = string.match(connectedCode, "function Connected.takeInRoom%(.-" .. NL .. "end") or ""
local connectAt = string.find(takeBody, "self:connect(userId, now)", 1, true)
local forgetAt = string.find(takeBody, "supervisor:forget(userId)", 1, true)
check("(guard) the capture path connects a caught player", connectAt ~= nil)
check("the Supervisor is told to forget them", forgetAt ~= nil)
if connectAt and forgetAt then
	check("...right after they are connected, not before", forgetAt > connectAt)
end

-- R59 and R60, and this is the CLASS. R49 wrote the rule in `tests/soak.luau` in
-- capitals -- "IT IS WIRED LIKE THE SERVER OR IT IS NOT EVIDENCE" -- after its
-- own first draft called `board:submit` directly, skipped `board.onSolved`, and
-- produced a finding that turned out to be the harness. Twice since then the
-- soak has drifted anyway:
--
--   R54  dispatched with `Config.Rooms[(userId % #Config.Rooms) + 1]`, a room
--        picked from a user id, and reported 36 calls where the wired version
--        reports 18.
--   R54- caught people with `for i = 1, #present - 1 do line:connect(present[i])`,
--   R59  the first N entries of an array, so `reachedInRoom` was never called,
--        nobody had a position, and where the Operator stood did not enter into
--        it. R23's whole rule -- it takes the ROOM, not a circle -- was
--        unexercised, and R47's and R48's findings rest on who gets caught.
--
-- A capital-letter comment is not a guard. What each server path reaches for is
-- DERIVED from its own source, and the soak has to reach for it too.
print("")
print("the soak runs the server's paths, not its own")

local soakSource = fs.readFile("tests/soak.luau")
local soakCode = LuauCode.stripNonCode(soakSource)
check("(guard) read the soak", #soakCode > 0)

-- Remotes and Roblox-only lookups are excluded by name: the soak has no clients
-- and no Instances, and those are the parts it is RIGHT not to mirror.
local NOT_THE_SOAKS_JOB: { [string]: boolean } = {
	heardRemote = true,
	connectedRemote = true,
	objectivesRemote = true,
	silenceRemote = true,
	Players = true,
	Round = true,
	built = true,
	os = true,
	math = true,
	table = true,
	string = true,
	livePositions = true,
	-- `p` is the loop variable over `Players:GetPlayers()`. The soak has no
	-- Player objects and works in bare user ids, which is the right model.
	p = true,
	pushObjectives = true,
}

-- R110: the dispatch is no longer copied into the soak -- both call it.
check("the soak runs the server's own dispatch", string.find(soakCode, ":putThrough(", 1, true) ~= nil)
for _, path in { "takeWhoeverIsHere", "workTheWayOut" } do
	local body = string.match(serverCode, `local function {path}%(%).-` .. NL .. "end") or ""
	check(`(guard) read the server's '{path}'`, #body > 0)

	local wanted: { string } = {}
	local seen: { [string]: boolean } = {}
	local function want(owner: string, member: string)
		local key = `{owner}.{member}`
		if not NOT_THE_SOAKS_JOB[owner] and not seen[key] then
			seen[key] = true
			table.insert(wanted, key)
		end
	end
	for owner, member in string.gmatch(body, "([%a][%w_]*)[.:]([%a][%w_]*)%(") do
		want(owner, member)
	end
	for owner, member in string.gmatch(body, "([%a][%w_]*)%.([%a][%w_]*)[^(%w_]") do
		want(owner, member)
	end
	table.sort(wanted)
	check(`(guard) '{path}' reaches for several things ({#wanted})`, #wanted >= 3)

	local missing: { string } = {}
	for _, key in wanted do
		local member = string.match(key, "%.([%a][%w_]*)$") :: string
		-- The soak names its locals differently (`supervisor`, `pursuit`,
		-- `line`), so the MEMBER is what has to appear, not the expression.
		if not string.find(soakCode, "." .. member, 1, true) and not string.find(soakCode, ":" .. member, 1, true) then
			table.insert(missing, key)
		end
	end
	check(`the soak uses everything '{path}' uses ({#missing} missing)`, #missing == 0)
	if #missing > 0 then
		print(`        the soak never touches: {table.concat(missing, ", ")}`)
	end
end

-- The three that carry the meaning, stated outright so a rename cannot quietly
-- drop them from the derived lists above.
check("the soak finds a player's room by position", string.find(soakCode, "Layout.inRoom(", 1, true) ~= nil)
check("...forgives nobody unless the call went through", string.find(soakCode, "onItsWay", 1, true) ~= nil)
check(
	"...and catches whoever is in the room, not the first N",
	-- R112: through the server's own capture, which is reachedInRoom inside.
	string.find(soakCode, ":takeInRoom(", 1, true) ~= nil
)
-- R138: the way out, through the same step as the server. The bot playtest's
-- traces are quoted as evidence in the log, so it is held to the same rule.
check("...and settles the way out with the server's own step", string.find(soakCode, "escape:step(", 1, true) ~= nil)
-- R140: the bots and tools/play.luau share one world, tools/sim.luau.
local botCode = LuauCode.stripNonCode(fs.readFile("tools/sim.luau"))
check("(guard) read the playtest world", #botCode > 0)
check("the playtest world settles the way out with that step too", string.find(botCode, "escape:step(", 1, true) ~= nil)

-- (control) a member no server path reaches for must not be reported as covered.
check("(control) the reader does not invent coverage", string.find(soakCode, ".neverWrittenMember", 1, true) == nil)

-- R66, and this is the CLASS. R58's own log entry recorded that `BAND_COLOUR`
-- in `init.client.luau` restates `Silence`'s band names as string-literal keys,
-- and carried it forward as "latent, not fixed" through R59-R65 without ever
-- being checked. A fourth band added to `Silence.luau` (the way R56 added the
-- whole Supervisor system to this game) would silently draw with no colour; a
-- renamed band would silently fall back to the `clear` colour for an OVERDUE
-- player, which is the one situation this bar exists to make legible.
--
-- Swept from `Silence`'s own `Band` type, never from a list typed here.
print("")
print("every band Silence can report has a colour in the client")

local silenceSource = fs.readFile("src/shared/Silence.luau")
local bandType = string.match(silenceSource, "export type Band = ([^" .. NL .. "]+)") or ""
check(`(guard) found the Band type ({bandType})`, #bandType > 0)

local bands: { string } = {}
for name in string.gmatch(bandType, '"([%a]+)"') do
	table.insert(bands, name)
end
check(`(guard) it names some bands ({table.concat(bands, ", ")})`, #bands >= 2)

local colourBlock = string.match(clientSource, "local BAND_COLOUR: { %[string%]: Color3 } = {(.-)}") or ""
check("(guard) found the client's BAND_COLOUR table", #colourBlock > 0)

local coloured: { [string]: boolean } = {}
for name in string.gmatch(colourBlock, "([%a][%w_]*) = Color3%.fromRGB") do
	coloured[name] = true
end

local mute: { string } = {}
for _, band in bands do
	if not coloured[band] then
		table.insert(mute, band)
	end
end
check(`every band has a colour ({#mute} without one)`, #mute == 0)
if #mute > 0 then
	print(`        no colour for: {table.concat(mute, ", ")}`)
end

-- And the reverse: a colour for a band Silence does not have is dead code that
-- looks like coverage, the same shape as R56's dead `stillThere` line.
local stray: { string } = {}
local bandSet: { [string]: boolean } = {}
for _, band in bands do
	bandSet[band] = true
end
for name in coloured do
	if not bandSet[name] then
		table.insert(stray, name)
	end
end
check(`no colour is drawn for a band that does not exist ({#stray} stray)`, #stray == 0)

-- (control) a band that does not exist must not be found to have a colour.
check("(control) the reader does not invent bands", coloured["abandoned"] == nil)

-- R70, checked in the PRODUCT's own file. The server stops watching a caught
-- player's silence the instant Supervisor.forget runs (R67), and
-- showEveryoneTheirClock simply stops sending them anything from then on -- it
-- never tells the client the clock is gone. Without a corresponding client-side
-- hide, the panel kept whatever band was last pushed, possibly the red "SILENT
-- LINE - TRACED" state, for the rest of the round.
print("")
print("a captured player's silence panel is hidden, not left stale")

local connectedBody = string.match(
	clientCode,
	"connectedRemote%.OnClientEvent:Connect%(Guard%.wrap%( , function%(caught: boolean%).-" .. NL .. "end%)%)"
) or ""
check("(guard) found the client's Connected handler", #connectedBody > 0)
local ifCaughtAt = string.find(connectedBody, "if caught then", 1, true)
local hideAt = string.find(connectedBody, "silencePanel.Visible = false", 1, true)
check("the Silence panel is hidden on capture", hideAt ~= nil)
if ifCaughtAt and hideAt then
	check("...inside the caught branch, not unconditionally", hideAt > ifCaughtAt)
end

-- R71, and this is the CLASS. R56 built this guard for ONE remote: "the
-- server fires Silence at one client, never everyone", because a player's own
-- clock is not everyone's business. This is the same guard for the three other
-- remotes that carry something private, generalised rather than repeated --
-- and the most serious of the four is `Objectives`, which carries the actual
-- two-digit answers players are supposed to relay by talking, not read off
-- someone else's screen. Nothing checked any of the three before this.
--
-- The local variable each remote is bound to is DERIVED from the source
-- (`local xRemote = Remotes.get("Name")`), never typed here, so a rename does
-- not silently blind the sweep.
-- R57, and this is the CLASS. `Hud.EXCLUSIVE` is a list of promises about what
-- the CLIENT will do, held in a shared module the client does not have to obey.
-- R56 added `{ "Round over", "Supervisor" }` and used it to justify placing the
-- clock where those two rects overlap at MinWidth -- then wrote a client that
-- shows the panel on every push and never hides it again. The promise was true
-- of the server and false of the product.
--
-- Swept from `Hud.exclusions()`, never from a list typed here.
print("")
print("every panel promised to be exclusive can actually be hidden")

local HudModule = rt.require(rt.shared.Hud)

-- Which local holds which panel, read from the client rather than assumed.
local holders: { [string]: string } = {}
for var, name in string.gmatch(clientSource, 'local ([%a][%w_]*) = panel%("([^"]+)"%)') do
	holders[name] = var
end
local holderCount = 0
for _ in holders do
	holderCount += 1
end
check(`(guard) found the client's panels ({holderCount})`, holderCount >= 4)

local pairs_ = HudModule.exclusions()
check(`(guard) found the exclusions ({#pairs_} pairs)`, #pairs_ >= 2)

for _, pair in pairs_ do
	for _, name in pair do
		local var = holders[name]
		check(`the client builds a panel for '{name}'`, var ~= nil)
		if var then
			-- Every assignment to this panel's visibility, and how many of them
			-- could HIDE it. The creation line is skipped: it is the first, and
			-- every panel starts hidden, so counting it would let a panel that
			-- can only ever be shown afterwards pass.
			--
			-- "Could hide it" is anything that is not the literal `true`. A
			-- panel driven by an expression -- `onLine.Visible = caught == true`
			-- -- can hide itself and must count, so testing for a literal
			-- `false` would fail on correct code.
			--
			-- This is the rule that catches R56 by itself: its clock panel was
			-- created hidden and then only ever set `true`, so it had ZERO ways
			-- back. Counting assignments alone did not catch it -- creation plus
			-- the push made two -- which is why the count is of hiding ones.
			local shows, hides, seenCreation = 0, 0, false
			for rhs in string.gmatch(clientCode, var .. "%.Visible = ([^" .. NL .. "]+)") do
				if not seenCreation then
					seenCreation = true
					continue
				end
				if string.match(rhs, "^true%s*$") then
					shows += 1
				else
					hides += 1
				end
			end
			check(`(guard) '{name}' is shown somewhere ({shows})`, shows + hides > 0)
			check(`'{name}' has a way back off the screen ({hides} of {shows + hides})`, hides > 0)
		end
	end
end

-- The specific promise R56 made, checked where it is kept.
local phaseBody = string.match(clientCode, "local function onPhase%(.-" .. NL .. "end") or ""
check("(guard) found the client's phase handler", #phaseBody > 0)
check(
	"the Supervisor's clock is hidden when the round ends",
	string.find(phaseBody, "silencePanel.Visible = false", 1, true) ~= nil
)

-- (control) the reader must be able to fail: a panel nobody built is not found,
-- and a variable nobody assigns has no assignments.
check("(control) a panel that does not exist is not found", holders["Nothing"] == nil)
check(
	"(control) a variable nobody touches has no assignments",
	select(2, string.gsub(clientCode, "neverWrittenPanel.Visible =", "")) == 0
)

-- R48/R49. Everyone taken is one way to lose; nobody LEFT being able to finish
-- anything is the other. Three of four caught in one arrival strands a line with
-- its reader, and the survivor could then neither win nor be forced to lose.
--
-- R48 put this inside the capture path. R49's soak measured what that cost --
-- 134 ticks of a stranded round still running after the Operator walked away --
-- so it now lives in a function of its own that BOTH the capture path and the
-- tick ask. These checks follow it there.
-- R108: the body moved to Lifecycle.nobodyCanWin (where tests/lifecycle RUNS
-- it); these text checks follow it there.
local lifecycleCode = LuauCode.stripNonCode(fs.readFile("src/server/systems/Lifecycle.luau"))
local loseBody = string.match(lifecycleCode, "function Lifecycle.nobodyCanWin%(.-" .. NL .. "end") or ""
-- R51. `Presence` must SPEAK through Shared.Hum, or the pitch difference is a
-- module nobody consults and coming still sounds like going.
local presenceCode = LuauCode.stripNonCode(fs.readFile("src/server/systems/Presence.luau"))
check("Presence requires Shared.Hum", string.find(presenceCode, "Shared.Hum", 1, true) ~= nil)
-- R65: a source sweep cannot tell a real fade from a snap, which is exactly why
-- this one survived a mutation sweep. Presence must call the tested function
-- rather than restate the arithmetic inline.
check(
	"Presence fades volume through Hum.smooth, not inline math",
	string.find(presenceCode, "Hum.smooth(", 1, true) ~= nil
)
check("...and asks it per state", string.find(presenceCode, "Hum.forState(tracker.state)", 1, true) ~= nil)
check("...and sets the pitch it returns", string.find(presenceCode, "hum.PlaybackSpeed = voice.pitch", 1, true) ~= nil)
check("...and no longer carries its own volume", string.find(presenceCode, "then 0.35 else 0", 1, true) == nil)

check("(guard) found the losing rule", #loseBody > 0)
check(
	"...and everyone being taken still loses (control)",
	string.find(loseBody, "line:allTaken(present)", 1, true) ~= nil
)
check(
	"a round with a line nobody free may enter is also lost",
	string.find(loseBody, "board:stranded(able) ~= nil", 1, true) ~= nil
)
check("...and a WON board is excluded from it", string.find(loseBody, "board:allSolved()", 1, true) ~= nil)
check(
	"...measured against the players who can still act",
	string.find(loseBody, "line:isConnected(userId)", 1, true) ~= nil
)
-- The clause that stops a solo server losing instantly and looping: a board
-- nobody can finish with NOBODY connected is the dealing problem, not a round
-- that play has stranded.
check("...and only when play stranded it", string.find(loseBody, "line:count() > 0", 1, true) ~= nil)

-- RAW source: the remote name is a string body and the lexer strips those, so
-- against `clientCode` this reads `Remotes.get()` and never matches. Fifth time
-- this project has hit that; the remote-names block above says the same thing.
check("the client listens for the phase", string.find(clientSource, 'Remotes.get("Phase")', 1, true) ~= nil)
-- R138: every kind of row the objectives panel is given has its own style. A
-- kind without one falls back to the small grey note, which is how the way-out
-- row would read if its style were lost. Kinds read from Readout's RAW source:
-- they are string bodies, which the stripped source blanks.
local rowKinds = 0
local unstyled: { string } = {}
for kind in string.gmatch(fs.readFile("src/shared/Readout.luau"), 'kind = "(%a+)"') do
	rowKinds += 1
	if not string.find(clientSource, NL .. "%s*" .. kind .. " = { size = ") then
		table.insert(unstyled, kind)
	end
end
check(`(guard) found the panel's row kinds ({rowKinds})`, rowKinds >= 5)
check(`every row kind has its own style ({table.concat(unstyled, ", ")})`, #unstyled == 0)
-- CONNECTED, not merely defined. The first version of this check looked for the
-- handler's name and passed against a client that declared `onPhase` and never
-- subscribed to anything -- the same weakness R20 found in its ramp check.
-- R34. The layout module is only worth having if the client reads it. A
-- `Shared.Hud` nobody consults is decoration, and the sweep in tests/hud.luau
-- would go on passing against a client full of hand-typed rects.
-- R35. The row list is only worth having if the client renders it in the order
-- it comes back. Rebuilding an order at render time is how the notes came adrift
-- from their lines in the first place.
check(
	"the client requires Shared.Readout",
	string.find(clientCode, "require(ReplicatedStorage.Shared.Readout)", 1, true) ~= nil
)
check(
	"...and renders the rows it returns, with where the Operator is waiting",
	string.find(clientCode, "Readout.lineRows(entries, holding)", 1, true) ~= nil
)

local renderBody = string.match(clientCode, "local function renderObjectives%(.-" .. NL .. "end") or ""
check("(guard) found renderObjectives", #renderBody > 0)
check(
	"the panel does not invent an order of its own",
	string.find(renderBody, "+ 100", 1, true) == nil and string.find(renderBody, "900", 1, true) == nil
)

check(
	"the client requires Shared.Hud",
	string.find(clientCode, "require(ReplicatedStorage.Shared.Hud)", 1, true) ~= nil
)
check("...and builds its panels from it", string.find(clientCode, "Hud.get(name)", 1, true) ~= nil)

-- No panel may carry geometry of its own any more: `panel()` takes a name and
-- nothing else. A call with extra arguments is a rect the sweep cannot see.
local strayGeometry = 0
for args in string.gmatch(clientCode, "= panel%((.-)%)") do
	if string.find(args, ",", 1, true) then
		strayGeometry += 1
		print(`    panel call carries its own geometry: {args}`)
	end
end
check("(guard) panel call sites were found", string.find(clientCode, "= panel(", 1, true) ~= nil)
check(`no panel is placed with numbers typed in the client ({strayGeometry})`, strayGeometry == 0)

check(
	"...and actually subscribes to it",
	string.find(clientCode, "phaseRemote.OnClientEvent:Connect(Guard.wrap( , onPhase))", 1, true) ~= nil
)

print("")
print("nothing the client DISPLAYS is a giveaway")

-- R43, finishing what R41 and R42 started. Those checked the station prompts and
-- the panel's exported constants. The client's own inline literals were judged
-- "coherent" BY EYE â€” and one was not: the keypad hint read "enter the NUMBER
-- you were told for the {stationId}", which conveyed `jack_number` at every
-- station including the breaker, in front of the player working it. It also
-- showed the raw station id, and `board` and `breaker` ARE the plain terms.
--
-- Scoped to text the client puts ON SCREEN: literals passed to `label(...)` and
-- assigned to `.Text`. An identifier that is never rendered is not a giveaway.

local Round = rt.require(rt.systems.Round)
local Heuristic = rt.require(rt.systems.Heuristic)

-- SEEDED. This file calls `Round.dealSecrets(99)` itself, so it rolls the same
-- dice `tests/soak.luau` did -- and its own sweep below is what found that out.
math.randomseed(71)

local livePool = Round.dealSecrets(99)

local function saidAloud(text: string): { string }
	local out: { string } = {}
	for _, reading in Heuristic.conveyed({ speaker = { UserId = 1 } :: any, text = text, at = 1 }, livePool, {}) do
		table.insert(out, reading.concept :: string)
	end
	return out
end

-- Text the game shows only while the Operator is NOT listening. R32 gates the
-- chat feed on the round being live, and `tests/wiring.luau` asserts that gate,
-- so this exemption is earned rather than asserted.
-- R138 retired its one entry, "The board was restored.": the win text that
-- replaced it says nothing the Operator hears, and the sweep below holds it to
-- that like any other string.
local AFTER_THE_ROUND: { [string]: boolean } = {}

-- Three shapes, because the client displays text three ways. The first draft
-- collected only two and found THREE strings while the client shows six -- the
-- coverage guard below caught that rather than letting a narrow sweep pass.
local clientRaw = fs.readFile("src/client/init.client.luau")

-- R118. A round is lost two ways (Lifecycle.nobodyCanWin: everyone taken, OR
-- nobody still free can finish), and the server sends only "lost". The text
-- the client shows for it must be true of both, so it may not claim everyone
-- was taken.
local lostText = string.match(clientRaw, NL .. '%s*lost = "([^"]+)"')
check(`(guard) found the loss text ({lostText or "none"})`, lostText ~= nil)
-- R138: every way of saying "all of you", not only the one word. The review
-- found "All of you reached the lobby." would have passed a check for
-- "everyone" alone.
local function claimsEveryone(text: string?): boolean
	local lower = string.lower(text or "")
	for _, phrase in { "everyone", "everybody", "all of you", "every one of you", "the whole group" } do
		if string.find(lower, phrase, 1, true) then
			return true
		end
	end
	return false
end
check("(control) the reader hears it said another way", claimsEveryone("All of you reached the lobby."))
check("the loss text does not claim everyone was taken", lostText ~= nil and not claimsEveryone(lostText))
-- R138, the same rule for the other ending. A round is won two ways too
-- (Escape.step: everyone still free in the lobby, OR anyone free in it at the
-- time limit), and the server sends only "won". A win at the limit leaves
-- somebody outside, so the text may not claim everyone got out.
local wonText = string.match(clientRaw, NL .. '%s*won = "([^"]+)"')
check(`(guard) found the win text ({wonText or "none"})`, wonText ~= nil)
check("the win text does not claim everyone got out", wonText ~= nil and not claimsEveryone(wonText))
local displayed: { [string]: boolean } = {}
for text in string.gmatch(clientRaw, 'label%([%w_.]+, "([^"]+)"') do
	displayed[text] = true
end
for text in string.gmatch(clientRaw, '%.Text = "([^"]+)"') do
	displayed[text] = true
end
-- Sentences, wherever they sit: a lookup table, an `or` fallback, an argument.
-- Anchoring on `= "` missed `or "The round is over."` and the coverage guard
-- caught that too.
for text in string.gmatch(clientRaw, '"([%u][^"]*%.)"') do
	displayed[text] = true
end

-- BACKTICK strings, with their interpolation spans removed. The defect this
-- guard exists to catch was written as
-- `enter the number you were told for the {stationId}` -- and the first version
-- of this sweep read only double-quoted text, so planting that exact wording
-- back PASSED. A guard blind to the form of its own defect is worse than none.
-- The `{...}` spans are code, not words, so they are stripped and what remains
-- is the sentence a player reads.
-- Comment lines are skipped: a comment may quote a concept id in backticks and
-- would otherwise be reported as text the client displays. R37 hit the same
-- false positive from the other direction, where a comment invented a field.
for line in string.gmatch(clientRaw .. NL, "([^" .. NL .. "]*)" .. NL) do
	if not string.match(line, "^%s*%-%-") then
		for template in string.gmatch(line, "`([^`]+)`") do
			local words = string.gsub(template, "{[^}]*}", " ")
			if string.find(words, "%a") then
				displayed[words] = true
			end
		end
	end
end

local shown = 0
for _ in displayed do
	shown += 1
end
check(`(guard) found text the client displays ({shown} strings)`, shown >= 6)

local leaked = 0
for text in displayed do
	if AFTER_THE_ROUND[text] then
		continue
	end
	local gives = saidAloud(text)
	if #gives > 0 then
		leaked += 1
		print(`    "{text}" -> {table.concat(gives, ", ")}`)
	end
end
check(`no displayed string gives a concept away ({leaked})`, leaked == 0)

-- R121. The scan above reads the CLIENT's literals. Players also read text
-- that lives in shared modules: every HUD panel title, the reader's notes in
-- Readout, and the Supervisor's band notes in Silence. None of it was scanned.
-- Measured when added: 12 strings, ONE conveys a secret -- the keypad panel's
-- title "The board" (jack) -- and it is never shown: the panel starts hidden
-- and onOpenBoard replaces its title on every open. That exemption is kept
-- honest by the check below it.
local ReadoutModule = rt.require(rt.shared.Readout)
local SilenceModule = rt.require(rt.shared.Silence)
local TITLE_NEVER_SHOWN: { [string]: boolean } = { ["The board"] = true }
local sharedShown: { string } = {
	ReadoutModule.PRIVATE_NOTE,
	ReadoutModule.NOTHING_HELD,
	ReadoutModule.ESCAPE_NOTE,
	ReadoutModule.ESCAPE_WAIT,
	ReadoutModule.TITLE_WON,
	ReadoutModule.TITLE_LOST,
	SilenceModule.note("clear"),
	SilenceModule.note("warned"),
	SilenceModule.note("overdue"),
}
for _, spec in HudModule.panels() do
	if not TITLE_NEVER_SHOWN[spec.name] then
		table.insert(sharedShown, spec.name)
	end
end
-- R144: the waiting row, as it reads for every station.
for _, station in Round.STATIONS do
	table.insert(sharedShown, string.format(ReadoutModule.WAITING, station.label))
end
local sharedLeaks: { string } = {}
for _, text in sharedShown do
	if #saidAloud(text) > 0 then
		table.insert(sharedLeaks, text)
	end
end
check(`(guard) scanned the shared display text ({#sharedShown} strings)`, #sharedShown >= 10)
check(`no shared display text gives a concept away ({table.concat(sharedLeaks, " | ")})`, #sharedLeaks == 0)
for name in TITLE_NEVER_SHOWN do
	check(`the exempt title '{name}' really does convey something (or drop the exemption)`, #saidAloud(name) > 0)
end
-- R122/R126. The station prompts are displayed text too: World builds each with
-- ObjectText = the station's name and ActionText = the verb, shown over the
-- station to anyone near it. R122 found all three names conveyed their own
-- secret ("Directory", "Switchboard" -> jack, "Breaker") and filed it; the owner
-- ruled a label must not give its secret away, so R126 renamed them and there
-- are NO exemptions: no name and no verb a prompt shows may convey anything.
-- R137: objective stations take their name and verb from Round.STATIONS; the
-- reader keeps a literal in World. Both are read.
local worldRaw = fs.readFile("src/server/systems/World.luau")
local promptCount, promptLeaks = 0, {}
local function scanPrompt(name: string, verb: string)
	promptCount += 1
	if #saidAloud(name) > 0 then
		table.insert(promptLeaks, name)
	end
	if #saidAloud(verb) > 0 then
		table.insert(promptLeaks, verb)
	end
end
for name, verb in string.gmatch(worldRaw, 'station%("([^"]+)", "([^"]+)"') do
	scanPrompt(name, verb)
end
for _, s in Round.STATIONS do
	scanPrompt(s.label, s.actionText)
end
check(
	"(guard) World labels objective stations from Round.STATIONS",
	string.find(worldRaw, "station(s.label, s.actionText", 1, true) ~= nil
)
check(`(guard) found the station prompts ({promptCount})`, promptCount >= 4)
check(`no station prompt gives a concept away ({table.concat(promptLeaks, " | ")})`, #promptLeaks == 0)

check(
	"...and the keypad's title really is replaced on every open",
	string.find(clientSource, 'title.Text = string.upper(actionText or "keypad")', 1, true) ~= nil
)

-- The exemption must be real: the string it covers has to actually leak, or it
-- is hiding nothing and should not exist.
for text in AFTER_THE_ROUND do
	check(`the exemption for "{text}" covers a real leak`, #saidAloud(text) > 0)
	check(`...and that string is actually in the client`, string.find(clientRaw, text, 1, true) ~= nil)
end

-- The control: the sweep is not passing because the reader went deaf.
check("(control) a plain giveaway is still heard", #saidAloud("enter the jack number") > 0)

-- And the specific defect, named, so a regression says which.
check("the keypad hint no longer names the jack", #saidAloud("enter what you were told") == 0)

-- R94. The server hands players text too: rejection reasons fired at one
-- client and the reason every Objectives refusal carries. Neither the client
-- template scan above nor R93's Round.LINES check reads them, and a player
-- repeating "someone else has to patch this" is chat like any other.
local serverSaid = {}
for _, file in
	{
		"src/server/init.server.luau",
		"src/server/systems/Exchange.luau",
		"src/server/systems/Objectives.luau",
		"src/server/systems/Station.luau",
	}
do
	local raw = fs.readFile(file)
	for text in string.gmatch(raw, 'reason = "([^"]+)"') do
		serverSaid[text] = true
	end
	-- R144: a refusal in a station's own verb is a template; read it with each.
	for text in string.gmatch(raw, "reason = `([^`]+)`") do
		for _, station in Round.STATIONS do
			serverSaid[(string.gsub(text, "{[^}]*}", string.lower(station.actionText)))] = true
		end
	end
	for text in string.gmatch(raw, 'FireClient%([^,]+, [^,]+, "([^"]+)"') do
		serverSaid[text] = true
	end
end
local serverCount, serverLeaks = 0, {}
for text in serverSaid do
	serverCount += 1
	if #saidAloud(text) > 0 then
		table.insert(serverLeaks, text)
	end
end
check(`(guard) found the server's player-facing reasons ({serverCount})`, serverCount >= 7)
check(`no server reason gives a concept away ({table.concat(serverLeaks, " | ")})`, #serverLeaks == 0)

print("")
print("where the Operator is waiting reaches every panel (R144)")
check(
	"the client redraws its panel when told",
	string.find(clientCode, "holdingRemote.OnClientEvent:Connect(", 1, true) ~= nil
		and string.find(clientCode, "renderObjectives(shownEntries)", 1, true) ~= nil
)
check(
	"the sim's players see the same row",
	string.find(botCode, "Readout.lineRows(self.board:viewFor(id), holding)", 1, true) ~= nil
)

print("")
print("every engine API on its own side (PLATFORM.md)")

-- R139 (COACH.md C1). The suite mocks Roblox, so it cannot see an API used on
-- the side it does not run on: the chat hook was a client-only callback set in
-- the server script for 138 rounds, and the chat check above REQUIRED it. This
-- is a lint, not a behaviour test: which side a file runs on is only visible in
-- its source. PLATFORM.md lists each side-restricted API with the source that
-- says where it runs; this sweeps every source file against that table.
local platform = fs.readFile("PLATFORM.md")
local onlyOn: { [string]: { string } } = { client = {}, server = {} }
for api, side in string.gmatch(platform, "| `([%a][%w_]*)` | (%a+) |") do
	local list = onlyOn[side]
	if list then
		table.insert(list, api)
	end
end
check(`(guard) PLATFORM.md names client-only APIs ({#onlyOn.client})`, #onlyOn.client >= 4)
check(`(guard) ...and server-only ones ({#onlyOn.server})`, #onlyOn.server >= 4)

local function luauFiles(dir: string, into: { string }): { string }
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			luauFiles(path, into)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(into, path)
		end
	end
	return into
end
-- Used as a member (`x.Api`, `x:Api`), in code: comments and strings are
-- stripped first, so a comment naming an API is not a use of it.
local function uses(code: string, api: string): boolean
	return string.find(code, "[.:]" .. api .. "[^%w_]") ~= nil
end
local wrongSide: { string } = {}
local swept = 0
local function sweep(dir: string, banned: { string })
	for _, path in luauFiles(dir, {}) do
		swept += 1
		local code = LuauCode.stripNonCode(fs.readFile(path))
		for _, api in banned do
			if uses(code, api) then
				table.insert(wrongSide, `{path}: {api}`)
			end
		end
	end
end
sweep("src/server", onlyOn.client)
sweep("src/client", onlyOn.server)
-- Shared modules run on both sides, so neither list may appear there.
sweep("src/shared", onlyOn.client)
sweep("src/shared", onlyOn.server)
check(`(guard) swept the source ({swept} files)`, swept >= 20)
check(`no engine API is used where it does not run ({table.concat(wrongSide, "; ")})`, #wrongSide == 0)
check(
	"(control) the sweep sees the pre-R139 hook",
	uses(LuauCode.stripNonCode("TextChatService.OnIncomingMessage = function() end" .. NL), "OnIncomingMessage")
)
check(
	"(control) ...and not a mention in a comment",
	not uses(LuauCode.stripNonCode("-- .OnIncomingMessage" .. NL), "OnIncomingMessage")
)

print("")
print("the sim keeps the codes secret the way the server does (tests/exchange runs the server's side)")
check("the sim asks the board for the live codes", string.find(botCode, "board:liveCodes()", 1, true) ~= nil)
check("...rerolls a heard code", string.find(botCode, "board:reroll(concept)", 1, true) ~= nil)
check("...and rings a wrong code through", string.find(botCode, "result.ringsThrough", 1, true) ~= nil)

print("")
print("the sim's wall says where each word leads")
check(
	"the sim's wall is labelled with where each word leads",
	string.find(botCode, "Round.wallRows(self.operator:snapshot(), self.operator:countingRows())", 1, true) ~= nil
)

print("")
print("a restore teaches the counting learner in the sim")
check(
	"the sim credits the code just entered",
	string.find(botCode, "self.operator:creditCode(objective.answer, self.now, objective.holder)", 1, true) ~= nil
)

print("")
print("ARCHITECTURE.md maps every module")
-- The map is how a reader finds the module that owns a concern, so a module
-- added, moved or split without its line there is a map that lies.
local architecture = fs.readFile("ARCHITECTURE.md")
local function mapped(dir: string, prefix: string)
	for _, entry in fs.readDir(dir) do
		local stem = string.match(entry, "^(.+)%.luau$")
		if stem and not string.find(stem, "%.") then
			check(`ARCHITECTURE.md lists {prefix}{stem}`, string.find(architecture, `| {stem} |`, 1, true) ~= nil)
		end
	end
end
mapped("src/server/systems", "src/server/systems/")
mapped("src/shared", "src/shared/")
for _, entry in { "src/server/init.server.luau", "src/client/init.client.luau" } do
	check(`ARCHITECTURE.md lists {entry}`, string.find(architecture, entry, 1, true) ~= nil)
end

Kit.finish()
