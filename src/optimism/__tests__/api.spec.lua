-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/api.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Error = LuauPolyfill.Error

	type Array<T> = LuauPolyfill.Array<T>

	-- local createHash = require(Packages.crypto).createHash
	local optimismModule = require(script.Parent.Parent)
	local wrap = optimismModule.wrap
	local defaultMakeCacheKey = optimismModule.defaultMakeCacheKey
	type OptimisticWrapperFunction<TArgs, TResult, TKeyArgs, TCacheKey> =
		optimismModule.OptimisticWrapperFunction<TArgs, TResult, TKeyArgs, TCacheKey>
	-- local wrapYieldingFiberMethods = require(srcWorkspace.wry.context).wrapYieldingFiberMethods
	local dep = require(script.Parent.Parent.dep).dep

	type NumThunk = OptimisticWrapperFunction<Array<nil>, number, any, any>

	describe("optimism", function()
		it("sanity", function()
			jestExpect(typeof(wrap)).toBe("function")
			jestExpect(typeof(defaultMakeCacheKey)).toBe("function")
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
			jestExpect(test("a")).toBe("asalt")

			salt = "NaCl"
			jestExpect(test("a")).toBe("asalt")
			jestExpect(test("b")).toBe("bNaCl")

			test:dirty("a")
			jestExpect(test("a")).toBe("aNaCl")
		end)

		-- ROBLOX SKIP: no crypto dependency available
		xit("works with two layers of functions", function()
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

			-- jestExpect(hash1).toBe(hash2)
			-- jestExpect(hash1).never.toBe(hash3)
			-- jestExpect(hash1).never.toBe(hash4)
			-- jestExpect(hash3).never.toBe(hash4)
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

			jestExpect(test("a")).toBe("a,a,a")

			jestExpect(test("b")).toBe("b,b,b")
			jestExpect(unsubscribed).toEqual({ a = true })

			jestExpect(test("c")).toBe("c,c,c")
			jestExpect(unsubscribed).toEqual({ a = true, b = true })

			sep = ":"

			jestExpect(test("c")).toBe("c,c,c")
			jestExpect(unsubscribed).toEqual({ a = true, b = true })

			dirty()

			jestExpect(test("c")).toBe("c:c:c")
			jestExpect(unsubscribed).toEqual({ a = true, b = true })

			jestExpect(test("d")).toBe("d:d:d")
			jestExpect(unsubscribed).toEqual({ a = true, b = true, c = true })
		end)

		-- ROBLOX SKIP: no fibers dependency available
		xit("is not confused by fibers", function()
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
			-- 	jestExpect(o1()).toBe("one")
			-- 	table.insert(order, 3)
			-- 	result1 ..= ":dirty"
			-- 	jestExpect(o1()).toBe("one")
			-- 	table.insert(order, 4)
			-- 	Fiber:yield()
			-- 	table.insert(order, 5)
			-- 	jestExpect(o1()).toBe("one")
			-- 	table.insert(order, 6)
			-- 	o1:dirty()
			-- 	table.insert(order, 7)
			-- 	jestExpect(o1()).toBe("one:dirty")
			-- 	table.insert(order, 8)
			-- 	jestExpect(o2()).toBe("two:dirty")
			-- 	table.insert(order, 9)
			-- end)

			-- result2 = "two"
			-- local o2 = wrap(function()
			-- 	return result2
			-- end)

			-- table.insert(order, 0)

			-- f1:run()
			-- jestExpect(order).toEqual({ 0, 1, 2 })

			-- -- The primary goal of this test is to make sure this call to o2()
			-- -- does not register a dirty-chain dependency for o1.
			-- jestExpect(o2()).toBe("two")

			-- f1:run()
			-- jestExpect(order).toEqual({ 0, 1, 2, 3, 4 })

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
			-- jestExpect(order).toEqual({ 0, 1, 2, 3, 4, 5, 6, 7 })

			-- f1:run()
			-- jestExpect(order).toEqual({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 })
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

			jestExpect(parent("asdf")).toBe("asdf*^")

			childSalt = "&"
			parentSalt = "%"

			jestExpect(parent("asdf")).toBe("asdf*^")
			jestExpect(child("zxcv")).toBe("zxcv&")
			jestExpect(parent("asdf")).toBe("asdf&%")
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

			jestExpect(parent()).toBe(expected)
			jestExpect(parent()).toBe(expected)

			child:dirty()
			jestExpect(parent()).toBe(expected)

			parent:dirty()
			jestExpect(parent()).toBe(expected)
		end)

		it("reports clean children to correct parents", function()
			local childResult = "a"
			local child = wrap(function()
				return childResult
			end)

			local parent = wrap(function(x: any)
				return child() .. x
			end)

			jestExpect(parent(1)).toBe("a1")
			jestExpect(parent(2)).toBe("a2")

			childResult = "b"
			child:dirty()

			-- If this call to parent(1) mistakenly reports child() as clean to
			-- parent(2), then the second assertion will fail by returning "a2".
			jestExpect(parent(1)).toBe("b1")
			jestExpect(parent(2)).toBe("b2")
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
			jestExpect(wrapped(a, a)).toBe(0)
			jestExpect(wrapped(a, b)).toBe(1)
			jestExpect(wrapped(b, a)).toBe(2)
			jestExpect(wrapped(b, b)).toBe(3)

			-- But the same combinations of arguments should return the same
			-- cached values when passed again.
			jestExpect(wrapped(a, a)).toBe(0)
			jestExpect(wrapped(a, b)).toBe(1)
			jestExpect(wrapped(b, a)).toBe(2)
			jestExpect(wrapped(b, b)).toBe(3)
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

			jestExpect(wrapped(0)).toBe(0)
			jestExpect(callCount).toBe(1)
			jestExpect(wrapped(0)).toBe(0)
			jestExpect(callCount).toBe(1)

			jestExpect(wrapped("")).toBe("")
			jestExpect(callCount).toBe(2)
			jestExpect(wrapped("")).toBe("")
			jestExpect(callCount).toBe(2)

			--[[
				ROBLOX deviation: 
				there is no distinction between null and undefined in Lua
				artificially triggering call of wrapped function to retail callCount
			]]
			wrapped(-1)
			-- jestExpect(wrapped(nil)).toBe(nil)
			-- jestExpect(callCount).toBe(3)
			-- jestExpect(wrapped(nil)).toBe(nil)
			-- jestExpect(callCount).toBe(3)

			jestExpect(wrapped(false)).toBe(false)
			jestExpect(callCount).toBe(4)
			jestExpect(wrapped(false)).toBe(false)
			jestExpect(callCount).toBe(4)

			jestExpect(wrapped(0)).toBe(0)
			jestExpect(wrapped("")).toBe("")
			--ROBLOX deviation: there is no distinction between null and undefined in Lua
			-- jestExpect(wrapped(nil)).toBe(nil)
			jestExpect(wrapped(false)).toBe(false)
			jestExpect(callCount).toBe(4)

			jestExpect(wrapped(1)).toBe(1)
			jestExpect(wrapped("oyez")).toBe("oyez")
			jestExpect(wrapped(true)).toBe(true)
			jestExpect(callCount).toBe(7)

			jestExpect(wrapped(nil)).toBe(nil)
			jestExpect(wrapped(nil)).toBe(nil)
			jestExpect(wrapped(nil)).toBe(nil)
			jestExpect(callCount).toBe(10)
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
					jestExpect(e.message).toBe("already recomputing")
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

			jestExpect(fn()).toBe(0)
			jestExpect(returnZero).toBe(false)

			returnZero = true
			jestExpect(fn()).toBe(0)
			jestExpect(returnZero).toBe(true)

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
						jestExpect(e.message).toBe("already recomputing")
					end
					ok, e = pcall(function()
						sumEven(10)
						return nil
					end)
					if not ok then
						jestExpect(e.message).toBe("already recomputing")
					end
				else
					jestExpect(sumEven(10)).toBe(55)
					jestExpect(sumOdd(10)).toBe(55)
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
					sum = Array.reduce(args, function(sum, arg)
						if typeof(arg) == "number" then
							return arg + sum
						else
							return sum
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

			jestExpect(sumNums().sum).toBe(0)
			jestExpect(sumNums("asdf", true, sumNums).sum).toBe(0)

			local sumObj1 = sumNums(1, "zxcv", true, 2, false, 3)
			jestExpect(sumObj1.sum).toBe(6)
			-- These results are === sumObj1 because the numbers involved are identical.
			jestExpect(sumNums(1, 2, 3)).toBe(sumObj1)
			jestExpect(sumNums("qwer", 1, 2, true, 3, { 3 })).toBe(sumObj1)
			jestExpect(sumNums("backwards", 3, 2, 1).sum).toBe(6)
			jestExpect(sumNums("backwards", 3, 2, 1)).never.toBe(sumObj1)

			sumNums:dirty(1, 2, 3)
			local sumObj2 = sumNums(1, 2, 3)
			jestExpect(sumObj2.sum).toBe(6)
			jestExpect(sumObj2).never.toBe(sumObj1)
			jestExpect(sumNums("a", 1, "b", 2, "c", 3)).toBe(sumObj2)
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

			jestExpect(parent()).toBe("child")

			childBody = callParent
			parentBody = function()
				return "parent"
			end
			child:dirty()
			jestExpect(child()).toBe("parent")
			dep:dirty()
			jestExpect(child()).toBe("parent")
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

			jestExpect(fib(78)).toBe(8944394323791464)
			jestExpect(fib(68)).toBe(72723460248141)
			jestExpect(fib(58)).toBe(591286729879)
			jestExpect(fib(48)).toBe(4807526976)
			jestExpect(fib(38)).toBe(39088169)
			jestExpect(fib(28)).toBe(317811)
			jestExpect(fib(18)).toBe(2584)
			jestExpect(fib(8)).toBe(21)
		end)

		it("allows peeking the current value", function()
			local sumFirst: OptimisticWrapperFunction<any, any, any, any>
			sumFirst = wrap(function(n: number): number
				return n < 1 and 0 or n + sumFirst(n - 1)
			end)

			jestExpect(sumFirst:peek(3)).toBe(nil)
			jestExpect(sumFirst:peek(2)).toBe(nil)
			jestExpect(sumFirst:peek(1)).toBe(nil)
			jestExpect(sumFirst:peek(0)).toBe(nil)
			jestExpect(sumFirst(3)).toBe(6)
			jestExpect(sumFirst:peek(3)).toBe(6)
			jestExpect(sumFirst:peek(2)).toBe(3)
			jestExpect(sumFirst:peek(1)).toBe(1)
			jestExpect(sumFirst:peek(0)).toBe(0)

			jestExpect(sumFirst:peek(7)).toBe(nil)
			jestExpect(sumFirst(10)).toBe(55)
			jestExpect(sumFirst:peek(9)).toBe(55 - 10)
			jestExpect(sumFirst:peek(8)).toBe(55 - 10 - 9)
			jestExpect(sumFirst:peek(7)).toBe(55 - 10 - 9 - 8)

			sumFirst:dirty(7)
			-- Everything from 7 and above is now unpeekable.
			jestExpect(sumFirst:peek(10)).toBe(nil)
			jestExpect(sumFirst:peek(9)).toBe(nil)
			jestExpect(sumFirst:peek(8)).toBe(nil)
			jestExpect(sumFirst:peek(7)).toBe(nil)
			-- Since 6 < 7, its value is still cached.
			jestExpect(sumFirst:peek(6)).toBe(6 * 7 / 2)
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

			jestExpect(sumFirst(10)).toBe(55)
			jestExpect(ns).toEqual(inclusiveDescendingRange(10))

			jestExpect(sumFirst:forget(6)).toBe(true)
			jestExpect(sumFirst(4)).toBe(10)
			jestExpect(ns).toEqual(inclusiveDescendingRange(10))

			jestExpect(sumFirst(11)).toBe(66)
			jestExpect(ns).toEqual(Array.concat({}, inclusiveDescendingRange(10), inclusiveDescendingRange(11, 6)))

			jestExpect(sumFirst:forget(3)).toBe(true)
			jestExpect(sumFirst(7)).toBe(28)
			jestExpect(ns).toEqual(
				Array.concat(
					{},
					inclusiveDescendingRange(10),
					inclusiveDescendingRange(11, 6),
					inclusiveDescendingRange(7, 3)
				)
			)

			jestExpect(sumFirst:forget(123)).toBe(false)
			jestExpect(sumFirst:forget(-1)).toBe(false)
			jestExpect(sumFirst:forget("7")).toBe(false)
			jestExpect(sumFirst.forget(sumFirst, 6, 4)).toBe(false)
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

			jestExpect(sumFirst(10)).toBe(55)

			--[[
			 * Verify:
			 * 1- Calling forgetKey will remove the entry.
			 * 2- Calling forgetKey again will return false.
			 * 3- Callling forget on the same entry will return false.
			]]
			jestExpect(sumFirst:forgetKey(6 * 2)).toBe(true)
			jestExpect(sumFirst:forgetKey(6 * 2)).toBe(false)
			jestExpect(sumFirst:forget(6)).toBe(false)

			--[[
			 * Verify:
			 * 1- Calling forget will remove the entry.
			 * 2- Calling forget again will return false.
			 * 3- Callling forgetKey on the same entry will return false.
			]]
			jestExpect(sumFirst:forget(7)).toBe(true)
			jestExpect(sumFirst:forget(7)).toBe(false)
			jestExpect(sumFirst:forgetKey(7 * 2)).toBe(false)

			--[[
			 * Verify you can query an entry key.
			]]
			jestExpect(sumFirst:getKey(9)).toBe(18)
			jestExpect(sumFirst:forgetKey(sumFirst:getKey(9))).toBe(true)
			jestExpect(sumFirst:forgetKey(sumFirst:getKey(9))).toBe(false)
			jestExpect(sumFirst:forget(9)).toBe(false)
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

			jestExpect(fib.size).toBe(0)

			jestExpect(fib(0)).toBe(0)
			jestExpect(fib(1)).toBe(1)
			jestExpect(fib(2)).toBe(1)
			jestExpect(fib(3)).toBe(2)
			jestExpect(fib(4)).toBe(3)
			jestExpect(fib(5)).toBe(5)
			jestExpect(fib(6)).toBe(8)
			jestExpect(fib(7)).toBe(13)
			jestExpect(fib(8)).toBe(21)

			jestExpect(fib.size).toBe(9)

			fib:dirty(6)
			--  Merely dirtying an Entry does not remove it from the LRU cache.
			jestExpect(fib.size).toBe(9)

			fib:forget(6)
			-- Forgetting an Entry both dirties it and removes it from the LRU cache.
			jestExpect(fib.size).toBe(8)

			fib:forget(4)
			jestExpect(fib.size).toBe(7)

			-- This way of calling d.dirty causes any parent Entry objects to be
			-- forgotten (removed from the LRU cache).
			d:dirty("shared", "forget")
			jestExpect(fib.size).toBe(0)
		end)
	end)
end
