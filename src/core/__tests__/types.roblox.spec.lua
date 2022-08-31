local coreWorkspace = script.Parent.Parent
local rootWorkspace = coreWorkspace.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

require(coreWorkspace.types)

describe("Core types", function()
	it("empty test", function()
		expect("").toEqual("")
	end)
end)

return {}
