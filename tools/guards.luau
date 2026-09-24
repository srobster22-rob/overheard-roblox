--!strict
-- A lint over src: every connection and every spawned, deferred or delayed task
-- goes through `Guard.wrap`, so an error in one is kept with its tag instead of
-- lost. Prints `path:line: what` for each call whose arguments do not include
-- `Guard.wrap(`, and exits 1. Comments and strings are not code, so a mention
-- never counts.

local fs = require("@lune/fs")
local process = require("@lune/process")

local LuauCode = require("../tests/luaucode")

local RULES = {
	{ pattern = ":Connect%(", what = "a connection not under Guard.wrap" },
	{ pattern = "task%.spawn%(", what = "a spawned task not under Guard.wrap" },
	{ pattern = "task%.defer%(", what = "a deferred task not under Guard.wrap" },
	{ pattern = "task%.delay%(", what = "a delayed task not under Guard.wrap" },
}

local function walk(dir: string, out: { string })
	for _, entry in fs.readDir(dir) do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			walk(path, out)
		elseif string.find(entry, "%.luau$") then
			table.insert(out, path)
		end
	end
end

-- The text between the `(` at `open` and its matching `)`.
local function arguments(code: string, open: number): string
	local depth = 0
	for i = open, #code do
		local c = string.sub(code, i, i)
		if c == "(" then
			depth += 1
		elseif c == ")" then
			depth -= 1
			if depth == 0 then
				return string.sub(code, open + 1, i - 1)
			end
		end
	end
	return string.sub(code, open + 1)
end

local files: { string } = {}
walk("src", files)
table.sort(files)

local found = 0
for _, path in files do
	if path == "src/shared/Guard.luau" then
		continue
	end
	local raw = fs.readFile(path)
	local code = LuauCode.stripNonCode(raw)
	-- Stripping drops the line breaks inside a long comment or string, and then
	-- the line numbers below drift. Say so rather than point at a wrong line.
	if #string.split(code, "\n") ~= #string.split(raw, "\n") then
		print(`{path}: (line numbers below may drift: a long comment or string)`)
	end
	for _, rule in RULES do
		local from = 1
		while true do
			local _, open = string.find(code, rule.pattern, from)
			if not open then
				break
			end
			if not string.find(arguments(code, open), "Guard.wrap(", 1, true) then
				local _, breaks = string.gsub(string.sub(code, 1, open), "\n", "")
				print(`{path}:{breaks + 1}: {rule.what}`)
				found += 1
			end
			from = open + 1
		end
	end
end

if found > 0 then
	print(`{found} unguarded in src`)
	process.exit(1)
end
print(`every connection and task in src is guarded ({#files} files)`)
