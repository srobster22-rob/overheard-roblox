--!strict
-- The one check command: every gate the SHIP gate needs, run in turn, ending
-- with a summary that names each failing gate, its first failing assertion and
-- where it is. `test.cmd` runs this.
--
--     lune run tools/check               every gate
--     lune run tools/check heuristic     only the gates whose names contain it
--     lune run tools/check verbose       and print every gate's output
--
-- Exits 1 if any gate failed.

local process = require("@lune/process")
local fs = require("@lune/fs")

local Suites = require("./suites")

local ROKIT = `{process.env.USERPROFILE or ""}\\.rokit\\bin`

-- A tool installed by rokit, or the bare name if it is on PATH instead.
local function tool(name: string): string
	local path = `{ROKIT}\\{name}.exe`
	return if fs.isFile(path) then path else name
end

type Gate = { name: string, program: string, args: { string } }

local function gates(): { Gate }
	local lune = tool("lune")
	local list: { Gate } = {}
	for _, suite in Suites.list() do
		table.insert(list, { name = suite, program = lune, args = { "run", `tests/{suite}` } })
	end
	-- The bot and session players: their traces are evidence in LOOP_LOG, so they
	-- must keep running. `gate` fails if the bots win no round at all.
	table.insert(
		list,
		{ name = "bots", program = lune, args = { "run", "tools/playtest", "quiet", "2", "11", "gate" } }
	)
	table.insert(list, { name = "smoke", program = lune, args = { "run", "tools/play", "tools/sessions/smoke.txt" } })
	-- MARKET.md's totals and gap values must be the ones its matrix computes.
	table.insert(list, { name = "market", program = lune, args = { "run", "tools/market", "check" } })
	table.insert(list, { name = "selene", program = tool("selene"), args = { "src" } })
	table.insert(list, { name = "stylua", program = tool("stylua"), args = { "--check", "src", "tests", "tools" } })
	local built = `{process.env.TEMP or "."}\\overheard-check.rbxlx`
	table.insert(list, { name = "rojo", program = tool("rojo"), args = { "build", "-o", built } })
	return list
end

local ROOT = string.lower((string.gsub(process.cwd, "\\", "/")))

-- A repo-relative `path.luau:line` for a path a tool printed. Lune prints
-- absolute paths and drops the extension; selene and stylua keep it.
local function place(path: string, line: string?): string
	local p = string.gsub(path, "\\", "/")
	if string.sub(string.lower(p), 1, #ROOT) == ROOT then
		p = string.sub(p, #ROOT + 1)
	end
	if not string.find(p, "%.luau$") then
		p ..= ".luau"
	end
	return if line then `{p}:{line}` else p
end

local function trim(s: string): string
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end

-- How each tool says what failed, tried in this order over the whole output.
-- Each returns the failure, with its place where the output has one.
type Reader = (lines: { string }, i: number) -> string?
local READERS: { Reader } = {
	-- A suite's failed check, which carries its place already (tests/kit).
	function(lines, i)
		return string.match(lines[i], "^%s*(FAIL%s+.+)$")
	end,
	-- A runtime error: `path:line: message`.
	function(lines, i)
		local path, n, message = string.match(lines[i], "^(.-):(%d+): (.+)$")
		if path and string.find(path, "[/\\]") then
			return `{trim(message)}  ({place(path, n)})`
		end
		return nil
	end,
	-- selene: `warning[rule]: message`, its place on the next line.
	function(lines, i)
		local lint = string.match(lines[i], "^(%a+%[[%w_]+%]: .+)$")
		if not lint then
			return nil
		end
		local path, n = string.match(lines[i + 1] or "", "─ (.-):(%d+):%d+")
		return if path then `{trim(lint)}  ({place(path, n)})` else trim(lint)
	end,
	-- stylua: `Diff in path:`.
	function(lines, i)
		local path = string.match(lines[i], "^Diff in (.+):$")
		return if path then `not formatted  ({place(path)})` else nil
	end,
	-- The bot gate, and a session line the player refused.
	function(lines, i)
		return string.match(lines[i], "^(GATE: .+)$") or string.match(lines[i], "^(line %d+: .+)$")
	end,
	-- The market check: the first problem is on the next line.
	function(lines, i)
		if string.find(lines[i], "disagrees with its own matrix", 1, true) then
			return `{trim(lines[i])} {trim(lines[i + 1] or "")}`
		end
		return nil
	end,
	-- Anything else that says it failed.
	function(lines, i)
		if string.find(string.lower(lines[i]), "error") or string.find(lines[i], "FAILED", 1, true) then
			return trim(lines[i])
		end
		return nil
	end,
}

local function firstFailure(output: string): string
	local lines = string.split(output, "\n")
	for _, read in READERS do
		for i = 1, #lines do
			local found = read(lines, i)
			if found then
				return found
			end
		end
	end
	-- Nothing recognised: the last line the gate printed.
	for i = #lines, 1, -1 do
		if string.find(lines[i], "%S") then
			return trim(lines[i])
		end
	end
	return "(no output)"
end

local function checkCount(output: string): number
	return tonumber(string.match(output, "%d+/(%d+) passed")) or 0
end

local args = process.args
local verbose = table.find(args, "verbose") ~= nil
local only = {}
for _, a in args do
	if a ~= "verbose" then
		table.insert(only, a)
	end
end
local function wanted(name: string): boolean
	if #only == 0 then
		return true
	end
	for _, a in only do
		if string.find(name, a, 1, true) then
			return true
		end
	end
	return false
end

local started = os.clock()
local ran, checks = 0, 0
local failed: { { name: string, first: string } } = {}
for _, gate in gates() do
	if not wanted(gate.name) then
		continue
	end
	local t0 = os.clock()
	local result = process.exec(gate.program, gate.args)
	local output = result.stdout .. (if result.stderr ~= "" then "\n" .. result.stderr else "")
	local n = checkCount(output)
	ran += 1
	checks += n
	local took = string.format("%.1f s", os.clock() - t0)
	if result.ok then
		print(string.format("ok    %-12s %s", gate.name, if n > 0 then `{n} checks, {took}` else took))
		if verbose then
			print(output)
		end
	else
		table.insert(failed, { name = gate.name, first = firstFailure(output) })
		print(string.format("FAIL  %-12s exit %d, %s", gate.name, result.code, took))
		print(output)
	end
end

local total = string.format("%.1f s", os.clock() - started)
print("")
if #failed == 0 then
	print(`check passed: {ran} gates, {checks} checks, {total}`)
else
	print(`CHECK FAILED: {#failed} of {ran} gates ({checks} checks, {total})`)
	for _, f in failed do
		print(`  {f.name}: {f.first}`)
	end
	process.exit(1)
end
