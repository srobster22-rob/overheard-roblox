--!strict
-- Guards a whole class of quiet lie: a tuning dial that nothing reads.
--
-- `Config.CoolPerRound` sat in the config for three rounds with a comment
-- describing forgetting the game did not do, next to `Operator.cool`, whose
-- only caller in the entire repo was a test. Nothing failed, nothing warned;
-- the config just described a game that was not shipping.
--
-- So: every key at the TOP LEVEL of Config must be read somewhere under `src/`.
-- Dials for systems that do not exist yet belong under `Config.Planned`, where
-- they are visibly not live. Both halves are derived from the files, not from a
-- hand-maintained list, so this cannot drift.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".

local fs = require("@lune/fs")

local Kit = require("./kit")
local check = Kit.check

local CONFIG_PATH = "src/shared/Config.luau"
local REMOTES_PATH = "src/shared/Remotes.luau"

-- Every `.luau` under src/, except Config itself.
local function sources(dir: string, out: { string }): { string }
	for _, entry in fs.readDir(dir) do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			sources(path, out)
		elseif string.match(entry, "%.luau$") and path ~= CONFIG_PATH then
			table.insert(out, path)
		end
	end
	return out
end

-- A MENTION IS NOT A READ, and this has now fooled the guard twice.
--
-- R4's version searched the raw file text, so the single line
-- `-- Must cover every name in Config.Rooms.` in World.luau was enough to
-- certify `Config.Rooms` as a live dial; it was read nowhere in src/ for two
-- rounds and the suite printed `ok` every time. R6 stripped comments with two
-- regexes and closed that, then immediately hit the same defect in a new
-- place: its own new `error(...)` message named the dial, and the plant passed.
-- R6 filed the string-literal hole as unfixable, on the grounds that stripping
-- strings would kill `Config.GameName`, whose only reads live inside
-- interpolated strings.
--
-- It is fixable, and it does not need a parser. The distinction Luau itself
-- makes is exactly the one the guard wants: inside a backtick string, a
-- `{expr}` span IS code the compiler evaluates, and everything else in it is
-- text; inside `'...'`, `"..."` and `[[...]]`, NOTHING is code. So instead of
-- pattern-matching over the text, scan it left to right the way the lexer does,
-- keeping code and interpolation spans and dropping comment and string bodies.
--
-- The scanner also fixes two latent bugs the regexes had and nothing tested:
-- a `--` inside a string ate the rest of that line of real code, and a long
-- string `[[ ... ]]` was not stripped at all.
--
-- The scanner itself now lives in `tests/luaucode.luau`, because the leave-path
-- guard in `tests/objectives.luau` needs the same distinction and the two must
-- not drift apart. Its credibility is still proven here, below.
local stripNonCode = require("./luaucode").stripNonCode

local corpus = ""
for _, path in sources("src", {}) do
	corpus ..= stripNonCode(fs.readFile(path))
end

-- Top-level keys are indented exactly one tab; anything nested is deeper.
local configSource = fs.readFile(CONFIG_PATH)
local topLevel: { string } = {}
for line in string.gmatch(configSource, "[^\n]+") do
	local key = string.match(line, "^\t([%a][%w]*) = ")
	if key then
		table.insert(topLevel, key)
	end
end

-- The guard's own credibility, checked before it is trusted. If the scanner
-- silently stopped working, every check below would go back to accepting a
-- mention and would still print `ok`. Every form Luau has for holding text is
-- swept here, not a representative one, because R6's partial plant passed.
local function reads(sample: string): boolean
	return string.find(stripNonCode(sample), "Config.Ghost", 1, true) ~= nil
end

print("a mention is not a read")
check("a line comment naming a dial does not count", not reads("-- see Config.Ghost for this\n"))
check("a block comment naming a dial does not count", not reads("--[[ Config.Ghost ]]"))
check("a long-bracket block comment naming a dial does not count", not reads("--[==[ Config.Ghost ]==]"))
check("a double-quoted string naming a dial does not count", not reads('local s = "Config.Ghost"\n'))
check("a single-quoted string naming a dial does not count", not reads("local s = 'Config.Ghost'\n"))
check("a long string naming a dial does not count", not reads("local s = [[Config.Ghost]]\n"))
check("a long-bracket string naming a dial does not count", not reads("local s = [==[Config.Ghost]==]\n"))
check("backtick TEXT naming a dial does not count", not reads("local s = `Config.Ghost`\n"))
check("an escaped brace in a backtick string does not count", not reads("local s = `\\{Config.Ghost}`\n"))

