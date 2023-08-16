--[[
 * Copyright (c) 2016 Ben Newman
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/api.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Error = LuauPolyfill.Error

type Array<T> = LuauPolyfill.Array<T>

-- local createHash = require(Packages.crypto).createHash
local optimismModule = require(script.Parent.Parent)
local wrap = optimismModule.wrap
local defaultMakeCacheKey = optimismModule.defaultMakeCacheKey
type OptimisticWrapperFunction<TArgs, TResult, TKeyArgs, TCacheKey> = optimismModule.OptimisticWrapperFunction<
	TArgs,
	TResult,
	TKeyArgs,
	TCacheKey
>
-- local wrapYieldingFiberMethods = require(srcWorkspace.wry.context).wrapYieldingFiberMethods
local dep = require(script.Parent.Parent.dep).dep

type NumThunk = OptimisticWrapperFunction<Array<nil>, number, any, any>

describe("optimism", function()
	it("sanity", function()
		expect(typeof(wrap)).toBe("function")
		expect(typeof(defaultMakeCacheKey)).toBe("function")
	end)

	it("works with single functions", function()
		local salt
		local test = wrap(function(x: string)
			return x .. salt
		end, {
			makeCacheKey = function(_self, x: string)
				return x
			end,
		})
		salt = "salt"
		expect(test("a")).toBe("asalt")

		salt = "NaCl"
		expect(test("a")).toBe("asalt")
		expect(test("b")).toBe("bNaCl")

		test:dirty("a")
		expect(test("a")).toBe("aNaCl")
	end)

	-- ROBLOX SKIP: no crypto dependency available
	it.skip("works with two layers of functions", function()
		-- local files: { [string]: string } = {
		-- 	["a.js"] = "a",
		-- 	["b.js"] = "b",
		-- }

		-- local fileNames = Object.keys(files)

		-- local read = wrap(function(path: string)
		-- 	return files[path]
		-- end)

		-- local hash = wrap(function(paths: Array<string>)
		-- 	local h = createHash("sha1")
		-- 	Array.forEach(paths, function(path)
		-- 		h:update(read(path))
		-- 	end)
		-- 	return h:digest("hex")
		-- end)

		-- local hash1 = hash(fileNames)
		-- files["a.js"] ..= "yy"
		-- local hash2 = hash(fileNames)
		-- read:dirty("a.js")
		-- local hash3 = hash(fileNames)
		-- files["b.js"] ..= "ee"
		-- read:dirty("b.js")
		-- local hash4 = hash(fileNames)

		-- expect(hash1).toBe(hash2)
		-- expect(hash1).never.toBe(hash3)
		-- expect(hash1).never.toBe(hash4)
		-- expect(hash3).never.toBe(hash4)
	end)

	it("works with subscription functions", function()
		local dirty: () -> ()
		local sep = ","
		local unsubscribed = {}
		local test: any
		test = wrap(function(x: string)
			return Array.join({ x, x, x }, sep)
		end, {
			max = 1,
			subscribe = function(x: string)
				dirty = function()
					test:dirty(x)
				end

				unsubscribed[x] = nil

				return function()
					unsubscribed[x] = true
				end
			end,
		})

		expect(test("a")).toBe("a,a,a")

		expect(test("b")).toBe("b,b,b")
		expect(unsubscribed).toEqual({ a = true })

		expect(test("c")).toBe("c,c,c")
		expect(unsubscribed).toEqual({ a = true, b = true })

		sep = ":"

		expect(test("c")).toBe("c,c,c")
		expect(unsubscribed).toEqual({ a = true, b = true })

		dirty()

		expect(test("c")).toBe("c:c:c")
		expect(unsubscribed).toEqual({ a = true, b = true })

		expect(test("d")).toBe("d:d:d")
		expect(unsubscribed).toEqual({ a = true, b = true, c = true })
	end)

	-- ROBLOX SKIP: no fibers dependency available
	it.skip("is not confused by fibers", function()
		-- local Fiber = wrapYieldingFiberMethods(require("fibers"))

		-- local order = {}
		-- local result1 = "one"
		-- local result2 = "two"

		-- local f1 = Fiber.new(function()
		-- 	table.insert(order, 1)

		-- 	local o1 = wrap(function()
		-- 		Fiber:yield()
		-- 		return result1
		-- 	end)

		-- 	table.insert(order, 2)
		-- 	expect(o1()).toBe("one")
		-- 	table.insert(order, 3)
		-- 	result1 ..= ":dirty"
		-- 	expect(o1()).toBe("one")
		-- 	table.insert(order, 4)
		-- 	Fiber:yield()
		-- 	table.insert(order, 5)
		-- 	expect(o1()).toBe("one")
		-- 	table.insert(order, 6)
		-- 	o1:dirty()
		-- 	table.insert(order, 7)
		-- 	expect(o1()).toBe("one:dirty")
		-- 	table.insert(order, 8)
		-- 	expect(o2()).toBe("two:dirty")
		-- 	table.insert(order, 9)
		-- end)

		-- result2 = "two"
		-- local o2 = wrap(function()
		-- 	return result2
		-- end)

		-- table.insert(order, 0)

		-- f1:run()
		-- expect(order).toEqual({ 0, 1, 2 })

		-- -- The primary goal of this test is to make sure this call to o2()
		-- -- does not register a dirty-chain dependency for o1.
		-- expect(o2()).toBe("two")

		-- f1:run()
		-- expect(order).toEqual({ 0, 1, 2, 3, 4 })

		-- -- If the call to o2() captured o1() as a parent, then this o2.dirty()
		-- -- call will report the o1() call dirty, which is not what we want.
		-- result2 ..= ":dirty"
		-- o2:dirty()

		-- f1:run()
		-- -- The call to o1() between order.push(5) and order.push(6) should not
		-- -- yield, because it should still be cached, because it should not be
		-- -- dirty. However, the call to o1() between order.push(7) and
		-- -- order.push(8) should yield, because we call o1.dirty() explicitly,
		-- -- which is why this assertion stops at 7.
		-- expect(order).toEqual({ 0, 1, 2, 3, 4, 5, 6, 7 })

		-- f1:run()
		-- expect(order).toEqual({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 })
	end)

	it("marks evicted cache entries dirty", function()
		local childSalt = "*"
		local child = wrap(function(x: string)
			return x .. childSalt
		end, { max = 1 })

		local parentSalt = "^"
		local parent = wrap(function(x: string)
			return child(x) .. parentSalt
		end)

		expect(parent("asdf")).toBe("asdf*^")

		childSalt = "&"
		parentSalt = "%"

		expect(parent("asdf")).toBe("asdf*^")
		expect(child("zxcv")).toBe("zxcv&")
		expect(parent("asdf")).toBe("asdf&%")
	end)

	it("handles children throwing exceptions", function()
		local expected = Error.new("oyez")

		local child = wrap(function()
			error(expected)
			return nil
		end)

		local parent = wrap(function()
			local ok, result = pcall(function()
				child()
				return nil
			end)
			if not ok then
				return result
			end
			return nil
		end)

		expect(parent()).toBe(expected)
		expect(parent()).toBe(expected)

		child:dirty()
		expect(parent()).toBe(expected)

		parent:dirty()
		expect(parent()).toBe(expected)
	end)

	it("reports clean children to correct parents", function()
		local childResult = "a"
		local child = wrap(function()
			return childResult
		end)

		local parent = wrap(function(x: any)
			return child() .. x
		end)

		expect(parent(1)).toBe("a1")
		expect(parent(2)).toBe("a2")

		childResult = "b"
		child:dirty()

		-- If this call to parent(1) mistakenly reports child() as clean to
		-- parent(2), then the second assertion will fail by returning "a2".
		expect(parent(1)).toBe("b1")
		expect(parent(2)).toBe("b2")
	end)

	it("supports object cache keys", function()
		local counter = 0
		local wrapped = wrap(function(a: any, b: any)
			local result = counter
			counter += 1
			return result
		end)

		local a = {}
		local b = {}

		-- Different combinations of distinct object references should
		-- increment the counter.
		expect(wrapped(a, a)).toBe(0)
		expect(wrapped(a, b)).toBe(1)
		expect(wrapped(b, a)).toBe(2)
		expect(wrapped(b, b)).toBe(3)

		-- But the same combinations of arguments should return the same
		-- cached values when passed again.
		expect(wrapped(a, a)).toBe(0)
		expect(wrapped(a, b)).toBe(1)
		expect(wrapped(b, a)).toBe(2)
		expect(wrapped(b, b)).toBe(3)
	end)

	it("supports falsy non-void cache keys", function()
		local callCount = 0
		local wrapped = wrap(function(key: number | string | nil | boolean)
			callCount += 1
			return key
		end, {
			makeCacheKey = function(_self, key)
				return key
			end,
		})

		expect(wrapped(0)).toBe(0)
		expect(callCount).toBe(1)
		expect(wrapped(0)).toBe(0)
		expect(callCount).toBe(1)

		expect(wrapped("")).toBe("")
		expect(callCount).toBe(2)
		expect(wrapped("")).toBe("")
		expect(callCount).toBe(2)

		--[[
				ROBLOX deviation:
				there is no distinction between null and undefined in Lua
				artificially triggering call of wrapped function to retail callCount
			]]
		wrapped(-1)
		-- expect(wrapped(nil)).toBe(nil)
		-- expect(callCount).toBe(3)
		-- expect(wrapped(nil)).toBe(nil)
		-- expect(callCount).toBe(3)

		expect(wrapped(false)).toBe(false)
		expect(callCount).toBe(4)
		expect(wrapped(false)).toBe(false)
		expect(callCount).toBe(4)

		expect(wrapped(0)).toBe(0)
		expect(wrapped("")).toBe("")
		--ROBLOX deviation: there is no distinction between null and undefined in Lua
		-- expect(wrapped(nil)).toBe(nil)
		expect(wrapped(false)).toBe(false)
		expect(callCount).toBe(4)

		expect(wrapped(1)).toBe(1)
		expect(wrapped("oyez")).toBe("oyez")
		expect(wrapped(true)).toBe(true)
		expect(callCount).toBe(7)

		expect(wrapped(nil)).toBe(nil)
		expect(wrapped(nil)).toBe(nil)
		expect(wrapped(nil)).toBe(nil)
		expect(callCount).toBe(10)
	end)

	it("detects problematic cycles", function()
		local self: NumThunk
		self = wrap(function()
			return self() + 1
		end)

		local mutualA: NumThunk
		local mutualB: NumThunk

		mutualA = wrap(function()
			return mutualB() + 1
		end)

		mutualB = wrap(function()
			return mutualA() + 1
		end)

		local function check(fn: any)
			local ok, e: any = pcall(function()
				fn()
				error(Error.new("should not get here"))
				return nil
			end)
			if not ok then
				expect(e.message).toBe("already recomputing")
			end

			-- Try dirtying the function, now that there's a cycle in the Entry
			-- graph. This should succeed.
			fn:dirty()
		end

		check(self)
		check(mutualA)
		check(mutualB)

		local returnZero = true
		local fn: NumThunk
		fn = wrap(function()
			if returnZero then
				returnZero = false
				return 0
			end
			returnZero = true
			return fn() + 1
		end)

		expect(fn()).toBe(0)
		expect(returnZero).toBe(false)

		returnZero = true
		expect(fn()).toBe(0)
		expect(returnZero).toBe(true)

		fn:dirty()

		returnZero = false
		check(fn)
	end)

	it("tolerates misbehaving makeCacheKey functions", function()
		type NumNum = OptimisticWrapperFunction<Array<number>, number, any, any>

		local chaos = false
		local counter = 0
		local allOddsDep = wrap(function()
			counter += 1
			return counter
		end)

		local sumOdd: NumNum
		local sumEven: NumNum

		sumOdd = wrap(function(n: number)
			allOddsDep()
			if n < 1 then
				return 0
			end
			if n % 2 == 1 then
				return n + sumEven(n - 1)
			end
			return sumEven(n)
		end, {
			makeCacheKey = function(_self, n)
				-- Even though the computation completes, returning "constant" causes
				-- cycles in the Entry graph.
				return chaos and "constant" or n
			end,
		})

		sumEven = wrap(function(n: number)
			if n < 1 then
				return 0
			end
			if n % 2 == 0 then
				return n + sumOdd(n - 1)
			end
			return sumOdd(n)
		end)

		local function check()
			sumEven:dirty(10)
			sumOdd:dirty(10)
			if chaos then
				local ok, e: any = pcall(function()
					sumOdd(10)
					return nil
				end)
				if not ok then
					expect(e.message).toBe("already recomputing")
				end
				ok, e = pcall(function()
					sumEven(10)
					return nil
				end)
				if not ok then
					expect(e.message).toBe("already recomputing")
				end
			else
				expect(sumEven(10)).toBe(55)
				expect(sumOdd(10)).toBe(55)
			end
		end

		check()

		allOddsDep:dirty()
		sumEven:dirty(10)
		check()

		allOddsDep:dirty()
		allOddsDep()
		check()

		chaos = true
		check()

		allOddsDep:dirty()
		allOddsDep()
		check()

		allOddsDep:dirty()
		check()

		chaos = false
		allOddsDep:dirty()
		check()

		chaos = true
		sumOdd:dirty(9)
		sumOdd:dirty(7)
		sumOdd:dirty(5)
		check()

		chaos = false
		check()
	end)

	it("supports options.keyArgs", function()
		local sumNums = wrap(function(...)
			local args = { ... }
			return {
				sum = Array.reduce(args, function(sum: number, arg)
					if typeof(arg) == "number" then
						return (arg + sum) :: number
					else
						return sum :: number
					end
				end, 0) :: number,
			}
		end, {
			keyArgs = function(...)
				local args = { ... }
				return Array.filter(args, function(arg)
					return typeof(arg) == "number"
				end)
			end,
		})

		expect(sumNums().sum).toBe(0)
		expect(sumNums("asdf", true, sumNums).sum).toBe(0)

		local sumObj1 = sumNums(1, "zxcv", true, 2, false, 3)
		expect(sumObj1.sum).toBe(6)
		-- These results are === sumObj1 because the numbers involved are identical.
		expect(sumNums(1, 2, 3)).toBe(sumObj1)
		expect(sumNums("qwer", 1, 2, true, 3, { 3 })).toBe(sumObj1)
		expect(sumNums("backwards", 3, 2, 1).sum).toBe(6)
		expect(sumNums("backwards", 3, 2, 1)).never.toBe(sumObj1)

		sumNums:dirty(1, 2, 3)
		local sumObj2 = sumNums(1, 2, 3)
		expect(sumObj2.sum).toBe(6)
		expect(sumObj2).never.toBe(sumObj1)
		expect(sumNums("a", 1, "b", 2, "c", 3)).toBe(sumObj2)
	end)

	it("tolerates cycles when propagating dirty/clean signals", function()
		local counter = 0
		local dep = wrap(function()
			counter += 1
			return counter
		end)

		local child: any

		local function callChild()
			return child()
		end
		local parentBody = callChild
		local parent = wrap(function()
			dep()
			return parentBody()
		end)

		local function callParent()
			return parent()
		end
		local function childBody()
			return "child"
		end
		child = wrap(function()
			dep()
			return childBody()
		end)

		expect(parent()).toBe("child")

		childBody = callParent
		parentBody = function()
			return "parent"
		end
		child:dirty()
		expect(child()).toBe("parent")
		dep:dirty()
		expect(child()).toBe("parent")
	end)

	it("is not confused by eviction during recomputation", function()
		local fib: OptimisticWrapperFunction<Array<number>, number, any, any>
		fib = wrap(function(n: number)
			if n > 1 then
				return fib(n - 1) + fib(n - 2)
			end
			return n
		end, {
			max = 10,
		})

		expect(fib(78)).toBe(8944394323791464)
		expect(fib(68)).toBe(72723460248141)
		expect(fib(58)).toBe(591286729879)
		expect(fib(48)).toBe(4807526976)
		expect(fib(38)).toBe(39088169)
		expect(fib(28)).toBe(317811)
		expect(fib(18)).toBe(2584)
		expect(fib(8)).toBe(21)
	end)

	it("allows peeking the current value", function()
		local sumFirst: OptimisticWrapperFunction<any, any, any, any>
		sumFirst = wrap(function(n: number): number
			return n < 1 and 0 or n + sumFirst(n - 1)
		end)

		expect(sumFirst:peek(3)).toBe(nil)
		expect(sumFirst:peek(2)).toBe(nil)
		expect(sumFirst:peek(1)).toBe(nil)
		expect(sumFirst:peek(0)).toBe(nil)
		expect(sumFirst(3)).toBe(6)
		expect(sumFirst:peek(3)).toBe(6)
		expect(sumFirst:peek(2)).toBe(3)
		expect(sumFirst:peek(1)).toBe(1)
		expect(sumFirst:peek(0)).toBe(0)

		expect(sumFirst:peek(7)).toBe(nil)
		expect(sumFirst(10)).toBe(55)
		expect(sumFirst:peek(9)).toBe(55 - 10)
		expect(sumFirst:peek(8)).toBe(55 - 10 - 9)
		expect(sumFirst:peek(7)).toBe(55 - 10 - 9 - 8)

		sumFirst:dirty(7)
		-- Everything from 7 and above is now unpeekable.
		expect(sumFirst:peek(10)).toBe(nil)
		expect(sumFirst:peek(9)).toBe(nil)
		expect(sumFirst:peek(8)).toBe(nil)
		expect(sumFirst:peek(7)).toBe(nil)
		-- Since 6 < 7, its value is still cached.
		expect(sumFirst:peek(6)).toBe(6 * 7 / 2)
	end)

	it("allows forgetting entries", function()
		local ns: Array<number> = {}
		local sumFirst: OptimisticWrapperFunction<any, any, any, any>
		sumFirst = wrap(function(n: number): number
			table.insert(ns, n)
			return n < 1 and 0 or n + sumFirst(n - 1)
		end)

		local function inclusiveDescendingRange(n: number, limit_: number?)
			local limit = limit_ :: number
			if limit == nil then
				limit = 0
			end
			local range: Array<number> = {}
			while n >= limit do
				table.insert(range, n)
				n -= 1
			end
			return range
		end

		expect(sumFirst(10)).toBe(55)
		expect(ns).toEqual(inclusiveDescendingRange(10))

		expect(sumFirst:forget(6)).toBe(true)
		expect(sumFirst(4)).toBe(10)
		expect(ns).toEqual(inclusiveDescendingRange(10))

		expect(sumFirst(11)).toBe(66)
		expect(ns).toEqual(Array.concat({}, inclusiveDescendingRange(10), inclusiveDescendingRange(11, 6)))

		expect(sumFirst:forget(3)).toBe(true)
		expect(sumFirst(7)).toBe(28)
		expect(ns).toEqual(
			Array.concat(
				{},
				inclusiveDescendingRange(10),
				inclusiveDescendingRange(11, 6),
				inclusiveDescendingRange(7, 3)
			)
		)

		expect(sumFirst:forget(123)).toBe(false)
		expect(sumFirst:forget(-1)).toBe(false)
		expect(sumFirst:forget("7")).toBe(false)
		expect(sumFirst.forget(sumFirst, 6, 4)).toBe(false)
	end)

	it("allows forgetting entries by key", function()
		local ns: Array<number> = {}
		local sumFirst: OptimisticWrapperFunction<any, any, any, any>
		sumFirst = wrap(function(n: number): number
			table.insert(ns, n)
			return n < 1 and 0 or n + sumFirst(n - 1)
		end, {
			makeCacheKey = function(_self, x: number)
				return x * 2
			end,
		})

		expect(sumFirst(10)).toBe(55)

		--[[
			 * Verify:
			 * 1- Calling forgetKey will remove the entry.
			 * 2- Calling forgetKey again will return false.
			 * 3- Callling forget on the same entry will return false.
			]]
		expect(sumFirst:forgetKey(6 * 2)).toBe(true)
		expect(sumFirst:forgetKey(6 * 2)).toBe(false)
		expect(sumFirst:forget(6)).toBe(false)

		--[[
			 * Verify:
			 * 1- Calling forget will remove the entry.
			 * 2- Calling forget again will return false.
			 * 3- Callling forgetKey on the same entry will return false.
			]]
		expect(sumFirst:forget(7)).toBe(true)
		expect(sumFirst:forget(7)).toBe(false)
		expect(sumFirst:forgetKey(7 * 2)).toBe(false)

		--[[
			 * Verify you can query an entry key.
			]]
		expect(sumFirst:getKey(9)).toBe(18)
		expect(sumFirst:forgetKey(sumFirst:getKey(9))).toBe(true)
		expect(sumFirst:forgetKey(sumFirst:getKey(9))).toBe(false)
		expect(sumFirst:forget(9)).toBe(false)
	end)

	it("exposes optimistic.size property, returning cache.map.size", function()
		local d = dep()
		local fib: any
		fib = wrap(function(n: number): number
			d("shared")
			return (function()
				if n > 1 then
					return fib(n - 1) + fib(n - 2)
				else
					return n
				end
			end)()
		end, {
			makeCacheKey = function(_self, n)
				return n
			end,
		})

		expect(fib.size).toBe(0)

		expect(fib(0)).toBe(0)
		expect(fib(1)).toBe(1)
		expect(fib(2)).toBe(1)
		expect(fib(3)).toBe(2)
		expect(fib(4)).toBe(3)
		expect(fib(5)).toBe(5)
		expect(fib(6)).toBe(8)
		expect(fib(7)).toBe(13)
		expect(fib(8)).toBe(21)

		expect(fib.size).toBe(9)

		fib:dirty(6)
		--  Merely dirtying an Entry does not remove it from the LRU cache.
		expect(fib.size).toBe(9)

		fib:forget(6)
		-- Forgetting an Entry both dirties it and removes it from the LRU cache.
		expect(fib.size).toBe(8)

		fib:forget(4)
		expect(fib.size).toBe(7)

		-- This way of calling d.dirty causes any parent Entry objects to be
		-- forgotten (removed from the LRU cache).
		d:dirty("shared", "forget")
		expect(fib.size).toBe(0)
	end)
end)

return {}
