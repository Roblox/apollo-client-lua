--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local RegExp = require(rootWorkspace.LuauRegExp)
local equal = require(script.Parent.Parent.equal)
describe("equal", function()
	it("should return false if types don't match", function()
		expect(equal(1, "1")).toEqual(false)
		expect(equal(1, true)).toEqual(false)
		expect(equal({}, "table")).toEqual(false)
		expect(equal(1, nil)).toEqual(false)
	end)

	it("should return true when compared to itself", function()
		local a = { "foo" }
		local b = 1
		local c = false
		local d = { foo = "foo", bar = "bar" }
		local e = d
		expect(equal(a, a)).toEqual(true)
		expect(equal(b, b)).toEqual(true)
		expect(equal(c, c)).toEqual(true)
		expect(equal(d, d)).toEqual(true)
		expect(equal(d, e)).toEqual(true)
	end)

	it("should compare nested tables", function()
		local a = { foo = "foo", bar = "bar", baz = { fizz = "fizz", fuzz = "fuzz" } }
		local b = { foo = "foo", bar = "bar", baz = { fizz = "fizz", fuzz = "fuzz" } }
		local c = { foo = "foo", bar = "bar", baz = { fizz = "fizz", fuzz = "fail" } }
		local d = { foo = "foo", bar = "bar", baz = { fizz = "fizz", fail = "fuzz" } }
		local e = { foo = "foo", bar = "bar", baz = { fizz = "fizz" } }
		expect(equal(a, b)).toEqual(true)
		expect(equal(a, c)).toEqual(false)
		expect(equal(a, d)).toEqual(false)
		expect(equal(a, e)).toEqual(false)
	end)

	it("should compare array-like tables", function()
		local a = { "foo", "bar", "baz" }
		local b = { "foo", "bar", "baz" }
		local c = { "bar", "foo", "baz" }
		expect(equal(a, b)).toEqual(true)
		expect(equal(a, c)).toEqual(false)
	end)

	it("should compare functions", function()
		local function a() end
		local b = a
		local function c() end
		expect(equal(a, b)).toBe(true)
		expect(equal(a, c)).toBe(false)
	end)

	it("should fail if type is not supported and using '==' is not enough", function()
		local a = newproxy(false)
		local b = a
		local c = newproxy()
		expect(equal(a, b)).toEqual(true)
		expect(function()
			equal(a, c)
		end).toThrowError(RegExp("unhandled equality check"))
	end)

	it("should return false table items count differs", function()
		local a = { "foo", "bar" }
		local b = { "foo" }
		local c = { foo = "foo" }
		local d = { foo = "foo", bar = "bar" }
		local e = { foo = "foo", bar = "bar", baz = "baz" }
		expect(equal(a, b)).toEqual(false)
		expect(equal(c, d)).toEqual(false)
		expect(equal(d, e)).toEqual(false)
	end)
end)

return {}
