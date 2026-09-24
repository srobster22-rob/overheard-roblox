--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: the game not hearing what players type
-- on a real server (COACH.md C1, R139).
--
-- Until R139 chat reached the Operator through a callback Roblox only runs on
-- the client, and the suite called that hook by hand, so it never noticed the
-- live game heard nothing. `ChatFeed` listens on `Player.Chatted`, which fires
-- on the server (PLATFORM.md). This file drives it with fakes that behave like
-- the real signals on the server: connections that can be dropped, a Players
-- service that announces who joins and who leaves.

local Harness = require("./harness")

local rt = Harness.build()
local ChatFeed = rt.require(rt.systems.ChatFeed)

local Kit = require("./kit")
local check = Kit.check

-- A signal like RBXScriptSignal: `Connect` returns a connection with
-- `Disconnect`; `fire` calls every connection still live; `live` counts them.
local function signal()
	local connections: { { handler: (...any) -> (), live: boolean } } = {}
	local s = {}
	function s.Connect(_self: any, handler: (...any) -> ())
		local entry = { handler = handler, live = true }
		table.insert(connections, entry)
		return {
			Disconnect = function(_: any)
				entry.live = false
			end,
		}
	end
	function s.fire(...: any)
		for _, entry in connections do
			if entry.live then
				entry.handler(...)
			end
		end
	end
	function s.live(): number
		local n = 0
		for _, entry in connections do
			n += if entry.live then 1 else 0
		end
		return n
	end
	return s
end

local function fakePlayer(userId: number)
	return { UserId = userId, Chatted = signal() }
end

local heard: { string } = {}
local function onChat(speaker: any, text: string)
	table.insert(heard, `{speaker.UserId}:{text}`)
end

print("what a player types is heard, once")
local feed = ChatFeed.new(onChat)
local ana = fakePlayer(1)
feed:listen(ana :: any)
ana.Chatted.fire("the blue kettle")
check(`a message reaches the listener with who typed it ({tostring(heard[1])})`, heard[1] == "1:the blue kettle")
feed:listen(ana :: any)
ana.Chatted.fire("again")
check(`listening twice does not hear twice ({#heard} heard)`, #heard == 2 and ana.Chatted.live() == 1)

print("")
print("a player who leaves is no longer heard")
feed:forget(1)
ana.Chatted.fire("gone")
check(`after they leave, nothing more of theirs is heard ({#heard} heard)`, #heard == 2)
check("...because their connection was dropped", ana.Chatted.live() == 0)
check(
	"forgetting someone twice, or someone never heard, is harmless",
	pcall(function()
		feed:forget(1)
		feed:forget(99)
	end)
)

print("")
print("following a Players service hears everyone in it")
table.clear(heard)
local early, late = fakePlayer(10), fakePlayer(20)
local roster = { list = { early }, PlayerAdded = signal(), PlayerRemoving = signal() }
function roster.GetPlayers(self: any): { any }
	return self.list
end
local server = ChatFeed.new(onChat)
server:follow(roster :: any)
early.Chatted.fire("already here")
check("someone already in the server when it starts is heard", heard[1] == "10:already here")
roster.PlayerAdded.fire(late)
late.Chatted.fire("just joined")
check("someone who joins afterwards is heard", heard[2] == "20:just joined")
roster.PlayerRemoving.fire(early)
early.Chatted.fire("still typing")
check(`someone who leaves is not heard ({#heard} heard)`, #heard == 2)
check("...and their connection is dropped", early.Chatted.live() == 0)
late.Chatted.fire("still here")
check("...while everyone else still is", heard[3] == "20:still here")

Kit.finish()
