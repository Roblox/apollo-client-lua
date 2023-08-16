--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/core/__tests__/QueryManager/multiple-results.ts

-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
local TICK = 1000 / 30

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local console = LuauPolyfill.console
local Error = LuauPolyfill.Error
local setTimeout = LuauPolyfill.setTimeout
type Error = LuauPolyfill.Error
local NULL = require(srcWorkspace.utilities).NULL

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
type DoneFn = ((string | Error)?) -> ()

-- externals
local gql = require(rootWorkspace.GraphQLTag).default
local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache.inmemory.inMemoryCache).InMemoryCache
local stripSymbols = require(script.Parent.Parent.Parent.Parent.utilities.testing.stripSymbols).stripSymbols

-- mocks
local MockSubscriptionLink =
	require(script.Parent.Parent.Parent.Parent.utilities.testing.mocking.mockSubscriptionLink).MockSubscriptionLink

-- core
local QueryManagerModule = require(script.Parent.Parent.Parent.QueryManager)
local QueryManager = QueryManagerModule.QueryManager
type QueryManager<TStore> = QueryManagerModule.QueryManager<TStore>
local GraphQLError = require(rootWorkspace.GraphQL).GraphQLError

-- ROBLOX deviation START: importing NormalizedCacheObject for explicit cast
local InMemoryCacheTypesModule = require(script.Parent.Parent.Parent.Parent.cache.inmemory.types)
type NormalizedCacheObject = InMemoryCacheTypesModule.NormalizedCacheObject
-- ROBLOX deviation END

describe("mutiple results", function()
	it("allows multiple query results from link", function(_, done)
		local query = gql([[

      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      }
    ]])

		local initialData = {
			people_one = {
				name = "Luke Skywalker",
				friends = nil,
			},
		}

		local laterData = {
			people_one = {
				-- XXX true defer's wouldn't send this
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
		observable:subscribe({
			next = function(_self, result)
				count += 1
				if count == 1 then
					link:simulateResult({ result = { data = laterData } })
				end
				if count == 2 then
					done()
				end
			end,
			error = function(_self, e)
				console.error(e)
			end,
		})

		-- fire off first result
		link:simulateResult({ result = { data = initialData } })
	end)

	it("allows multiple query results from link with ignored errors", function(_, done)
		local query = gql([[

      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      }
    ]])

		local initialData = {
			people_one = {
				name = "Luke Skywalker",
				friends = nil,
			},
		}

		local laterData = {
			people_one = {
				-- XXX true defer's wouldn't send this
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
			errorPolicy = "ignore",
		})

		local count = 0
		observable:subscribe({
			next = function(_self, result)
				-- errors should never be passed since they are ignored
				expect(result.errors).toBeUndefined()
				count += 1
				if count == 1 then
					-- this shouldn't fire the next event again
					link:simulateResult({
						result = { errors = { GraphQLError.new("defer failed") } },
					} :: any)
					setTimeout(
						function()
							link:simulateResult({ result = { data = laterData } })
						end,
						-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
						20 * TICK
					)
				end
				if count == 2 then
					-- make sure the count doesn't go up by accident
					setTimeout(function()
						if count == 3 then
							error(Error.new("error was not ignored"))
						end
						done()
					end)
				end
			end,
			error = function(_self, e)
				console.error(e)
			end,
		})

		-- fire off first result
		link:simulateResult({ result = { data = initialData } })
	end)

	it("strips errors from a result if ignored", function(_, done: DoneFn)
		local query = gql([[

      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      }
    ]])

		local initialData = {
			people_one = {
				name = "Luke Skywalker",
				friends = NULL,
			},
		}

		local laterData = {
			people_one = {
				-- XXX true defer's wouldn't send this
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
			errorPolicy = "ignore",
		})

		local count = 0
		observable:subscribe({
			next = function(_self, result)
				-- errors should never be passed since they are ignored
				expect(result.errors).toBeUndefined()
				count += 1

				if count == 1 then
					expect(stripSymbols(result.data)).toEqual(initialData)
					-- this should fire the `next` event without this error
					link:simulateResult({
						result = { errors = { GraphQLError.new("defer failed") }, data = laterData },
					} :: any)
				end
				if count == 2 then
					expect(stripSymbols(result.data)).toEqual(laterData)
					expect(result.errors).toBeUndefined()
					-- make sure the count doesn't go up by accident
					setTimeout(
						function()
							if count == 3 then
								-- ROBLOX deviation START: using done(error) instead of done.fail(error)
								done(Error.new("error was not ignored"))
								-- ROBLOX deviation END
							end
							done()
						end,
						-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
						10 * TICK
					)
				end
			end,
			error = function(_self, e)
				console.error(e)
			end,
		})

		-- fire off first result
		link:simulateResult({ result = { data = initialData } })
	end)

	-- ROBLOX comment: this test is skipped upstream
	it.skip("allows multiple query results from link with all errors", function(_, done: DoneFn)
		local query = gql([[

      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      }
    ]])

		local initialData = {
			people_one = {
				name = "Luke Skywalker",
				friends = nil,
			},
		}

		local laterData = {
			people_one = {
				-- XXX true defer's wouldn't send this
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
			errorPolicy = "all",
		})

		local count = 0

		observable:subscribe({
			next = function(_self, result)
				xpcall(function()
					-- errors should never be passed since they are ignored
					count += 1
					if count == 1 then
						expect(result.errors).toBeUndefined()
						-- this should fire the next event again
						link:simulateResult({
							error = Error.new("defer failed"),
						})
					end
					if count == 2 then
						expect(result.errors).toBeDefined()
						link:simulateResult({ result = { data = laterData } })
					end
					if count == 3 then
						expect(result.errors).toBeUndefined()
						-- make sure the count doesn't go up by accident
						setTimeout(function()
							if count == 4 then
								-- ROBLOX deviation START: using done(error) instead of done.fail(error)
								done(Error.new("error was not ignored"))
								-- ROBLOX deviation END
							end
							done()
						end)
					end
				end, function(e)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					done(e)
					-- ROBLOX deviation END
				end)
			end,
			error = function(_self, e)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done(e)
				-- ROBLOX deviation END
			end,
		})

		-- fire off first result
		link:simulateResult({ result = { data = initialData } })
	end)

	it("closes the observable if an error is set with the none policy", function(_, done)
		local query = gql([[

      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      }
    ]])
		local initialData = {
			people_one = {
				name = "Luke Skywalker",
				friends = nil,
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
			-- errorPolicy: 'none', // this is the default
		})

		local count = 0
		observable:subscribe({
			next = function(_self, result)
				-- errors should never be passed since they are ignored
				count += 1
				if count == 1 then
					expect(result.errors).toBeUndefined()
					-- this should fire the next event again
					link:simulateResult({
						error = Error.new("defer failed"),
					})
				end
				if count == 2 then
					console.log(Error.new("result came after an error"))
				end
			end,
			error = function(_self, e)
				expect(e).toBeDefined()
				expect(e.graphQLErrors).toBeDefined()
				done()
			end,
		})

		-- fire off first result
		link:simulateResult({ result = { data = initialData } })
	end)
end)

return {}
