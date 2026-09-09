--!strict
-- Headless run of the acquisition assertions. Run: lune run tests/operator
-- Same assertions as src/server/systems/TestOperator, executed with no engine.

local Harness = require("./harness")

local rt = Harness.build()
local TestOperator = rt.require(rt.systems.TestOperator)

local ok, err = pcall(TestOperator)
if not ok then
	print(`FAILED: {err}`)
	process.exit(1)
end
print("operator: all assertions passed")
