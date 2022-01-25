-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/core/__tests__/QueryManager/multiple-results.ts

return function()
	-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
	local TICK = 1000 / 30

	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local console = LuauPolyfill.console
	local Error = LuauPolyfill.Error
	local setTimeout = LuauPolyfill.setTimeout
	local Promise = require(rootWorkspace.Promise)
	local NULL = require(srcWorkspace.utilities).NULL

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	-- externals
	local gql = require(rootWorkspace.GraphQLTag).default
	local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache.inmemory.inMemoryCache).InMemoryCache
	local stripSymbols = require(script.Parent.Parent.Parent.Parent.utilities.testing.stripSymbols).stripSymbols

	-- mocks
	local MockSubscriptionLink = require(
		script.Parent.Parent.Parent.Parent.utilities.testing.mocking.mockSubscriptionLink
	).MockSubscriptionLink

	-- core
	local QueryManagerModule = require(script.Parent.Parent.Parent.QueryManager)
	local QueryManager = QueryManagerModule.QueryManager
	type QueryManager<TStore> = QueryManagerModule.QueryManager<TStore>
	local GraphQLError = require(rootWorkspace.GraphQL).GraphQLError

	-- ROBLOX deviation START: importing NormalizedCacheObject for explicit cast
	local InMemoryCacheTypesModule = require(script.Parent.Parent.Parent.Parent.cache.inmemory.types)
	type NormalizedCacheObject = InMemoryCacheTypesModule.NormalizedCacheObject
	-- ROBLOX deviation END

	-- ROBLOX deviation: creating a factory function to create a callable table `done` with fail property function
	local function createDone(resolve, reject)
		return setmetatable({
			fail = reject,
		}, {
			__call = function(_self, ...)
				return resolve(...)
			end,
		})
	end

	describe("mutiple results", function()
		it("allows multiple query results from link", function()
			Promise.new(function(resolve, reject)
				local done = createDone(resolve, reject)

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
			end):timeout(3):expect()
		end)

		it("allows multiple query results from link with ignored errors", function()
			Promise.new(function(resolve, reject)
				local done = createDone(resolve, reject)

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
						jestExpect(result.errors).toBeUndefined()
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
			end):timeout(3):expect()
		end)

		it("strips errors from a result if ignored", function()
			Promise.new(function(resolve, reject)
				local done = createDone(resolve, reject)

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
						jestExpect(result.errors).toBeUndefined()
						count += 1

						if count == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(initialData)
							-- this should fire the `next` event without this error
							link:simulateResult({
								result = { errors = { GraphQLError.new("defer failed") }, data = laterData },
							} :: any)
						end
						if count == 2 then
							jestExpect(stripSymbols(result.data)).toEqual(laterData)
							jestExpect(result.errors).toBeUndefined()
							-- make sure the count doesn't go up by accident
							setTimeout(
								function()
									if count == 3 then
										done.fail(Error.new("error was not ignored"))
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
			end):timeout(3):expect()
		end)

		-- ROBLOX comment: this test is skipped upstream
		xit("allows multiple query results from link with all errors", function()
			Promise.new(function(resolve, reject)
				local done = createDone(resolve, reject)

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
								jestExpect(result.errors).toBeUndefined()
								-- this should fire the next event again
								link:simulateResult({
									error = Error.new("defer failed"),
								})
							end
							if count == 2 then
								jestExpect(result.errors).toBeDefined()
								link:simulateResult({ result = { data = laterData } })
							end
							if count == 3 then
								jestExpect(result.errors).toBeUndefined()
								-- make sure the count doesn't go up by accident
								setTimeout(function()
									if count == 4 then
										done.fail(Error.new("error was not ignored"))
									end
									done()
								end)
							end
						end, function(e)
							done.fail(e)
						end)
					end,
					error = function(_self, e)
						done.fail(e)
					end,
				})

				-- fire off first result
				link:simulateResult({ result = { data = initialData } })
			end):timeout(3):expect()
		end)

		it("closes the observable if an error is set with the none policy", function()
			Promise.new(function(resolve, reject)
				local done = createDone(resolve, reject)

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
							jestExpect(result.errors).toBeUndefined()
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
						jestExpect(e).toBeDefined()
						jestExpect(e.graphQLErrors).toBeDefined()
						done()
					end,
				})

				-- fire off first result
				link:simulateResult({ result = { data = initialData } })
			end):timeout(3):expect()
		end)
	end)
end
