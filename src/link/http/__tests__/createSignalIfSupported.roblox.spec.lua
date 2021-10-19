-- ROBLOX no upstream

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local createSignalIfSupported = require(script.Parent.Parent.createSignalIfSupported).createSignalIfSupported

	describe("createSignalIfSupported", function()
		it("should be a function", function()
			jestExpect(typeof(createSignalIfSupported)).toBe("function")
		end)

		it("should not throw", function()
			jestExpect(createSignalIfSupported).never.toThrow()
		end)
	end)
end
