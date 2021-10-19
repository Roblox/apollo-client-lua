-- ROBLOX deviation: no upstream tests

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent
	local PackagesWorkspace = rootWorkspace.Parent

	local JestGlobals = require(PackagesWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local getApolloContext = require(rootWorkspace.react.context).getApolloContext

	describe("ApolloContext", function()
		it("should return an empty ApolloContext", function()
			jestExpect(getApolloContext()).never.toBe(nil)
		end)
	end)
end
