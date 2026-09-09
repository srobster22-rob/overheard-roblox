--!strict
-- Guard: a `local function` must be declared before anything calls it.
--
-- Luau closes over locals lexically. A closure written ABOVE a
-- `local function f` does not capture it — the name resolves to a global, which
-- is `nil`, and the call errors only when that code path finally runs. Nothing
-- catches this: it compiles, `selene` passes, and the headless suite never
-- executes `init.server`.
--
-- R16 shipped exactly this. `takeWhoeverIsHere` (line 72) called
-- `pushObjectives` (line 105), so the FIRST TIME the Operator ever arrived --
-- the payoff the whole game builds toward -- the server would have errored
-- instead. Found by reading, not by running, which is precisely why it is now
-- a test.

local fs = require("@lune/fs")
local process = require("@lune/process")

local LuauCode = require("./luaucode")

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

-- Only files that RUN top to bottom need this. A ModuleScript's functions are
-- all defined before anything calls them, because the caller is another module.
local ENTRY_POINTS = {
	"src/server/init.server.luau",
	"src/client/init.client.luau",
}

-- Returns declaration line per local function, and every line that calls one.
local function analyse(source: string)
	local code = LuauCode.stripNonCode(source)

	local declaredAt: { [string]: number } = {}
	local lines: { string } = {}
	for lineText in string.gmatch(code .. "\n", "([^\n]*)\n") do
		table.insert(lines, lineText)
	end

	for number, text in lines do
		local name = string.match(text, "^%s*local function ([%w_]+)")
		if name and not declaredAt[name] then
			declaredAt[name] = number
		end
	end

	return declaredAt, lines
end

for _, path in ENTRY_POINTS do
	print(path)
	local declaredAt, lines = analyse(fs.readFile(path))

	local declaredCount = 0
	for _ in declaredAt do
		declaredCount += 1
	end
	-- If the scan finds nothing, every check below passes vacuously.
	check(`  (guard) found local functions to check`, declaredCount > 0)

	for number, text in lines do
		for name, declLine in declaredAt do
			-- A call, not the declaration itself and not a mention.
			if number == declLine then
				continue
			end
			local pattern = "[^%w_]" .. name .. "%s*%("
			if string.find(" " .. text, pattern) then
				if number < declLine then
					check(`  '{name}' called on line {number} is declared on {declLine}`, false)
				end
			end
		end
	end
end

-- The guard must be able to fail, or it proves nothing. Synthetic source with a
-- known use-before-declaration.
print("the guard itself")
local bad = "local function early()\n\tlate()\nend\n\nlocal function late()\nend\n"
local declaredAt, lines = analyse(bad)
check("it sees both declarations", declaredAt.early == 1 and declaredAt.late == 5)
local caught = false
for number, text in lines do
	if string.find(" " .. text, "[^%w_]late%s*%(") and number < declaredAt.late then
		caught = true
	end
end
check("it flags a call above its declaration", caught)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
