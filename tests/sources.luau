--!strict
-- The server's code, as the checks that read source see it: the entry script
-- and systems/Exchange (the flow it hands its host), with the one level of
-- indent inside `Exchange.build` taken off, so each function reads as it did at
-- the top of the entry script. tests/exchange.luau runs the same flow with a
-- fake host; these source checks are being replaced by it.

local fs = require("@lune/fs")

local Sources = {}

local function dedent(text: string): string
	local out = {}
	for _, line in string.split(text, "\n") do
		table.insert(out, if string.sub(line, 1, 1) == "\t" then string.sub(line, 2) else line)
	end
	return table.concat(out, "\n")
end

-- The entry script, then the flow, both raw.
function Sources.server(): string
	return fs.readFile("src/server/init.server.luau") .. "\n" .. dedent(fs.readFile("src/server/systems/Exchange.luau"))
end

return Sources
