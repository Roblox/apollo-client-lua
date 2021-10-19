return function()
	local coreWorkspace = script.Parent.Parent
	local rootWorkspace = coreWorkspace.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	require(coreWorkspace.types)

	describe("Core types", function()
		it("empty test", function()
			jestExpect("").toEqual("")
		end)
	end)
end
