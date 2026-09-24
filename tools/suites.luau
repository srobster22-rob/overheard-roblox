--!strict
-- Which files in tests/ are suites. A file another test requires as `./name`
-- is a helper (the harness, the checker); every other .luau file is a suite,
-- and `tools/check` runs it. Derived from the files themselves, so a new
-- suite cannot be left out of the check the way a hand-kept list could.

local fs = require("@lune/fs")

local Suites = {}

local DIR = "tests"

local function stems(): { string }
	local out = {}
	for _, entry in fs.readDir(DIR) do
		local stem = string.match(entry, "^(.+)%.luau$")
		if stem then
			table.insert(out, stem)
		end
	end
	table.sort(out)
	return out
end

-- Every file some test requires as `./name`.
function Suites.helpers(): { [string]: boolean }
	local helpers = {}
	for _, stem in stems() do
		for required in string.gmatch(fs.readFile(`{DIR}/{stem}.luau`), 'require%("%./([%w_]+)"%)') do
			helpers[required] = true
		end
	end
	return helpers
end

-- Every suite, sorted: each file in tests/ that no test requires.
function Suites.list(): { string }
	local helpers = Suites.helpers()
	local out = {}
	for _, stem in stems() do
		if not helpers[stem] then
			table.insert(out, stem)
		end
	end
	return out
end

return Suites
