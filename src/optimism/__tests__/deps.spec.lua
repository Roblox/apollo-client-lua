-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/deps.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local ParentModule = require(script.Parent.Parent)
local wrap = ParentModule.wrap
local dep = ParentModule.dep

describe("OptimisticDependencyFunction<TKey>", function()
	it("can dirty OptimisticWrapperFunctions", function()
		local numberDep = dep()
		local stringDep = dep()
		local callCount = 0
		local fn = wrap(function(n: number, s: string)
			numberDep(n)
			stringDep(s)
			callCount += 1
			return string.rep(s, n)
		end)
		expect(fn(0, "oyez")).toEqual("")
		expect(callCount).toEqual(1)
		expect(fn(1, "oyez")).toEqual("oyez")
		expect(callCount).toEqual(2)
		expect(fn(2, "oyez")).toEqual("oyezoyez")
		expect(callCount).toEqual(3)
		expect(fn(0, "oyez")).toEqual("")
		expect(fn(1, "oyez")).toEqual("oyez")
		expect(fn(2, "oyez")).toEqual("oyezoyez")
		expect(callCount).toEqual(3)
		numberDep:dirty(0)
		expect(fn(0, "oyez")).toEqual("")
		expect(callCount).toEqual(4)
		expect(fn(1, "oyez")).toEqual("oyez")
		expect(callCount).toEqual(4)
		expect(fn(2, "oyez")).toEqual("oyezoyez")
		expect(callCount).toEqual(4)
		stringDep:dirty("mlem")
		expect(fn(0, "oyez")).toEqual("")
		expect(callCount).toEqual(4)
		stringDep:dirty("oyez")
		expect(fn(2, "oyez")).toEqual("oyezoyez")
		expect(callCount).toEqual(5)
		expect(fn(1, "oyez")).toEqual("oyez")
		expect(callCount).toEqual(6)
		expect(fn(0, "oyez")).toEqual("")
		expect(callCount).toEqual(7)
		expect(fn(0, "oyez")).toEqual("")
		expect(fn(1, "oyez")).toEqual("oyez")
		expect(fn(2, "oyez")).toEqual("oyezoyez")
		expect(callCount).toEqual(7)
	end)

	it("should be forgotten when parent is recomputed", function()
		local d = dep()
		local callCount = 0
		local shouldDepend = true
		local parent = wrap(function(id: string)
			if shouldDepend then
				d(id)
			end
			callCount += 1
			return callCount
		end)
		expect(parent("oyez")).toEqual(1)
		expect(parent("oyez")).toEqual(1)
		expect(parent("mlem")).toEqual(2)
		expect(parent("mlem")).toEqual(2)
		d:dirty("mlem")
		expect(parent("oyez")).toEqual(1)
		expect(parent("mlem")).toEqual(3)
		d:dirty("oyez")
		expect(parent("oyez")).toEqual(4)
		expect(parent("mlem")).toEqual(3)
		parent:dirty("oyez")
		shouldDepend = false
		expect(parent("oyez")).toEqual(5)
		expect(parent("mlem")).toEqual(3)
		d:dirty("oyez")
		shouldDepend = true
		expect(parent("oyez")).toEqual(5)
		expect(parent("mlem")).toEqual(3)
		d:dirty("oyez")
		expect(parent("oyez")).toEqual(5)
		expect(parent("mlem")).toEqual(3)
		parent:dirty("oyez")
		expect(parent("oyez")).toEqual(6)
		expect(parent("mlem")).toEqual(3)
		d:dirty("oyez")
		expect(parent("oyez")).toEqual(7)
		expect(parent("mlem")).toEqual(3)
		parent:dirty("mlem")
		shouldDepend = false
		expect(parent("oyez")).toEqual(7)
		expect(parent("mlem")).toEqual(8)
		d:dirty("oyez")
		d:dirty("mlem")
		expect(parent("oyez")).toEqual(9)
		expect(parent("mlem")).toEqual(8)
		d:dirty("oyez")
		d:dirty("mlem")
		expect(parent("oyez")).toEqual(9)
		expect(parent("mlem")).toEqual(8)
		shouldDepend = true
		parent:dirty("mlem")
		expect(parent("oyez")).toEqual(9)
		expect(parent("mlem")).toEqual(10)
		d:dirty("oyez")
		d:dirty("mlem")
		expect(parent("oyez")).toEqual(9)
		expect(parent("mlem")).toEqual(11)
	end)

	it("supports subscribing and unsubscribing", function()
		local subscribeCallCount = 0
		local unsubscribeCallCount = 0
		local parentCallCount = 0
		local function check(counts: { subscribe: number, unsubscribe: number, parent: number })
			expect(counts.subscribe).toEqual(subscribeCallCount)
			expect(counts.unsubscribe).toEqual(unsubscribeCallCount)
			expect(counts.parent).toEqual(parentCallCount)
		end
		local d = dep({
			subscribe = function(_key: string)
				subscribeCallCount += 1
				return function()
					unsubscribeCallCount += 1
				end
			end,
		})
		expect(subscribeCallCount).toEqual(0)
		expect(unsubscribeCallCount).toEqual(0)
		local parent = wrap(function(key: string)
			d(key)
			parentCallCount += 1
			return parentCallCount
		end) :: any
		expect(parent("rawr")).toEqual(1)
		check({ subscribe = 1, unsubscribe = 0, parent = 1 })
		expect(parent("rawr")).toEqual(1)
		check({ subscribe = 1, unsubscribe = 0, parent = 1 })
		expect(parent("blep")).toEqual(2)
		check({ subscribe = 2, unsubscribe = 0, parent = 2 })
		expect(parent("rawr")).toEqual(1)
		check({ subscribe = 2, unsubscribe = 0, parent = 2 })
		expect(parent("blep")).toEqual(2)
		check({ subscribe = 2, unsubscribe = 0, parent = 2 })
		d:dirty("blep")
		check({ subscribe = 2, unsubscribe = 1, parent = 2 })
		expect(parent("rawr")).toEqual(1)
		check({ subscribe = 2, unsubscribe = 1, parent = 2 })
		d:dirty("blep")
		check({ subscribe = 2, unsubscribe = 1, parent = 2 })
		expect(parent("blep")).toEqual(3)
		check({ subscribe = 3, unsubscribe = 1, parent = 3 })
		expect(parent("blep")).toEqual(3)
		check({ subscribe = 3, unsubscribe = 1, parent = 3 })
		d:dirty("rawr")
		check({ subscribe = 3, unsubscribe = 2, parent = 3 })
		expect(parent("blep")).toEqual(3)
		check({ subscribe = 3, unsubscribe = 2, parent = 3 })
		expect(parent("rawr")).toEqual(4)
		check({ subscribe = 4, unsubscribe = 2, parent = 4 })
		expect(parent("blep")).toEqual(3)
		check({ subscribe = 4, unsubscribe = 2, parent = 4 })
	end)
end)

return {}
