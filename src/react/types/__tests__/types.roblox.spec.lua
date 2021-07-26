-- ROBLOX no upstream

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local typesModule = require(script.Parent.Parent.types)

	describe("types module", function()
		it("empty test", function()
			-- just to verify the types file is executing properly
			jestExpect("").toEqual("")
		end)
	end)
end
