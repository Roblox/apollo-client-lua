-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/core/__tests__/QueryManager/recycler.ts

--[[
 * This test is used to verify the requirements for how react-apollo
 * preserves observables using QueryRecycler. Eventually, QueryRecycler
 * will be removed, but this test file should still be valid
 ]]

-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
local TICK = 1000 / 30

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local setInterval = require(srcWorkspace.luaUtils).setInterval
local setTimeout = LuauPolyfill.setTimeout

type Array<T> = LuauPolyfill.Array<T>

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

-- externals
local gql = require(rootWorkspace.GraphQLTag).default
local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache.inmemory.inMemoryCache).InMemoryCache
local stripSymbols = require(script.Parent.Parent.Parent.Parent.utilities.testing.stripSymbols).stripSymbols
local MockSubscriptionLink =
	require(script.Parent.Parent.Parent.Parent.utilities.testing.mocking.mockSubscriptionLink).MockSubscriptionLink

-- core
local QueryManagerModule = require(script.Parent.Parent.Parent.QueryManager)
local QueryManager = QueryManagerModule.QueryManager
type QueryManager<TStore> = QueryManagerModule.QueryManager<TStore>
local observableQueryModule = require(script.Parent.Parent.Parent.ObservableQuery_types)
type ObservableQuery__ = observableQueryModule.ObservableQuery__
local observableModule = require(script.Parent.Parent.Parent.Parent.utilities.observables.Observable)
type Subscription = observableModule.ObservableSubscription

-- ROBLOX deviation START: required for explicit casting
local inMemoryCacheTypesModule = require(script.Parent.Parent.Parent.Parent.cache.inmemory.types)
type NormalizedCacheObject = inMemoryCacheTypesModule.NormalizedCacheObject
-- ROBLOX deviation END

describe("Subscription lifecycles", function()
	it("cleans up and reuses data like QueryRecycler wants", function(_, done)
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
			people_one = {
				name = "Luke Skywalker",
				friends = { { name = "Leia Skywalker" } },
			},
		}

		local link = MockSubscriptionLink.new()

		-- ROBLOX FIXME: explicit cast to QueryManager<NormalizedCacheObject> when it should be inferred
		local queryManager = (
			QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			}) :: any
		) :: QueryManager<NormalizedCacheObject>

		-- step 1, get some data
		local observable = queryManager:watchQuery({
			query = query,
			variables = {},
			fetchPolicy = "cache-and-network",
		})

		local observableQueries: Array<{ observableQuery: ObservableQuery__, subscription: Subscription }> = {}

		local function resubscribe()
			local ref = table.remove(observableQueries) :: any
			local observableQuery, subscription = ref.observableQuery, ref.subscription
			subscription:unsubscribe()

			observableQuery:setOptions({
				query = query,
				fetchPolicy = "cache-and-network",
			})

			return observableQuery
		end

		local sub
		sub = observable:subscribe({
			next = function(_self, result: any)
				expect(result.loading).toBe(false)
				expect(stripSymbols(result.data)).toEqual(initialData)
				expect(stripSymbols(observable:getCurrentResult().data)).toEqual(initialData)

				-- step 2, recycle it
				observable:setOptions({ fetchPolicy = "standby", pollInterval = 0 } :: any)

				table.insert(observableQueries, {
					observableQuery = observable,
					subscription = observable:subscribe({}),
				} :: any)

				-- step 3, unsubscribe from observable
				sub:unsubscribe()

				setTimeout(
					function()
						-- step 4, start new Subscription;
						local recycled = resubscribe()
						local currentResult = recycled:getCurrentResult()
						expect(stripSymbols(currentResult.data)).toEqual(initialData)
						done()
					end,
					-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
					10 * TICK
				)
			end,
		})

		setInterval(
			function()
				-- fire off first result
				link:simulateResult({ result = { data = initialData } })
			end,
			-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
			10 * TICK
		)
	end)
end)

return {}