print("")
print("but real code still reads")
check("a bare read counts", reads("local x = Config.Ghost\n"))
check("a read trailed by a comment counts", reads("local x = Config.Ghost -- a note\n"))
check("an interpolated read counts", reads("print(`hi {Config.Ghost} there`)\n"))
-- The reason R6 believed this hole could not be closed: GameName is read
-- ONLY through interpolation, so a guard that drops all string bodies would
-- report the game's own name as a dead dial.
check("an interpolated read beside text counts", reads("print(`[client] {Config.Ghost} ready`)\n"))
check("an interpolated read holding a table counts", reads("print(`{ #Config.Ghost } x`)\n"))
-- Both latent regex bugs, as tests: a `--` inside a string used to eat the
-- rest of the line, and `[[ ]]` was never stripped at all.
check("a string containing -- does not eat the code after it", reads('local s = "a -- b" .. Config.Ghost\n'))
check("a comment containing a quote does not eat the code after it", reads("-- it's fine\nlocal x = Config.Ghost\n"))
check("a long string is not treated as code", not reads("local s = [[ x ]] local y = [[Config.Ghost]]\n"))

print("")
print("every live dial is read")
check("Config has top-level keys to check", #topLevel > 0)
for _, key in topLevel do
	if key == "Planned" then
		continue
	end
	local used = string.find(corpus, `Config.{key}`, 1, true) ~= nil
	check(`'{key}' is read somewhere in src/`, used)
end

print("")
print("planned dials are declared, not live")
local planned = string.match(configSource, "Planned = {(.-)\n\t}")
check("a Planned block exists", planned ~= nil)
if planned then
	local count = 0
	for key in string.gmatch(planned, "\n\t\t([%a][%w]*) = ") do
		count += 1
		-- A planned dial that IS read should have been promoted out of Planned.
		check(`planned '{key}' is genuinely unwired`, string.find(corpus, `Config.{key}`, 1, true) == nil)
	end
	check("Planned is not empty", count > 0)
end

-- Remotes. The same family as the dials, one layer over: `REMOTE_NAMES` in
-- Remotes.luau is the hand-kept list of what the SERVER creates, and every
-- `Remotes.get("X")` call site is a separate hand-typed string. Fetch a name
-- nobody creates and `WaitForChild` yields forever — the UI panel behind it is
-- simply dead, on the client only, with no error printed anywhere.
--
-- Note this check reads the RAW source: these names live in string literals,
-- which is precisely what the scanner above throws away. Same class of bug,
-- opposite mechanism, so they cannot share one corpus.
print("")
print("remotes are created and used")
local remotesSource = fs.readFile(REMOTES_PATH)
local declared: { [string]: boolean } = {}
local declaredCount = 0
local namesList = -- Whitespace-tolerant, same as tests/wiring.luau: stylua wraps this declaration
	-- onto two lines once the list is long enough, and a pattern demanding `= {` on
	-- one line fails the moment a remote is added. The brittle version lived in BOTH
	-- files; R33 fixed one and the suite caught the other.
	string.match(remotesSource, "local REMOTE_NAMES%s*=%s*{(.-)}") or ""
for name in string.gmatch(namesList, '"([%w_]+)"') do
	declared[name] = true
	declaredCount += 1
end
check("REMOTE_NAMES was found in Remotes.luau", declaredCount > 0)

local fetched: { [string]: boolean } = {}
local fetchCount = 0
for _, path in sources("src", {}) do
	if path == REMOTES_PATH then
		continue
	end
	for name in string.gmatch(fs.readFile(path), 'Remotes%.get%("([%w_]+)"%)') do
		fetched[name] = true
		fetchCount += 1
	end
end
check("some call site fetches a remote", fetchCount > 0)
for name in fetched do
	check(`fetched remote '{name}' is created by the server`, declared[name] == true)
end
for name in declared do
	check(`created remote '{name}' is fetched somewhere`, fetched[name] == true)
end

Kit.finish()
