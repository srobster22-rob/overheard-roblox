--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: a save format that trusts what it is
-- handed back.
--
-- A `DataStoreService` read can return nothing, something from an older
-- version of this format, or something corrupted by a bug elsewhere on the
-- platform. None of that may crash the server -- `LexiconSave.decode` has to
-- validate every field itself and drop what it cannot trust, never assume the
-- shape is right because a caller says it came from a trustworthy place.

local Harness = require("./harness")

local rt = Harness.build()
local LexiconSave = rt.require(rt.shared.LexiconSave)

local Kit = require("./kit")
local check = Kit.check

local function coinage(phrase: string, concept: string, heat: number, sightings: number, coinedBy: number?)
	return { phrase = phrase, concept = concept, heat = heat, sightings = sightings, coinedBy = coinedBy }
end

print("round-tripping a Lexicon")

local live = {
	coinage("the blue one", "jack_number", 0.75, 6, 1),
	coinage("gizmo", "breaker", 0.4, 3, 2),
}
local saved = LexiconSave.encode(live)
check("(guard) the version is stamped", saved.v == LexiconSave.VERSION)
check("both coinages survive", #saved.coinages == 2)

local back = LexiconSave.decode(saved)
check("decoding what encode just produced returns the same count", #back == 2)

local byPhrase: { [string]: any } = {}
for _, c in back do
	byPhrase[c.phrase] = c
end
check("(guard) both phrases came back", byPhrase["the blue one"] ~= nil and byPhrase["gizmo"] ~= nil)
if byPhrase["the blue one"] then
	local c = byPhrase["the blue one"]
	check("phrase survives exactly", c.phrase == "the blue one")
	check("concept survives exactly", c.concept == "jack_number")
	check("heat survives exactly", c.heat == 0.75)
	check("sightings survives exactly", c.sightings == 6)
	check("coinedBy survives exactly", c.coinedBy == 1)
end

print("")
print("a cold coinage is not worth saving")

-- R14's rule for the live panel, applied here for the identical reason: a
-- phrase burned all the way to zero carries nothing the group has not already
-- forgotten, and saving it anyway means every session's file grows even when
-- nothing meaningful survived it.
local withCold = { coinage("dead phrase", "jack_number", 0, 1, 1), coinage("live phrase", "jack_number", 0.5, 1, 1) }
local encodedCold = LexiconSave.encode(withCold)
check("(guard) two coinages went in", #withCold == 2)
check("only the live one is saved", #encodedCold.coinages == 1)
check("...and it is the right one", encodedCold.coinages[1].phrase == "live phrase")

print("")
print("the save is ordered strongest-first, and stable")

local mixed = {
	coinage("weak", "jack_number", 0.2, 1, 1),
	coinage("strong", "jack_number", 0.9, 1, 1),
	coinage("middle", "jack_number", 0.5, 1, 1),
}
local orderedOnce = LexiconSave.encode(mixed)
check("strongest sorts first", orderedOnce.coinages[1].phrase == "strong" and orderedOnce.coinages[3].phrase == "weak")

-- Same coinages, different table order: the save must not depend on it.
local reordered = { mixed[3], mixed[1], mixed[2] }
local orderedTwice = LexiconSave.encode(reordered)
local same = true
for i, c in orderedOnce.coinages do
	if orderedTwice.coinages[i].phrase ~= c.phrase then
		same = false
	end
end
check("the order does not depend on the caller's table order", same)

-- R74. The check above used three DIFFERENT heats, so it could only ever prove
-- the heat comparator, never the tie-break -- a mutation sweep dropped the
-- tie-break entirely (`return a.phrase < b.phrase` -> `return false`) and
-- nothing noticed. This gives two coinages at the EXACT SAME heat and checks
-- the save orders them the same way regardless of which one the caller listed
-- first.
local tiedA = { coinage("zephyr", "jack_number", 0.5, 1, 1), coinage("anchor", "jack_number", 0.5, 1, 1) }
local tiedB = { coinage("anchor", "jack_number", 0.5, 1, 1), coinage("zephyr", "jack_number", 0.5, 1, 1) }
local savedA = LexiconSave.encode(tiedA)
local savedB = LexiconSave.encode(tiedB)
check(
	"a tie between equal-heat coinages breaks the same way regardless of input order",
	savedA.coinages[1].phrase == savedB.coinages[1].phrase and savedA.coinages[2].phrase == savedB.coinages[2].phrase
)
check("...specifically, alphabetically -- 'anchor' before 'zephyr'", savedA.coinages[1].phrase == "anchor")

print("")
print("decode never trusts, and never errors")

check("nil decodes to an empty Lexicon", #LexiconSave.decode(nil) == 0)
check("a bare string decodes to empty, not an error", #LexiconSave.decode("not a save") == 0)
check("a number decodes to empty", #LexiconSave.decode(42) == 0)
check("an empty table decodes to empty", #LexiconSave.decode({}) == 0)
check(
	"the wrong version is refused entirely",
	#LexiconSave.decode({ v = 999, coinages = { coinage("x", "y", 1, 1) } }) == 0
)
check(
	"a coinages field that is not a table is refused",
	#LexiconSave.decode({ v = LexiconSave.VERSION, coinages = "nope" }) == 0
)

-- One bad entry must not poison the whole decode -- the others still come
-- back.
local mixedGood = LexiconSave.decode({
	v = LexiconSave.VERSION,
	coinages = {
		coinage("good one", "jack_number", 0.5, 2, 1),
		{ phrase = "missing fields" },
		coinage("good two", "jack_number", 0.3, 1, 1),
		{ phrase = "bad heat", concept = "jack_number", heat = 5, sightings = 1 },
		{ phrase = "bad heat", concept = "jack_number", heat = 0 / 0, sightings = 1 },
		{ phrase = "bad sightings", concept = "jack_number", heat = 0.5, sightings = -1 },
		{ phrase = "", concept = "jack_number", heat = 0.5, sightings = 1 },
	},
})
check(`(guard) seven entries were offered, two are valid ({#mixedGood})`, #mixedGood == 2)
local names = {}
for _, c in mixedGood do
	names[c.phrase] = true
end
check("the two well-formed entries survive", names["good one"] and names["good two"])

print("")
print("the size backstop")

local huge = {}
for i = 1, LexiconSave.MAX_SAVED + 50 do
	table.insert(huge, coinage(`phrase{i}`, "jack_number", 0.01 + i * 0.001, 1, 1))
end
local cappedSave = LexiconSave.encode(huge)
check(
	`(guard) more coinages were offered than the cap ({#huge} > {LexiconSave.MAX_SAVED})`,
	#huge > LexiconSave.MAX_SAVED
)
check(`the save is capped at MAX_SAVED ({#cappedSave.coinages})`, #cappedSave.coinages == LexiconSave.MAX_SAVED)
-- And it is the STRONGEST that survive the cap, not an arbitrary prefix.
local weakestKept = cappedSave.coinages[#cappedSave.coinages].heat
local strongestDropped = 0.01 + 1 * 0.001
check("the cap drops the WEAKEST entries, not the first ones seen", weakestKept > strongestDropped)

local cappedBack = LexiconSave.decode(cappedSave)
check("decode also respects the cap on the way back in", #cappedBack <= LexiconSave.MAX_SAVED)

print("")
print("what a load keeps (R102 mutation sweep)")
local function one(c): number
	return #LexiconSave.decode({ v = LexiconSave.VERSION, coinages = { c } })
end
check(
	"a BURNED coinage (heat exactly 1) survives a load",
	one({ phrase = "zorp", concept = "exit", heat = 1, sightings = 4 }) == 1
)
check(
	"a stone-cold coinage (heat 0) is still a valid entry",
	one({ phrase = "zorp", concept = "exit", heat = 0, sightings = 4 }) == 1
)
check(
	"a coinage never sighted (0) is still a valid entry",
	one({ phrase = "zorp", concept = "exit", heat = 0.5, sightings = 0 }) == 1
)
check(
	"a coinage with no coiner survives (coinedBy is optional)",
	one({ phrase = "zorp", concept = "exit", heat = 0.5, sightings = 1 }) == 1
)
local okStr, nStr = pcall(one, { phrase = "zorp", concept = "exit", heat = 0.5, sightings = "4" })
check("a string for sightings is rejected, not an error", okStr and nStr == 0)
local many = {}
for i = 1, LexiconSave.MAX_SAVED + 50 do
	table.insert(many, { phrase = `zorp{i}`, concept = "exit", heat = 0.5, sightings = 1 })
end
check(
	"a load never hands back more than MAX_SAVED",
	#LexiconSave.decode({ v = LexiconSave.VERSION, coinages = many }) == LexiconSave.MAX_SAVED
)

Kit.finish()
