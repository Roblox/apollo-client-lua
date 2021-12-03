-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/__tests__/ObservableQuery.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Boolean = LuauPolyfill.Boolean
	local Error = LuauPolyfill.Error
	local Object = LuauPolyfill.Object
	local instanceof = LuauPolyfill.instanceof
	local setTimeout = LuauPolyfill.setTimeout
	local Promise = require(rootWorkspace.Promise)

	type Array<T> = LuauPolyfill.Array<T>
	type Object = LuauPolyfill.Object

	local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
	type Promise<T> = PromiseTypeModule.Promise<T>

	-- ROBLOX FIXME: remove if better solution is found
	type FIX_ANALYZE = any

	-- ROBLOX TODO: replace when function generics are available
	type T_ = any

	local gql = require(rootWorkspace.GraphQLTag).default
	local GraphQLError = require(rootWorkspace.GraphQL).GraphQLError
	local typedDocumentNodeModule = require(srcWorkspace.jsutils.typedDocumentNode)
	type TypedDocumentNode_<Result> = typedDocumentNodeModule.TypedDocumentNode_<Result>

	local coreModule = require(script.Parent.Parent.Parent.core)
	local ApolloClient = coreModule.ApolloClient
	local NetworkStatus = coreModule.NetworkStatus
	local observableQueryModule = require(script.Parent.Parent.ObservableQuery)
	local ObservableQuery = observableQueryModule.ObservableQuery
	local observableQueryTypesModule = require(script.Parent.Parent.ObservableQuery_types)
	type ObservableQuery_<TData> = observableQueryTypesModule.ObservableQuery_<TData>
	local queryManagerModule = require(script.Parent.Parent.QueryManager)
	local QueryManager = queryManagerModule.QueryManager
	type QueryManager<TStore> = queryManagerModule.QueryManager<TStore>

	local Observable = require(script.Parent.Parent.Parent.utilities).Observable
	local apolloLinkModule = require(script.Parent.Parent.Parent.link.core)
	local ApolloLink = apolloLinkModule.ApolloLink
	type ApolloLink = apolloLinkModule.ApolloLink
	local cacheModule = require(script.Parent.Parent.Parent.cache)
	local InMemoryCache = cacheModule.InMemoryCache
	type NormalizedCacheObject = cacheModule.NormalizedCacheObject
	local ApolloError = require(script.Parent.Parent.Parent.errors).ApolloError

	local testingModule = require(script.Parent.Parent.Parent.testing)
	local itAsync = testingModule.itAsync
	local stripSymbols = testingModule.stripSymbols
	local mockSingleLink = testingModule.mockSingleLink
	local subscribeAndCount = testingModule.subscribeAndCount
	local mockQueryManager = require(script.Parent.Parent.Parent.utilities.testing.mocking.mockQueryManager).default
	local mockWatchQuery = require(script.Parent.Parent.Parent.utilities.testing.mocking.mockWatchQuery).default
	local wrap = require(script.Parent.Parent.Parent.utilities.testing.wrap).default

	local mockFetchQuery = require(script.Parent.ObservableQuery).mockFetchQuery

	describe("ObservableQuery", function()
		-- Standard data for all these tests
		local query: TypedDocumentNode_<{
			people_one: {
				name: string,
			},
		}> = gql([[

    query query($id: ID!) {
      people_one(id: $id) {
        name
      }
    }
  ]])
		local variables = { id = 1 }
		local differentVariables = { id = 2 }
		local dataOne = {
			people_one = {
				name = "Luke Skywalker",
			},
		}
		local dataTwo = {
			people_one = {
				name = "Leia Skywalker",
			},
		}

		local error_ = GraphQLError.new("is offline.", nil, nil, nil, { "people_one" })

		local function createQueryManager(ref)
			local link = ref.link
			return QueryManager.new({
				link = link,
				assumeImmutableResults = true,
				cache = InMemoryCache.new({
					addTypename = false,
				}),
			})
		end

		describe("setOptions", function()
			describe("to change pollInterval", function()
				itAsync(it)("starts polling if goes from 0 -> something", function(resolve, reject)
					local manager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = {
							data = dataOne,
						},
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataTwo,
						},
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataTwo,
						},
					})

					local observable = manager:watchQuery({
						query = query,
						variables = variables,
						notifyOnNetworkStatusChange = false,
					})

					subscribeAndCount(reject, observable, function(handleCount, result)
						if handleCount == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(dataOne)
							observable:setOptions({ query = query, pollInterval = 10 } :: FIX_ANALYZE)
						elseif handleCount == 2 then
							jestExpect(stripSymbols(result.data)).toEqual(dataTwo)
							observable:stopPolling()
							resolve()
						end
					end)
				end)

				itAsync(it)("stops polling if goes from something -> 0", function(resolve, reject)
					local manager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = {
							data = dataOne,
						},
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataTwo,
						},
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataTwo,
						},
					})

					local observable = manager:watchQuery({
						query = query,
						variables = variables,
						pollInterval = 10,
					})

					subscribeAndCount(reject, observable, function(handleCount, result)
						if handleCount == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(dataOne)
							observable:setOptions({ query = query, pollInterval = 0 } :: FIX_ANALYZE)
							setTimeout(resolve, 5)
						elseif handleCount == 2 then
							reject(Error.new("Should not get more than one result"))
						end
					end)
				end)

				itAsync(it)("can change from x>0 to y>0", function(resolve, reject)
					local manager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = {
							data = dataOne,
						},
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataTwo,
						},
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataTwo,
						},
					})

					local observable = manager:watchQuery({
						query = query,
						variables = variables,
						pollInterval = 100,
						notifyOnNetworkStatusChange = false,
					})

					subscribeAndCount(reject, observable, function(handleCount, result)
						if handleCount == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(dataOne)
							observable:setOptions({ query = query, pollInterval = 10 } :: FIX_ANALYZE)
						elseif handleCount == 2 then
							jestExpect(stripSymbols(result.data)).toEqual(dataTwo)
							observable:stopPolling()
							resolve()
						end
					end)
				end)
			end)

			itAsync(it)("does not break refetch", function(resolve, reject)
				-- This query and variables are copied from react-apollo
				local queryWithVars = gql([[

        query people($first: Int) {
          allPeople(first: $first) {
            people {
              name
            }
          }
        }
      ]])
				local data = { allPeople = { people = { { name = "Luke Skywalker" } } } }
				local variables1 = { first = 0 }

				local data2 = { allPeople = { people = { { name = "Leia Skywalker" } } } }
				local variables2 = { first = 1 }

				local queryManager = mockQueryManager(reject, {
					request = {
						query = queryWithVars,
						variables = variables1,
					},
					result = { data = data },
				}, {
					request = {
						query = queryWithVars,
						variables = variables2,
					},
					result = { data = data2 },
				})

				local observable = queryManager:watchQuery({
					query = queryWithVars,
					variables = variables1,
					notifyOnNetworkStatusChange = true,
				})

				subscribeAndCount(reject, observable, function(handleCount, result): ...any
					if handleCount == 1 then
						jestExpect(result.data).toEqual(data)
						jestExpect(result.loading).toBe(false)
						return observable:refetch(variables2 :: FIX_ANALYZE)
					elseif handleCount == 2 then
						jestExpect(result.loading).toBe(true)
						jestExpect(result.networkStatus).toBe(NetworkStatus.setVariables)
					elseif handleCount == 3 then
						jestExpect(result.loading).toBe(false)
						jestExpect(result.data).toEqual(data2)
						resolve()
					end
				end)
			end)

			itAsync(it)("rerenders when refetch is called", function(resolve, reject)
				local query = gql([[

        query people($first: Int) {
          allPeople(first: $first) {
            people {
              name
            }
          }
        }
      ]])
				local data = { allPeople = { people = { { name = "Luke Skywalker" } } } }
				local variables = { first = 0 }

				local data2 = { allPeople = { people = { { name = "Leia Skywalker" } } } }

				local queryManager = mockQueryManager(
					reject,
					{ request = {
						query = query,
						variables = variables,
					}, result = { data = data } },
					{ request = {
						query = query,
						variables = variables,
					}, result = { data = data2 } }
				)

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					notifyOnNetworkStatusChange = true,
				})

				subscribeAndCount(reject, observable, function(handleCount, result): ...any
					if handleCount == 1 then
						jestExpect(result.loading).toEqual(false)
						jestExpect(result.data).toEqual(data)
						return observable:refetch()
					elseif handleCount == 2 then
						jestExpect(result.loading).toEqual(true)
						jestExpect(result.networkStatus).toEqual(NetworkStatus.refetch)
					elseif handleCount == 3 then
						jestExpect(result.loading).toEqual(false)
						jestExpect(result.data).toEqual(data2)
						resolve()
					end
				end)
			end)

			itAsync(it)(
				"rerenders with new variables then shows correct data for previous variables",
				function(resolve, reject)
					-- This query and variables are copied from react-apollo
					local query = gql([[

        query people($first: Int) {
          allPeople(first: $first) {
            people {
              name
            }
          }
        }
      ]])
					local data = { allPeople = { people = { { name = "Luke Skywalker" } } } }
					local variables = { first = 0 }

					local data2 = { allPeople = { people = { { name = "Leia Skywalker" } } } }
					local variables2 = { first = 1 }

					local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
						request = {
							query = query,
							variables = variables,
						},
						result = { data = data },
					}, {
						request = {
							query = query,
							variables = variables2,
						},
						result = { data = data2 },
					})

					subscribeAndCount(reject, observable, function(handleCount, result)
						if handleCount == 1 then
							jestExpect(result.data).toEqual(data)
							jestExpect(result.loading).toBe(false)
							observable
								:setOptions({
									variables = variables2,
									notifyOnNetworkStatusChange = true,
								} :: FIX_ANALYZE)
								:expect()
						elseif handleCount == 2 then
							jestExpect(result.loading).toBe(true)
							jestExpect(result.networkStatus).toBe(NetworkStatus.setVariables)
						elseif handleCount == 3 then
							jestExpect(result.loading).toBe(false)
							jestExpect(result.data).toEqual(data2)
							-- go back to first set of variables
							local current = observable
								:reobserve({
									variables = variables,
								} :: FIX_ANALYZE)
								:expect()
							jestExpect(current.data).toEqual(data)
							resolve()
						end
					end)
				end
			)

			-- TODO: Something isn't quite right with this test. It's failing but not
			-- for the right reasons.
			itAsync(xit)(
				"if query is refetched, and an error is returned, no other observer callbacks will be called",
				function(resolve, reject)
					local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
						request = { query = query, variables = variables },
						result = {
							data = dataOne,
						},
					}, {
						request = { query = query, variables = variables },
						result = { errors = { error_ } :: FIX_ANALYZE },
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataOne,
						},
					})

					local handleCount = 0
					observable:subscribe({
						next = function(result)
							handleCount += 1
							if handleCount == 1 then
								jestExpect(stripSymbols(result.data)).toEqual(dataOne)
								observable:refetch()
							elseif handleCount == 3 then
								error(Error.new("next shouldn't fire after an error"))
							end
						end,
						error = function()
							handleCount += 1
							jestExpect(handleCount).toBe(2)
							observable:refetch()
							setTimeout(resolve, 25)
						end,
					})
				end
			)

			itAsync(it)("does a network request if fetchPolicy becomes networkOnly", function(resolve, reject)
				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = {
						data = dataOne,
					},
				}, {
					request = { query = query, variables = variables },
					result = {
						data = dataTwo,
					},
				})

				subscribeAndCount(reject, observable, function(handleCount, result): ...any
					if handleCount == 1 then
						jestExpect(result.loading).toBe(false)
						jestExpect(result.data).toEqual(dataOne)
						return observable:setOptions({ fetchPolicy = "network-only" } :: FIX_ANALYZE)
					elseif handleCount == 2 then
						jestExpect(result.loading).toBe(false)
						jestExpect(result.data).toEqual(dataTwo)
						resolve()
					end
				end)
			end)

			itAsync(it)(
				"does a network request if fetchPolicy is cache-only then store is reset then fetchPolicy becomes not cache-only",
				function(resolve, reject)
					local testQuery = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])
					local data = {
						author = {
							firstName = "John",
							lastName = "Smith",
						},
					}

					local timesFired = 0
					local link: ApolloLink = ApolloLink.from({
						function()
							return Observable.new(function(observer)
								timesFired += 1
								observer:next({ data = data })
								observer:complete()
							end)
						end,
					})

					local queryManager = createQueryManager({ link = link })
					-- fetch first data from server
					local observable = queryManager:watchQuery({
						query = testQuery,
					})

					subscribeAndCount(reject, observable, function(handleCount, result)
						if handleCount == 1 then
							jestExpect(result.data).toEqual(data)
							jestExpect(timesFired).toBe(1)
							-- set policy to be cache-only but data is found
							observable
								:setOptions({
									fetchPolicy = "cache-only",
								} :: FIX_ANALYZE)
								:expect()
							queryManager:resetStore():expect()
						elseif handleCount == 2 then
							jestExpect(result.data).toEqual({})
							jestExpect(result.loading).toBe(false)
							jestExpect(result.networkStatus).toBe(NetworkStatus.ready)
							jestExpect(timesFired).toBe(1)
							resolve()
						end
					end)
				end
			)

			itAsync(it)("does a network request if fetchPolicy changes from cache-only", function(resolve, reject)
				local testQuery = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])
				local data = {
					author = {
						firstName = "John",
						lastName = "Smith",
					},
				}

				local timesFired = 0
				local link: ApolloLink = ApolloLink.from({
					function()
						return Observable.new(function(observer)
							timesFired += 1
							observer:next({ data = data })
							observer:complete()
						end)
					end,
				})

				local queryManager = createQueryManager({ link = link })

				local observable = queryManager:watchQuery({
					query = testQuery,
					fetchPolicy = "cache-only",
					notifyOnNetworkStatusChange = false,
				})

				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(result.loading).toBe(false)
						jestExpect(result.data).toEqual({})
						jestExpect(timesFired).toBe(0)
						observable:setOptions({ fetchPolicy = "cache-first" } :: FIX_ANALYZE)
					elseif handleCount == 2 then
						jestExpect(result.loading).toBe(false)
						jestExpect(result.data).toEqual(data)
						jestExpect(timesFired).toBe(1)
						resolve()
					end
				end)
			end)

			itAsync(it)("can set queries to standby and will not fetch when doing so", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local observable: ObservableQuery_<any>
				local testQuery = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])
				local data = {
					author = {
						firstName = "John",
						lastName = "Smith",
					},
				}

				local timesFired = 0
				local link: ApolloLink = ApolloLink.from({
					function()
						return Observable.new(function(observer)
							timesFired += 1
							observer:next({ data = data })
							observer:complete()
							return
						end)
					end,
				})
				queryManager = createQueryManager({ link = link })
				observable = queryManager:watchQuery({
					query = testQuery,
					fetchPolicy = "cache-first",
					notifyOnNetworkStatusChange = false,
				})

				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(stripSymbols(result.data)).toEqual(data)
						jestExpect(timesFired).toBe(1)
						observable
							:setOptions({
								query = query,
								fetchPolicy = "standby",
							} :: FIX_ANALYZE)
							:expect()
						-- make sure the query didn't get fired again.
						jestExpect(timesFired).toBe(1)
						resolve()
					elseif handleCount == 2 then
						error(Error.new("Handle should not be triggered on standby query"))
					end
				end)
			end)

			itAsync(it)("will not fetch when setting a cache-only query to standby", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local observable: ObservableQuery_<any>
				local testQuery = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])
				local data = {
					author = {
						firstName = "John",
						lastName = "Smith",
					},
				}

				local timesFired = 0
				local link: ApolloLink = ApolloLink.from({
					function()
						return Observable.new(function(observer)
							timesFired += 1
							observer:next({ data = data })
							observer:complete()
							return
						end)
					end,
				})
				queryManager = createQueryManager({ link = link })

				queryManager:query({ query = testQuery }):andThen(function()
					observable = queryManager:watchQuery({
						query = testQuery,
						fetchPolicy = "cache-first",
						notifyOnNetworkStatusChange = false,
					})

					subscribeAndCount(reject, observable, function(handleCount, result)
						if handleCount == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(data)
							jestExpect(timesFired).toBe(1)
							observable
								:setOptions({
									query = query,
									fetchPolicy = "standby",
								} :: FIX_ANALYZE)
								:expect()
							-- make sure the query didn't get fired again.
							jestExpect(timesFired).toBe(1)
							resolve()
						elseif handleCount == 2 then
							error(Error.new("Handle should not be triggered on standby query"))
						end
					end)
				end)
			end)

			itAsync(it)("returns a promise which eventually returns data", function(resolve, reject)
				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne },
				}, {
					request = { query = query, variables = variables },
					result = { data = dataTwo },
				})

				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(result.data).toEqual(dataOne)
						observable
							:setOptions({ fetchPolicy = "cache-and-network" } :: FIX_ANALYZE)
							:andThen(function(res)
								jestExpect(res.data).toEqual(dataTwo)
							end)
							:andThen(resolve, reject)
					end
				end)
			end)
		end)

		describe("setVariables", function()
			itAsync(it)("reruns query if the variables change", function(resolve, reject)
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne },
				}, {
					request = { query = query, variables = differentVariables },
					result = { data = dataTwo },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					notifyOnNetworkStatusChange = true,
				})

				subscribeAndCount(reject, observable, function(handleCount, result): ...any
					if handleCount == 1 then
						jestExpect(result.loading).toBe(false)
						jestExpect(stripSymbols(result.data)).toEqual(dataOne)
						return observable:setVariables(differentVariables)
					elseif handleCount == 2 then
						jestExpect(result.loading).toBe(true)
						jestExpect(result.networkStatus).toBe(NetworkStatus.setVariables)
					elseif handleCount == 3 then
						jestExpect(result.loading).toBe(false)
						jestExpect(stripSymbols(result.data)).toEqual(dataTwo)
						resolve()
					end
				end)
			end)

			itAsync(it)("does invalidate the currentResult data if the variables change", function(resolve, reject)
				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = {
						data = dataOne,
					},
				}, {
					request = { query = query, variables = differentVariables },
					result = { data = dataTwo },
					delay = 25,
				})
				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(stripSymbols(result.data)).toEqual(dataOne)
						jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(dataOne)
						observable:setVariables(differentVariables):expect()
					end
					jestExpect(observable:getCurrentResult().data).toEqual(dataTwo)
					jestExpect(observable:getCurrentResult().loading).toBe(false)
					resolve()
				end)
			end)

			itAsync(it)("does invalidate the currentResult data if the variables change_", function(resolve, reject)
				-- Standard data for all these tests
				local query = gql([[

        query UsersQuery($page: Int) {
          users {
            id
            name
            posts(page: $page) {
              title
            }
          }
        }
      ]])
				local variables = { page = 1 }
				local differentVariables = { page = 2 }
				local dataOne = {
					users = {
						{
							id = 1,
							name = "James",
							posts = { { title = "GraphQL Summit" }, { title = "Awesome" } },
						},
					},
				}
				local dataTwo = {
					users = {
						{
							id = 1,
							name = "James",
							posts = { { title = "Old post" } },
						},
					},
				}

				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = {
						data = dataOne,
					},
				}, {
					request = { query = query, variables = differentVariables },
					result = { data = dataTwo },
					delay = 25,
				})

				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(stripSymbols(result.data)).toEqual(dataOne)
						jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(dataOne)
						observable:setVariables(differentVariables):expect()
					end
					jestExpect(observable:getCurrentResult().data).toEqual(dataTwo)
					jestExpect(observable:getCurrentResult().loading).toBe(false)
					resolve()
				end)
			end)

			itAsync(it)(
				"does not invalidate the currentResult errors if the variables change",
				function(resolve, reject)
					local queryManager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = { errors = { error_ } :: FIX_ANALYZE },
					}, {
						request = { query = query, variables = differentVariables },
						result = { data = dataTwo },
					})

					local observable = queryManager:watchQuery({
						query = query,
						variables = variables,
						errorPolicy = "all",
					})

					subscribeAndCount(reject, observable, function(handleCount, result)
						if handleCount == 1 then
							jestExpect(result.errors).toEqual({ error_ })
							jestExpect(observable:getCurrentResult().errors).toEqual({ error_ })
							observable:setVariables(differentVariables)
							jestExpect(observable:getCurrentResult().errors).toEqual({ error_ })
						elseif handleCount == 2 then
							jestExpect(stripSymbols(result.data)).toEqual(dataTwo)
							jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(dataTwo)
							jestExpect(observable:getCurrentResult().loading).toBe(false)
							resolve()
						end
					end)
				end
			)

			itAsync(it)("does not perform a query when unsubscribed if variables change", function(resolve, reject)
				-- Note: no responses, will throw if a query is made
				local queryManager = mockQueryManager(reject)
				local observable = queryManager:watchQuery({ query = query, variables = variables })
				observable:setVariables(differentVariables :: FIX_ANALYZE):andThen(resolve, reject)
			end)

			itAsync(it)("sets networkStatus to `setVariables` when fetching", function(resolve, reject)
				local mockedResponses = {
					{
						request = { query = query, variables = variables },
						result = { data = dataOne },
					},
					{
						request = { query = query, variables = differentVariables },
						result = { data = dataTwo },
					},
				}

				local queryManager = mockQueryManager(reject, table.unpack(mockedResponses))
				local firstRequest = mockedResponses[1].request
				local observable = queryManager:watchQuery({
					query = firstRequest.query,
					variables = firstRequest.variables,
					notifyOnNetworkStatusChange = true,
				})

				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(result.loading).toBe(false)
						jestExpect(stripSymbols(result.data)).toEqual(dataOne)
						jestExpect(result.networkStatus).toBe(NetworkStatus.ready)
						observable:setVariables(differentVariables)
					elseif handleCount == 2 then
						jestExpect(result.loading).toBe(true)
						jestExpect(result.networkStatus).toBe(NetworkStatus.setVariables)
					elseif handleCount == 3 then
						jestExpect(result.loading).toBe(false)
						jestExpect(result.networkStatus).toBe(NetworkStatus.ready)
						jestExpect(stripSymbols(result.data)).toEqual(dataTwo)
						resolve()
					end
				end)
			end)

			itAsync(it)(
				"sets networkStatus to `setVariables` when calling refetch with new variables",
				function(resolve, reject)
					local mockedResponses = {
						{
							request = { query = query, variables = variables },
							result = {
								data = dataOne,
							},
						},
						{
							request = { query = query, variables = differentVariables },
							result = { data = dataTwo },
						},
					}

					local queryManager = mockQueryManager(reject, table.unpack(mockedResponses))
					local firstRequest = mockedResponses[1].request
					local observable = queryManager:watchQuery({
						query = firstRequest.query,
						variables = firstRequest.variables,
						notifyOnNetworkStatusChange = true,
					})

					subscribeAndCount(reject, observable, function(handleCount, result)
						if handleCount == 1 then
							jestExpect(result.loading).toBe(false)
							jestExpect(stripSymbols(result.data)).toEqual(dataOne)
							jestExpect(result.networkStatus).toBe(NetworkStatus.ready)
							observable:refetch(differentVariables :: FIX_ANALYZE)
						elseif handleCount == 2 then
							jestExpect(result.loading).toBe(true)
							jestExpect(result.networkStatus).toBe(NetworkStatus.setVariables)
						elseif handleCount == 3 then
							jestExpect(result.loading).toBe(false)
							jestExpect(result.networkStatus).toBe(NetworkStatus.ready)
							jestExpect(stripSymbols(result.data)).toEqual(dataTwo)
							resolve()
						end
					end)
				end
			)

			itAsync(it)("does not rerun query if variables do not change", function(resolve, reject)
				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne },
				}, {
					request = { query = query, variables = variables },
					result = { data = dataTwo },
				})

				local errored = false
				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(stripSymbols(result.data)).toEqual(dataOne)
						observable:setVariables(variables)

						-- Nothing should happen, so we'll wait a moment to check that
						setTimeout(function()
							if Boolean.toJSBoolean(not Boolean.toJSBoolean(errored)) then
								return resolve()
							else
								return not Boolean.toJSBoolean(errored)
							end
						end, 10)
					elseif handleCount == 2 then
						errored = true
						error(Error.new("Observable callback should not fire twice"))
					end
				end)
			end)

			itAsync(it)("handles variables changing while a query is in-flight", function(resolve, reject)
				-- The expected behavior is that the original variables are forgotten
				-- and the query stays in loading state until the result for the new variables
				-- has returned.
				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne },
					delay = 20,
				}, {
					request = { query = query, variables = differentVariables },
					result = { data = dataTwo },
					delay = 20,
				})

				observable:setVariables(differentVariables)

				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(result.networkStatus).toBe(NetworkStatus.ready)
						jestExpect(result.loading).toBe(false)
						jestExpect(stripSymbols(result.data)).toEqual(dataTwo)
						resolve()
					else
						reject(Error.new("should not deliver more than one result"))
					end
				end)
			end)
		end)

		describe("refetch", function()
			itAsync(it)(
				"calls fetchRequest with fetchPolicy `network-only` when using a non-networked fetch policy",
				function(resolve, reject)
					local mockedResponses = {
						{
							request = { query = query, variables = variables },
							result = {
								data = dataOne,
							},
						},
						{
							request = { query = query, variables = differentVariables },
							result = { data = dataTwo },
						},
					}

					local queryManager = mockQueryManager(reject, table.unpack(mockedResponses))
					local firstRequest = mockedResponses[1].request
					local observable = queryManager:watchQuery({
						query = firstRequest.query,
						variables = firstRequest.variables,
						fetchPolicy = "cache-first",
					})

					local mocks = mockFetchQuery(queryManager)

					subscribeAndCount(reject, observable, function(handleCount)
						if handleCount == 1 then
							observable:refetch(differentVariables :: FIX_ANALYZE)
						elseif handleCount == 2 then
							local fqbpCalls = mocks.fetchQueryByPolicy.mock.calls
							jestExpect(#fqbpCalls).toBe(2)
							-- ROBLOX deviation checking 3rd argument to account for self param
							jestExpect(fqbpCalls[2][3].fetchPolicy).toEqual("network-only")
							-- Although the options.fetchPolicy we passed just now to
							-- fetchQueryByPolicy should have been network-only,
							-- observable.options.fetchPolicy should now be updated to
							-- cache-first, thanks to options.nextFetchPolicy.
							jestExpect(observable.options.fetchPolicy).toBe("cache-first")
							local fqoCalls = mocks.fetchQueryObservable.mock.calls
							jestExpect(#fqoCalls).toBe(2)
							-- ROBLOX deviation checking 3rd argument to account for self param
							jestExpect(fqoCalls[2][3].fetchPolicy).toEqual("cache-first")
							resolve()
						end
					end)
				end
			)

			itAsync(it)(
				"calls fetchRequest with fetchPolicy `no-cache` when using `no-cache` fetch policy",
				function(resolve, reject)
					local mockedResponses = {
						{
							request = { query = query, variables = variables },
							result = {
								data = dataOne,
							},
						},
						{
							request = { query = query, variables = differentVariables },
							result = { data = dataTwo },
						},
					}

					local queryManager = mockQueryManager(reject, table.unpack(mockedResponses))
					local firstRequest = mockedResponses[1].request
					local observable = queryManager:watchQuery({
						query = firstRequest.query,
						variables = firstRequest.variables,
						fetchPolicy = "no-cache",
					})

					local mocks = mockFetchQuery(queryManager)

					subscribeAndCount(reject, observable, function(handleCount)
						if handleCount == 1 then
							observable:refetch(differentVariables :: FIX_ANALYZE)
						elseif handleCount == 2 then
							local fqbpCalls = mocks.fetchQueryByPolicy.mock.calls
							jestExpect(#fqbpCalls).toBe(2)
							-- ROBLOX deviation checking 3rd argument to account for self param
							jestExpect(fqbpCalls[2][3].fetchPolicy).toBe("no-cache")
							jestExpect(observable.options.fetchPolicy).toBe("no-cache")

							-- Unlike network-only or cache-and-network, the no-cache
							-- FetchPolicy does not switch to cache-first after the first
							-- network request.
							local fqoCalls = mocks.fetchQueryObservable.mock.calls
							jestExpect(#fqoCalls).toBe(2)
							-- ROBLOX deviation checking 3rd argument to account for self param
							jestExpect(fqoCalls[2][3].fetchPolicy).toBe("no-cache")

							resolve()
						end
					end)
				end
			)

			itAsync(it)("calls ObservableQuery.next even after hitting cache", function(resolve, reject)
				-- This query and variables are copied from react-apollo
				local queryWithVars = gql([[

        query people($first: Int) {
          allPeople(first: $first) {
            people {
              name
            }
          }
        }
      ]])

				local data = { allPeople = { people = { { name = "Luke Skywalker" } } } }
				local variables1 = { first = 0 }

				local data2 = { allPeople = { people = { { name = "Leia Skywalker" } } } }
				local variables2 = { first = 1 }

				local queryManager = mockQueryManager(reject, {
					request = { query = queryWithVars, variables = variables1 },
					result = { data = data },
				}, {
					request = { query = queryWithVars, variables = variables2 },
					result = { data = data2 },
				}, {
					request = { query = queryWithVars, variables = variables1 },
					result = { data = data },
				})

				local observable = queryManager:watchQuery({
					query = queryWithVars,
					variables = variables1,
					fetchPolicy = "cache-and-network",
					notifyOnNetworkStatusChange = true,
				})

				subscribeAndCount(reject, observable, function(handleCount, result)
					if handleCount == 1 then
						jestExpect(result.data).toEqual(data)
						jestExpect(result.loading).toBe(false)
						observable:refetch(variables2 :: FIX_ANALYZE)
					elseif handleCount == 2 then
						jestExpect(result.loading).toBe(true)
						jestExpect(result.networkStatus).toBe(NetworkStatus.setVariables)
					elseif handleCount == 3 then
						jestExpect(result.data).toEqual(data2)
						jestExpect(result.loading).toBe(false)
						observable:refetch(variables1 :: FIX_ANALYZE)
					elseif handleCount == 4 then
						jestExpect(result.loading).toBe(true)
						jestExpect(result.networkStatus).toBe(NetworkStatus.setVariables)
					elseif handleCount == 5 then
						jestExpect(result.data).toEqual(data)
						jestExpect(result.loading).toBe(false)
						resolve()
					end
				end)
			end)

			itAsync(itFIXME)(
				"cache-and-network refetch should run @client(always: true) resolvers when network request fails",
				function(resolve, reject)
					local query = gql([[

        query MixedQuery {
          counter @client(always: true)
          name
        }
      ]])

					local count = 0

					local linkObservable = Observable.of({ data = { name = "Ben" } })

					local intentionalNetworkFailure = ApolloError.new({
						networkError = Error.new("intentional network failure"),
					})

					local errorObservable: typeof(linkObservable) = Observable.new(function(observer)
						observer:error(intentionalNetworkFailure)
					end)

					local client = ApolloClient.new({
						link = ApolloLink.new(function(request)
							return linkObservable
						end),
						cache = InMemoryCache.new(),
						resolvers = {
							Query = {
								counter = function(self)
									count += 1
									return count
								end,
							},
						},
					})

					local observable = client:watchQuery({
						query = query,
						fetchPolicy = "cache-and-network",
						returnPartialData = true,
					})

					local handleCount = 0
					observable:subscribe({
						error = function(_self, error_)
							jestExpect(error_).toBe(intentionalNetworkFailure)
						end,
						next = function(_self, result)
							handleCount += 1

							if handleCount == 1 then
								jestExpect(result).toEqual({
									data = {
										counter = 1,
									},
									loading = true,
									networkStatus = NetworkStatus.loading,
									partial = true,
								})
							elseif handleCount == 2 then
								jestExpect(result).toEqual({
									data = {
										counter = 2,
										name = "Ben",
									},
									loading = false,
									networkStatus = NetworkStatus.ready,
								})

								local oldLinkObs = linkObservable
								-- Make the next network request fail.
								linkObservable = errorObservable

								observable:refetch():andThen(function()
									reject(Error.new("should have gotten an error"))
								end, function(error_)
									jestExpect(error_).toBe(intentionalNetworkFailure)

									-- Switch back from errorObservable.
									linkObservable = oldLinkObs

									observable:refetch():andThen(function(result)
										jestExpect(result).toEqual({
											data = {
												counter = 5,
												name = "Ben",
											},
											loading = false,
											networkStatus = NetworkStatus.ready,
										})
										setTimeout(resolve, 50)
									end, reject)
								end)
							elseif handleCount == 3 then
								jestExpect(result).toEqual({
									data = {
										counter = 3,
										name = "Ben",
									},
									loading = true,
									networkStatus = NetworkStatus.refetch,
								})
							elseif handleCount > 3 then
								reject(Error.new("should not get here"))
							end
						end,
					})
				end
			)
		end)

		describe("currentResult", function()
			-- ROBLOX TODO: doesn't support fragments yet
			itAsync(itFIXME)("returns the same value as observableQuery.next got", function(resolve, reject)
				local queryWithFragment = gql([[

        fragment CatInfo on Cat {
          isTabby
          __typename
        }

        fragment DogInfo on Dog {
          hasBrindleCoat
          __typename
        }

        fragment PetInfo on Pet {
          id
          name
          age
          ... on Cat {
            ...CatInfo
            __typename
          }
          ... on Dog {
            ...DogInfo
            __typename
          }
          __typename
        }

        {
          pets {
            ...PetInfo
            __typename
          }
        }
      ]])

				local petData = {
					{
						id = 1,
						name = "Phoenix",
						age = 6,
						isTabby = true,
						__typename = "Cat",
					} :: FIX_ANALYZE,
					{
						id = 2,
						name = "Tempe",
						age = 3,
						isTabby = false,
						__typename = "Cat",
					},
					{
						id = 3,
						name = "Robin",
						age = 10,
						hasBrindleCoat = true,
						__typename = "Dog",
					},
				}

				local dataOneWithTypename = {
					pets = Array.slice(petData, 1, 3),
				}
				local dataTwoWithTypename = {
					pets = Array.slice(petData, 1, 4),
				}

				local ni = mockSingleLink({
					request = { query = queryWithFragment, variables = variables },
					result = { data = dataOneWithTypename },
				}, {
					request = { query = queryWithFragment, variables = variables },
					result = { data = dataTwoWithTypename },
				}):setOnError(reject)

				local client = ApolloClient.new({
					link = ni,
					cache = InMemoryCache.new({
						possibleTypes = {
							Creature = { "Pet" },
							Pet = { "Dog", "Cat" },
						},
					}),
				})

				local observable = client:watchQuery({
					query = queryWithFragment,
					variables = variables,
					notifyOnNetworkStatusChange = true,
				})

				subscribeAndCount(reject, observable, function(count, result)
					local ref = observable:getCurrentResult()
					local data, loading, networkStatus = ref.data, ref.loading, ref.networkStatus
					jestExpect(result.loading).toEqual(loading)
					jestExpect(result.networkStatus).toEqual(networkStatus)
					jestExpect(result.data).toEqual(data)

					if count == 1 then
						jestExpect(result.loading).toBe(false)
						jestExpect(result.networkStatus).toEqual(NetworkStatus.ready)
						jestExpect(result.data).toEqual(dataOneWithTypename)
						observable:refetch()
					elseif count == 2 then
						jestExpect(result.loading).toBe(true)
						jestExpect(result.networkStatus).toEqual(NetworkStatus.refetch)
					elseif count == 3 then
						jestExpect(result.loading).toBe(false)
						jestExpect(result.networkStatus).toEqual(NetworkStatus.ready)
						jestExpect(result.data).toEqual(dataTwoWithTypename)
						setTimeout(resolve, 5)
					else
						reject(Error.new("Observable.next called too many times"))
					end
				end)
			end)

			itAsync(it)("returns the current query status immediately", function(resolve, reject)
				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne },
					delay = 100,
				})

				subscribeAndCount(reject, observable, function()
					jestExpect(stripSymbols(observable:getCurrentResult())).toEqual({
						data = dataOne,
						loading = false,
						networkStatus = 7,
					})
					resolve()
				end)

				jestExpect(observable:getCurrentResult()).toEqual({
					loading = true,
					data = nil,
					networkStatus = 1,
					partial = true,
				})

				setTimeout(
					wrap(reject, function()
						jestExpect(observable:getCurrentResult()).toEqual({
							loading = true,
							data = nil,
							networkStatus = 1,
							partial = true,
						})
					end),
					0
				)
			end)

			itAsync(it)("returns results from the store immediately", function(resolve, reject)
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne },
				})

				return queryManager
					:query({ query = query, variables = variables })
					:andThen(function(result: any)
						jestExpect(stripSymbols(result)).toEqual({
							data = dataOne,
							loading = false,
							networkStatus = 7,
						})
						local observable = queryManager:watchQuery({
							query = query,
							variables = variables,
						})
						jestExpect(stripSymbols(observable:getCurrentResult())).toEqual({
							data = dataOne,
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
					end)
					:andThen(resolve, reject)
			end)

			itAsync(it)("returns errors from the store immediately", function(resolve, reject)
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { errors = { error_ } :: FIX_ANALYZE },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
				})

				observable:subscribe({
					error = function(_self, theError)
						jestExpect(theError.graphQLErrors).toEqual({ error_ })

						local currentResult = observable:getCurrentResult()
						jestExpect(currentResult.loading).toBe(false)
						jestExpect((currentResult.error :: any).graphQLErrors).toEqual({ error_ })
						resolve()
					end,
				})
			end)

			itAsync(it)("returns referentially equal errors", function(resolve, reject)
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { errors = { error_ } :: FIX_ANALYZE },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
				})

				return observable
					:result()
					:catch(function(theError: any)
						jestExpect(theError.graphQLErrors).toEqual({ error_ })

						local currentResult = observable:getCurrentResult()
						jestExpect(currentResult.loading).toBe(false)
						jestExpect((currentResult.error :: any).graphQLErrors).toEqual({ error_ })
						local currentResult2 = observable:getCurrentResult()
						jestExpect(currentResult.error == currentResult2.error).toBe(true)
					end)
					:andThen(resolve, reject)
			end)

			itAsync(it)("returns errors with data if errorPolicy is all", function(resolve, reject)
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne, errors = { error_ } :: FIX_ANALYZE },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					errorPolicy = "all",
				})

				return observable
					:result()
					:andThen(function(result)
						jestExpect(stripSymbols(result.data)).toEqual(dataOne)
						jestExpect(result.errors).toEqual({ error_ })
						local currentResult = observable:getCurrentResult()
						jestExpect(currentResult.loading).toBe(false)
						jestExpect(currentResult.errors).toEqual({ error_ })
						jestExpect(currentResult.error).toBeUndefined()
					end)
					:andThen(resolve, reject)
			end)

			itAsync(it)("errors out if errorPolicy is none", function(resolve, reject)
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne, errors = { error_ } :: FIX_ANALYZE },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					errorPolicy = "none",
				})

				return observable
					:result()
					:andThen(function()
						return reject("Observable did not error when it should have")
					end)
					:catch(function(currentError)
						-- ROBLOX deviation: while debugging the upstream tests the resulting currentError and error_ are the same and the test matcher seem to only compare the message
						jestExpect(currentError.message).toEqual(error_.message)
						local lastError = observable:getLastError() :: any
						-- ROBLOX deviation: while debugging the upstream tests the resulting currentError and error_ are the same and the test matcher seem to only compare the message
						jestExpect(lastError.message).toEqual(error_.message)
						resolve()
					end)
					:catch(reject)
			end)

			itAsync(it)("errors out if errorPolicy is none and the observable has completed", function(resolve, reject)
				local queryManager = mockQueryManager(
					reject,
					{
						request = { query = query, variables = variables },
						result = { data = dataOne, errors = { error_ } :: FIX_ANALYZE },
					},
					-- FIXME: We shouldn't need a second mock, there should only be one network request
					{
						request = { query = query, variables = variables },
						result = { data = dataOne, errors = { error_ } :: FIX_ANALYZE },
					}
				)

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					errorPolicy = "none",
				})

				return observable
					:result()
					:andThen(function()
						return reject("Observable did not error when it should have")
					end) -- We wait for the observable to error out and reobtain a promise
					:catch(function()
						return observable:result() :: FIX_ANALYZE
					end)
					:andThen(function(result)
						return reject("Observable did not error the second time we fetched results when it should have")
					end)
					:catch(function(currentError)
						-- ROBLOX deviation: while debugging the upstream tests the resulting currentError and error_ are the same and the test matcher seem to only compare the message
						jestExpect(currentError.message).toEqual(error_.message)
						local lastError = observable:getLastError() :: any
						-- ROBLOX deviation: while debugging the upstream tests the resulting currentError and error_ are the same and the test matcher seem to only compare the message
						jestExpect(lastError.message).toEqual(error_.message)
						resolve()
					end)
					:catch(reject)
			end)

			itAsync(it)("ignores errors with data if errorPolicy is ignore", function(resolve, reject)
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { errors = { error_ } :: FIX_ANALYZE, data = dataOne },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					errorPolicy = "ignore",
				})

				return observable
					:result()
					:andThen(function(result)
						jestExpect(stripSymbols(result.data)).toEqual(dataOne)
						jestExpect(result.errors).toBeUndefined()
						local currentResult = observable:getCurrentResult()
						jestExpect(currentResult.loading).toBe(false)
						jestExpect(currentResult.errors).toBeUndefined()
						jestExpect(currentResult.error).toBeUndefined()
					end)
					:andThen(resolve, reject)
			end)

			--[[
				ROBLOX FIXME:
				the test is passing intermittently
				it seems to fail due to the setTimeout and Promise resolution order not being deterministic 
			]]
			itAsync(itFIXME)("returns partial data from the store immediately", function(resolve, reject)
				local superQuery = gql([[

        query superQuery($id: ID!) {
          people_one(id: $id) {
            name
            age
          }
        }
      ]])

				local superDataOne = { people_one = {
					name = "Luke Skywalker",
					age = 21,
				} }

				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne },
				}, {
					request = { query = superQuery, variables = variables },
					result = { data = superDataOne },
				})

				queryManager:query({ query = query, variables = variables }):andThen(function(result)
					local observable = queryManager:watchQuery({
						query = superQuery,
						variables = variables,
						returnPartialData = true,
					})

					jestExpect(observable:getCurrentResult()).toEqual({
						data = dataOne,
						loading = true,
						networkStatus = 1,
						partial = true,
					})

					-- we can use this to trigger the query
					subscribeAndCount(reject, observable, function(handleCount, subResult)
						local ref = observable:getCurrentResult()
						local data, loading, networkStatus = ref.data, ref.loading, ref.networkStatus

						jestExpect(subResult.data).toEqual(data)
						jestExpect(subResult.loading).toEqual(loading)
						jestExpect(subResult.networkStatus).toEqual(networkStatus)

						if handleCount == 1 then
							jestExpect(subResult).toEqual({
								data = dataOne,
								loading = true,
								networkStatus = 1,
								partial = true,
							})
						elseif handleCount == 2 then
							jestExpect(subResult).toEqual({
								data = superDataOne,
								loading = false,
								networkStatus = 7,
							})
							resolve()
						end
					end)
				end)
			end)

			itAsync(it)(
				"returns loading even if full data is available when using network-only fetchPolicy",
				function(resolve, reject)
					local queryManager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = {
							data = dataOne,
						},
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataTwo,
						},
					})

					queryManager:query({ query = query, variables = variables }):andThen(function(result)
						jestExpect(result).toEqual({
							data = dataOne,
							loading = false,
							networkStatus = NetworkStatus.ready,
						})

						local observable = queryManager:watchQuery({
							query = query,
							variables = variables,
							fetchPolicy = "network-only",
						})

						jestExpect(observable:getCurrentResult()).toEqual({
							data = dataOne,
							loading = true,
							networkStatus = NetworkStatus.loading,
						})

						subscribeAndCount(reject, observable, function(handleCount, subResult)
							if handleCount == 1 then
								jestExpect(subResult).toEqual({
									loading = true,
									data = dataOne,
									networkStatus = NetworkStatus.loading,
								})
							elseif handleCount == 2 then
								jestExpect(subResult).toEqual({
									data = dataTwo,
									loading = false,
									networkStatus = NetworkStatus.ready,
								})
								resolve()
							end
						end)
					end)
				end
			)

			-- ROBLOX FIXME: this test seem to fail due to the setTimeout and Promise resolution order not being deterministic
			itAsync(itFIXME)(
				"returns loading on no-cache fetchPolicy queries when calling getCurrentResult",
				function(resolve, reject)
					local queryManager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = {
							data = dataOne,
						},
					}, {
						request = { query = query, variables = variables },
						result = {
							data = dataTwo,
						},
					})

					queryManager:query({ query = query, variables = variables }):andThen(function()
						local observable = queryManager:watchQuery({
							query = query,
							variables = variables,
							fetchPolicy = "no-cache",
						})
						jestExpect(stripSymbols(observable:getCurrentResult())).toEqual({
							data = nil,
							loading = true,
							networkStatus = 1,
						})

						subscribeAndCount(reject, observable, function(handleCount, subResult)
							local ref = observable:getCurrentResult()
							local data, loading, networkStatus = ref.data, ref.loading, ref.networkStatus

							if handleCount == 1 then
								jestExpect(subResult).toEqual({
									data = data,
									loading = loading,
									networkStatus = networkStatus,
								})
							elseif handleCount == 2 then
								jestExpect(stripSymbols(subResult)).toEqual({
									data = dataTwo,
									loading = false,
									networkStatus = 7,
								})
								resolve()
							end
						end)
					end)
				end
			)

			describe("mutations", function()
				local mutation = gql([[

        mutation setName {
          name
        }
      ]])

				local mutationData = {
					name = "Leia Skywalker",
				}

				local optimisticResponse = {
					name = "Leia Skywalker (optimistic)",
				}

				local updateQueries = {
					query = function(_self, _: any, ref)
						local mutationResult = ref.mutationResult
						return { people_one = { name = mutationResult.data.name } }
					end,
				}

				--[[
					ROBLOX FIXME:
					the test is passing intermittently
					it seems to fail due to the setTimeout and Promise resolution order not being deterministic 
				]]
				itAsync(itFIXME)("returns optimistic mutation results from the store", function(resolve, reject)
					local queryManager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = {
							data = dataOne,
						},
					}, {
						request = { query = mutation },
						result = { data = mutationData },
					})

					local observable = queryManager:watchQuery({
						query = query,
						variables = variables,
					})

					subscribeAndCount(reject, observable, function(count, result)
						local ref = observable:getCurrentResult()
						local data, loading, networkStatus = ref.data, ref.loading, ref.networkStatus
						jestExpect(result).toEqual({
							data = data,
							loading = loading,
							networkStatus = networkStatus,
						})

						if count == 1 then
							jestExpect(stripSymbols(result)).toEqual({
								data = dataOne,
								loading = false,
								networkStatus = 7,
							})
							queryManager:mutate({
								mutation = mutation,
								optimisticResponse = optimisticResponse,
								updateQueries = updateQueries,
							})
						elseif count == 2 then
							jestExpect(stripSymbols(result.data.people_one)).toEqual(optimisticResponse)
						elseif count == 3 then
							jestExpect(stripSymbols(result.data.people_one)).toEqual(mutationData)
							resolve()
						end
					end)
				end)
			end)
		end)

		describe("assumeImmutableResults", function()
			itAsync(itFIXME)("should prevent costly (but safe) cloneDeep calls", function(resolve, reject)
				local queryOptions = {
					query = gql([[

          query {
            value
          }
        ]]),
					pollInterval = 20,
				}

				local function check(ref)
					local assumeImmutableResults, assertFrozenResults =
						(function()
							if ref.assumeImmutableResults == nil then
								return true
							else
								return ref.assumeImmutableResults
							end
						end)(), (function()
							if ref.assertFrozenResults == nil then
								return false
							else
								return ref.assertFrozenResults
							end
						end)()
					local cache = InMemoryCache.new()
					local client = ApolloClient.new({
						link = mockSingleLink(
							{ request = queryOptions, result = { data = { value = 1 } } },
							{ request = queryOptions, result = { data = { value = 2 } } },
							{ request = queryOptions, result = { data = { value = 3 } } }
						):setOnError(function(error_)
							error(error_)
						end),
						assumeImmutableResults = assumeImmutableResults,
						cache = cache,
					})
					local observable = client:watchQuery(queryOptions)
					local values: Array<any> = {}
					return Promise.new(function(resolve, reject)
						observable:subscribe({
							next = function(_self, ref)
								local data = ref.data
								table.insert(values, data.value)
								if Boolean.toJSBoolean(assertFrozenResults) then
									xpcall(function()
										data.value = "oyez"
									end, function(error_)
										reject(error_)
									end)
								else
									data = Object.assign({}, data, { value = "oyez" })
								end
								client:writeQuery({ query = queryOptions.query, data = data })
							end,
							error = function(_self, err)
								jestExpect(err.message).toMatch("No more mocked responses")
								resolve(values)
							end,
						})
					end)
				end

				local function checkThrows(assumeImmutableResults: boolean)
					return Promise.new(function(resolve_)
						local ok, error_ = pcall(function()
							check({
								assumeImmutableResults = assumeImmutableResults,
								-- No matter what value we provide for assumeImmutableResults, if we
								-- tell the InMemoryCache to deep-freeze its results, destructive
								-- modifications of the result objects will become fatal. Once you
								-- start enforcing immutability in this way, you might as well pass
								-- assumeImmutableResults: true, to prevent calling cloneDeep.
								assertFrozenResults = true,
							}):expect()
							error(Error.new("not reached"))
						end)

						if not ok then
							-- ROBLOX deviation: no TypeError in Luau
							jestExpect(error_).toBeInstanceOf(Error)
							jestExpect(error_.message).toMatch("Cannot assign to read only property 'value'")
						end
						resolve_()
					end)
				end
				checkThrows(true):expect()
				checkThrows(false):expect()

				resolve()
			end)
		end)

		describe("resetQueryStoreErrors", function()
			itAsync(it)("should remove any GraphQLError's stored in the query store", function(resolve, reject)
				local graphQLError = GraphQLError.new("oh no!")

				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = { errors = { graphQLError } :: FIX_ANALYZE },
				})

				observable:subscribe({
					error = function(_self)
						local ref = observable :: any
						local queryManager = ref.queryManager
						local queryInfo = queryManager["queries"]:get(observable.queryId)
						jestExpect(queryInfo.graphQLErrors).toEqual({ graphQLError })

						observable:resetQueryStoreErrors()
						jestExpect(queryInfo.graphQLErrors).toEqual({})

						resolve()
					end,
				})
			end)

			itAsync(it)("should remove network error's stored in the query store", function(resolve, reject)
				local networkError = Error.new("oh no!")

				local observable: ObservableQuery_<any> = mockWatchQuery(reject, {
					request = { query = query, variables = variables },
					result = { data = dataOne },
				})

				observable:subscribe({
					next = function(_self)
						local ref = observable :: any
						local queryManager = ref.queryManager
						local queryInfo = queryManager["queries"]:get(observable.queryId)
						queryInfo.networkError = networkError
						observable:resetQueryStoreErrors()
						jestExpect(queryInfo.networkError).toBeUndefined()
						resolve()
					end,
				})
			end)
		end)

		itAsync(it)("QueryInfo does not notify for !== but deep-equal results", function(resolve, reject)
			local queryManager = mockQueryManager(reject, {
				request = { query = query, variables = variables },
				result = { data = dataOne },
			})

			local observable = queryManager:watchQuery({
				query = query,
				variables = variables,
				-- If we let the cache return canonical results, it will be harder to
				-- write this test, because any two results that are deeply equal will
				-- also be !==, making the choice of equality test in queryInfo.setDiff
				-- less visible/important.
				canonizeResults = false,
			})

			local queryInfo = (observable :: FIX_ANALYZE)["queryInfo"]
			local cache = queryInfo["cache"]
			--[[
				ROBLOX deviation:
				using jest.fn instead of jest.spyOn until spyOn is implemented
				original code:
				local setDiffSpy = jest:spyOn(queryInfo, "setDiff")
				local notifySpy = jest:spyOn(queryInfo, "notify")
			]]
			local setDiffSpy = jest.fn()
			queryInfo.setDiff = setDiffSpy
			local notifySpy = jest.fn()
			queryInfo.notify = notifySpy

			subscribeAndCount(reject, observable, function(count, result)
				if count == 1 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = dataOne,
					})

					local invalidateCount = 0
					local onWatchUpdatedCount = 0

					cache:batch({
						optimistic = true,
						update = function(_self, cache)
							cache:modify({
								fields = {
									people_one = function(self, value, ref)
										local INVALIDATE = ref.INVALIDATE
										jestExpect(value).toEqual(dataOne.people_one)
										invalidateCount += 1
										return INVALIDATE
									end,
								},
							})
						end,
						-- Verify that the cache.modify operation did trigger a cache broadcast.
						onWatchUpdated = function(self, watch, diff)
							jestExpect(watch.watcher).toBe(queryInfo)
							jestExpect(diff).toEqual({
								complete = true,
								result = {
									people_one = {
										name = "Luke Skywalker",
									},
								},
							})
							onWatchUpdatedCount += 1
						end,
					})

					Promise.new(function(resolve)
						return setTimeout(resolve, 100)
					end)
						:andThen(function()
							jestExpect(setDiffSpy).toHaveBeenCalledTimes(1)
							jestExpect(notifySpy).never.toHaveBeenCalled()
							jestExpect(invalidateCount).toBe(1)
							jestExpect(onWatchUpdatedCount).toBe(1)
							queryManager:stop()
						end)
						:andThen(resolve, reject)
				else
					reject("too many results")
				end
			end)
		end)

		-- ROBLOX FIXME: instanceof doesn't work correctly because of getters in ObservableQuery
		itAsync(itFIXME)("ObservableQuery#map respects Symbol.species", function(resolve, reject)
			local observable = mockWatchQuery(reject, {
				request = { query = query, variables = variables },
				result = { data = dataOne },
			})
			jestExpect(instanceof(observable, Observable)).toBe(true)
			jestExpect(instanceof(observable, ObservableQuery)).toBe(true)

			local mapped = observable:map(function(result)
				jestExpect(result).toEqual({
					loading = false,
					networkStatus = NetworkStatus.ready,
					data = dataOne,
				})
				return Object.assign({}, result, {
					data = { mapped = true },
				})
			end)
			jestExpect(mapped).toBeInstanceOf(Observable)
			jestExpect(mapped).never.toBeInstanceOf(ObservableQuery)

			local sub
			sub = mapped:subscribe({
				next = function(_self, result)
					sub:unsubscribe()
					local ok, error_ = pcall(function()
						jestExpect(result).toEqual({
							loading = false,
							networkStatus = NetworkStatus.ready,
							data = { mapped = true },
						})
					end)
					if not ok then
						reject(error_)
						return
					end
					resolve()
				end,
				error = reject,
			})
		end)
	end)
end
