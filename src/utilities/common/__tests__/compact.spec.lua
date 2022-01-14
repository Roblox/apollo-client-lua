-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/common/__tests__/compact.ts
return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local Packages = srcWorkspace.Parent
	local LuauPolyfill = require(Packages.LuauPolyfill)
	local Object = LuauPolyfill.Object
	local JestGlobals = require(Packages.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local compact = require(script.Parent.Parent.compact).compact
	local hasOwn = require(srcWorkspace.luaUtils.hasOwnProperty)
	describe("compact", function()
		it("should produce an empty object when called without args", function()
			jestExpect(compact()).toEqual({})
		end)
		it("should merge objects without modifying them", function()
			local a = { a = 1, ay = "a" }
			local b = { b = 2, bee = "b" }
			local c = compact(a, b)
			jestExpect(c).toEqual(Object.assign({}, a, b))
			-- ROBLOX deviation: can't rely on order of keys
			local aKeys = Object.keys(a)
			table.sort(aKeys)
			local bKeys = Object.keys(b)
			table.sort(bKeys)
			jestExpect(aKeys).toEqual({ "a", "ay" })
			jestExpect(bKeys).toEqual({ "b", "bee" })
		end)
		it("should clean undefined values from single objects", function()
			local source = { zero = 0, undef = 0 and nil or nil, three = 3 }
			local result = compact(source)
			jestExpect(result).toEqual({ zero = 0, three = 3 })
			-- ROBLOX deviation: can't rely on order of keys
			local resultKeys = Object.keys(result)
			table.sort(resultKeys)
			jestExpect(resultKeys).toEqual({ "three", "zero" })
		end)
		it("should skip over undefined values in later objects", function()
			jestExpect(compact({ a = 1, b = 2 }, { b = 0 and nil or nil, c = 3 }, { a = 4, c = 0 and nil or nil })).toEqual({
				a = 4,
				b = 2,
				c = 3,
			})
		end)
		it("should not leave undefined properties in result object", function()
			local result = compact({ a = 1, b = 0 and nil or nil }, { a = 2, c = 0 and nil or nil })
			jestExpect(hasOwn(result, "a")).toBe(true)
			jestExpect(hasOwn(result, "b")).toBe(false)
			jestExpect(hasOwn(result, "c")).toBe(false)
			jestExpect(result).toEqual({ a = 2 })
		end)
	end)
end
