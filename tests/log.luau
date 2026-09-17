--!strict
-- THE CLASS OF BUG THIS FILE GUARDS: the step that records a result destroying
-- the record.
--
-- `LOOP_LOG.md` is the file this project says outranks every other doc, and
-- Stage 0 of every round begins by reading it. The last step of every round
-- wrote a `%%HASH%%` placeholder into the entry and then substituted the real
-- commit hash into it. The substitution wrote an empty file.
--
-- It first fired at R19, taking 2,509 lines with it -- nineteen rounds of
-- entries, plus the CHARTER, the GATE and the EXPANSION AXIS, which are the
-- loop's own operating rules. Then it fired again after every round from R20 to
-- R51. Each round wrote ~85 lines and the round's own last commit deleted them,
-- so for THIRTY-THREE rounds the file that outranks everything held exactly one
-- entry, and the hash it was trying to record was never once recorded.
--
-- Nothing caught it because nothing ever read the file. The suite tested the
-- game; the log was process, and process was assumed rather than checked. It is
-- checked here, against git rather than against a list typed in this file, so a
-- round that ships without an entry fails the same gate its code does.

local fs = require("@lune/fs")
local process = require("@lune/process")

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

-- Pure, so the control below can hand it a log it wrote itself.
local function roundsIn(text: string): { [number]: boolean }
	local found: { [number]: boolean } = {}
	for line in string.gmatch(text, "[^\n]+") do
		local n = string.match(line, "^## R(%d+)")
		if n then
			found[tonumber(n) :: number] = true
		end
	end
	return found
end

-- The hash a round's entry records, if it records one.
local function hashFor(text: string, round: number): string?
	local from = string.find(text, `## R{round} `, 1, true) or string.find(text, `## R{round}\n`, 1, true)
	if not from then
		return nil
	end
	local to = string.find(text, `## R{round + 1} `, from, true) or #text
	local section = string.sub(text, from, to)
	return string.match(section, "%*%*Commit%*?%*?%.?%s*`([0-9a-f]+)`")
end

local log = fs.readFile("LOOP_LOG.md")

print("the log still has every round in it")

-- The authority is git, not a list kept by hand here: a list would have to be
-- edited every round, and the thing being guarded against is a round that
-- forgets to write itself down.
local git = process.exec("git", { "log", "--format=%s" })
check("(guard) git history is readable", git.ok)

local shipped: { [number]: boolean } = {}
local shippedCount = 0
for line in string.gmatch(git.stdout, "[^\n]+") do
	local n = string.match(line, "^R(%d+):") or string.match(line, "^OVERHEARD R(%d+):")
	if n then
		local round = tonumber(n) :: number
		if not shipped[round] then
			shipped[round] = true
			shippedCount += 1
		end
	end
end
-- Without this, an unreadable or empty history would make every check below
-- pass by having nothing to check.
check(`(guard) history knows about many rounds ({shippedCount})`, shippedCount >= 20)

local present = roundsIn(log)
local missing: { number } = {}
local highest = 0
for round in shipped do
	highest = math.max(highest, round)
	if not present[round] then
		table.insert(missing, round)
	end
