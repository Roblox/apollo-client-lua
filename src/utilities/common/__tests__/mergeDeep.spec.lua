-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/common/__tests__/mergeDeep.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Boolean = LuauPolyfill.Boolean
	local String = LuauPolyfill.String
	type Array<T> = LuauPolyfill.Array<T>
	type Record<T, U> = { [T]: U }

	local HttpService = game:GetService("HttpService")

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local mergeDeepModule = require(script.Parent.Parent.mergeDeep)
	local mergeDeep = mergeDeepModule.mergeDeep
	local mergeDeepArray = mergeDeepModule.mergeDeepArray
	local DeepMerger = mergeDeepModule.DeepMerger
	type DeepMerger = mergeDeepModule.DeepMerger

	describe("mergeDeep", function()
		it("should return an object if first argument falsy", function()
			jestExpect(mergeDeep()).toEqual({})
			jestExpect(mergeDeep(nil)).toEqual({})
			jestExpect(mergeDeep(nil, { foo = 42 })).toEqual({ foo = 42 })
		end)

		it("should preserve identity for single arguments", function()
			local arg = {}
			jestExpect(mergeDeep(arg)).toBe(arg)
		end)

		it("should preserve identity when merging non-conflicting objects", function()
			local a = { a = { name = "ay" } }
			local b = { b = { name = "bee" } }
			local c = mergeDeep(a, b)
			jestExpect(c.a).toBe(a.a)
			jestExpect(c.b).toBe(b.b)
			jestExpect(c).toEqual({ a = { name = "ay" }, b = { name = "bee" } })
		end)

		it("should shallow-copy conflicting fields", function()
			local a = { conflict = { fromA = { 1, 2, 3 } } }
			local b = { conflict = { fromB = { 4, 5 } } }
			local c = mergeDeep(a, b)
			jestExpect(c.conflict).never.toBe(a.conflict)
			jestExpect(c.conflict).never.toBe(b.conflict)
			jestExpect(c.conflict.fromA).toBe(a.conflict.fromA)
			jestExpect(c.conflict.fromB).toBe(b.conflict.fromB)
			jestExpect(c).toEqual({ conflict = { fromA = { 1, 2, 3 }, fromB = { 4, 5 } } })
		end)

		it("should resolve conflicts among more than two objects", function()
			local sources = {}

			for i = 1, 100 do
				table.insert(sources, {
					["unique" .. i] = {
						value = i,
					},
					conflict = {
						["from" .. i] = {
							value = i,
						},
						nested = {
							["nested" .. i] = {
								value = i,
							},
						},
					},
				})
			end

			local merged = mergeDeep(table.unpack(sources))

			Array.forEach(sources, function(source, i)
				jestExpect(merged["unique" .. i].value).toBe(i)
				jestExpect(source["unique" .. i]).toBe(merged["unique" .. i])

				jestExpect(merged.conflict).never.toBe(source.conflict)
				jestExpect(merged.conflict["from" .. i].value).toBe(i)
				jestExpect(merged.conflict["from" .. i]).toBe(source.conflict["from" .. i])

				jestExpect(merged.conflict.nested).never.toBe(source.conflict.nested)
				jestExpect(merged.conflict.nested["nested" .. i].value).toBe(i)
				jestExpect(merged.conflict.nested["nested" .. i]).toBe(source.conflict.nested["nested" .. i])
			end)
		end)

		it("can merge array elements", function()
			local a = { { a = 1 } :: any, { a = "ay" }, "a" }
			local b = { { b = 2 } :: any, { b = "bee" }, "b" }
			local c = { { c = 3 } :: any, { c = "cee" }, "c" }
			local d = { [2] = { d = "dee" } }

			jestExpect(mergeDeep(a, b, c, d)).toEqual({
				{ a = 1, b = 2, c = 3 } :: any,
				{ a = "ay", b = "bee", c = "cee", d = "dee" },
				"c",
			})
		end)

		it("lets the last conflicting value win", function()
			jestExpect(mergeDeep("a", "b", "c")).toBe("c")

			jestExpect(mergeDeep({ a = "a", conflict = 1 }, { b = "b", conflict = 2 }, { c = "c", conflict = 3 })).toEqual({
				a = "a",
				b = "b",
				c = "c",
				conflict = 3,
			})

			jestExpect(mergeDeep({ "a" :: any, { "b", "c" }, "d" } :: any, {
				nil :: any, --[[empty]]
				{ "B" },
				"D",
			})).toEqual({
				"a" :: any,
				{ "B", "c" },
				"D",
			})

			jestExpect(mergeDeep({ "a" :: any, { "b", "c" }, "d" } :: any, {
				"A" :: any,
				{
					nil :: any, --[[empty]]
					"C",
				},
			})).toEqual({
				"A" :: any,
				{ "b", "C" },
				"d",
			})
		end)

		it("mergeDeep returns the intersection of its argument types", function()
			local abc = mergeDeep({ str = "hi", a = 1 }, { a = 3, b = 2 }, { b = 1, c = 2 })
			-- The point of this test is that the following lines type-check without
			-- resorting to any `any` loopholes:
			jestExpect(String.slice(abc.str, 1)).toBe("hi")
			jestExpect(abc.a * 2).toBe(6)
			jestExpect(abc.b - 0).toBe(1)
			jestExpect(abc.c / 2).toBe(1)
		end)

		it("mergeDeepArray returns the supertype of its argument types", function()
			type F = { check: (self: F) -> string }
			local F = {}
			F.__index = F
			function F.new(): F
				local self = setmetatable({}, F)
				return (self :: any) :: F
			end
			function F:check()
				return "ok"
			end
			local fs: Array<F> = { F.new(), F.new(), F.new() }
			-- Although mergeDeepArray doesn't have the same tuple type awareness as
			-- mergeDeep, it does infer that F should be the return type here:
			jestExpect(mergeDeepArray(fs):check()).toBe("ok")
		end)

		it("supports custom reconciler functions", function()
			local merger = DeepMerger.new(function(self, target, source, key)
				local targetValue = target[tostring(key)]
				local sourceValue = source[tostring(key)]
				if Boolean.toJSBoolean(Array.isArray(sourceValue)) then
					if not Boolean.toJSBoolean(Array.isArray(targetValue)) then
						return sourceValue
					end
					return Array.concat({}, targetValue, sourceValue)
				end
				return self:merge(targetValue, sourceValue)
			end)

			jestExpect(merger:merge({
				a = { 1, 2, 3 },
				b = "replace me",
			}, {
				a = { 4, 5 },
				b = { "I", "win" },
			})).toEqual({
				a = { 1, 2, 3, 4, 5 },
				b = { "I", "win" },
			})
		end)

		it("returns original object references when possible", function()
			local target = {
				a = 1,
				b = {
					c = 3,
					d = 4,
				},
				e = 5,
			}

			jestExpect(mergeDeep(target, { b = { c = 3 } })).toBe(target)

			local partial = mergeDeep(target, {
				a = 1,
				b = {
					c = 3,
				},
				e = "eee",
			})

			jestExpect(partial).never.toBe(target)
			jestExpect(partial.b).toBe(target.b)

			local multiple = mergeDeep(target, {
				a = 1,
			}, {
				b = { d = 4 },
			}, {
				e = 5,
			})

			jestExpect(multiple).toBe(target)

			local targetWithArrays = {
				a = 1,
				b = { 2 :: any, {
					c = { 3, 4 },
					d = 5,
				}, 6 },
				e = { 7, 8, 9 },
			}

			jestExpect(mergeDeep(targetWithArrays, { e = {} })).toBe(targetWithArrays)

			jestExpect(mergeDeep(targetWithArrays, {
				e = {
					nil :: any, --[[hole]]
					nil, --[[hole]]
					9,
				},
			})).toBe(targetWithArrays)

			jestExpect(mergeDeep(targetWithArrays, {
				a = 1,
				e = { 7, 8 },
			})).toBe(targetWithArrays)

			jestExpect(mergeDeep(targetWithArrays, {
				b = { 2 :: any, {
					c = {},
					d = 5,
				} },
			})).toBe(targetWithArrays)

			jestExpect(mergeDeep(targetWithArrays, {
				b = { 2 :: any, {
					c = { 3 },
					d = 5,
				}, 6 },
				e = {},
			})).toBe(targetWithArrays)

			local nestedInequality = mergeDeep(targetWithArrays, {
				b = { 2 :: any, {
					c = { 3 },
					d = 5,
				}, "wrong" },
				e = {},
			})

			jestExpect(nestedInequality).never.toBe(targetWithArrays)
			jestExpect(nestedInequality.b).never.toBe(targetWithArrays.b)
			jestExpect(nestedInequality.b[2]).toEqual({
				c = { 3, 4 },
				d = 5,
			})
			jestExpect(nestedInequality.b[2]).toBe(targetWithArrays.b[2])

			jestExpect(
				mergeDeep(
					targetWithArrays,
					HttpService:JSONDecode(HttpService:JSONEncode(targetWithArrays)),
					HttpService:JSONDecode(HttpService:JSONEncode(targetWithArrays)),
					HttpService:JSONDecode(HttpService:JSONEncode(targetWithArrays))
				)
			).toBe(targetWithArrays)
		end)

		it("provides optional context to reconciler function", function()
			local contextObject = { contextWithSpaces = "c o n t e x t" } :: any

			local shallowContextValues: Array<any> = {}
			local shallowMerger = DeepMerger.new(
				function(
					self: DeepMerger,
					target: Record<string | number, any>,
					source: Record<string | number, any>,
					property: string | number,
					context: any
				)
					-- ROBLOX deviation: inserting { context = context } instead of just context to be able to insert nil context
					table.insert(shallowContextValues, { context = context })
					-- Deliberately not passing context down to nested levels.
					return self:merge(target[property], source[property])
				end
			)

			local typicalContextValues: Array<any> = {}
			local typicalMerger = DeepMerger.new(
				function(
					self: DeepMerger,
					target: Record<string | number, any>,
					source: Record<string | number, any>,
					property: string | number,
					context: any
				)
					table.insert(typicalContextValues, context)
					-- Passing context down this time.
					return self:merge(target[property], source[property], context)
				end
			)

			local left = {
				a = 1,
				b = {
					c = 2,
					d = { 3, 4 },
				},
				e = 5,
			}

			local right = {
				b = {
					d = { 3, 4, 5 },
				},
			}
			local expected = {
				a = 1,
				b = {
					c = 2,
					d = { 3, 4, 5 },
				},
				e = 5,
			}

			jestExpect(shallowMerger:merge(left, right, contextObject)).toEqual(expected)
			jestExpect(typicalMerger:merge(left, right, contextObject)).toEqual(expected)

			jestExpect(#shallowContextValues).toBe(2)
			jestExpect(shallowContextValues[1].context).toBe(contextObject)
			jestExpect(shallowContextValues[2].context).toBeUndefined()

			jestExpect(#typicalContextValues).toBe(2)
			jestExpect(typicalContextValues[1]).toBe(contextObject)
			jestExpect(typicalContextValues[2]).toBe(contextObject)
		end)
	end)
end
