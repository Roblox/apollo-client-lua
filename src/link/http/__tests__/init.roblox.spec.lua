--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX no upstream

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local linkHttpModule = require(script.Parent.Parent)

describe("link/http", function()
	it("should re-export parseAndCheckHttpResponse", function()
		expect(typeof(linkHttpModule.parseAndCheckHttpResponse)).toBe("function")
	end)

	it("should re-export serializeFetchParameter", function()
		expect(typeof(linkHttpModule.serializeFetchParameter)).toBe("function")
	end)

	it("should re-export selectHttpOptionsAndBody", function()
		expect(typeof(linkHttpModule.fallbackHttpConfig)).toBe("table")
		expect(typeof(linkHttpModule.selectHttpOptionsAndBody)).toBe("function")
	end)

	it("should re-export checkFetcher", function()
		expect(typeof(linkHttpModule.checkFetcher)).toBe("function")
	end)

	it("should re-export createSignalIfSupported", function()
		expect(typeof(linkHttpModule.createSignalIfSupported)).toBe("function")
	end)

	it("should re-export selectURI", function()
		expect(typeof(linkHttpModule.selectURI)).toBe("function")
	end)

	it("should re-export createHttpLink", function()
		expect(typeof(linkHttpModule.createHttpLink)).toBe("function")
	end)

	it("should re-export HttpLink", function()
		expect(typeof(linkHttpModule.HttpLink)).toBe("table")
	end)

	it("should re-export rewriteURIForGET", function()
		expect(typeof(linkHttpModule.rewriteURIForGET)).toBe("function")
	end)
end)

return {}
