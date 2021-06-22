-- ROBLOX deviation: no upstream tests

return function()
	local rootWorkspace = script.Parent.Parent
	local PackagesWorkspace = rootWorkspace.Parent

	local JestRoblox = require(PackagesWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local ApolloContext = require(rootWorkspace.react.context).ApolloContext
	local getApolloContext = ApolloContext.getApolloContext

	describe("ApolloContext", function()
		it("should return an empty ApolloContext", function()
			jestExpect(getApolloContext()).never.toBe(nil)
		end)
	end)
end
