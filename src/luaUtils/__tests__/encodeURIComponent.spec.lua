--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: no upstream
local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local encodeURIComponent = require(script.Parent.Parent.encodeURIComponent)

describe("encodeURIComponent", function()
	it("should encode strings properly", function()
		local set1 = ";,/?:@&=+$" -- Reserved Characters
		local set2 = "-_.!~*'()" -- Unescaped Characters
		local set3 = "#" -- Number Sign
		local set4 = "ABC abc 123" -- Alphanumeric Characters + Space
		local set5 = "#$&+,/:;=?@" -- Custom set

		expect(encodeURIComponent(set1)).toEqual("%3B%2C%2F%3F%3A%40%26%3D%2B%24")
		expect(encodeURIComponent(set2)).toEqual("-_.!~*'()")
		expect(encodeURIComponent(set3)).toEqual("%23")
		expect(encodeURIComponent(set4)).toEqual("ABC%20abc%20123") -- the space gets encoded as %20
		expect(encodeURIComponent(set5)).toEqual("%23%24%26%2B%2C%2F%3A%3B%3D%3F%40")
	end)
end)

return {}
