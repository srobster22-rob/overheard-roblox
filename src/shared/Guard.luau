--!strict
-- Every handler, loop and callback runs through here. An error in one is
-- caught with its traceback and the tag of the code that ran it, kept where
-- the checks can read it, and warned to the output, instead of silently
-- killing one connection or the whole beat loop.
--
--     signal:Connect(Guard.wrap("server.submit", function(player, ...) ... end))
--     Guard.run("server.beat", beat)

local Guard = {}

export type Failure = { tag: string, message: string, traceback: string }

-- Only the newest failures are kept, so one that repeats every beat cannot
-- grow without bound.
Guard.KEPT = 50

local failures: { Failure } = {}

local function capture(err: any): { message: string, traceback: string }
	local message = tostring(err)
	return { message = message, traceback = debug.traceback(message, 2) }
end

-- Runs `fn(...)` under xpcall: true and its results, or false once the failure
-- is recorded under `tag`.
function Guard.run(tag: string, fn: (...any) -> ...any, ...: any): (boolean, ...any)
	local results = table.pack(xpcall(fn, capture, ...))
	if results[1] then
		return table.unpack(results, 1, results.n)
	end
	local caught = results[2]
	table.insert(failures, { tag = tag, message = caught.message, traceback = caught.traceback })
	if #failures > Guard.KEPT then
		table.remove(failures, 1)
	end
	warn(`[{tag}] {caught.message}\n{caught.traceback}`)
	return false
end

-- `fn` under `run`, for a connection, a callback or a spawned task. It returns
-- `fn`'s results, or nothing when `fn` failed.
function Guard.wrap(tag: string, fn: (...any) -> ...any): (...any) -> ...any
	return function(...: any): ...any
		local results = table.pack(Guard.run(tag, fn, ...))
		if results[1] then
			return table.unpack(results, 2, results.n)
		end
		return
	end
end

-- Every failure kept, oldest first.
function Guard.failures(): { Failure }
	return table.clone(failures)
end

function Guard.clear()
	table.clear(failures)
end

return Guard
