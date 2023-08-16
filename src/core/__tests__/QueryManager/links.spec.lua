--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/core/__tests__/QueryManager/links.ts

-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
local TICK = 1000 / 30

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Array = LuauPolyfill.Array
type Array<T> = LuauPolyfill.Array<T>
local console = LuauPolyfill.console
local Error = LuauPolyfill.Error
local setTimeout = LuauPolyfill.setTimeout
type Record<T, U> = { [T]: U }

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

-- externals
local gql = require(rootWorkspace.GraphQLTag).default

local observableModule = require(script.Parent.Parent.Parent.Parent.utilities.observables.Observable)
local Observable = observableModule.Observable
type Subscription = observableModule.ObservableSubscription
local ApolloLink = require(script.Parent.Parent.Parent.Parent.link.core).ApolloLink
local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache.inmemory.inMemoryCache).InMemoryCache

-- ROBLOX deviation START: NormalizedCacheObject required for explicit cast
local InMemoryCacheTypesModule = require(script.Parent.Parent.Parent.Parent.cache.inmemory.types)
type NormalizedCacheObject = InMemoryCacheTypesModule.NormalizedCacheObject
-- ROBLOX deviation END

local stripSymbols = require(script.Parent.Parent.Parent.Parent.utilities.testing.stripSymbols).stripSymbols

-- mocks
local MockSubscriptionLink =
	require(script.Parent.Parent.Parent.Parent.utilities.testing.mocking.mockSubscriptionLink).MockSubscriptionLink

-- core
local QueryManagerModule = require(script.Parent.Parent.Parent.QueryManager)
local QueryManager = QueryManagerModule.QueryManager
type QueryManager<TStore> = QueryManagerModule.QueryManager<TStore>
local coreModule = require(script.Parent.Parent.Parent.Parent.core)
local coreLinkModule = require(script.Parent.Parent.Parent.Parent.link.core)
type NextLink = coreLinkModule.NextLink
type Operation = coreLinkModule.Operation
type Reference = coreModule.Reference

