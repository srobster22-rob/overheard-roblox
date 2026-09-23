--!strict
-- A fake Roblox runtime, just big enough to load our server modules headlessly.
--
-- Why this exists: the acquisition loop is the heart of the game, and waiting on
-- Studio to verify it makes every iteration slow. This lets `lune` load modules
-- that call `game:GetService` and `require(script.Parent.X)` for real, with no
-- engine present. It is a test double, not an emulator - it supports exactly the
-- two require shapes our code uses, and will fail loudly on anything else.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Harness = {}

-- A stand-in for an Instance that can be required and indexed by child name.
export type Handle = {
	__modulePath: string?,
	__children: { [string]: any },
	Name: string,
	Parent: any,
}

local function handle(name: string, modulePath: string?): Handle
	local h = {
		__modulePath = modulePath,
		__children = {},
		Name = name,
		Parent = nil :: any,
	}
	return (
		setmetatable(h, {
			__index = function(t, key)
				local child = rawget(t, "__children")[key]
				if child == nil then
					error(`harness: no child '{key}' under '{rawget(t, "Name")}'`, 2)
				end
				return child
			end,
		}) :: any
	) :: Handle
end

local function adopt(parent: Handle, child: Handle)
	local p = parent :: any
	local c = child :: any
	p.__children[c.Name] = c
	c.Parent = p
end

function Harness.build()
	local cache: { [any]: any } = {}

	-- Tree mirroring default.project.json.
	local replicated = handle("ReplicatedStorage")
	local shared = handle("Shared")
	adopt(replicated, shared)

	local serverScripts = handle("ServerScriptService")
	local server = handle("Server")
	local systems = handle("systems")
	adopt(serverScripts, server)
	adopt(server, systems)

	-- A shared module missing from this list cannot be required by any test, so
	-- it ships unhammered. `tests/wiring.luau` sweeps `src/shared/` against it.
	for _, name in
		{
			"Lexicon",
			"Types",
			"Config",
			"Remotes",
			"Heat",
			"Hud",
			"Hum",
			"Keypad",
			"Readout",
			"Layout",
			"Silence",
			"LexiconSave",
			"Numerals",
		}
	do
		adopt(shared, handle(name, `src/shared/{name}.luau`))
	end
	for _, name in
		{
			"Heuristic",
			"Operator",
			"Round",
			"Objectives",
			"Connected",
			"Lifecycle",
			"Pursuit",
			"Station",
			"Supervisor",
			"TestOperator",
			"Escape",
			"ChatFeed",
			"Censor",
		}
	do
		adopt(systems, handle(name, `src/server/systems/{name}.luau`))
	end

	local game = {
		GetService = function(_self: any, name: string)
			if name == "ReplicatedStorage" then
				return replicated
			elseif name == "ServerScriptService" then
				return serverScripts
			end
			error(`harness: unsupported service '{name}'`, 2)
		end,
	}

	local load

	local function requireHandle(target: any): any
		if cache[target] ~= nil then
			return cache[target]
		end
		local path = rawget(target, "__modulePath")
		if not path then
			error(`harness: '{rawget(target, "Name")}' is not a module`, 2)
		end
		local result = load(target, path)
		cache[target] = result
		return result
	end

	function load(scriptHandle: any, path: string): any
		local source = fs.readFile(path)
		local env: { [string]: any } = {
			game = game,
			script = scriptHandle,
			require = requireHandle,
			-- Standard library surface our modules actually touch.
			table = table,
			string = string,
			math = math,
			os = os,
			print = print,
			error = error,
			assert = assert,
			ipairs = ipairs,
			pairs = pairs,
			next = next,
			select = select,
			tostring = tostring,
			tonumber = tonumber,
			type = type,
			typeof = type,
			setmetatable = setmetatable,
			getmetatable = getmetatable,
			rawget = rawget,
			rawset = rawset,
			pcall = pcall,
			unpack = table.unpack,
		}
		local chunk = luau.load(source, {
			debugName = path,
			environment = env,
		})
		return chunk()
	end

	return {
		require = requireHandle,
		systems = systems,
		shared = shared,
	}
end

return Harness
