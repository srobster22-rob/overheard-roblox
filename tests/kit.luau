--!strict
-- The checker every suite shares. A failing check prints the file and line
-- that made it, so `tools/check` can say where a failure is without anyone
-- reading the suite's whole output.
--
--     local Kit = require("./kit")
--     local check = Kit.check
--     check("a thing holds", thing == true)
--     Kit.finish() -- last line: prints the count, exits 1 on any failure

local process = require("@lune/process")

local Kit = {}

local checks = 0
local failures = 0

-- The caller's `file:line`, relative to the repo root the suites run from.
local function callSite(level: number): string
	local source, line = debug.info(level + 1, "sl")
	local path = string.gsub(source or "?", "\\", "/")
	local root = string.gsub(process.cwd, "\\", "/")
	if string.sub(path, 1, #root) == root then
		path = string.sub(path, #root + 1)
	end
	if not string.find(path, "%.luau$") then
		path ..= ".luau"
	end
	return `{path}:{line}`
end

function Kit.check(name: string, condition: any)
	checks += 1
	if condition then
		print(`  ok    {name}`)
	else
		failures += 1
		print(`  FAIL  {name}  ({callSite(2)})`)
	end
end

-- Ends the suite: the pass count `tools/check` reads, and the exit code.
function Kit.finish()
	print(`\n{checks - failures}/{checks} passed`)
	if failures > 0 then
		process.exit(1)
	end
end

return Kit
