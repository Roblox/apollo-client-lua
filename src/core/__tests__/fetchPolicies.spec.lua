-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/__tests__/fetchPolicies.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Error = LuauPolyfill.Error
	local Object = LuauPolyfill.Object
	local setTimeout = LuauPolyfill.setTimeout

	type Array<T> = LuauPolyfill.Array<T>

	local utilitiesModule = require(srcWorkspace.utilities)
	type Observable<T> = utilitiesModule.Observable<T>

	local gql = require(rootWorkspace.Dev.GraphQLTag).default

	local coreModule = require(srcWorkspace.core)
	local ApolloClient = coreModule.ApolloClient
	local NetworkStatus = coreModule.NetworkStatus

	local ApolloLink = require(srcWorkspace.link.core).ApolloLink
	local InMemoryCache = require(srcWorkspace.cache.inmemory.inMemoryCache).InMemoryCache
	local Observable = require(srcWorkspace.utilities).Observable

	local testingModule = require(srcWorkspace.testing)
	local stripSymbols = testingModule.stripSymbols
	local subscribeAndCount = testingModule.subscribeAndCount
	local itAsync = testingModule.itAsync
	local mockSingleLink = testingModule.mockSingleLink

	local query = gql([[

  query {
    author {
      __typename
      id
      firstName
      lastName
    }
  }
]])

	local result = {
		author = { __typename = "Author", id = 1, firstName = "John", lastName = "Smith" },
	}

	local mutation = gql([[

  mutation updateName($id: ID!, $firstName: String!) {
    updateName(id: $id, firstName: $firstName) {
      __typename
      id
      firstName
    }
  }
]])

	local variables = { id = 1, firstName = "James" }

	local mutationResult = { updateName = { id = 1, __typename = "Author", firstName = "James" } }

	local merged = { author = Object.assign({}, result.author, { firstName = "James" }) }

	local function createLink(reject: (reason: any) -> any)
		return mockSingleLink(
			{ request = { query = query }, result = { data = result } },
			{ request = { query = query }, result = { data = result } }
		):setOnError(reject)
	end

	local function createFailureLink()
		return mockSingleLink(
			{ request = { query = query }, ["error"] = Error.new("query failed") },
			{ request = { query = query }, result = { data = result } }
		)
	end

	local function createMutationLink(reject: (reason: any) -> any)
		return mockSingleLink(
			-- fetch the data
			{ request = { query = query }, result = { data = result } },
			-- update the data
			{ request = { query = mutation, variables = variables }, result = { data = mutationResult } },
			-- get the new results
			{ request = { query = query }, result = { data = merged } }
		):setOnError(reject)
	end

	describe("network-only", function()
		itAsync(it)("requests from the network even if already in cache", function(resolve, reject)
			local called = 0
			local inspector = ApolloLink.new(function(_self, operation, forward)
				called += 1
				return forward(operation):map(function(result)
					called += 1
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createLink(reject)),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			return client
				:query({ query = query })
				:andThen(function()
					return client:query({ fetchPolicy = "network-only", query = query }):andThen(function(actualResult)
						jestExpect(stripSymbols(actualResult.data)).toEqual(result)
						jestExpect(called).toBe(4)
					end)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("saves data to the cache on success", function(resolve, reject)
			local called = 0
			local inspector = ApolloLink.new(function(_self, operation, forward)
				called += 1
				return forward(operation):map(function(result)
					called += 1
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createLink(reject)),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			return client
				:query({ query = query, fetchPolicy = "network-only" })
				:andThen(function()
					return client:query({ query = query }):andThen(function(actualResult)
						jestExpect(stripSymbols(actualResult.data)).toEqual(result)
						jestExpect(called).toBe(2)
					end)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("does not save data to the cache on failure", function(resolve, reject)
			local called = 0
			local inspector = ApolloLink.new(function(_self, operation, forward)
				called += 1

				return forward(operation):map(function(result)
					called += 1
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createFailureLink()),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			local didFail = false
			return client
				:query({ query = query, fetchPolicy = "network-only" })
				:catch(function(e)
					jestExpect(e.message).toMatch("query failed")
					didFail = true
				end)
				:andThen(function()
					return client:query({ query = query }):andThen(function(actualResult)
						jestExpect(stripSymbols(actualResult.data)).toEqual(result)
						-- the first error doesn't call .map on the inspector
						jestExpect(called).toBe(3)
						jestExpect(didFail).toBe(true)
					end)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("updates the cache on a mutation", function(resolve, reject)
			local inspector = ApolloLink.new(function(_self, operation, forward)
				return forward(operation):map(function(result)
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createMutationLink(reject)),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			return client
				:query({ query = query })
				:andThen(function()
					-- XXX currently only no-cache is supported as a fetchPolicy
					-- this mainly serves to ensure the cache is updated correctly
					return client:mutate({ mutation = mutation, variables = variables }) :: any
				end)
				:andThen(function()
					return client:query({ query = query }):andThen(function(actualResult)
						jestExpect(stripSymbols(actualResult.data)).toEqual(merged)
					end)
				end)
				:andThen(resolve, reject)
		end)
	end)

	describe("no-cache", function()
		itAsync(it)("requests from the network when not in cache", function(resolve, reject)
			local called = 0
			local inspector = ApolloLink.new(function(_self, operation, forward)
				called += 1

				return forward(operation):map(function(result)
					called += 1
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createLink(reject)),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			return client
				:query({ fetchPolicy = "no-cache", query = query })
				:andThen(function(actualResult)
					jestExpect(actualResult.data).toEqual(result)
					jestExpect(called).toBe(2)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("requests from the network even if already in cache", function(resolve, reject)
			local called = 0
			local inspector = ApolloLink.new(function(_self, operation, forward)
				called += 1

				return forward(operation):map(function(result)
					called += 1
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createLink(reject)),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			return client
				:query({ query = query })
				:andThen(function()
					return client:query({ fetchPolicy = "no-cache", query = query }):andThen(function(actualResult)
						jestExpect(actualResult.data).toEqual(result)
						jestExpect(called).toBe(4)
					end)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("does not save the data to the cache on success", function(resolve, reject)
			local called = 0
			local inspector = ApolloLink.new(function(_self, operation, forward)
				called += 1
				return forward(operation):map(function(result)
					called += 1
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createLink(reject)),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			return client
				:query({ query = query, fetchPolicy = "no-cache" })
				:andThen(function()
					return client:query({ query = query }):andThen(function(actualResult)
						jestExpect(stripSymbols(actualResult.data)).toEqual(result)
						-- the second query couldn't read anything from the cache
						jestExpect(called).toBe(4)
					end)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("does not save data to the cache on failure", function(resolve, reject)
			local called = 0
			local inspector = ApolloLink.new(function(_self, operation, forward)
				called += 1
				return forward(operation):map(function(result)
					called += 1
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createFailureLink()),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			local didFail = false
			return client
				:query({ query = query, fetchPolicy = "no-cache" })
				:catch(function(e)
					jestExpect(e.message).toMatch("query failed")
					didFail = true
				end)
				:andThen(function()
					return client:query({ query = query }):andThen(function(actualResult)
						jestExpect(stripSymbols(actualResult.data)).toEqual(result)
						-- the first error doesn't call .map on the inspector
						jestExpect(called).toBe(3)
						jestExpect(didFail).toBe(true)
					end)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("does not update the cache on a mutation", function(resolve, reject)
			local inspector = ApolloLink.new(function(_self, operation, forward)
				return forward(operation):map(function(result)
					return result
				end) :: Observable<any>
			end)

			local client = ApolloClient.new({
				link = inspector:concat(createMutationLink(reject)),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			return client
				:query({ query = query })
				:andThen(function()
					return client:mutate({
						mutation = mutation,
						variables = variables,
						fetchPolicy = "no-cache",
					}) :: any
				end)
				:andThen(function()
					return client:query({ query = query }):andThen(function(actualResult)
						jestExpect(stripSymbols(actualResult.data)).toEqual(result)
					end)
				end)
				:andThen(resolve, reject)
		end)

		describe("when notifyOnNetworkStatusChange is set", function()
			itAsync(it)("does not save the data to the cache on success", function(resolve, reject)
				local called = 0
				local inspector = ApolloLink.new(function(_self, operation, forward)
					called += 1
					return forward(operation):map(function(result)
						called += 1
						return result
					end) :: Observable<any>
				end)

				local client = ApolloClient.new({
					link = inspector:concat(createLink(reject)),
					cache = InMemoryCache.new({ addTypename = false }),
				})

				return client
					:query({
						query = query,
						fetchPolicy = "no-cache",
						notifyOnNetworkStatusChange = true,
					})
					:andThen(function()
						return client:query({ query = query }):andThen(function(actualResult)
							jestExpect(stripSymbols(actualResult.data)).toEqual(result)
							-- the second query couldn't read anything from the cache
							jestExpect(called).toBe(4)
						end)
					end)
					:andThen(resolve, reject)
			end)

			itAsync(it)("does not save data to the cache on failure", function(resolve, reject)
				local called = 0
				local inspector = ApolloLink.new(function(_self, operation, forward)
					called += 1
					return forward(operation):map(function(result)
						called += 1
						return result
					end) :: Observable<any>
				end)

				local client = ApolloClient.new({
					link = inspector:concat(createFailureLink()),
					cache = InMemoryCache.new({ addTypename = false }),
				})

				local didFail = false
				return client
					:query({
						query = query,
						fetchPolicy = "no-cache",
						notifyOnNetworkStatusChange = true,
					})
					:catch(function(e)
						jestExpect(e.message).toMatch("query failed")
						didFail = true
					end)
					:andThen(function()
						return client:query({ query = query }):andThen(function(actualResult)
							jestExpect(stripSymbols(actualResult.data)).toEqual(result)
							-- the first error doesn't call .map on the inspector
							jestExpect(called).toBe(3)
							jestExpect(didFail).toBe(true)
						end)
					end)
					:andThen(resolve, reject)
			end)

			itAsync(it)("gives appropriate networkStatus for watched queries", function(resolve, reject)
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
					resolvers = {
						Query = {
							hero = function(_self, _data, args)
								return Object.assign({}, { __typename = "Hero" }, args, { name = "Luke Skywalker" })
							end,
						},
					},
				})

				local observable = client:watchQuery({
					query = gql([[

          query FetchLuke($id: String) {
            hero(id: $id) @client {
              id
              name
            }
          }
        ]]),
					fetchPolicy = "no-cache",
					variables = { id = "1" },
					notifyOnNetworkStatusChange = true,
				})

				local function dataWithId(id: number | string)
					return { hero = { __typename = "Hero", id = tostring(id), name = "Luke Skywalker" } }
				end

				subscribeAndCount(reject, observable, function(count, result)
					if count == 1 then
						jestExpect(result).toEqual({
							data = dataWithId(1),
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
						jestExpect(client.cache:extract(true)).toEqual({})
						return observable:setVariables({ id = "2" })
					elseif count == 2 then
						jestExpect(result).toEqual({
							loading = true,
							networkStatus = NetworkStatus.setVariables,
							partial = true,
						})
					elseif count == 3 then
						jestExpect(result).toEqual({
							data = dataWithId(2),
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
						jestExpect(client.cache:extract(true)).toEqual({})
						return observable:refetch() :: any
					elseif count == 4 then
						jestExpect(result).toEqual({
							data = dataWithId(2),
							loading = true,
							networkStatus = NetworkStatus.refetch,
						})
						jestExpect(client.cache:extract(true)).toEqual({})
					elseif count == 5 then
						jestExpect(result).toEqual({
							data = dataWithId(2),
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
						jestExpect(client.cache:extract(true)).toEqual({})
						return observable:refetch({ id = "3" } :: any) :: any
					elseif count == 6 then
						jestExpect(result).toEqual({
							loading = true,
							networkStatus = NetworkStatus.setVariables,
							partial = true,
						})
						jestExpect(client.cache:extract(true)).toEqual({})
					elseif count == 7 then
						jestExpect(result).toEqual({
							data = dataWithId(3),
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
						jestExpect(client.cache:extract(true)).toEqual({})
						resolve()
					end
					return nil :: any
				end)
			end)
		end)
	end)

	describe("cache-first", function()
		-- ROBLOX comment: skipped upstream
		itAsync(itSKIP)("does not trigger network request during optimistic update", function(resolve, reject)
			local results: Array<any> = {}
			local client = ApolloClient.new({
				link = ApolloLink.new(function(_self, operation, forward)
					return forward(operation):map(function(result)
						table.insert(results, result)
						return result
					end) :: Observable<any>
				end):concat(createMutationLink(reject)),
				cache = InMemoryCache.new(),
			})
			local inOptimisticTransaction = false
			subscribeAndCount(
				reject,
				client:watchQuery({
					query = query,
					fetchPolicy = "cache-and-network",
					returnPartialData = true,
				}),
				function(count, ref)
					local data, loading, networkStatus = ref.data, ref.loading, ref.networkStatus
					if count == 1 then
						jestExpect(#results).toBe(0)
						jestExpect(loading).toBe(true)
						jestExpect(networkStatus).toBe(NetworkStatus.loading)
						jestExpect(data).toEqual({})
					elseif count == 2 then
						jestExpect(#results).toBe(1)
						jestExpect(loading).toBe(false)
						jestExpect(networkStatus).toBe(NetworkStatus.ready)
						jestExpect(data).toEqual({
							author = {
								__typename = "Author",
								id = 1,
								firstName = "John",
								lastName = "Smith",
							},
						})
						inOptimisticTransaction = true
						client.cache:recordOptimisticTransaction(function(cache)
							cache:writeQuery({
								query = query,
								data = { author = { __typename = "Bogus" } },
							})
						end, "bogus")
					elseif count == 3 then
						jestExpect(#results).toBe(1)
						jestExpect(loading).toBe(false)
						jestExpect(networkStatus).toBe(NetworkStatus.ready)
						jestExpect(data).toEqual({ author = { __typename = "Bogus" } })
						setTimeout(function()
							inOptimisticTransaction = false
							client.cache:removeOptimistic("bogus")
						end, 100)
					elseif count == 4 then
						-- A network request should not be triggered until after the bogus
						-- optimistic transaction has been removed.
						jestExpect(inOptimisticTransaction).toBe(false)
						jestExpect(#results).toBe(1)
						jestExpect(loading).toBe(false)
						jestExpect(networkStatus).toBe(NetworkStatus.ready)
						jestExpect(data).toEqual({
							author = {
								__typename = "Author",
								id = 1,
								firstName = "John",
								lastName = "Smith",
							},
						})
						client.cache:writeQuery({
							query = query,
							data = {
								author = {
									__typename = "Author",
									id = 2,
									firstName = "Chinua",
									lastName = "Achebe",
								},
							},
						})
					elseif count == 5 then
						jestExpect(inOptimisticTransaction).toBe(false)
						jestExpect(#results).toBe(1)
						jestExpect(loading).toBe(false)
						jestExpect(networkStatus).toBe(NetworkStatus.ready)
						jestExpect(data).toEqual({
							author = {
								__typename = "Author",
								id = 2,
								firstName = "Chinua",
								lastName = "Achebe",
							},
						})
						setTimeout(resolve, 100)
					else
						reject(Error.new("unreached"))
					end
				end
			)
		end)
	end)
	describe("cache-only", function()
		itAsync(it)("allows explicit refetch to happen", function(resolve, reject)
			local counter = 0
			local client = ApolloClient.new({
				cache = InMemoryCache.new(),
				link = ApolloLink.new(function(operation)
					return Observable.new(function(observer)
						observer:next({
							data = { count = (function()
								counter += 1
								return counter
							end)() },
						})
						observer:complete()
					end)
				end),
			})

			local query = gql("query { count }")

			local observable = client:watchQuery({ query = query, nextFetchPolicy = "cache-only" })

			subscribeAndCount(reject, observable, function(count, result)
				if count == 1 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = { count = 1 },
					})

					jestExpect(observable.options.fetchPolicy).toBe("cache-only")

					observable:refetch():catch(reject)
				elseif count == 2 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = { count = 2 },
					})
					jestExpect(observable.options.fetchPolicy).toBe("cache-only")
					setTimeout(resolve, 50)
				else
					reject(("too many results (%s)"):format(count))
				end
			end)
		end)
	end)

	describe("cache-and-network", function()
		itAsync(it)("gives appropriate networkStatus for refetched queries", function(resolve, reject)
			local client = ApolloClient.new({
				link = ApolloLink.empty(),
				cache = InMemoryCache.new(),
				resolvers = {
					Query = {
						hero = function(_self, _data, args)
							return Object.assign({}, { __typename = "Hero" }, args, { name = "Luke Skywalker" })
						end,
					},
				},
			})

			local observable = client:watchQuery({
				query = gql([[

        query FetchLuke($id: String) {
          hero(id: $id) @client {
            id
            name
          }
        }
      ]]),
				fetchPolicy = "cache-and-network",
				variables = { id = "1" },
				notifyOnNetworkStatusChange = true,
			})

			local function dataWithId(id: number | string)
				return { hero = { __typename = "Hero", id = tostring(id), name = "Luke Skywalker" } }
			end

			subscribeAndCount(reject, observable, function(count, result)
				if count == 1 then
					jestExpect(result).toEqual({
						data = dataWithId(1),
						loading = false,
						networkStatus = NetworkStatus.ready,
					})
					return observable:setVariables({ id = "2" })
				elseif count == 2 then
					jestExpect(result).toEqual({
						data = {},
						loading = true,
						networkStatus = NetworkStatus.setVariables,
						partial = true,
					})
				elseif count == 3 then
					jestExpect(result).toEqual({
						data = dataWithId(2),
						loading = false,
						networkStatus = NetworkStatus.ready,
					})
					return observable:refetch() :: any
				elseif count == 4 then
					jestExpect(result).toEqual({
						data = dataWithId(2),
						loading = true,
						networkStatus = NetworkStatus.refetch,
					})
				elseif count == 5 then
					jestExpect(result).toEqual({
						data = dataWithId(2),
						loading = false,
						networkStatus = NetworkStatus.ready,
					})
					return observable:refetch({ id = "3" } :: any) :: any
				elseif count == 6 then
					jestExpect(result).toEqual({
						data = {},
						loading = true,
						networkStatus = NetworkStatus.setVariables,
						partial = true,
					})
				elseif count == 7 then
					jestExpect(result).toEqual({
						data = dataWithId(3),
						loading = false,
						networkStatus = NetworkStatus.ready,
					})
					resolve()
				end
				return nil :: any
			end)
		end)
	end)
end
