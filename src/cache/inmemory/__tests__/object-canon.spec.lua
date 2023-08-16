--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/object-canon.ts
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
type Array<T> = LuauPolyfill.Array<T>
type Object = { [string]: any } | Array<any>

local Object = require(srcWorkspace.luaUtils.Object)

local ObjectCanon = require(script.Parent.Parent["object-canon"]).ObjectCanon

describe("ObjectCanon", function()
	it("can canonicalize objects and arrays", function()
		local canon = ObjectCanon.new()

		local obj1 = { a = { 1, 2 }, b = { c = { { d = "dee", e = "ee" } :: any, "f" }, g = "gee" } }

		local obj2 = { b = { g = "gee", c = { { e = "ee", d = "dee" } :: any, "f" } }, a = { 1, 2 } }

		expect(obj1).toEqual(obj2)
		expect(obj1).never.toBe(obj2)

		local c1 = canon:admit(obj1)
		local c2 = canon:admit(obj2)

		expect(c1).toBe(c2)
		expect(c1).toEqual(obj1)
		expect(c1).toEqual(obj2)
		expect(c2).toEqual(obj1)
		expect(c2).toEqual(obj2)
		expect(c1).never.toBe(obj1)
		expect(c1).never.toBe(obj2)
		expect(c2).never.toBe(obj1)
		expect(c2).never.toBe(obj2)

		expect(canon:admit(c1)).toBe(c1)
		expect(canon:admit(c2)).toBe(c2)
	end)

	-- TODO Reenable this when ObjectCanon allows enabling canonization for
	-- arbitrary prototypes (not just {Array,Object}.prototype and null).
	-- ROBLOX comment: this test is skipped upstream
	it.skip("preserves custom prototypes", function()
		local canon = ObjectCanon.new()

		type Custom = { value: any, getValue: (self: Custom) -> any }

		local Custom = {}
		Custom.__index = Custom

		function Custom.new(value: any): Custom
			local self = setmetatable({}, Custom)

			self.value = value

			return (self :: any) :: Custom
		end

		function Custom:getValue()
			return self.value
		end

		local customs = { Custom.new("oyez"), Custom.new(1234), Custom.new(true) }

		local admitted = canon:admit(customs)
		expect(admitted).never.toBe(customs)
		expect(admitted).toEqual(customs)

		local function check(i: number)
			expect(admitted[i]).toEqual(customs[i])
			expect(admitted[i]).never.toBe(customs[i])
			expect(admitted[i]:getValue()).toBe(customs[i]:getValue())
			expect(Object.getPrototypeOf(admitted[i])).toBe(Custom)
			expect(admitted[i]).toBeInstanceOf(Custom)
		end
		check(1)
		check(2)
		check(3)

		expect(canon:admit(customs)).toBe(admitted)

		local function checkProto(proto: nil | Object)
			local a = Object.create(proto)
			local b = Object.create(proto, {
				visible = "bee",
				-- ROBLOX TODO: there is no way to create non-enumerable props in Lua
				-- visible = { value = "bee", enumerable = true },
				-- hidden = { value = "invisibee", enumerable = false },
			})

			local admitted = canon:admit({ a = a, b = b })

			expect(admitted.a).toEqual(a)
			expect(admitted.a).never.toBe(a)

			expect(admitted.b).toEqual(b)
			expect(admitted.b).never.toBe(b)

			expect(Object.getPrototypeOf(admitted.a)).toBe(proto)
			expect(Object.getPrototypeOf(admitted.b)).toBe(proto)

			expect(admitted.b.visible).toBe("bee")
			expect(admitted.b.hidden).toBeUndefined()
		end
		checkProto(nil)
		checkProto({})
		checkProto({ 1, 2, 3 })
		-- TODO
		-- checkProto(function()
		-- 	return "fun"
		-- end)
	end)

	it("unwraps Pass wrappers as-is", function()
		local canon = ObjectCanon.new()

		local cd = { c = "see", d = "dee" }

		local obj = { a = cd, b = canon:pass(cd), e = cd }

		local function check()
			local admitted = canon:admit(obj)
			expect(admitted).never.toBe(obj)
			expect(admitted.b).toBe(cd)
			expect(admitted.e).toEqual(cd)
			expect(admitted.e).never.toBe(cd)
			expect(admitted.e).toEqual(admitted.b)
			expect(admitted.e).never.toBe(admitted.b)
			expect(admitted.e).toBe(admitted.a)
		end
		check()
		check()
	end)
end)

return {}
