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
local process = require("@lune/process")

local fs = require("@lune/fs")

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
local scanCode: (string, number, boolean, { string }) -> number
local scanBacktick: (string, number, { string }) -> number

-- Skips a long bracket `[==[ ... ]==]` opening at `i`, if there is one.
-- Returns the index after it, or nil when `i` is not a long bracket.
local function skipLongBracket(source: string, i: number, offset: number): number?
	local eq = string.match(source, "^%[(=*)%[", i + offset)
	if not eq then
		return nil
	end
	local _, closeEnd = string.find(source, `]{string.rep("=", #eq)}]`, i + offset, true)
	return if closeEnd then closeEnd + 1 else #source + 1
end

-- Text of a `'...'` or `"..."` string starting at `i`. Unterminated strings and
-- a raw newline both end it, so a stray quote cannot swallow the whole file.
local function skipShortString(source: string, i: number): number
	local quote = string.sub(source, i, i)
	local j = i + 1
	while j <= #source do
		local c = string.sub(source, j, j)
		if c == "\\" then
			j += 2
		elseif c == quote then
			return j + 1
		elseif c == "\n" then
			return j
		else
			j += 1
		end
	end
	return j
end

-- Inside a backtick string: drop the text, but hand every `{...}` span back to
-- the code scanner, because that span is code.
function scanBacktick(source: string, i: number, out: { string }): number
	while i <= #source do
		local c = string.sub(source, i, i)
		if c == "\\" then
			i += 2
		elseif c == "`" then
			return i + 1
		elseif c == "{" then
			table.insert(out, " ")
			i = scanCode(source, i + 1, true, out)
		else
			i += 1
		end
	end
	return i
end

-- Code. Emits code characters, emits a space for anything dropped so nothing
-- joins up across a hole. `stopAtBrace` is set inside an interpolation span and
-- for nested braces, so table constructors inside a `{...}` stay balanced.
function scanCode(source: string, i: number, stopAtBrace: boolean, out: { string }): number
	while i <= #source do
		local c = string.sub(source, i, i)
		if c == "}" and stopAtBrace then
			table.insert(out, " ")
			return i + 1
		elseif c == "{" then
			table.insert(out, " ")
			i = scanCode(source, i + 1, true, out)
		elseif c == "-" and string.sub(source, i + 1, i + 1) == "-" then
			local after = skipLongBracket(source, i, 2)
			if after then
				i = after
			else
				local newline = string.find(source, "\n", i, true)
				i = if newline then newline else #source + 1
			end
			table.insert(out, " ")
		elseif c == '"' or c == "'" then
			i = skipShortString(source, i)
			table.insert(out, " ")
		elseif c == "[" then
			local after = skipLongBracket(source, i, 0)
			if after then
				i = after
				table.insert(out, " ")
			else
				table.insert(out, c)
				i += 1
			end
		elseif c == "`" then
			table.insert(out, " ")
			i = scanBacktick(source, i + 1, out)
		else
			table.insert(out, c)
			i += 1
		end
	end
	return i
end

-- The source with every comment body and every string body removed, and
-- interpolation spans kept.
local function stripNonCode(source: string): string
	local out: { string } = {}
	scanCode(source, 1, false, out)
	return table.concat(out)
end

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
local namesList = string.match(remotesSource, "local REMOTE_NAMES = {(.-)}") or ""
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

print("")
print(`{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
