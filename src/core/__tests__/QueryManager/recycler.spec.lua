--!nocheck
--!nolint
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/__tests__/QueryManager/recycler.ts

--[[
 * This test is used to verify the requirements for how react-apollo
 * preserves observables using QueryRecycler. Eventually, QueryRecycler
 * will be removed, but this test file should still be valid
 ]]
return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Boolean, clearTimeout, console, Error, Object, setInterval, setTimeout =
		LuauPolyfill.Boolean,
		LuauPolyfill.clearTimeout,
		LuauPolyfill.console,
		LuauPolyfill.Error,
		LuauPolyfill.Object,
		LuauPolyfill.setInterval,
		LuauPolyfill.setTimeout
	local Promise = require(rootWorkspace.Promise)
	local RegExp = require(rootWorkspace.LuauRegExp)

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest

	local HttpService = game:GetService("HttpService")

	-- externals
	local gql = require(rootWorkspace.Dev.GraphQLTag).default
	local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache.inmemory.inMemoryCache).InMemoryCache
	local stripSymbols = require(script.Parent.Parent.Parent.Parent.utilities.testing.stripSymbols).stripSymbols
	local MockSubscriptionLink = {} :: any
	-- local MockSubscriptionLink = require(
	-- 	script.Parent.Parent.Parent.Parent.utilities.testing.mocking.mockSubscriptionLink
	-- ).MockSubscriptionLink

	-- core
	local QueryManager = require(script.Parent.Parent.Parent.QueryManager).QueryManager
	local ObservableQuery = require(script.Parent.Parent.Parent.ObservableQuery).ObservableQuery
	xdescribe("Subscription lifecycles", function()
		it("cleans up and reuses data like QueryRecycler wants", function(done)
			local query = gql([[

				query Luke {
				  people_one(id: 1) {
					name
					friends {
					  name
					}
				  }
				}
			]])

			local initialData = {
				people_one = { name = "Luke Skywalker", friends = { { name = "Leia Skywalker" } } },
			}

			local link = MockSubscriptionLink.new()

			local queryManager = QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			})

			-- step 1, get some data
			local observable = queryManager:watchQuery({
				query = query,
				variables = {},
				fetchPolicy = "cache-and-network",
			})

			local observableQueries: Array<{ observableQuery: ObservableQuery, subscription: Subscription }> = {}

			local function resubscribe()
				local observableQuery, subscription
				do
					local ref = observableQueries.pop()
					observableQuery, subscription = ref.observableQuery, ref.subscription
				end

				subscription:unsubscribe()

				observableQuery:setOptions({ query = query, fetchPolicy = "cache-and-network" })

				return observableQuery
			end

			local sub = observable:subscribe({
				next = function(self, result: any)
					jestExpect(result.loading).toBe(false)
					jestExpect(stripSymbols(result.data)).toEqual(initialData)
					jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(initialData)

					-- step 2, recycle it
					observable:setOptions({ fetchPolicy = "standby", pollInterval = 0 })

					observableQueries:push({
						observableQuery = observable,
						subscription = observable:subscribe({}),
					})

					-- step 3, unsubscribe from observable
					sub:unsubscribe()

					setTimeout(function()
						-- step 4, start new Subscription;
						local recycled = resubscribe()
						local currentResult = recycled:getCurrentResult()
						jestExpect(stripSymbols(currentResult.data)).toEqual(initialData)
						done()
					end, 10)
				end,
			})

			setInterval(function()
				-- fire off first result
				link:simulateResult({ result = { data = initialData } })
			end, 10)
		end)
	end)
end
