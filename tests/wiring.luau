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
local nameList = string.match(remotesSource, "local REMOTE_NAMES = {(.-)}") or ""
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
check("the client actually requires Keypad", string.find(clientCode, "require(ReplicatedStorage.Shared.Keypad)", 1, true) ~= nil)

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
check(
	"the server fires Rejected at ONE client",
	string.find(serverCode, "rejectedRemote:FireClient", 1, true) ~= nil
)
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
local sharedList = string.match(harnessSource, "for _, name in {(.-)} do\n\t\tadopt%(shared") or ""
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
check(
	`the submit path speaks in exactly two places, both deliberate ({tostring(heardInSubmit)})`,
	heardInSubmit == 2
)

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


print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
