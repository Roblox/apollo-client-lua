-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/object-canon.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

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

			jestExpect(obj1).toEqual(obj2)
			jestExpect(obj1).never.toBe(obj2)

			local c1 = canon:admit(obj1)
			local c2 = canon:admit(obj2)

			jestExpect(c1).toBe(c2)
			jestExpect(c1).toEqual(obj1)
			jestExpect(c1).toEqual(obj2)
			jestExpect(c2).toEqual(obj1)
			jestExpect(c2).toEqual(obj2)
			jestExpect(c1).never.toBe(obj1)
			jestExpect(c1).never.toBe(obj2)
			jestExpect(c2).never.toBe(obj1)
			jestExpect(c2).never.toBe(obj2)

			jestExpect(canon:admit(c1)).toBe(c1)
			jestExpect(canon:admit(c2)).toBe(c2)
		end)

		-- TODO Reenable this when ObjectCanon allows enabling canonization for
		-- arbitrary prototypes (not just {Array,Object}.prototype and null).
		-- ROBLOX comment: this test is skipped upstream
		xit("preserves custom prototypes", function()
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
			jestExpect(admitted).never.toBe(customs)
			jestExpect(admitted).toEqual(customs)

			local function check(i: number)
				jestExpect(admitted[i]).toEqual(customs[i])
				jestExpect(admitted[i]).never.toBe(customs[i])
				jestExpect(admitted[i]:getValue()).toBe(customs[i]:getValue())
				jestExpect(Object.getPrototypeOf(admitted[i])).toBe(Custom)
				jestExpect(admitted[i]).toBeInstanceOf(Custom)
			end
			check(1)
			check(2)
			check(3)

			jestExpect(canon:admit(customs)).toBe(admitted)

			local function checkProto(proto: nil | Object)
				local a = Object.create(proto)
				local b = Object.create(proto, {
					visible = "bee",
					-- ROBLOX TODO: there is no way to create non-enumerable props in Lua
					-- visible = { value = "bee", enumerable = true },
					-- hidden = { value = "invisibee", enumerable = false },
				})

				local admitted = canon:admit({ a = a, b = b })

				jestExpect(admitted.a).toEqual(a)
				jestExpect(admitted.a).never.toBe(a)

				jestExpect(admitted.b).toEqual(b)
				jestExpect(admitted.b).never.toBe(b)

				jestExpect(Object.getPrototypeOf(admitted.a)).toBe(proto)
				jestExpect(Object.getPrototypeOf(admitted.b)).toBe(proto)

				jestExpect(admitted.b.visible).toBe("bee")
				jestExpect(admitted.b.hidden).toBeUndefined()
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
				jestExpect(admitted).never.toBe(obj)
				jestExpect(admitted.b).toBe(cd)
				jestExpect(admitted.e).toEqual(cd)
				jestExpect(admitted.e).never.toBe(cd)
				jestExpect(admitted.e).toEqual(admitted.b)
				jestExpect(admitted.e).never.toBe(admitted.b)
				jestExpect(admitted.e).toBe(admitted.a)
			end
			check()
			check()
		end)
	end)
end