local inmemoryPoliciesTypesModule = require(script.Parent.Parent.Parent.Parent.cache.inmemory.policies_types)
type FieldFunctionOptions<TArgs, TVars> = inmemoryPoliciesTypesModule.FieldFunctionOptions<TArgs, TVars>
describe("Link interactions", function()
	it("includes the cache on the context for eviction links", function(_, done)
		local query = gql([[

      query CachedLuke {
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

		-- ROBLOX deviation: predefine variable
		local count

		local function evictionLink(_self, operation: Operation, forward: NextLink)
			local cache = operation:getContext().cache

			expect(cache).toBeDefined()

			return forward(operation):map(function(result)
				setTimeout(
					function()
						local cacheResult = stripSymbols(cache:read({ query = query }))
						expect(cacheResult).toEqual(initialData)
						expect(cacheResult).toEqual(stripSymbols(result.data))
						if count == 1 then
							done()
						end
					end,
					-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
					10 * TICK
				)

				return result
			end)
		end

		local mockLink = MockSubscriptionLink.new()

		local link = ApolloLink.from({ evictionLink :: any, mockLink })

		-- ROBLOX FIXME: explicit cast to QueryManager<NormalizedCacheObject> when it should be inferred
		local queryManager = (
			QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			}) :: any
		) :: QueryManager<NormalizedCacheObject>

		local observable = queryManager:watchQuery({ query = query, variables = {} })

		count = 0
		observable:subscribe({
			next = function(_self, result)
				count += 1
			end,
			error = function(_self, e)
				console.error(e)
			end,
		})

		-- fire off first result
		mockLink:simulateResult({ result = { data = initialData } })
	end)

	it("cleans up all links on the final unsubscribe from watchQuery", function(_, done)
		local query = gql([[

      query WatchedLuke {
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

		local observable = queryManager:watchQuery({
			query = query,
			variables = {},
		})

		local count = 0
		local four: Subscription
		-- first watch
		local one = observable:subscribe(function(result)
			local ref = count
			count += 1
			return ref
		end)
		-- second watch
		local two = observable:subscribe(function(result)
			local ref = count
			count += 1
			return ref
		end)
		-- third watch (to be unsubscribed)
		local three
		three = observable:subscribe(function(result)
			count += 1
			three:unsubscribe()
			-- fourth watch
			four = observable:subscribe(function(x)
				local ref = count
				count += 1
				return ref
			end)
		end)

		-- fire off first result
		link:simulateResult({ result = { data = initialData } })
		setTimeout(
			function()
				one:unsubscribe()
				link:simulateResult({
					result = {
						data = {
							people_one = {
								name = "Luke Skywalker",
								friends = { { name = "R2D2" } },
							},
						},
					},
				})
				setTimeout(
					function()
						four:unsubscribe()
						two:unsubscribe()
					end,
					-- ROBLOX deviation: using multiple of TICK ms for timeout as it looks like the minimum value to ensure the correct order of execution
					10 * TICK
				)
			end,
			-- ROBLOX deviation: using multiple of TICK ms for timeout as it looks like the minimum value to ensure the correct order of execution
			10 * TICK
		)

		link:onUnsubscribe(function()
			expect(count).toEqual(6)
			done()
		end)
	end)

	it("cleans up all links on the final unsubscribe from watchQuery [error]", function(_, done)
		local query = gql([[

      query WatchedLuke {
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

		-- ROBLOX FIXME: explicit cast to QueryManager<NormalizedCacheObject> when it should be inferred
		local queryManager = (
			QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			}) :: any
		) :: QueryManager<NormalizedCacheObject>

		local observable = queryManager:watchQuery({ query = query, variables = {} })

		local count = 0

		local four: Subscription

		-- first watch
		local one = observable:subscribe(function(result)
			local ref = count
			count += 1
			return ref
		end)

		-- second watch
		observable:subscribe({
			next = function()
				local ref = count
				count += 1
				return ref
			end,
			error = function()
				count = 0
			end,
		})

		-- third watch (to be unsubscribed)
		local three
		three = observable:subscribe(function(result)
			count += 1
			three:unsubscribe()
			-- fourth watch
			four = observable:subscribe(function(x)
				local ref = count
				count += 1
				return ref
			end)
		end)

		-- fire off first result
		link:simulateResult({ result = { data = initialData } })

		setTimeout(
			function()
				one:unsubscribe()
				four:unsubscribe()
				-- final unsubscribe should be called now
				-- since errors clean up subscriptions
				link:simulateResult({ error = Error.new("dang") })
				setTimeout(
					function()
						expect(count).toEqual(0)
						done()
					end,
					-- ROBLOX deviation: using multiple of TICK ms for timeout as it looks like the minimum value to ensure the correct order of execution
					10 * TICK
				)
			end,
			-- ROBLOX deviation: using multiple of TICK ms for timeout as it looks like the minimum value to ensure the correct order of execution
			10 * TICK
		)

		link:onUnsubscribe(function()
			expect(count).toEqual(4)
		end)
	end)

	it("includes the cache on the context for mutations", function(_, done)
		local mutation = gql([[

      mutation UpdateLuke {
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

		local function evictionLink(_self, operation: Operation, forward: NextLink)
			local cache = operation:getContext().cache
			expect(cache).toBeDefined()
			done()
			return forward(operation)
		end

		local mockLink = MockSubscriptionLink.new()

		local link = ApolloLink.from({ evictionLink :: any, mockLink })

		-- ROBLOX FIXME: explicit cast to QueryManager<NormalizedCacheObject> when it should be inferred
		local queryManager = (
			QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			}) :: any
		) :: QueryManager<NormalizedCacheObject>

		queryManager:mutate({ mutation = mutation })

		-- fire off first result
		mockLink:simulateResult({ result = { data = initialData } })
	end)

	it("includes passed context in the context for mutations", function(_, done)
		local mutation = gql([[

      mutation UpdateLuke {
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

		local function evictionLink(_self, operation: Operation, forward: NextLink)
			local planet = operation:getContext().planet

			expect(planet).toBe("Tatooine")

			done()

			return forward(operation)
		end

		local mockLink = MockSubscriptionLink.new()

		local link = ApolloLink.from({ evictionLink :: any, mockLink })

		-- ROBLOX FIXME: explicit cast to QueryManager<NormalizedCacheObject> when it should be inferred
		local queryManager = (
			QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			}) :: any
		) :: QueryManager<NormalizedCacheObject>

		queryManager:mutate({ mutation = mutation, context = { planet = "Tatooine" } })

		-- fire off first result
		mockLink:simulateResult({ result = { data = initialData } })
	end)

	it("includes getCacheKey function on the context for cache resolvers", function()
		local query = gql([[

      {
        books {
          id
          title
        }
      }
    ]])

		local shouldHitCacheResolver = gql([[

      {
        book(id: 1) {
          title
        }
      }
    ]])

		local bookData = {
			books = {
				{ id = 1, title = "Woo", __typename = "Book" },
				{ id = 2, title = "Foo", __typename = "Book" },
			},
		}

		local link = ApolloLink.new(function(_self, operation, forward)
			local ref = operation:getContext()
			local getCacheKey = ref.getCacheKey
			expect(getCacheKey).toBeDefined()
			-- ROBLOX deviation START? policies:identify() specifies multiple return values, but cache and inmemory cache specify it as `string?` this mismatch is also upstream!
			expect(({ ref:getCacheKey({ id = 1, __typename = "Book" }) })[1]).toEqual("Book:1")
			-- ROBLOX deviation END
			return Observable.of({ data = bookData })
		end)

		local queryManager = QueryManager.new({
			link = link,
			cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							book = function(
								_self,
								_,
								ref_: FieldFunctionOptions<Record<string, any>, Record<string, any>>
							): any
								local args_ = ref_.args
								if not Boolean.toJSBoolean(args_) then
									error(Error.new("arg must never be null"))
								end
								local args = args_ :: Record<string, any>
								local ref = ref_:toReference({ __typename = "Book", id = args.id })
								if not ref then
									error(Error.new("ref must never be null"))
								end
								expect(ref).toEqual({ __ref = ("Book:%s"):format(args.id) })
								local found = Array.find(ref_:readField("books") :: Array<Reference>, function(book)
									-- ROBLOX FIXME Luau: Luau doesn't see the `not ref` branch above as eliminating nil-ability
									return book.__ref == (ref :: Reference).__ref
								end)
								expect(found).toBeTruthy()
								return found
							end,
						} :: any,
					},
				},
			}),
		})

		queryManager:query({ query = query }):expect()

		return (
			queryManager:query({ query = shouldHitCacheResolver }):andThen(function(ref)
				local data = ref.data
				expect(data).toMatchObject({ book = { title = "Woo", __typename = "Book" } })
			end) :: any
		) -- ROBLOX TODO: timeout is a valid method in Promise, add to Polyfill:timeout(3):expect()
	end)
end)

return {}
