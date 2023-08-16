--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
local coreWorkspace = script.Parent.Parent
local rootWorkspace = coreWorkspace.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

require(coreWorkspace.types)

describe("Core types", function()
	it("empty test", function()
		expect("").toEqual("")
	end)
end)

return {}
