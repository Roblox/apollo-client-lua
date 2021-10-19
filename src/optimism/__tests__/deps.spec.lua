-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/deps.ts
--!nocheck

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

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
			jestExpect(fn(0, "oyez")).toEqual("")
			jestExpect(callCount).toEqual(1)
			jestExpect(fn(1, "oyez")).toEqual("oyez")
			jestExpect(callCount).toEqual(2)
			jestExpect(fn(2, "oyez")).toEqual("oyezoyez")
			jestExpect(callCount).toEqual(3)
			jestExpect(fn(0, "oyez")).toEqual("")
			jestExpect(fn(1, "oyez")).toEqual("oyez")
			jestExpect(fn(2, "oyez")).toEqual("oyezoyez")
			jestExpect(callCount).toEqual(3)
			numberDep:dirty(0)
			jestExpect(fn(0, "oyez")).toEqual("")
			jestExpect(callCount).toEqual(4)
			jestExpect(fn(1, "oyez")).toEqual("oyez")
			jestExpect(callCount).toEqual(4)
			jestExpect(fn(2, "oyez")).toEqual("oyezoyez")
			jestExpect(callCount).toEqual(4)
			stringDep:dirty("mlem")
			jestExpect(fn(0, "oyez")).toEqual("")
			jestExpect(callCount).toEqual(4)
			stringDep:dirty("oyez")
			jestExpect(fn(2, "oyez")).toEqual("oyezoyez")
			jestExpect(callCount).toEqual(5)
			jestExpect(fn(1, "oyez")).toEqual("oyez")
			jestExpect(callCount).toEqual(6)
			jestExpect(fn(0, "oyez")).toEqual("")
			jestExpect(callCount).toEqual(7)
			jestExpect(fn(0, "oyez")).toEqual("")
			jestExpect(fn(1, "oyez")).toEqual("oyez")
			jestExpect(fn(2, "oyez")).toEqual("oyezoyez")
			jestExpect(callCount).toEqual(7)
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
			jestExpect(parent("oyez")).toEqual(1)
			jestExpect(parent("oyez")).toEqual(1)
			jestExpect(parent("mlem")).toEqual(2)
			jestExpect(parent("mlem")).toEqual(2)
			d:dirty("mlem")
			jestExpect(parent("oyez")).toEqual(1)
			jestExpect(parent("mlem")).toEqual(3)
			d:dirty("oyez")
			jestExpect(parent("oyez")).toEqual(4)
			jestExpect(parent("mlem")).toEqual(3)
			parent:dirty("oyez")
			shouldDepend = false
			jestExpect(parent("oyez")).toEqual(5)
			jestExpect(parent("mlem")).toEqual(3)
			d:dirty("oyez")
			shouldDepend = true
			jestExpect(parent("oyez")).toEqual(5)
			jestExpect(parent("mlem")).toEqual(3)
			d:dirty("oyez")
			jestExpect(parent("oyez")).toEqual(5)
			jestExpect(parent("mlem")).toEqual(3)
			parent:dirty("oyez")
			jestExpect(parent("oyez")).toEqual(6)
			jestExpect(parent("mlem")).toEqual(3)
			d:dirty("oyez")
			jestExpect(parent("oyez")).toEqual(7)
			jestExpect(parent("mlem")).toEqual(3)
			parent:dirty("mlem")
			shouldDepend = false
			jestExpect(parent("oyez")).toEqual(7)
			jestExpect(parent("mlem")).toEqual(8)
			d:dirty("oyez")
			d:dirty("mlem")
			jestExpect(parent("oyez")).toEqual(9)
			jestExpect(parent("mlem")).toEqual(8)
			d:dirty("oyez")
			d:dirty("mlem")
			jestExpect(parent("oyez")).toEqual(9)
			jestExpect(parent("mlem")).toEqual(8)
			shouldDepend = true
			parent:dirty("mlem")
			jestExpect(parent("oyez")).toEqual(9)
			jestExpect(parent("mlem")).toEqual(10)
			d:dirty("oyez")
			d:dirty("mlem")
			jestExpect(parent("oyez")).toEqual(9)
			jestExpect(parent("mlem")).toEqual(11)
		end)

		it("supports subscribing and unsubscribing", function()
			local subscribeCallCount = 0
			local unsubscribeCallCount = 0
			local parentCallCount = 0
			local function check(counts: { subscribe: number, unsubscribe: number, parent: number })
				jestExpect(counts.subscribe).toEqual(subscribeCallCount)
				jestExpect(counts.unsubscribe).toEqual(unsubscribeCallCount)
				jestExpect(counts.parent).toEqual(parentCallCount)
			end
			local d = dep({
				subscribe = function(_self, _key: string)
					subscribeCallCount += 1
					return function()
						unsubscribeCallCount += 1
					end
				end,
			})
			jestExpect(subscribeCallCount).toEqual(0)
			jestExpect(unsubscribeCallCount).toEqual(0)
			local parent = wrap(function(key: string)
				d(key)
				parentCallCount += 1
				return parentCallCount
			end) :: any
			jestExpect(parent("rawr")).toEqual(1)
			check({ subscribe = 1, unsubscribe = 0, parent = 1 })
			jestExpect(parent("rawr")).toEqual(1)
			check({ subscribe = 1, unsubscribe = 0, parent = 1 })
			jestExpect(parent("blep")).toEqual(2)
			check({ subscribe = 2, unsubscribe = 0, parent = 2 })
			jestExpect(parent("rawr")).toEqual(1)
			check({ subscribe = 2, unsubscribe = 0, parent = 2 })
			jestExpect(parent("blep")).toEqual(2)
			check({ subscribe = 2, unsubscribe = 0, parent = 2 })
			d:dirty("blep")
			check({ subscribe = 2, unsubscribe = 1, parent = 2 })
			jestExpect(parent("rawr")).toEqual(1)
			check({ subscribe = 2, unsubscribe = 1, parent = 2 })
			d:dirty("blep")
			check({ subscribe = 2, unsubscribe = 1, parent = 2 })
			jestExpect(parent("blep")).toEqual(3)
			check({ subscribe = 3, unsubscribe = 1, parent = 3 })
			jestExpect(parent("blep")).toEqual(3)
			check({ subscribe = 3, unsubscribe = 1, parent = 3 })
			d:dirty("rawr")
			check({ subscribe = 3, unsubscribe = 2, parent = 3 })
			jestExpect(parent("blep")).toEqual(3)
			check({ subscribe = 3, unsubscribe = 2, parent = 3 })
			jestExpect(parent("rawr")).toEqual(4)
			check({ subscribe = 4, unsubscribe = 2, parent = 4 })
			jestExpect(parent("blep")).toEqual(3)
			check({ subscribe = 4, unsubscribe = 2, parent = 4 })
		end)
	end)
end
