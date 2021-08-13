-- ROBLOX deviation: no upstream tests

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent
	local PackagesWorkspace = rootWorkspace.Parent

	local JestRoblox = require(PackagesWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local getApolloContext = require(rootWorkspace.react.context).getApolloContext

	describe("ApolloContext", function()
		it("should return an empty ApolloContext", function()
			jestExpect(getApolloContext()).never.toBe(nil)
		end)
	end)
end
