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

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
