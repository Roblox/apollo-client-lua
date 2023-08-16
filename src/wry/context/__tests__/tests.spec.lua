--[[
 * Copyright (c) 2019-2021 Ben Newman <ben@eloper.dev>
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/benjamn/wryware/blob/91655122045a99ad445aa330e88905feb3775db6/packages/context/src/tests.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array

local Promise = require(rootWorkspace.Promise)

local contextModule = require(script.Parent.Parent.context)
local Slot = contextModule.Slot
local bind = contextModule.bind
local noContext = contextModule.noContext
local setTimeout = contextModule.setTimeout
-- local asyncFromGen = contextModule.asyncFromGen
type Slot<TValue> = contextModule.Slot<TValue>

local function repeat_(s: string, times: number)
	local result = ""
	while times > 0 do
		times -= 1
		result ..= s
	end
	return result
end
describe("Slot", function()
	it("is importable", function()
		expect(typeof(Slot.new)).toBe("function")
	end)

	it("has no value initially", function()
		local slot = Slot.new()
		expect(slot:hasValue()).toBe(false)
		expect(typeof(slot:getValue())).toBe("nil")
	end)

	it("retains values set by withValue", function()
		local slot = Slot.new()

		local results = slot:withValue(123, function()
			expect(slot:hasValue()).toBe(true)
			expect(slot:getValue()).toBe(123)

			local results = {
				slot:getValue(),
				slot:withValue(456, function()
					expect(slot:hasValue()).toBe(true)
					return slot:getValue()
				end),
				slot:withValue(789, function()
					expect(slot:hasValue()).toBe(true)
					return slot:getValue()
				end),
			}

			expect(slot:hasValue()).toBe(true)
			expect(slot:getValue()).toBe(123)

			return results
		end)

		expect(slot:hasValue()).toBe(false)
		expect(results).toEqual({ 123, 456, 789 })
	end)

	it("is not confused by other slots", function()
		local stringSlot = Slot.new()
		local numberSlot = Slot.new()

		local function inner()
			return repeat_(stringSlot:getValue(), numberSlot:getValue())
		end

		local oneWay = stringSlot:withValue("oyez", function()
			return numberSlot:withValue(3, inner)
		end)

		expect(stringSlot:hasValue()).toBe(false)
		expect(numberSlot:hasValue()).toBe(false)

		local otherWay = numberSlot:withValue(3, function()
			return stringSlot:withValue("oyez", inner)
		end)

		expect(stringSlot:hasValue()).toBe(false)
		expect(numberSlot:hasValue()).toBe(false)

		expect(oneWay).toBe(otherWay)
		expect(oneWay).toBe("oyezoyezoyez")
	end)

	it("is a singleton", function()
		local cjsSlotModule = require(script.Parent.Parent.slot)
		expect(Slot.new()).toBeInstanceOf(cjsSlotModule.Slot)
		expect(cjsSlotModule.Slot.new()).toBeInstanceOf(Slot)
		expect(cjsSlotModule.Slot).toBe(Slot)
		expect((Array :: any)["@wry/context:Slot"]).toBe(Slot)
		-- ROBLOX deviation: there is no way in Lua to have a non-enumerable key
		-- expect(Object.keys(Array)).toEqual({})
	end)

	it("can be subclassed", function()
		local NamedSlot = setmetatable({}, Slot)
		NamedSlot.__index = NamedSlot

		type NamedSlot = Slot<any> & { name: string }

		function NamedSlot.new(name: string)
			local super = Slot.new()
			local self = setmetatable(super, NamedSlot)

			self.name = name
			self.id = name .. ":" .. self.id

			return (self :: any) :: NamedSlot
		end

		local ageSlot = NamedSlot.new("age")
		expect(ageSlot:hasValue()).toBe(false)
		ageSlot:withValue(87, function()
			expect(ageSlot:hasValue()).toBe(true)
			local age = ageSlot:getValue()
			expect(age).toBe(87)
			expect(ageSlot.name).toBe("age")
			expect(string.find(ageSlot.id, "age:slot:") == 1).toBe(true)
			return nil
		end)

		local DefaultSlot = setmetatable({}, Slot)
		DefaultSlot.__index = DefaultSlot

		type DefaultSlot = Slot<any> & { defaultValue: any }

		function DefaultSlot.new(defaultValue: any)
			local super = Slot.new()

			local self = setmetatable(super, DefaultSlot)
			self.defaultValue = defaultValue

			return (self :: any) :: DefaultSlot
		end

		function DefaultSlot:hasValue()
			return true
		end

		function DefaultSlot:getValue()
			if Slot.hasValue(self) then
				return Slot.getValue(self)
			else
				return self.defaultValue
			end
		end

		local defaultSlot = DefaultSlot.new("default")
		expect(defaultSlot:hasValue()).toBe(true)
		expect(defaultSlot:getValue()).toBe("default")
		local check = defaultSlot:withValue("real", function()
			expect(defaultSlot:hasValue()).toBe(true)
			expect(defaultSlot:getValue()).toBe("real")
			return bind(function()
				expect(defaultSlot:hasValue()).toBe(true)
				expect(defaultSlot:getValue()).toBe("real")
			end)
		end)
		expect(defaultSlot:hasValue()).toBe(true)
		expect(defaultSlot:getValue()).toBe("default")
		check()
	end)
end)

describe("bind", function()
	it("is importable", function()
		expect(typeof(bind)).toBe("function")
	end)

	it("preserves multiple slots", function()
		local stringSlot = Slot.new()
		local numberSlot = Slot.new()

		local function neither()
			expect(stringSlot:hasValue()).toBe(false)
			expect(numberSlot:hasValue()).toBe(false)
		end

		local checks = { bind(neither) }

		stringSlot:withValue("asdf", function()
			local function justStringAsdf()
				expect(stringSlot:hasValue()).toBe(true)
				expect(stringSlot:getValue()).toBe("asdf")
				expect(numberSlot:hasValue()).toBe(false)
			end

			table.insert(checks, bind(justStringAsdf))

			numberSlot:withValue(54321, function()
				table.insert(
					checks,
					bind(function()
						expect(stringSlot:hasValue()).toBe(true)
						expect(stringSlot:getValue()).toBe("asdf")
						expect(numberSlot:hasValue()).toBe(true)
						expect(numberSlot:getValue()).toBe(54321)
					end)
				)
			end)

			stringSlot:withValue("oyez", function()
				table.insert(
					checks,
					bind(function()
						expect(stringSlot:hasValue()).toBe(true)
						expect(stringSlot:getValue()).toBe("oyez")
						expect(numberSlot:hasValue()).toBe(false)
					end)
				)

				numberSlot:withValue(12345, function()
					table.insert(
						checks,
						bind(function()
							expect(stringSlot:hasValue()).toBe(true)
							expect(stringSlot:getValue()).toBe("oyez")
							expect(numberSlot:hasValue()).toBe(true)
							expect(numberSlot:getValue()).toBe(12345)
						end)
					)
				end)
			end)

			table.insert(checks, bind(justStringAsdf))
		end)

		table.insert(checks, bind(neither))

		Array.forEach(checks, function(check)
			return check()
		end)
	end)

	it("does not permit rebinding", function()
		local slot = Slot.new()
		local bound = slot:withValue(1, function()
			return bind(function()
				expect(slot:hasValue()).toBe(true)
				expect(slot:getValue()).toBe(1)
				return slot:getValue()
			end)
		end)
		expect(bound()).toBe(1)
		local rebound = slot:withValue(2, function()
			return bind(bound)
		end)
		expect(rebound()).toBe(1)
		expect(slot:hasValue()).toBe(false)
	end)
end)

describe("noContext", function()
	it("is importable", function()
		expect(typeof(noContext)).toBe("function")
	end)

	it("severs context set by withValue", function()
		local slot = Slot.new()
		local result = slot:withValue("asdf", function()
			expect(slot:getValue()).toBe("asdf")
			return noContext(function()
				expect(slot:hasValue()).toBe(false)
				return "inner"
			end)
		end)
		expect(result).toBe("inner")
	end)

	it("severs bound context", function()
		local slot = Slot.new()
		local bound = slot:withValue("asdf", function()
			expect(slot:getValue()).toBe("asdf")
			return bind(function()
				expect(slot:getValue()).toBe("asdf")
				return noContext(function()
					expect(slot:hasValue()).toBe(false)
					return "inner"
				end)
			end)
		end)
		expect(slot:hasValue()).toBe(false)
		expect(bound()).toBe("inner")
	end)

	it("permits reestablishing inner context values", function()
		local slot = Slot.new()
		local bound = slot:withValue("asdf", function()
			expect(slot:getValue()).toBe("asdf")
			return bind(function()
				expect(slot:getValue()).toBe("asdf")
				return noContext(function()
					expect(slot:hasValue()).toBe(false)
					return slot:withValue("oyez", function()
						expect(slot:hasValue()).toBe(true)
						return slot:getValue()
					end)
				end)
			end)
		end)
		expect(slot:hasValue()).toBe(false)
		expect(bound()).toBe("oyez")
	end)

	it("permits passing arguments and this", function()
		local slot = Slot.new()
		local self_ = {}
		local notSelf = {}
		local result = slot:withValue(1, function(self, a: number)
			expect(slot:hasValue()).toBe(true)
			expect(slot:getValue()).toBe(1)
			expect(self).toBe(self_)
			return noContext(function(self, b: number)
				expect(slot:hasValue()).toBe(false)
				expect(self).toBe(notSelf)
				-- ROBLOX deviation: there are no arrow functions in Lua. Mimicking the behavior with additional variable
				local outerSelf = self
				return slot:withValue(b, function(_, aArg, bArg)
					expect(slot:hasValue()).toBe(true)
					expect(slot:getValue()).toBe(b)
					-- ROBLOX deviation: using outerSelf explicitely
					expect(outerSelf).toBe(notSelf)
					expect(a).toBe(aArg)
					expect(b).toBe(bArg)
					return aArg * bArg
				end, {
					a,
					b,
				}, self_)
			end, {
				3,
			}, notSelf)
		end, {
			2,
		}, self_)
		expect(result).toBe(2 * 3)
	end)

	it("works with Array-like (arguments) objects", function()
		local function multiply(a: number, b: number, ...)
			local arguments = table.pack(a, b, ...)
			return noContext(function(self, a: number, b: number)
				return a * b
			end, arguments :: any)
		end
		expect(multiply(3, 7) * 2).toBe(42)
	end)
end)

describe("setTimeout", function()
	it("is importable", function()
		expect(typeof(setTimeout)).toBe("function")
	end)

	it("binds its callback", function()
		local booleanSlot = Slot.new()
		local objectSlot = Slot.new()
		Promise.new(function(resolve, reject)
			booleanSlot:withValue(true, function()
				expect(booleanSlot:getValue()).toBe(true)
				objectSlot:withValue({ foo = 42 }, function()
					setTimeout(function()
						xpcall(function()
							expect(booleanSlot:hasValue()).toBe(true)
							expect(booleanSlot:getValue()).toBe(true)
							expect(objectSlot:hasValue()).toBe(true)
							expect(objectSlot:getValue().foo).toBe(42)
							resolve()
						end, function(error_)
							reject(error_)
						end)
						return nil
					end, 10)
				end)
			end)
		end)
			:andThen(function()
				--[[
						ROBLOX deviation:
						because Luau implementation of Promise resolves synchronously
						we need to delay the execution on andThen callback to the next tick
						so that the bound context is restored
					]]
				return Promise.delay(0)
			end)
			:andThen(function()
				expect(booleanSlot:hasValue()).toBe(false)
				expect(objectSlot:hasValue()).toBe(false)
			end)
			:expect()
	end)
end)

-- ROBLOX deviation: Luau doesn't support generators
-- describe("asyncFromGen", function()
-- 	it("is importable", function()
-- 		expect(typeof(asyncFromGen)).toBe("function")
-- 	end)

-- 	it(
-- 		"works like an async function",
-- 		asyncFromGen(function(): Generator<number | Promise<number>, Promise<string>, number>
-- 			local sum = 0
-- 			local limit = error("not implemented")
-- 			--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 			--[[ yield new Promise(resolve => {
-- 				setTimeout(() => resolve(10), 10);
-- 			}) ]]
-- 			error("not implemented")
-- 			--[[ ROBLOX TODO: Unhandled node for type: ForStatement ]]
-- 			--[[ for (let i = 0; i < limit; ++i) {
-- 				sum += yield i + 1;
-- 			} ]]
-- 			expect(sum).toBe(55)
-- 			return Promise.resolve("ok")
-- 		end)
-- 	)
-- 	it("properly handles exceptions", function()
-- 		local fn = asyncFromGen(function(throwee: any)
-- 			local result = error("not implemented")
-- 			--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 			--[[ yield Promise.resolve("ok") ]]
-- 			if Boolean.toJSBoolean(throwee) then
-- 				error(
-- 					error("not implemented")
-- 					--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 					--[[ yield throwee ]]
-- 				)
-- 			end
-- 			return result
-- 		end)
-- 		local okPromise = fn()
-- 		local expected = {}
-- 		local koPromise = fn(expected)
-- 		expect(okPromise:expect())("ok")
-- 		xpcall(function()
-- 			koPromise:expect()
-- 			error(Error.new("not reached"))
-- 		end, function(error_)
-- 			expect(error_).toBe(expected)
-- 		end)
-- 		xpcall(function()
-- 			fn(Promise.resolve("oyez")):expect()
-- 			error(Error.new("not reached"))
-- 		end, function(thrown)
-- 			expect(thrown).toBe("oyez")
-- 		end)
-- 	end)

-- 	it("propagates contextual slot values across yields", function()
-- 		local stringSlot = Slot.new()
-- 		local numberSlot = Slot.new()
-- 		local function checkNoValues()
-- 			expect(stringSlot:hasValue()).toBe(false)
-- 			expect(numberSlot:hasValue()).toBe(false)
-- 		end
-- 		local inner = asyncFromGen(function(stringValue: string, numberValue: number)
-- 			local function checkValues()
-- 				expect(stringSlot:getValue()).toBe(stringValue)
-- 				expect(numberSlot:getValue()).toBe(numberValue)
-- 			end
-- 			checkValues()
-- 			error("not implemented")
-- 			--[[ yield new Promise<void>(resolve => setTimeout(function () {
-- 				checkValues();
-- 				resolve();
-- 			}, 10)) ]]
-- 			--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 			checkValues()
-- 			error("not implemented")
-- 			--[[ yield new Promise<void>(resolve => {
-- 				checkValues();
-- 				resolve();
-- 			}) ]]
-- 			--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 			checkValues()
-- 			error("not implemented")
-- 			--[[ yield Promise.resolve().then(checkNoValues) ]]
-- 			--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 			checkValues()
-- 			return repeat_(stringValue, numberValue)
-- 		end)
-- 		local outer = asyncFromGen(function()
-- 			checkNoValues()
-- 			local oyezPromise = stringSlot:withValue("oyez", function()
-- 				return numberSlot:withValue(3, function()
-- 					return inner("oyez", 3)
-- 				end)
-- 			end)
-- 			checkNoValues()
-- 			local hahaPromise = numberSlot:withValue(4, function()
-- 				return stringSlot:withValue("ha", function()
-- 					return inner("ha", 4)
-- 				end)
-- 			end)
-- 			checkNoValues()
-- 			expect(
-- 				error("not implemented")
-- 				--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 				--[[ yield oyezPromise ]]
-- 			).toBe("oyezoyezoyez")
-- 			expect(
-- 				error("not implemented")
-- 				--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 				--[[ yield hahaPromise ]]
-- 			).toBe("hahahaha")
-- 			checkNoValues()
-- 			return Promise.all({ oyezPromise, hahaPromise })
-- 		end)
-- 		return outer():then_(function(results)
-- 			checkNoValues()
-- 			expect(results).toEqual({ "oyezoyezoyez", "hahahaha" })
-- 		end)
-- 	end)

-- 	it("allows Promise rejections to be caught", function()
-- 		local fn = asyncFromGen(function()
-- 			do --[[ ROBLOX COMMENT: try-catch block conversion ]]
-- 				local ok, result, hasReturned = xpcall(function()
-- 					error("not implemented")
-- 					--[[ yield Promise.reject(new Error("expected")) ]]
-- 					--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
-- 					error(Error.new("not reached"))
-- 				end, function(error_)
-- 					expect(error_.message).toBe("expected")
-- 				end)
-- 				if hasReturned then
-- 					return result
-- 				end
-- 			end
-- 			return "ok"
-- 		end)
-- 		return fn():then_(function(result)
-- 			expect(result).toBe("ok")
-- 		end)
-- 	end)
-- end)

return {}
