-- ROBLOX no upstream

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local _typesModule = require(script.Parent.Parent.types)

	describe("types module", function()
		it("empty test", function()
			-- just to verify the types file is executing properly
			jestExpect("").toEqual("")
		end)
	end)
end
