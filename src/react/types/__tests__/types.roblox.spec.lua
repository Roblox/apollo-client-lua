--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX no upstream

local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect
local describe = JestGlobals.describe
local it = JestGlobals.it

local _typesModule = require(script.Parent.Parent.types)

describe("types module", function()
	it("empty test", function()
		-- just to verify the types file is executing properly
		expect("").toEqual("")
	end)
end)

return {}
