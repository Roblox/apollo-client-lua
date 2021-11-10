--!nocheck
--!nolint
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/__tests__/QueryManager/multiple-results.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local console, Error, setTimeout = LuauPolyfill.console, LuauPolyfill.Error, LuauPolyfill.setTimeout

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	-- externals
	local gql = require(rootWorkspace.Dev.GraphQLTag).default
	local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache.inmemory.inMemoryCache).InMemoryCache
	local stripSymbols = require(script.Parent.Parent.Parent.Parent.utilities.testing.stripSymbols).stripSymbols

	-- mocks
	local MockSubscriptionLink = {} :: any
	-- local MockSubscriptionLink =
	-- 	require(srcWorkspace.utilities.testing.mocking.mockSubscriptionLink).MockSubscriptionLink

	-- core
	local QueryManager = require(script.Parent.Parent.Parent.QueryManager).QueryManager
	local GraphQLError = require(rootWorkspace.GraphQL).GraphQLError

	xdescribe("mutiple results", function()
		it("allows multiple query results from link", function(done)
			local query = gql([[
      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      ]])

			local initialData = { people_one = { name = "Luke Skywalker", friends = nil } }

			local laterData = {
				people_one = {
					-- XXX true defer's wouldn't send this
					name = "Luke Skywalker",
					friends = { { name = "Leia Skywalker" } },
				},
			}

			local link = MockSubscriptionLink.new()

			local queryManager = QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			})

			local observable = queryManager:watchQuery({ query = query, variables = {} })

			local count = 0

			observable:subscribe({
				next = function(result)
					(function()
						local result = count
						count += 1
						return result
					end)()
					if count == 1 then
						link:simulateResult({ result = { data = laterData } })
					end
					if count == 2 then
						done()
					end
				end,
				["error"] = function(e)
					console:error_(e)
				end,
			})

			-- fire off first result
			link:simulateResult({ result = { data = initialData } })
		end)

		it("allows multiple query results from link with ignored errors", function(done)
			local query = gql([[
      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      ]])

			local initialData = { people_one = { name = "Luke Skywalker", friends = nil } }

			local laterData = {
				people_one = {
					-- XXX true defer's wouldn't send this
					name = "Luke Skywalker",
					friends = { { name = "Leia Skywalker" } },
				},
			}

			local link = MockSubscriptionLink.new()

			local queryManager = QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			})

			local observable = queryManager:watchQuery({
				query = query,
				variables = {},
				errorPolicy = "ignore",
			})

			local count = 0

			observable:subscribe({
				next = function(result)
					-- errors should never be passed since they are ignored
					jestExpect(result.errors).toBeUndefined();
					(function()
						local result_ = count
						count += 1
						return result_
					end)()
					if count == 1 then
						link:simulateResult({ result = { errors = { GraphQLError.new("defer failed") } } })
						setTimeout(function()
							link:simulateResult({ result = { data = laterData } })
						end, 20)
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
				["error"] = function(e)
					console:error_(e)
				end,
			})

			-- fire off first result
			link:simulateResult({ result = { data = initialData } })
		end)

		it("strips errors from a result if ignored", function(done)
			local query = gql([[
      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      ]])

			local initialData = { people_one = {

				name = "Luke Skywalker",
				friends = nil,
			} }

			local laterData = {
				people_one = {
					-- XXX true defer's wouldn't send this
					name = "Luke Skywalker",
					friends = { { name = "Leia Skywalker" } },
				},
			}

			local link = MockSubscriptionLink.new()

			local queryManager = QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			})

			local observable = queryManager:watchQuery({
				query = query,
				variables = {},
				errorPolicy = "ignore",
			})

			local count = 0

			observable:subscribe({
				next = function(result)
					-- errors should never be passed since they are ignored
					jestExpect(result.errors).toBeUndefined();
					(function()
						local result = count
						count += 1
						return result
					end)()
					if count == 1 then
						jestExpect(stripSymbols(result.data)).toEqual(initialData)
						-- this should fire the `next` event without this error
						link:simulateResult({
							result = { errors = { GraphQLError.new("defer failed") }, data = laterData },
						})
					end
					if count == 2 then
						jestExpect(stripSymbols(result.data)).toEqual(laterData)
						-- make sure the count doesn't go up by accident
						jestExpect(result.errors).toBeUndefined()
						setTimeout(function()
							if count == 3 then
								done:fail(Error.new("error was not ignored"))
							end
							done()
						end, 10)
					end
				end,
				["error"] = function(e)
					console:error_(e)
				end,
			})

			-- fire off first result
			link:simulateResult({ result = { data = initialData } })
		end)

		xit("allows multiple query results from link with all errors", function(done)
			local query = gql([[
      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      ]])

			local initialData = { people_one = { name = "Luke Skywalker", friends = nil } }

			local laterData = {
				people_one = {
					-- XXX true defer's wouldn't send this
					name = "Luke Skywalker",
					friends = { { name = "Leia Skywalker" } },
				},
			}

			local link = MockSubscriptionLink.new()

			local queryManager = QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			})

			local observable = queryManager:watchQuery({
				query = query,
				variables = {},
				errorPolicy = "all",
			})

			local count = 0

			observable:subscribe({
				next = function(result)
					do --[[ ROBLOX COMMENT: try-catch block conversion ]]
						local _ok, result_, hasReturned = xpcall(function()
							-- errors should never be passed since they are ignored
							(function()
								local result__ = count
								count += 1
								return result__
							end)()
							if count == 1 then
								jestExpect(result.errors).toBeUndefined()

								-- this should fire the next event again
								link:simulateResult({ ["error"] = Error.new("defer failed") })
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
										done:fail(Error.new("error was not ignored"))
									end
									done()
								end)
							end
						end, function(e)
							done:fail(e)
						end)
						if hasReturned then
							return result_
						end
					end
				end,
				["error"] = function(e)
					done:fail(e)
				end,
			})

			-- fire off first result
			link:simulateResult({ result = { data = initialData } })
		end)

		it("closes the observable if an error is set with the none policy", function(done)
			local query = gql([[
      query LazyLoadLuke {
        people_one(id: 1) {
          name
          friends @defer {
            name
          }
        }
      ]])
			local initialData = { people_one = { name = "Luke Skywalker", friends = nil } }

			local link = MockSubscriptionLink.new()

			local queryManager = QueryManager.new({
				cache = InMemoryCache.new({ addTypename = false }),
				link = link,
			})

			local observable = queryManager:watchQuery({
				query = query,
				variables = {},
				-- errorPolicy: 'none', // this is the default
			})

			local count = 0

			observable:subscribe({
				next = function(result)
					-- errors should never be passed since they are ignored
					(function()
						local result = count
						count += 1
						return result
					end)()
					if count == 1 then
						jestExpect(result.errors).toBeUndefined()
						-- this should fire the next event again
						link:simulateResult({ ["error"] = Error.new("defer failed") })
					end
					if count == 2 then
						console:log(Error.new("result came after an error"))
					end
				end,
				["error"] = function(e)
					jestExpect(e).toBeDefined()
					jestExpect(e.graphQLErrors).toBeDefined()
					done()
				end,
			})

			-- fire off first result
			link:simulateResult({ result = { data = initialData } })
		end)
	end)
end
