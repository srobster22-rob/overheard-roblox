--!strict
-- The market numbers, COMPUTED from MARKET.md's parity matrix (AGENT_LOOP
-- v3.3: every total and gap value comes from a committed script, never by
-- hand). R136's table carried a gap value that no longer matched its own row
-- (COACH.md C6). Run from the project root:
--     lune run tools/market          prints every score and gap value
--     lune run tools/market check    also fails if MARKET.md states any other
--                                    number (test.cmd runs this)

local fs = require("@lune/fs")
local process = require("@lune/process")

-- Line endings normalised: git may check the file out either way.
local text = string.gsub(fs.readFile("MARKET.md"), "\r\n", "\n")
local lines: { string } = {}
for line in string.gmatch(text .. "\n", "(.-)\n") do
	table.insert(lines, line)
end

local function cells(line: string): { string }
	local out: { string } = {}
	for cell in string.gmatch(line, "|([^|]*)") do
		table.insert(out, (string.gsub(cell, "^%s*(.-)%s*$", "%1")))
	end
	table.remove(out) -- the empty cell after the closing bar
	return out
end

-- The matrix: the first table after the "## Parity matrix" heading.
local header: { string }? = nil
local rows: { { string } } = {}
local inMatrix = false
for _, line in lines do
	if string.find(line, "^## Parity matrix") then
		inMatrix = true
	elseif inMatrix and string.sub(line, 1, 1) == "|" then
		if header == nil then
			header = cells(line)
		elseif not string.find(line, "^|%-") then
			table.insert(rows, cells(line))
		end
	elseif inMatrix and header ~= nil then
		break
	end
end
assert(header, "MARKET.md has no parity matrix table")
local head = header :: { string }

local function column(name: string): number
	for i, cell in head do
		if cell == name then
			return i
		end
	end
	error(`the matrix has no '{name}' column`)
end
local W, US, EVIDENCE, GAP = column("W"), column("Us"), column("Evidence for us"), column("gap value")
local comparables: { number } = {}
for i = EVIDENCE + 1, GAP - 1 do
	table.insert(comparables, i)
end

local problems: { string } = {}
local function number(cell: string): number?
	return tonumber(string.match(cell, "%-?%d+%.?%d*"))
end

local most = 0
local ours = 0
local theirs: { [number]: number } = {}
local gaps: { { name: string, gap: number } } = {}
for _, row in rows do
	local name = string.gsub(row[1], "%*", "")
	local weight = number(row[W]) :: number
	local us = number(row[US]) :: number
	assert(weight and us, `row '{name}' has no weight or score`)
	most += weight * 5
	ours += weight * us
	local best = 0
	for _, i in comparables do
		local score = number(row[i]) :: number
		assert(score, `row '{name}' has no score for {head[i]}`)
		theirs[i] = (theirs[i] or 0) + weight * score
		best = math.max(best, score)
	end
	local stated = number(row[GAP])
	if string.find(name, "^Differentiator") then
		-- Ours is the best by definition; it has no gap to close.
		if stated ~= nil then
			table.insert(problems, `{name}: states a gap value ({stated}); the differentiator has none`)
		end
	else
		local gap = weight * math.max(0, best - us)
		table.insert(gaps, { name = name, gap = gap })
		if stated ~= gap then
			table.insert(problems, `{name}: states gap value {tostring(stated)}, the row computes {gap}`)
		end
	end
end

local function percent(total: number): number
	return math.floor(1000 * total / most + 0.5) / 10
end
print(`matrix: {#rows} rows, most possible {most}`)
print(`  us: {ours}/{most} = {percent(ours)}`)
local bestName, bestScore = "", -1
for _, i in comparables do
	print(`  {head[i]}: {theirs[i]}/{most} = {percent(theirs[i])}`)
	if theirs[i] > bestScore then
		bestName, bestScore = head[i], theirs[i]
	end
end
table.sort(gaps, function(a, b)
	return a.gap > b.gap
end)
local listed: { string } = {}
for _, g in gaps do
	table.insert(listed, `{g.name} {g.gap}`)
end
print(`gap values: {table.concat(listed, ", ")}`)

-- The stated market score: "**Market score:** us **22.0/100**", and the best
-- comparable named after it in bold.
local scoreLine = string.match(text, "%*%*Market score:%*%*[^\n]*")
if scoreLine == nil then
	table.insert(problems, "no '**Market score:**' line")
else
	local statedUs = tonumber(string.match(scoreLine, "us %*%*([%d%.]+)/100"))
	if statedUs ~= percent(ours) then
		table.insert(
			problems,
			`the market score line says us {tostring(statedUs)}; the matrix computes {percent(ours)}`
		)
	end
end
local bestLine = string.match(text, "%*%*Market score:%*%*.-\n\n") or ""
local statedBest = tonumber(string.match(bestLine, "%*%*([%d%.]+)%*%*"))
if statedBest ~= percent(bestScore) then
	table.insert(
		problems,
		`the best comparable is stated as {tostring(statedBest)}; the matrix computes {bestName} {percent(bestScore)}`
	)
end

-- The "Top gaps by value:" line: every gap it names must be the row's value.
local topLine = string.match(text, "%*%*Top gaps by value:%*%*([^\n]*\n?[^\n]*)") or ""
for label, value in string.gmatch(topLine, "([%a][%a ]-) (%d+)") do
	local found = false
	for _, g in gaps do
		if string.lower(string.sub(g.name, 1, #label)) == string.lower(label) then
			found = true
			if g.gap ~= tonumber(value) then
				table.insert(problems, `top gaps line: {label} {value}, the row computes {g.gap}`)
			end
		end
	end
	if not found then
		table.insert(problems, `top gaps line names '{label}', which is no row`)
	end
end

if #problems > 0 then
	print("")
	print("MARKET.md disagrees with its own matrix:")
	for _, p in problems do
		print(`  {p}`)
	end
	if process.args[1] == "check" then
		process.exit(1)
	end
elseif process.args[1] == "check" then
	print("MARKET.md's numbers match its matrix")
end
