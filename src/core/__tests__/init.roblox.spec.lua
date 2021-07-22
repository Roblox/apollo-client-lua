return function()
	local coreWorkspace = script.Parent.Parent
	local rootWorkspace = coreWorkspace.Parent.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local coreModule = require(coreWorkspace)
	local ApolloClient = coreModule.ApolloClient

	describe("Core init", function()
		it("Apollo Client should be exported", function()
			jestExpect(ApolloClient).never.toBe(nil)
		end)
	end)
end
