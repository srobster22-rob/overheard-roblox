--!strict
-- Builds the shipped place (default.project.json) and checks that nothing only
-- the dev project adds made it in. dev.project.json puts test code the Studio
-- runner needs under ServerScriptService.Dev; none of it may ship.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local rokit = `{process.env.USERPROFILE or ""}\\.rokit\\bin\\rojo.exe`
local rojo = if fs.isFile(rokit) then rokit else "rojo"
local built = `{process.env.TEMP or "."}\\overheard-check.rbxlx`

local result = process.exec(rojo, { "build", "-o", built })
if not result.ok then
	print(result.stdout)
	print(result.stderr)
	process.exit(1)
end

local dev = serde.decode("json", fs.readFile("dev.project.json"))
local devOnly = dev.tree.ServerScriptService.Dev
local place = fs.readFile(built)
local checked = 0
for name in devOnly do
	if string.sub(name, 1, 1) ~= "$" then
		checked += 1
		if string.find(place, `<string name="Name">{name}</string>`, 1, true) then
			print(`the shipped place holds dev-only test code: {name} (see dev.project.json)`)
			process.exit(1)
		end
	end
end
print(`built; the shipped place holds none of the {checked} dev-only modules`)
