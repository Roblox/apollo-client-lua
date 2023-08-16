--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: no upstream

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local createSignalIfSupported = require(script.Parent.Parent.createSignalIfSupported).createSignalIfSupported

describe("createSignalIfSupported", function()
	it("should be a function", function()
		expect(typeof(createSignalIfSupported)).toBe("function")
	end)

	it("should not throw", function()
		expect(createSignalIfSupported).never.toThrow()
	end)
end)

return {}
