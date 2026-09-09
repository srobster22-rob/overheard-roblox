--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: a message that is addressed to everybody
-- being rendered as if it were addressed to you.
--
-- The keypad has one red line under its input. Until R10 the only writer of it
-- was the `Heard` remote's detail field — and `Heard` is the Operator's voice,
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

local process = require("@lune/process")
local fs = require("@lune/fs")

local Harness = require("./harness")
local LuauCode = require("./luaucode")

local rt = Harness.build()

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

local clientSource = fs.readFile("src/client/init.client.luau")
local serverSource = fs.readFile("src/server/init.server.luau")
local remotesSource = fs.readFile("src/shared/Remotes.luau")
local harnessSource = fs.readFile("tests/harness.luau")

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

	print(`\n{checks - failures}/{checks} passed`)
	process.exit(1)
end

check("a rejection for the open station is shown", Keypad.accepts("board", "board") == true)
check("a rejection for the other station is dropped", Keypad.accepts("board", "breaker") == false)
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

print("")
print("Rejected is private")
-- The whole point of the new remote is that it is never broadcast. Sweep every
-- broadcast in the server and require none of them to be this one.
local broadcasts = 0
local leaks = 0
for target in string.gmatch(serverCode, "([%a][%w_]*):FireAllClients") do
	broadcasts += 1
	if target == "rejectedRemote" then
		leaks += 1
	end
end
check("broadcasts were found to sweep (guard)", broadcasts >= 3)
check(`no broadcast is on the Rejected remote ({broadcasts} swept)`, leaks == 0)
check("the server fires Rejected at ONE client", string.find(serverCode, "rejectedRemote:FireClient", 1, true) ~= nil)
-- And the reason must travel on that channel, not stuffed back into the voice.
local submitReply = string.match(serverCode, "board:submit(.-)\nend%)") or ""
check("the submit reply block was found", #submitReply > 0)
check("the submit failure path fires Rejected", string.find(submitReply, "rejectedRemote", 1, true) ~= nil)

-- Shared modules -----------------------------------------------------------
-- A shared module the harness does not adopt cannot be required by any test.

print("")
print("every shared module is reachable from tests")
local adopted: { [string]: boolean } = {}
local adoptedCount = 0
-- Whitespace-tolerant on purpose. This pattern used to require the list on
-- ONE line, and adding an eleventh shared module pushed it past the line
-- width, so stylua wrapped it and the sweep stopped finding the list at all
-- -- reporting all eleven modules as unadopted when every one of them was.
-- A guard that reads code must not depend on how the code is laid out (R7).
local sharedList = string.match(harnessSource, "for _, name in%s*{(.-)}%s*do%s*adopt%(shared") or ""
for name in string.gmatch(sharedList, '"([%a][%w_]*)"') do
	adopted[name] = true
	adoptedCount += 1
end
check("the harness's shared list was found", adoptedCount > 0)
local onDisk = 0
for _, entry in fs.readDir("src/shared") do
	local name = string.match(entry, "^([%a][%w_]*)%.luau$")
	if name then
		onDisk += 1
		check(`shared module '{name}' is adopted by the harness`, adopted[name] == true)
	end
end
check("shared modules were found on disk (guard)", onDisk >= 5)

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
	print(`\n{checks - failures}/{checks} passed`)
	process.exit(1)
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

print("")
print("Station is wired, and Submit is gated on it")
local triggeredBody = string.match(serverCode, "prompt%.Triggered:Connect%(function.-\n\tend%)")
check("init.server has a station prompt handler", triggeredBody ~= nil)
check(
	"reaching a station records it server-side",
	triggeredBody ~= nil and string.find(triggeredBody :: string, "desk:open", 1, true) ~= nil
)
local submitBody = string.match(serverCode, "submitRemote%.OnServerEvent:Connect%(function.-\nend%)")
check("init.server has a Submit handler", submitBody ~= nil)
check(
	"the Submit handler checks the player is at that station",
	submitBody ~= nil and string.find(submitBody :: string, "desk:accepts", 1, true) ~= nil
)
-- Order matters. If the station gate ran AFTER board:submit the answer would
-- already have been compared and a miss already counted, so a made-up station id
-- could burn the honest actor's jam allowance from across the map.
local gateAt = submitBody and string.find(submitBody :: string, "desk:accepts", 1, true)
local submitAt = submitBody and string.find(submitBody :: string, "board:submit", 1, true)
check("the station gate exists before board:submit is reached", gateAt ~= nil and submitAt ~= nil and gateAt < submitAt)
check(
	"a refused station replies on the private keypad channel, not the broadcast",
	submitBody ~= nil and string.find(submitBody :: string, "rejectedRemote:FireClient", 1, true) ~= nil
)
-- The leaver's seat is given up; the jam tables deliberately are not (see
-- tests/objectives.luau).
local removing = string.match(serverCode, "Players%.PlayerRemoving:Connect%(function.-\nend%)")
check("init.server has a PlayerRemoving handler", removing ~= nil)
check(
	"a departing player gives up their station",
	removing ~= nil and string.find(removing :: string, "desk:forget", 1, true) ~= nil
)

