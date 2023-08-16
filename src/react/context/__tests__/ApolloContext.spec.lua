--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX deviation: no upstream tests

local rootWorkspace = script.Parent.Parent.Parent.Parent
local PackagesWorkspace = rootWorkspace.Parent

local JestGlobals = require(PackagesWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local getApolloContext = require(rootWorkspace.react.context).getApolloContext

describe("ApolloContext", function()
	it("should return an empty ApolloContext", function()
		expect(getApolloContext()).never.toBe(nil)
	end)
end)

return {}
