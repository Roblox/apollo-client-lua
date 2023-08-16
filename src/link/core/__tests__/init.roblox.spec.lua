--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: no upstream
local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local linkCoreModule = require(script.Parent.Parent)
describe("link/core", function()
	it("should export relevant functions from './init.lua' module", function()
		expect(typeof(linkCoreModule.empty)).toBe("function")
		expect(typeof(linkCoreModule.from)).toBe("function")
		expect(typeof(linkCoreModule.split)).toBe("function")
		expect(typeof(linkCoreModule.concat)).toBe("function")
		expect(typeof(linkCoreModule.execute)).toBe("function")
		expect(typeof(linkCoreModule.ApolloLink)).toBe("table")
	end)
end)

return {}