-- The two opposite Operator lines. `taken` is the monster arriving; the round
-- being won must not fire the same string.
print("")
print("winning and being found are different lines")
check("the server announces arrival with LINES.taken", string.find(serverCode, "LINES.taken", 1, true) ~= nil)
check("and a won round with LINES.completed", string.find(serverCode, "LINES.completed", 1, true) ~= nil)
local solvedBody = string.match(serverCode, "board%.onSolved = function.-\nend")
check("the onSolved handler was found (guard)", solvedBody ~= nil)
check(
	"the won-round announcement is not LINES.taken",
	solvedBody ~= nil and string.find(solvedBody :: string, "LINES.taken", 1, true) == nil
)

-- WHO THE OPERATOR IS ALLOWED TO ACCUSE ------------------------------------
--
-- Same family as the keypad channels above, one layer up. `Rejected` is
-- private and station-tagged, so R10's fan-out cannot happen -- but the
-- Operator's `busy` line was still fired for EVERY `not ok`, and one of those
-- refusals ("already restored") is nobody's doing. Two players at one keypad
-- both enter the number they were told; the loser of the frame was told the
-- line was busy for typing the right answer, in the same tick as the win line.
-- The voice is now gated on `result.fault`; the keypad note is not.
print("")
print("the Operator only accuses a player at fault")

local faultGate = submitBody and string.match(submitBody :: string, "if result%.fault then.-\n\t\tend")
check("the Submit handler gates on result.fault", faultGate ~= nil)
check(
	"the Operator's line is inside that gate",
	faultGate ~= nil and string.find(faultGate :: string, "heardRemote:FireClient", 1, true) ~= nil
)
-- The other half, and the one a careless fix would break: the keypad note is
-- information, not an accusation, so gating it too would leave a blameless
-- player staring at a keypad that said nothing at all.
check(
	"but the station-tagged keypad note is NOT",
	faultGate ~= nil and string.find(faultGate :: string, "rejectedRemote:FireClient", 1, true) == nil
)
check(
	"and the Submit handler still sends one",
	submitBody ~= nil and string.find(submitBody :: string, "rejectedRemote:FireClient", 1, true) ~= nil
)
-- Guard: the gate must be the only `heardRemote` in the submit path, or a
-- second unguarded call would say `busy` anyway and every check above would
-- still pass. The station refusal earlier in the handler is the actor's fault
-- by construction (they submitted an id for a keypad they never reached), so it
-- keeps its voice line -- that is one, and the gated one is two.
local heardInSubmit = submitBody and select(2, string.gsub(submitBody :: string, "heardRemote:FireClient", ""))
check(`the submit path speaks in exactly two places, both deliberate ({tostring(heardInSubmit)})`, heardInSubmit == 2)

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

-- A SUITE FILE THAT IS NEVER RUN. `test.cmd` hand-keeps the list of suites, so
-- a new test file that never reaches that line ships unrun and the suite still
-- prints `suite passed` -- this project's oldest shape (a thing written and
-- wired to nothing) aimed at the guard rig itself. R15 added
-- `tests/heuristic.luau`, and this is what stops the next one being forgotten.
--
-- Both lists are DERIVED: the suites from the `for %%T in (...)` line, and the
-- helper files from the fact that another test requires them. Nothing here is
-- hand-kept, so it cannot drift the way `test.cmd` did.
print("every test file is actually run")
local testCmd = fs.readFile("test.cmd")
local suiteList = string.match(testCmd, "for %%%%T in %(([^)]*)%)")
check("test.cmd's suite list was found (guard)", suiteList ~= nil)

