-- ROBLOX no upstream

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local linkHttpModule = require(script.Parent.Parent)

	describe("link/http", function()
		it("should re-export parseAndCheckHttpResponse", function()
			jestExpect(typeof(linkHttpModule.parseAndCheckHttpResponse)).toBe("function")
		end)

		it("should re-export serializeFetchParameter", function()
			jestExpect(typeof(linkHttpModule.serializeFetchParameter)).toBe("function")
		end)

		it("should re-export selectHttpOptionsAndBody", function()
			jestExpect(typeof(linkHttpModule.fallbackHttpConfig)).toBe("table")
			jestExpect(typeof(linkHttpModule.selectHttpOptionsAndBody)).toBe("function")
		end)

		it("should re-export checkFetcher", function()
			jestExpect(typeof(linkHttpModule.checkFetcher)).toBe("function")
		end)

		it("should re-export createSignalIfSupported", function()
			jestExpect(typeof(linkHttpModule.createSignalIfSupported)).toBe("function")
		end)

		it("should re-export selectURI", function()
			jestExpect(typeof(linkHttpModule.selectURI)).toBe("function")
		end)

		it("should re-export createHttpLink", function()
			jestExpect(typeof(linkHttpModule.createHttpLink)).toBe("function")
		end)

		it("should re-export HttpLink", function()
			jestExpect(typeof(linkHttpModule.HttpLink)).toBe("table")
		end)

		it("should re-export rewriteURIForGET", function()
			jestExpect(typeof(linkHttpModule.rewriteURIForGET)).toBe("function")
		end)
	end)
end