end
table.sort(missing)
check(`every round git shipped has an entry in the log ({#missing} missing)`, #missing == 0)
if #missing > 0 then
	print(`        missing: R{table.concat(missing :: any, ", R")}`)
end

-- Contiguous, so a gap in the middle is caught even if the last round is there.
local gaps = 0
for round = 1, highest do
	if not present[round] then
		gaps += 1
	end
end
check(`the entries run R1..R{highest} with no gaps ({gaps})`, gaps == 0)

-- And the control: the same reader, given a log with R7 cut out of it, must
-- say so. Otherwise the checks above pass because the reader is deaf.
local mutilated = string.gsub(log, "## R7 ", "## SEVEN ", 1)
check("(control) a log missing a round is detected", roundsIn(mutilated)[7] == nil)
check("(control) ...and the real log is not", present[7] == true)

print("")
print("every round records the commit that shipped it")

-- A commit stamp must be a hash and nothing else. This is where the residue of
-- the failure lands: the substitution step leaves its placeholder sitting in
-- the stamp, which is what happened for thirty-three rounds.
--
-- Checked on the STAMP LINES rather than by searching the whole file for the
-- placeholder text, because an entry is allowed to talk ABOUT the placeholder
-- -- R53's does, four times -- and a search cannot tell prose from residue.
local function stampIsAHash(line: string): boolean
	-- R1-R19 wrote the stamp as `**Commit.**`, later rounds as `**Commit**`.
	-- The punctuation is not the point; what is inside the backticks is.
	local body = string.match(line, "^%*%*Commit[%.%*%s]*`([^`]*)`")
	return body ~= nil and string.match(body, "^[0-9a-f]+$") ~= nil
end

local stamps = 0
local bad = 0
for line in string.gmatch(log, "[^\n]+") do
	if string.match(line, "^%*%*Commit") then
		stamps += 1
		if not stampIsAHash(line) then
			bad += 1
			print(`        stamp is not a hash: {line}`)
		end
	end
end
check(`(guard) the log is full of commit stamps ({stamps})`, stamps >= 20)
check(`every commit stamp is a hash and nothing else ({bad} bad)`, bad == 0)
check("(control) an unsubstituted placeholder in a stamp is rejected", not stampIsAHash("**Commit** `%%HASH%%`"))
check("(control) ...and a real stamp is accepted", stampIsAHash("**Commit** `5792c1b`"))

-- From R131 the loop makes ONE commit per round with the entry inside it
-- (AGENT_LOOP v2), so an entry cannot name its own hash. For those rounds the
-- commit is found the other way round: git must hold a commit titled `R<n>:`,
-- which is what `shipped` already is. Earlier rounds keep the stamp rule.
local ONE_COMMIT_FROM = 131
local unstamped: { number } = {}
for round = 1, highest do
	if round >= ONE_COMMIT_FROM and shipped[round] then
		continue
	end
	if not hashFor(log, round) then
		table.insert(unstamped, round)
	end
end
check(`every entry names its commit ({#unstamped} without one)`, #unstamped == 0)
if #unstamped > 0 then
	print(`        unstamped: R{table.concat(unstamped :: any, ", R")}`)
end

-- The hashes have to be real commits, not plausible-looking text.
local sampled = 0
local unreal = 0
for _, round in { 1, math.floor(highest / 2), math.min(highest, 130) } do
	local hash = hashFor(log, round)
	if hash then
		sampled += 1
		local shown = process.exec("git", { "cat-file", "-t", hash })
		if not (shown.ok and string.match(shown.stdout, "commit")) then
			unreal += 1
			print(`        R{round} names {hash}, which is not a commit`)
		end
	end
end
check(`(guard) hashes were sampled ({sampled})`, sampled >= 3)
check(`the hashes name real commits ({unreal} bad)`, unreal == 0)

-- (control) a hash that is not in this repository must fail that same check.
local nonsense = process.exec("git", { "cat-file", "-t", "0000000" })
check("(control) a made-up hash is not a commit", not (nonsense.ok and string.match(nonsense.stdout, "commit")))

print("")
print("the loop's own rules are still in the file")

-- These went into the bin with R1..R19 and nobody noticed for thirty-three
-- rounds, because the only thing that reads them is the next round.
for _, section in { "## CHARTER", "## GATE", "## THE EXPANSION AXIS" } do
	check(`'{section}' survives`, string.find(log, section, 1, true) ~= nil)
end

-- A crude floor on size, so a truncation that leaves the headings intact but
-- guts the entries is still caught. Every round so far has run 70+ lines.
local lines = select(2, string.gsub(log, "\n", "")) + 1
check(`the log is the length {highest} rounds implies ({lines} lines)`, lines > highest * 40)

print(`\n{checks - failures}/{checks} passed`)
if failures > 0 then
	process.exit(1)
end
