-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/common/__tests__/compact.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local Packages = srcWorkspace.Parent
local LuauPolyfill = require(Packages.LuauPolyfill)
local Object = LuauPolyfill.Object

local JestGlobals = require(Packages.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local compact = require(script.Parent.Parent.compact).compact
local hasOwn = require(srcWorkspace.luaUtils.hasOwnProperty)
describe("compact", function()
	it("should produce an empty object when called without args", function()
		expect(compact()).toEqual({})
	end)
	it("should merge objects without modifying them", function()
		local a = { a = 1, ay = "a" }
		local b = { b = 2, bee = "b" }
		local c = compact(a, b)
		expect(c).toEqual(Object.assign({}, a, b))
		-- ROBLOX deviation: can't rely on order of keys
		local aKeys = Object.keys(a)
		table.sort(aKeys)
		local bKeys = Object.keys(b)
		table.sort(bKeys)
		expect(aKeys).toEqual({ "a", "ay" })
		expect(bKeys).toEqual({ "b", "bee" })
	end)
	it("should clean undefined values from single objects", function()
		local source = { zero = 0, undef = nil, three = 3 }
		local result = compact(source)
		expect(result).toEqual({ zero = 0, three = 3 })
		-- ROBLOX deviation: can't rely on order of keys
		local resultKeys = Object.keys(result)
		table.sort(resultKeys)
		expect(resultKeys).toEqual({ "three", "zero" })
	end)
	it("should skip over undefined values in later objects", function()
		expect(compact({ a = 1, b = 2 }, { b = nil, c = 3 }, { a = 4, c = nil })).toEqual({
			a = 4,
			b = 2,
			c = 3,
		})
	end)
	it("should not leave undefined properties in result object", function()
		local result = compact({ a = 1, b = nil }, { a = 2, c = nil })
		expect(hasOwn(result, "a")).toBe(true)
		expect(hasOwn(result, "b")).toBe(false)
		expect(hasOwn(result, "c")).toBe(false)
		expect(result).toEqual({ a = 2 })
	end)
end)

return {}