local declared: { [string]: boolean } = {}
local declaredCount = 0
if suiteList then
	for name in string.gmatch(suiteList :: string, "%S+") do
		declared[name] = true
		declaredCount += 1
	end
end
check("and it names more than one suite (guard)", declaredCount > 1)

-- Anything another test requires as `./name` is a helper, not a suite.
local helpers: { [string]: boolean } = {}
local testFiles: { string } = {}
for _, entry in fs.readDir("tests") do
	local stem = string.match(entry, "^(.+)%.luau$")
	if stem then
		table.insert(testFiles, stem)
		for required in string.gmatch(fs.readFile(`tests/{entry}`), 'require%("%./([%w_]+)"%)') do
			helpers[required] = true
		end
	end
end
check("tests/ was read and holds files (guard)", #testFiles > 1)
check("and helper files were detected (guard)", helpers.harness == true)

table.sort(testFiles)
for _, stem in testFiles do
	if not helpers[stem] then
		check(`tests/{stem}.luau is listed in test.cmd`, declared[stem] == true)
	end
end
-- The other direction: a suite renamed or deleted leaves test.cmd invoking a
-- file that is not there.
local declaredSorted: { string } = {}
for name in declared do
	table.insert(declaredSorted, name)
end
table.sort(declaredSorted)
for _, name in declaredSorted do
	check(`test.cmd's '{name}' exists as tests/{name}.luau`, fs.isFile(`tests/{name}.luau`))
end

print("")
print("the round can be LOST, not only won")

-- R16 wrote `Connected.allTaken` and nothing ever called it, so the Operator
-- could take every player and the round would just sit there: board still open,
-- nothing said, no way to finish. A capability written and never wired reads as
-- a shipped feature in the log and is invisible to every other test, so the
-- wiring itself is asserted here rather than the logic (which tests/connected
-- already covers).

local serverSource = fs.readFile("src/server/init.server.luau")
local serverCode = LuauCode.stripNonCode(serverSource)

check("`allTaken` is actually called in the server", string.find(serverCode, "allTaken(", 1, true) ~= nil)
check("the loss says its own line", string.find(serverCode, "LINES.lost", 1, true) ~= nil)

-- Three opposite events must not share one sentence. `completed` and `taken`
-- were already split for exactly this reason; `lost` must not undo it.
-- RAW source, not stripped. These lines ARE string bodies, and the lexer
-- removes string bodies -- reading them from stripped code finds nothing and
-- every comparison below then passes vacuously on nil. Same reasoning as the
-- remote-names block above.
local roundCode = fs.readFile("src/server/systems/Round.luau")
local said: { [string]: string } = {}
for key, text in string.gmatch(roundCode, '(%w+) = "([^"]+)",') do
	said[key] = text
end
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

-- It must stop hunting once there is nobody left, or the hum runs over a
-- finished round.
-- Newline built with string.char rather than an escape: this repo's tooling has
-- twice collapsed a backslash in a patch and turned "\n" inside a Luau string
-- into a real line break, producing "Malformed string".
local NL = string.char(10)
local capture = string.match(serverCode, "local function takeWhoeverIsHere%(.-" .. NL .. "end") or ""
check("(guard) found the capture function", #capture > 0)
check("the loss stops the Operator", string.find(capture, "pursuit:stop()", 1, true) ~= nil)
-- R49 moved the losing rule into `endTheRoundIfNobodyCanWin`, which the capture
-- path and the tick both ask, so the capture path no longer calls `allTaken`
-- directly. The rule's own checks are further down; this one only has to say
-- that capture still asks SOMETHING about losing.
check("the capture path still decides losses", string.find(capture, "endTheRoundIfNobodyCanWin", 1, true) ~= nil)

print("")
print("capture runs on the clock, not only on arrival")

-- R24. `tests/connected.luau` proves the RULE; this proves the SERVER runs it.
-- Capture used to be reachable from exactly one place — the `arrived`
-- transition — and `Pursuit.setState` returns early when the state has not
-- changed, so the Operator took whoever stood in the room at that one instant
-- and was harmless afterwards. A player could walk in and stay a minute.

local captureCalls = 0
local from = 1
while true do
	local first, last = string.find(serverCode, "takeWhoeverIsHere()", from, true)
	if not first then
		break
	end
	from = last + 1
	captureCalls += 1
end
-- One is the declaration, so two call sites means three occurrences.
check(`capture is reachable from more than one place ({captureCalls} occurrences)`, captureCalls >= 3)

local tickBody = string.match(serverCode, "task.spawn%(function%(%).-" .. string.char(10) .. "end%)") or ""
check("(guard) found the server tick loop", #tickBody > 0)
-- `pursuit.state` is CODE; the literal "arrived" is a string body the lexer
-- strips, so asking the stripped tick for it always fails. Same trap R18 hit
-- reading the Operator's lines out of stripped source.
check("the tick asks the Operator's state", string.find(tickBody, "pursuit.state", 1, true) ~= nil)
local rawTick = string.match(serverSource, "task.spawn%(function%(%).-" .. string.char(10) .. "end%)") or ""
check("(guard) found the tick in raw source too", #rawTick > 0)
check("and compares it against arrived", string.find(rawTick, "arrived", 1, true) ~= nil)
check("the tick runs capture", string.find(tickBody, "takeWhoeverIsHere()", 1, true) ~= nil)
check("the tick is paced by a dial, not a literal", string.find(tickBody, "Config.TickSeconds", 1, true) ~= nil)
check("decay keeps its own slower beat", string.find(tickBody, "Config.DecaySeconds", 1, true) ~= nil)

-- R25. The room must be RELEASED, or capture-while-arrived (R24) becomes a
-- permanent softlock: one plain word parks the Operator on an objective and
-- nobody can ever finish that station.
-- R36. A queued room is only taken up when the Operator is idle, so the server
-- has to ask. Without this the queue fills and nothing ever drains it.
check("the tick takes up a queued room", string.find(tickBody, "pursuit:takePending()", 1, true) ~= nil)

-- R49. Losing is asked on every beat, not only when the Operator arrives. R48
-- put it in the capture path alone and the soak measured the cost: 134 ticks of
-- a stranded round still running after the Operator had walked away.
check(
	"the tick asks whether the round is already lost",
	string.find(tickBody, "endTheRoundIfNobodyCanWin", 1, true) ~= nil
)

check("the tick asks whether it should leave", string.find(tickBody, "shouldLeave", 1, true) ~= nil)
check("the linger is a dial, not a literal", string.find(tickBody, "Config.LingerSeconds", 1, true) ~= nil)
-- R26: it WALKS out rather than switching off in place, and says so. `stop()`
-- released the room silently with the body motionless -- nothing told players
-- it was safe.
check("and the tick actually releases it", string.find(tickBody, "pursuit:withdrawTo", 1, true) ~= nil)

-- R29. A finished round is not a hunting ground, and there has to BE a next one.
check("capture is gated on the round still being played", string.find(tickBody, "round:isPlaying()", 1, true) ~= nil)

-- R32. Gating capture alone left the Operator announcing itself and walking
-- audibly through an intermission it could take nobody in. The FEED has to be
-- gated too, or the hum means nothing some of the time -- which is worse than
-- no hum, because the hum is the game.
local chatBody = string.match(serverCode, "TextChatService.OnIncomingMessage = function.-" .. NL .. "end") or ""
check("(guard) found the chat handler", #chatBody > 0)
check("...and it is the one that feeds the Operator (control)", string.find(chatBody, "operator:hear", 1, true) ~= nil)
check("the Operator only listens while a round is live", string.find(chatBody, "round:isPlaying()", 1, true) ~= nil)

-- R42. The Operator's OWN lines contain plain giveaways -- "Number, please." is
-- its greeting, and `number` is plain language for `jack_number`. That is not a
-- defect ONLY because its speech is delivered by RemoteEvent and never routed
-- back through `hear`, so it cannot summon itself. That exemption has to earn
-- itself rather than be believed, so: chat is the only thing that feeds it.
local fedFrom = 0
local at = 1
while true do
	local first, last = string.find(serverCode, "operator:hear", at, true)
	if not first then
		break
	end
	at = last + 1
	fedFrom += 1
end
check(`(guard) the Operator is fed at all ({fedFrom})`, fedFrom >= 1)
check("nothing but the chat handler feeds the Operator", fedFrom == 1)
check("...and that one call is inside the chat handler", string.find(chatBody, "operator:hear", 1, true) ~= nil)

-- R33, applying R32's lesson: enumerate EVERY behaviour the phase suppresses,
-- not the one that motivated the gate. Submit is the last place that takes
-- player input, and it checked isConnected, the station gate and the jam --
-- never the phase. So a player typed the number they were told into a keypad
-- the game still drew, and it vanished into a round that was over.
-- Named apart from the `submitBody` extracted earlier in this file; two locals
-- of the same name in one scope is legal Luau and reads like a bug.
local submitPhaseBody = string.match(serverCode, "submitRemote.OnServerEvent:Connect%(function.-" .. NL .. "end%)")
	or ""
check("(guard) found the submit handler", #submitPhaseBody > 0)
check(
	"...and it is the one that scores answers (control)",
	string.find(submitPhaseBody, "board:submit", 1, true) ~= nil
)
check("a finished round takes no more answers", string.find(submitPhaseBody, "round:isPlaying()", 1, true) ~= nil)

-- R39. Being AT a station is a place, not a memory of a trigger. Without a
-- position check here a player primes the Switchboard, walks 104 studs to the
-- room where the number is being read out, and patches from beside the reader.
check("submit reads where the player actually is", string.find(submitPhaseBody, "livePositions()", 1, true) ~= nil)
check("...and measures it against the station", string.find(submitPhaseBody, "Layout.within", 1, true) ~= nil)
check("...using the dial, not a literal", string.find(submitPhaseBody, "Config.StationReach", 1, true) ~= nil)
check("...against the position World built", string.find(submitPhaseBody, "built.stationAt", 1, true) ~= nil)

check("the tick waits out an intermission", string.find(tickBody, "Config.IntermissionSeconds", 1, true) ~= nil)
check("and starts the next round", string.find(tickBody, "beginRound()", 1, true) ~= nil)

-- R30. A new round must PLACE the Operator back at its post, not merely stop it:
-- `stop()` leaves the position where the last round ended, so round two began
-- with it standing inside a room and the next understanding arrived instantly
-- and silently.
local beginBody = string.match(serverCode, "local function beginRound%(%).-" .. NL .. "end") or ""
check("(guard) found beginRound", #beginBody > 0)
check("a new round sends the Operator home", string.find(beginBody, "pursuit:sendHome", 1, true) ~= nil)
check("...to the post World built, not a literal", string.find(beginBody, "built.operatorStart", 1, true) ~= nil)

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

-- `round` is the lifecycle itself: the TICK restarts it, and beginRound runs
-- after that, so it is handled by construction rather than reset here. It is
-- the only exemption, and it is named with its reason.
local EXEMPT: { [string]: boolean } = { round = true }

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

local leavingBody = string.match(serverCode, "Players.PlayerRemoving:Connect.-" .. NL .. "end%)") or ""
check("(guard) found the PlayerRemoving handler", #leavingBody > 0)

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
check(`(guard) found the per-player tables ({table.concat(perPlayer, ", ")})`, #perPlayer >= 2)

for _, name in perPlayer do
	check(
		`a player who leaves is cleared from '{name}'`,
		string.find(leavingBody, name .. "[player.UserId] = nil", 1, true) ~= nil
	)
end

-- (control) the reader must actually be able to fail. A table name that is not
-- cleared anywhere must not be reported as clean.
check(
	"(control) a table nobody clears would be caught",
	string.find(leavingBody, "notATable[player.UserId] = nil", 1, true) == nil
)

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

local dispatchBody = string.match(serverCode, "local function putThroughTheSilentLine%(%).-" .. NL .. "end") or ""
check("(guard) found the dispatch", #dispatchBody > 0)

local askedAt = string.find(dispatchBody, "onItsWay = pursuit:sendTo", 1, true)
check("it asks whether the call went through", askedAt ~= nil)

local bailedAt = string.find(dispatchBody, "if not onItsWay then", 1, true)
check("...and bails out when it did not", bailedAt ~= nil)

local forgaveAt = string.find(dispatchBody, "supervisor:called", 1, true)
local saidAt = string.find(dispatchBody, "Round.LINES.traced", 1, true)
check("(guard) it does forgive the player somewhere", forgaveAt ~= nil)
check("(guard) ...and does say the line somewhere", saidAt ~= nil)

if askedAt and bailedAt and forgaveAt and saidAt then
	check("the bail-out comes after the question", bailedAt > askedAt)
	check("a queued call never forgives the player", forgaveAt > bailedAt)
	check("...and is never announced", saidAt > bailedAt)
	-- And the announcement is gated a second time, so a trip already under way
	-- to that room punishes the silence without saying it twice.
	local alreadyAt = string.find(dispatchBody, "if not alreadyComing then", 1, true)
	check("a trip already under way is not announced again", alreadyAt ~= nil and alreadyAt < saidAt)
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
local everything = serverCode .. LuauCode.stripNonCode(fs.readFile("src/client/init.client.luau"))
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
check(
	"the server fires it at ONE client, never everyone",
	string.find(serverCode, "silenceRemote:FireClient", 1, true) ~= nil
)
check(
	"...and never broadcasts a player's own clock",
	string.find(serverCode, "silenceRemote:FireAllClients", 1, true) == nil
)
-- The words and the fill come from Shared.Silence, so the client cannot restate
-- a threshold the server does not use -- R20's defect, in a new panel.
check("the client is sent the words from Shared.Silence", string.find(serverCode, "Silence.note(", 1, true) ~= nil)
check("...and the fill from Shared.Silence", string.find(serverCode, "Silence.pressure(", 1, true) ~= nil)

-- R58. The server speaks only on a band change, so a client that draws only what
-- it was told shows three bar positions in a whole countdown. The fill between
-- pushes must come from `Shared.Silence`, not from arithmetic restated here --
-- R20's defect, and the thing this client's own comment already claimed.
check("the client fills the bar from Shared.Silence", string.find(clientCode, "Silence.fill(", 1, true) ~= nil)
check("...every frame, not only on a push", string.find(clientCode, "RunService.RenderStepped", 1, true) ~= nil)
check("the server sends how long is left", string.find(serverCode, "Silence.secondsLeft(", 1, true) ~= nil)
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

local captureBody = string.match(serverCode, "local function takeWhoeverIsHere%(%).-" .. NL .. "end") or ""
check("(guard) found the capture path", #captureBody > 0)
local connectAt = string.find(captureBody, "line:connect(userId, os.clock())", 1, true)
local forgetAt = string.find(captureBody, "supervisor:forget(userId)", 1, true)
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

for _, path in { "putThroughTheSilentLine", "takeWhoeverIsHere" } do
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
	string.find(soakCode, ":reachedInRoom(", 1, true) ~= nil
)

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
	"connectedRemote%.OnClientEvent:Connect%(function%(caught: boolean%).-" .. NL .. "end%)"
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
print("")
print("private remotes are never broadcast")

local PRIVATE_REMOTES = { "Objectives", "OpenBoard", "Rejected", "Connected" }
for _, name in PRIVATE_REMOTES do
	local var = string.match(serverSource, `local ([%a][%w_]*) = Remotes%.get%("{name}"%)`)
	check(`(guard) found the local '{name}' is bound to`, var ~= nil)
	if var then
		check(
			`'{name}' (as {var}) never fires FireAllClients`,
			string.find(serverCode, var .. ":FireAllClients", 1, true) == nil
		)
	end
end

-- (control) a remote that DOES broadcast (Phase, meant for everyone) must not
-- be reported as private-and-clean by a reader that is not actually looking.
local phaseVar = string.match(serverSource, 'local ([%a][%w_]*) = Remotes%.get%("Phase"%)')
check("(guard) found Phase's local", phaseVar ~= nil)
check(
	"(control) Phase really does broadcast, so the sweep is not vacuous",
	phaseVar ~= nil and string.find(serverCode, phaseVar .. ":FireAllClients", 1, true) ~= nil
)

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

-- Winning must stop the monster. Until R29 it did not, so a group finished the
-- board and was then taken by something that had no idea the round was over.
-- NL built with string.char, never an escape: this repo's patching has turned
-- "\n" inside a Luau string into a real line break three times now (R22, R24,
-- and again this round).
local solvedBlock = string.match(serverCode, "if board:allSolved%(%).-" .. NL .. "\tend") or ""
check("(guard) found the win path", #solvedBlock > 0)
check("winning goes through the lifecycle", string.find(solvedBlock, "round:finish", 1, true) ~= nil)
check("winning stops the Operator", string.find(solvedBlock, "pursuit:stop()", 1, true) ~= nil)
-- R33. And the client has to be TOLD. Every place the phase changes must push it, or
-- the panel is stale exactly when it matters.
check("the phase is pushed when the round is won", string.find(solvedBlock, "pushPhase", 1, true) ~= nil)

-- R48/R49. Everyone taken is one way to lose; nobody LEFT being able to finish
-- anything is the other. Three of four caught in one arrival strands a line with
-- its reader, and the survivor could then neither win nor be forced to lose.
--
-- R48 put this inside the capture path. R49's soak measured what that cost --
-- 134 ticks of a stranded round still running after the Operator walked away --
-- so it now lives in a function of its own that BOTH the capture path and the
-- tick ask. These checks follow it there.
local loseBody = string.match(serverCode, "local function endTheRoundIfNobodyCanWin%(.-" .. NL .. "end") or ""
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
check("a round nobody can finish is also lost", string.find(loseBody, "board:anyFinishable(able)", 1, true) ~= nil)
check("...and a WON board is excluded from it", string.find(loseBody, "board:allSolved()", 1, true) ~= nil)
check(
	"...measured against the players who can still act",
	string.find(loseBody, "line:isConnected(userId)", 1, true) ~= nil
)
-- The clause that stops a solo server losing instantly and looping: a board
-- nobody can finish with NOBODY connected is the dealing problem, not a round
-- that play has stranded.
check("...and only when play stranded it", string.find(loseBody, "line:count() > 0", 1, true) ~= nil)

local captureBody = string.match(serverCode, "local function takeWhoeverIsHere%(%).-" .. NL .. "end") or ""
check("(guard) found the capture path", #captureBody > 0)
check("the capture path asks the losing rule", string.find(captureBody, "endTheRoundIfNobodyCanWin", 1, true) ~= nil)
check("...and announces it (control)", string.find(captureBody, "LINES.lost", 1, true) ~= nil)
-- RAW source: the remote name is a string body and the lexer strips those, so
-- against `clientCode` this reads `Remotes.get()` and never matches. Fifth time
-- this project has hit that; the remote-names block above says the same thing.
check("the client listens for the phase", string.find(clientSource, 'Remotes.get("Phase")', 1, true) ~= nil)
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
check("...and renders the rows it returns", string.find(clientCode, "Readout.lineRows(entries)", 1, true) ~= nil)

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
	string.find(clientCode, "phaseRemote.OnClientEvent:Connect(onPhase)", 1, true) ~= nil
)
check("the release is announced", string.find(tickBody, "LINES.givingUp", 1, true) ~= nil)

print("")
print("nothing the client DISPLAYS is a giveaway")

-- R43, finishing what R41 and R42 started. Those checked the station prompts and
-- the panel's exported constants. The client's own inline literals were judged
-- "coherent" BY EYE — and one was not: the keypad hint read "enter the NUMBER
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
local AFTER_THE_ROUND: { [string]: boolean } = {
	["The board was restored."] = true,
}

-- Three shapes, because the client displays text three ways. The first draft
-- collected only two and found THREE strings while the client shows six -- the
-- coverage guard below caught that rather than letting a narrow sweep pass.
local clientRaw = fs.readFile("src/client/init.client.luau")
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

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
