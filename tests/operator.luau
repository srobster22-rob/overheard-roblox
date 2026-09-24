--!strict
-- Headless run of the acquisition assertions. Run: lune run tests/operator
-- Runs tests/studio/TestOperator (the Studio-run acquisition test) with no engine.

-- Lune does not expose `process` as a global; without this require the
-- FAILURE path of this file crashes instead of reporting, which hides the
-- real assertion behind "attempt to index nil with .exit".
local process = require("@lune/process")

local Harness = require("./harness")

local rt = Harness.build()
local TestOperator = rt.require(rt.dev.TestOperator)

local ok, err = pcall(TestOperator)
if not ok then
	print(`FAILED: {err}`)
	process.exit(1)
end
print("operator: all assertions passed")
