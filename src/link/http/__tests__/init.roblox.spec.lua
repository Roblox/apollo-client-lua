-- ROBLOX no upstream

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local linkHttpModule = require(script.Parent.Parent)

	describe("link/http", function()
		xit("should re-export parseAndCheckHttpResponse", function()
			-- jestExpect(typeof(linkHttpModule.parseAndCheckHttpResponse)).toBe("function")
		end)

		xit("should re-export serializeFetchParameter", function()
			-- jestExpect(typeof(linkHttpModule.serializeFetchParameter)).toBe("function")
		end)

		xit("should re-export selectHttpOptionsAndBody", function()
			-- jestExpect(typeof(linkHttpModule.fallbackHttpConfig)).toBe("function")
			-- jestExpect(typeof(linkHttpModule.selectHttpOptionsAndBody)).toBe("function")
		end)

		it("should re-export checkFetcher", function()
			jestExpect(typeof(linkHttpModule.checkFetcher)).toBe("function")
		end)

		it("should re-export createSignalIfSupported", function()
			jestExpect(typeof(linkHttpModule.createSignalIfSupported)).toBe("function")
		end)

		xit("should re-export selectURI", function()
			-- jestExpect(typeof(linkHttpModule.selectURI)).toBe("function")
		end)

		xit("should re-export createHttpLink", function()
			-- jestExpect(typeof(linkHttpModule.createHttpLink)).toBe("function")
		end)

		xit("should re-export HttpLink", function()
			-- jestExpect(typeof(linkHttpModule.HttpLink)).toBe("function")
		end)

		xit("should re-export rewriteURIForGET", function()
			-- jestExpect(typeof(linkHttpModule.rewriteURIForGET)).toBe("function")
		end)
	end)
end
