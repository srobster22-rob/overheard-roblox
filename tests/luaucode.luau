--!strict
-- Reading Luau the way Luau reads it: which characters in a source file are
-- CODE, and which are merely text that mentions code.
--
-- This lives in its own module because two guards need it and they must not
-- disagree. `tests/config.luau` uses it to tell a real read of a tuning dial
-- from a comment or string that names one; `tests/objectives.luau` uses it to
-- tell a real call to the leave-path re-deal from a comment that mentions it.
-- A guard a MENTION can satisfy reports safety it never checked, and this
-- project has now shipped that defect three times (R4's comment, R6's own
-- error strings, and R8's first draft of the wiring guard).
--
-- The distinction needs no parser, because Luau itself draws it lexically:
-- inside a backtick string a `{expr}` span IS code the compiler evaluates and
-- everything else is text; inside `'...'`, `"..."` and `[[...]]`, NOTHING is
-- code. So scan left to right, keep code and interpolation spans, and drop
-- comment and string bodies.
--
-- Its own credibility is checked in `tests/config.luau`, in the two blocks
-- "a mention is not a read" and "but real code still reads" — 17 checks that
-- sweep every text-holding form Luau has, in both directions. Those checks
-- now cover both callers, which is the point of sharing one scanner.

local scanCode: (string, number, boolean, { string }) -> number
local scanBacktick: (string, number, { string }) -> number

-- Skips a long bracket `[==[ ... ]==]` opening at `i`, if there is one.
-- Returns the index after it, or nil when `i` is not a long bracket.
local function skipLongBracket(source: string, i: number, offset: number): number?
	local eq = string.match(source, "^%[(=*)%[", i + offset)
	if not eq then
		return nil
	end
	local _, closeEnd = string.find(source, `]{string.rep("=", #eq)}]`, i + offset, true)
	return if closeEnd then closeEnd + 1 else #source + 1
end

-- Text of a `'...'` or `"..."` string starting at `i`. Unterminated strings and
-- a raw newline both end it, so a stray quote cannot swallow the whole file.
local function skipShortString(source: string, i: number): number
	local quote = string.sub(source, i, i)
	local j = i + 1
	while j <= #source do
		local c = string.sub(source, j, j)
		if c == "\\" then
			j += 2
		elseif c == quote then
			return j + 1
		elseif c == "\n" then
			return j
		else
			j += 1
		end
	end
	return j
end

-- Inside a backtick string: drop the text, but hand every `{...}` span back to
-- the code scanner, because that span is code.
function scanBacktick(source: string, i: number, out: { string }): number
	while i <= #source do
		local c = string.sub(source, i, i)
		if c == "\\" then
			i += 2
		elseif c == "`" then
			return i + 1
		elseif c == "{" then
			table.insert(out, " ")
			i = scanCode(source, i + 1, true, out)
		else
			i += 1
		end
	end
	return i
end

-- Code. Emits code characters, emits a space for anything dropped so nothing
-- joins up across a hole. `stopAtBrace` is set inside an interpolation span and
-- for nested braces, so table constructors inside a `{...}` stay balanced.
function scanCode(source: string, i: number, stopAtBrace: boolean, out: { string }): number
	while i <= #source do
		local c = string.sub(source, i, i)
		if c == "}" and stopAtBrace then
			table.insert(out, " ")
			return i + 1
		elseif c == "{" then
			table.insert(out, " ")
			i = scanCode(source, i + 1, true, out)
		elseif c == "-" and string.sub(source, i + 1, i + 1) == "-" then
			local after = skipLongBracket(source, i, 2)
			if after then
				i = after
			else
				local newline = string.find(source, "\n", i, true)
				i = if newline then newline else #source + 1
			end
			table.insert(out, " ")
		elseif c == '"' or c == "'" then
			i = skipShortString(source, i)
			table.insert(out, " ")
		elseif c == "[" then
			local after = skipLongBracket(source, i, 0)
			if after then
				i = after
				table.insert(out, " ")
			else
				table.insert(out, c)
				i += 1
			end
		elseif c == "`" then
			table.insert(out, " ")
			i = scanBacktick(source, i + 1, out)
		else
			table.insert(out, c)
			i += 1
		end
	end
	return i
end

-- The source with every comment body and every string body removed, and
-- interpolation spans kept.
local function stripNonCode(source: string): string
	local out: { string } = {}
	scanCode(source, 1, false, out)
	return table.concat(out)
end

local LuauCode = {}

LuauCode.stripNonCode = stripNonCode

return LuauCode
