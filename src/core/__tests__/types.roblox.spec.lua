return function()
	local coreWorkspace = script.Parent.Parent
	local rootWorkspace = coreWorkspace.Parent.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	require(coreWorkspace.types)

	describe("Core types", function()
		it("empty test", function()
			jestExpect("").toEqual("")
		end)
	end)
end
