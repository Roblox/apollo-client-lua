return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local linkCoreModule = require(script.Parent.Parent)
	describe("link/core", function()
		it("should export relevant functions from './init.lua' module", function()
			jestExpect(typeof(linkCoreModule.empty)).toBe("function")
			jestExpect(typeof(linkCoreModule.from)).toBe("function")
			jestExpect(typeof(linkCoreModule.split)).toBe("function")
			jestExpect(typeof(linkCoreModule.concat)).toBe("function")
			jestExpect(typeof(linkCoreModule.execute)).toBe("function")
			jestExpect(typeof(linkCoreModule.ApolloLink)).toBe("table")
		end)
	end)
end
