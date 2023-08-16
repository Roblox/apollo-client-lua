--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: no upstream
local coreWorkspace = script.Parent.Parent
local rootWorkspace = coreWorkspace.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local coreModule = require(coreWorkspace)
local ApolloClient = coreModule.ApolloClient

describe("Core init", function()
	it("Apollo Client should be exported", function()
		expect(ApolloClient).never.toBe(nil)
	end)
end)

return {}
