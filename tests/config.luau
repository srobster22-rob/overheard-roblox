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

local corpus = ""
for _, path in sources("src", {}) do
	corpus ..= fs.readFile(path)
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

print("")
print(`{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
