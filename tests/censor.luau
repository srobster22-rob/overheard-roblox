--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: words one player typed reaching another
-- player's screen without Roblox's text filter (COACH.md C2, R139).
--
-- The Lexicon panel is built from typed phrases. `Censor.rows` is the only way
-- they leave the server (tests/wiring.luau holds the server to that); this file
-- holds `Censor.rows` to never letting a raw phrase through.

local Harness = require("./harness")

local rt = Harness.build()
local Censor = rt.require(rt.systems.Censor)
local Operator = rt.require(rt.systems.Operator)
local Round = rt.require(rt.systems.Round)

local Kit = require("./kit")
local check = Kit.check

-- A fake filter that marks what it was given and for whom, so a test can tell
-- a filtered phrase from a raw one and see the author was passed.
local asked = 0
local function marked(text: string, author: number): string?
	asked += 1
	return `{author}|{string.upper(text)}`
end

-- True when any field of any row still holds one of the raw phrases.
local function leaks(rows: { any }, raw: { string }): boolean
	for _, row in rows do
		for _, value in row do
			if table.find(raw, value) then
				return true
			end
		end
	end
	return false
end

local rows = {
	{ phrase = "blue kettle", concept = "jack_number", heat = 0.4, sightings = 3, coinedBy = 7 },
	{ phrase = "tin whistle", concept = "breaker", heat = 0.9, sightings = 5, coinedBy = 8 },
}
local RAW = { "blue kettle", "tin whistle" }

print("every phrase is filtered for the player who typed it")
local shown = Censor.new(marked):rows(rows)
check(`(guard) both rows are shown ({#shown})`, #shown == 2)
check(
	`each phrase is what the filter returned for its author ({shown[1].phrase}, {shown[2].phrase})`,
	shown[1].phrase == "7|BLUE KETTLE" and shown[2].phrase == "8|TIN WHISTLE"
)
check(
	"...and the rest of the row is unchanged",
	shown[1].concept == "jack_number" and shown[1].heat == 0.4 and shown[1].sightings == 3 and shown[1].coinedBy == 7
)
check("no raw phrase is anywhere in what is sent", not leaks(shown, RAW))
check("the rows it was given keep the raw words (the Operator still hears them)", rows[1].phrase == "blue kettle")

print("")
print("a phrase that cannot be filtered is left out, never shown raw")
local partial = Censor.new(function(text: string, author: number): string?
	return if text == "tin whistle" then nil else marked(text, author)
end):rows(rows)
check(`a failed filter leaves just that phrase out ({#partial} shown)`, #partial == 1 and partial[1].coinedBy == 7)
check("...and does not send it raw", not leaks(partial, RAW))
local blank = Censor.new(function(): string?
	return ""
end):rows(rows)
check("an empty result counts as a failure", #blank == 0)
asked = 0
local anonymous = Censor.new(marked):rows({ { phrase = "red anchor", concept = "exit", heat = 0, sightings = 1 } })
check("a phrase nobody is known to have typed is left out", #anonymous == 0)
check("...without asking the filter", asked == 0)

print("")
print("each phrase is asked once while it is on the panel")
asked = 0
local panel = Censor.new(marked)
panel:rows(rows)
panel:rows(rows)
check(`the same panel twice asks once per phrase ({asked} calls)`, asked == 2)
panel:rows({ rows[1] })
panel:rows(rows)
check(`a phrase that left the panel is asked again when it comes back ({asked} calls)`, asked == 3)
local attempts = 0
local flaky = Censor.new(function(text: string, author: number): string?
	attempts += 1
	return if attempts == 1 then nil else marked(text, author)
end)
local first = flaky:rows({ rows[1] })
local second = flaky:rows({ rows[1] })
check("a failure is asked again next time, and then shown", #first == 0 and #second == 1 and attempts == 2)

print("")
print("the panel is sent filtered, and only the newest request")
-- A spawn that runs each send on its own coroutine, and a filter that yields
-- like the web call it stands in for, so the test decides the order in which
-- the filter calls come back.
local threads: { thread } = {}
local function spawnHere(work: () -> ())
	local thread = coroutine.create(work)
	table.insert(threads, thread)
	coroutine.resume(thread)
end
local function finish(thread: thread)
	while coroutine.status(thread) ~= "dead" do
		coroutine.resume(thread)
	end
end
local slow = Censor.new(function(text: string, author: number): string?
	coroutine.yield()
	return marked(text, author)
end)
local sent: { { any } } = {}
local panelNow: { any } = { rows[1] }
local sendPanel = slow:sender(function()
	return panelNow
end, function(visible)
	table.insert(sent, visible)
end, spawnHere)
sendPanel()
panelNow = rows
sendPanel()
check(`(guard) both sends are waiting on the filter ({#threads}, {#sent} sent)`, #threads == 2 and #sent == 0)
finish(threads[2])
check(`the newest panel is sent once its words are filtered ({#sent} sent)`, #sent == 1 and #sent[1] == 2)
finish(threads[1])
check(`an older request finishing later is not sent over it ({#sent} sent)`, #sent == 1)
check("...and what was sent is filtered", not leaks(sent[1], RAW))
local lone = Censor.new(marked)
local lonely: { { any } } = {}
lone:sender(function()
	return rows
end, function(visible)
	table.insert(lonely, visible)
end, spawnHere)()
check("a single request is sent", #lonely == 1 and #lonely[1] == 2)

print("")
print("against the real Operator")
-- A player coins a phrase in play; the panel shows only the filtered form.
-- Seeded: the real Operator's secrets are dealt at random.
math.randomseed(1)
local secret = Round.dealSecrets(5)[1]
local op = Operator.new({ secret })
op:hear({ speaker = { UserId = 5 } :: any, text = "the gizmo and the sprocket", at = 0 })
op:credit(secret.concept, 1)
local learned = op:snapshot()
local raw: { string } = {}
for _, c in learned do
	table.insert(raw, c.phrase)
end
check(`(guard) the Operator learned phrases from player 5 ({#learned})`, #learned > 0 and learned[1].coinedBy == 5)
local sent = Censor.new(marked):rows(learned)
check(`every learned phrase is sent ({#sent} of {#learned})`, #sent == #learned)
check("...each one filtered for player 5", sent[1] ~= nil and string.sub(sent[1].phrase, 1, 2) == "5|")
check("...and none of them raw", not leaks(sent, raw))

Kit.finish()
