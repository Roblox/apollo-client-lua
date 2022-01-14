-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/core/__tests__/QueryManager/index.ts

return function()
	-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
	local TICK = 1000 / 30

	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Boolean = LuauPolyfill.Boolean
	local clearTimeout = LuauPolyfill.clearTimeout
	local console = LuauPolyfill.console
	local Error = LuauPolyfill.Error
	local Object = LuauPolyfill.Object
	local setTimeout = LuauPolyfill.setTimeout
	local Promise = require(rootWorkspace.Promise)
	local RegExp = require(rootWorkspace.LuauRegExp)
	local NULL = require(srcWorkspace.utilities).NULL
	local mapForEach = require(srcWorkspace.luaUtils.mapForEach)

	type Array<T> = LuauPolyfill.Array<T>
	type Error = LuauPolyfill.Error
	type Object = LuauPolyfill.Object
	local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
	type Promise<T> = PromiseTypeModule.Promise<T>

	-- ROBLOX FIXME: remove if better solution is found
	type FIX_ANALYZE = any

	type Partial<T> = Object
	type ReturnType<T> = any
	type Function = (...any) -> ...any

	-- ROBLOX TODO: replace when fn generic types are avaliable
	type TData_ = any
	type TVars_ = any

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest

	local HttpService = game:GetService("HttpService")

	-- externals
	-- ROBLOX comment: RXJS not ported
	-- local from = require(Packages.rxjs).from
	-- local map = require(Packages.rxjs.operators).map
	local assign = Object.assign
	local gql = require(rootWorkspace.GraphQLTag).default
	local graphqlModule = require(rootWorkspace.GraphQL)
	type DocumentNode = graphqlModule.DocumentNode
	local GraphQLError = graphqlModule.GraphQLError
	type GraphQLError = graphqlModule.GraphQLError
	local setVerbosity = require(srcWorkspace.jsutils.invariant).setVerbosity

	local ObservableModule = require(srcWorkspace.utilities.observables.Observable)
	local Observable = ObservableModule.Observable
	type Observer<T> = ObservableModule.Observer<T>
	local coreModule = require(srcWorkspace.link.core)
	local ApolloLink = coreModule.ApolloLink
	type ApolloLink = coreModule.ApolloLink
	type GraphQLRequest = coreModule.GraphQLRequest
	export type FetchResult__<TData> = coreModule.FetchResult__<TData>
	export type FetchResult___ = coreModule.FetchResult___
	local inMemoryCacheModule = require(srcWorkspace.cache.inmemory.inMemoryCache)
	local InMemoryCache = inMemoryCacheModule.InMemoryCache
	type InMemoryCacheConfig = inMemoryCacheModule.InMemoryCacheConfig
	local inmemoryTypesModule = require(srcWorkspace.cache.inmemory.types)
	type ApolloReducerConfig = inmemoryTypesModule.ApolloReducerConfig
	type NormalizedCacheObject = inmemoryTypesModule.NormalizedCacheObject

	-- mocks
	local mockQueryManager = require(srcWorkspace.utilities.testing.mocking.mockQueryManager).default
	-- ROBLOX deviation: used only by RxJS tests
	-- local mockWatchQuery = require(srcWorkspace.utilities.testing.mocking.mockWatchQuery).default
	local mockLinkModule = require(srcWorkspace.utilities.testing.mocking.mockLink)
	type MockApolloLink = mockLinkModule.MockApolloLink
	local mockSingleLink = mockLinkModule.mockSingleLink
	type MockLink = mockLinkModule.MockLink
	local typesModule = require(script.Parent.Parent.Parent.types)

	-- core
	type ApolloQueryResult<T> = typesModule.ApolloQueryResult<T>
	local NetworkStatus = require(script.Parent.Parent.Parent.networkStatus).NetworkStatus
	local observableQueryModule = require(script.Parent.Parent.Parent.ObservableQuery_types)
	type ObservableQuery_<TData> = observableQueryModule.ObservableQuery_<TData>
	type ObservableQuery<TData, TVariables> = observableQueryModule.ObservableQuery<TData, TVariables>
	local watchQueryOptionsModule = require(script.Parent.Parent.Parent.watchQueryOptions_types)
	type MutationBaseOptions_<TData, TVariables, TContext> =
		watchQueryOptionsModule.MutationBaseOptions_<TData, TVariables, TContext>
	type MutationOptions_<TData, TVariables, TContext> =
		watchQueryOptionsModule.MutationOptions_<TData, TVariables, TContext>
	type WatchQueryOptions_<TData> = watchQueryOptionsModule.WatchQueryOptions_<TData>
	type WatchQueryOptions__ = watchQueryOptionsModule.WatchQueryOptions__
	local queryManagerModule = require(script.Parent.Parent.Parent.QueryManager)
	local QueryManager = queryManagerModule.QueryManager
	type QueryManager<TStore> = queryManagerModule.QueryManager<TStore>
	-- ROBLOX deviation: inline QueryManager_getQuery as `getQuery` is a private method
	local queryInfoModule = require(script.Parent.Parent.Parent.QueryInfo)
	type QueryInfo = queryInfoModule.QueryInfo
	type QueryManager_getQuery = (queryId: string) -> QueryInfo

	local errorsModule = require(srcWorkspace.errors)
	type ApolloError = errorsModule.ApolloError

	-- testing utils
	local wrap = require(srcWorkspace.utilities.testing.wrap).default
	local observableToPromiseModule = require(srcWorkspace.utilities.testing.observableToPromise)
	local observableToPromise = observableToPromiseModule.default
	local observableToPromiseAndSubscription = observableToPromiseModule.observableToPromiseAndSubscription
	local subscribeAndCount = require(srcWorkspace.utilities.testing.subscribeAndCount).default
	local stripSymbols = require(srcWorkspace.utilities.testing.stripSymbols).stripSymbols
	local itAsync = require(srcWorkspace.utilities.testing.itAsync)
	local ApolloClient = require(srcWorkspace.core).ApolloClient
	local mockFetchQuery = require(script.Parent.Parent.ObservableQuery).mockFetchQuery

	-- ROBLOX deviation: method not available
	local function fail(e: any?)
		error(e or "fail")
	end
	local process = {
		once = function(...) end,
	}

	type MockedMutation = {
		reject: ((reason: any) -> any),
		mutation: DocumentNode,
		data: Object?,
		errors: Array<GraphQLError>?,
		variables: Object?,
		config: ApolloReducerConfig?,
	}

	describe("QueryManager", function()
		-- Standard "get id from object" method.
		local function dataIdFromObject(_self, object: any)
			if Boolean.toJSBoolean(object.__typename) and Boolean.toJSBoolean(object.id) then
				return tostring(object.__typename) .. "__" .. object.id
			end
			return nil
		end

		-- Helper method that serves as the constructor method for
		-- QueryManager but has defaults that make sense for these
		-- tests.
		local function createQueryManager(
			ref: {
				link: ApolloLink,
				config: Partial<InMemoryCacheConfig>?,
				clientAwareness: { [string]: string }?,
				queryDeduplication: boolean?,
			}
		)
			local link, config, clientAwareness, queryDeduplication =
				ref.link, ref.config, ref.clientAwareness, ref.queryDeduplication

			if ref.config == nil then
				config = {}
			end
			if ref.clientAwareness == nil then
				clientAwareness = {}
			end
			if ref.queryDeduplication == nil then
				queryDeduplication = false
			end

			return QueryManager.new({
				link = link,
				cache = InMemoryCache.new(Object.assign({}, { addTypename = false }, config)),
				clientAwareness = clientAwareness,
				queryDeduplication = queryDeduplication,
				onBroadcast = function(_self) end,
			} :: FIX_ANALYZE)
		end

		-- Helper method that sets up a mockQueryManager and then passes on the
		-- results to an observer.
		local function assertWithObserver(
			ref: {
				reject: (reason: any) -> any,
				query: DocumentNode,
				variables: Object?,
				queryOptions: Object?,
				error: Error?,
				result: FetchResult___?,
				delay: number?,
				observer: Observer<ApolloQueryResult<any>>,
			}
		)
			local reject, query, variables, queryOptions, result, error_, delay, observer =
				ref.reject, ref.query, ref.variables, ref.queryOptions, ref.result, ref.error, ref.delay, ref.observer
			if ref.variables == nil then
				variables = {}
			end
			if ref.queryOptions == nil then
				queryOptions = {}
			end

			local queryManager = mockQueryManager(reject, {
				request = { query = query, variables = variables },
				result = result,
				error = error_,
				delay = delay,
			})

			local finalOptions = assign({ query = query, variables = variables }, queryOptions) :: WatchQueryOptions__

			return queryManager:watchQuery(finalOptions):subscribe({
				next = wrap(reject, (observer.next :: FIX_ANALYZE)),
				error = observer.error,
			})
		end

		local function mockMutation(ref: MockedMutation)
			local reject, mutation, data, errors, variables, config =
				ref.reject, ref.mutation, ref.data, ref.errors, ref.variables, ref.config
			if ref.variables == nil then
				variables = {}
			end
			if ref.config == nil then
				config = {}
			end

			local link = mockSingleLink({
				request = { query = mutation, variables = variables },
				result = { data = data, errors = errors },
			}):setOnError(reject)

			local queryManager = createQueryManager({
				link = link,
				config = config,
			})

			return Promise.new(function(resolve, reject)
				queryManager
					:mutate({ mutation = mutation, variables = variables })
					:andThen(function(result: any)
						resolve({ result = result, queryManager = queryManager })
					end)
					:catch(function(error_)
						reject(error_)
					end)
			end)
		end

		local function assertMutationRoundtrip(resolve: (result: any) -> any, opts: MockedMutation)
			local reject = opts.reject

			return mockMutation(opts)
				:andThen(function(ref)
					local result = ref.result
					jestExpect(stripSymbols(result.data)).toEqual(opts.data)
				end)
				:andThen(resolve, reject)
		end

		-- Helper method that takes a query with a first response and a second response.
		-- Used to assert stuff about refetches.
		local function mockRefetch(
			ref: {
				reject: (reason: any) -> any,
				request: GraphQLRequest,
				firstResult: FetchResult___,
				secondResult: FetchResult___,
				thirdResult: FetchResult___?,
			}
		)
			local reject, request, firstResult, secondResult, thirdResult =
				ref.reject, ref.request, ref.firstResult, ref.secondResult, ref.thirdResult

			local args = {
				{
					request = request,
					result = firstResult,
				} :: FIX_ANALYZE,
				{
					request = request,
					result = secondResult,
				},
			}

			if Boolean.toJSBoolean(thirdResult) then
				-- ROBLOX FIXME: figure out why Luau analyze didn't wan us about using args:push here
				table.insert(args, { request = request, result = thirdResult })
			end

			return mockQueryManager(reject, table.unpack(args, 1, #args))
		end

		local function getCurrentQueryResult(
			observableQuery: ObservableQuery<TData_, TVars_>
		): {
			data: TData_,
			partial: boolean,
		}
			local result = observableQuery:getCurrentResult()
			return { data = result.data, partial = Boolean.toJSBoolean(result.partial) }
		end

		itAsync(it)("handles GraphQL errors", function(resolve, reject)
			assertWithObserver({
				reject = reject,
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				variables = {},
				result = {
					errors = { GraphQLError.new("This is an error message.") },
				},
				observer = {
					next = function(_self)
						reject(Error.new("Returned a result when it was supposed to error out"))
					end,
					error = function(_self, apolloError)
						jestExpect(apolloError).toBeDefined()
						resolve()
					end,
				},
			} :: FIX_ANALYZE)
		end)

		itAsync(it)("handles GraphQL errors as data", function(resolve, reject)
			assertWithObserver({
				reject = reject,
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				variables = {},
				queryOptions = { errorPolicy = "all" },
				result = { errors = { GraphQLError.new("This is an error message.") } },
				observer = {
					next = function(_self, ref)
						local errors = ref.errors
						jestExpect(errors).toBeDefined()
						jestExpect((errors :: FIX_ANALYZE)[1].message).toBe("This is an error message.")
						resolve()
					end,
					error = function(_self, apolloError)
						reject(Error.new("Called observer.error instead of passing errors to observer.next"))
					end,
				},
			} :: FIX_ANALYZE)
		end)

		itAsync(it)("handles GraphQL errors with data returned", function(resolve, reject)
			assertWithObserver({
				reject = reject,
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				result = {
					data = {
						allPeople = {
							people = {
								name = "Ada Lovelace",
							},
						},
					},
					errors = {
						GraphQLError.new("This is an error message."),
					} :: FIX_ANALYZE,
				},
				observer = {
					next = function(_self)
						reject(Error.new("Returned data when it was supposed to error out."))
					end,
					error = function(_self, apolloError)
						jestExpect(apolloError).toBeDefined()
						resolve()
					end,
				},
			})
		end)

		itAsync(it)("empty error array (handle non-spec-compliant server) #156", function(resolve, reject)
			assertWithObserver({
				reject = reject,
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				result = {
					data = {
						allPeople = {
							people = {
								name = "Ada Lovelace",
							},
						},
					},
					errors = {} :: FIX_ANALYZE,
				},
				observer = {
					next = function(_self, result)
						jestExpect(result.data["allPeople"].people.name).toBe("Ada Lovelace")
						jestExpect(result["errors"]).toBeUndefined()
						resolve()
					end,
				},
			})
		end)

		-- Easy to get into this state if you write an incorrect `formatError`
		-- function with graphql-server or express-graphql
		itAsync(it)("error array with nulls (handle non-spec-compliant server) #1185", function(resolve, reject)
			assertWithObserver({
				reject = reject,
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				result = {
					errors = { NULL :: any } :: FIX_ANALYZE,
				},
				observer = {
					next = function(_self)
						reject(Error.new("Should not fire next for an error"))
					end,
					error = function(_self, error_)
						jestExpect((error_ :: any).graphQLErrors).toEqual({ NULL })
						jestExpect(error_.message).toBe("Error message not found.")
						resolve()
					end,
				},
			})
		end)

		itAsync(it)("handles network errors", function(resolve, reject)
			assertWithObserver({
				reject = reject,
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				error = Error.new("Network error"),
				observer = {
					next = function(_self)
						reject(Error.new("Should not deliver result"))
					end,
					error = function(_self, error_)
						local apolloError = error_ :: ApolloError
						jestExpect(apolloError.networkError).toBeDefined()
						jestExpect(apolloError.networkError.message).toMatch("Network error")
						resolve()
					end,
				},
			})
		end)

		itAsync(it)("uses console.error to log unhandled errors", function(resolve, reject)
			local oldError = console.error
			local printed: any
			console.error = function(...)
				printed = { ... }
			end

			assertWithObserver({
				reject = reject,
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				error = Error.new("Network error"),
				observer = {
					next = function(_self)
						reject(Error.new("Should not deliver result"))
					end,
				},
			})

			setTimeout(
				function()
					jestExpect(printed[1]).toMatch(RegExp("error"))
					console.error = oldError
					resolve()
				end, -- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
				10 * TICK
			)
		end)

		-- XXX this looks like a bug in zen-observable but we should figure
		-- out a solution for it
		-- ROBLOX comment: this test is skipped upstream
		itAsync(xit)("handles an unsubscribe action that happens before data returns", function(resolve, reject)
			local subscription = assertWithObserver({
				reject = reject,
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				delay = 1000,
				observer = {
					next = function(_self)
						reject(Error.new("Should not deliver result"))
					end,
					error = function(_self)
						reject(Error.new("Should not deliver result"))
					end,
				},
			})
			jestExpect(function()
				subscription:unsubscribe()
			end).never.toThrow()
		end)

		-- Query should be aborted on last .unsubscribe()
		itAsync(it)("causes link unsubscription if unsubscribed", function(resolve, reject)
			local expResult = {
				data = {
					allPeople = {
						people = { {
							name = "Luke Skywalker",
						} },
					},
				},
			}

			local request = {
				query = gql([[

        query people {
          allPeople(first: 1) {
            people {
              name
            }
          }
        }
      ]]),
				variables = nil,
			}

			local mockedResponse = {
				request = request,
				result = expResult,
			}

			local onRequestSubscribe = jest.fn()
			local onRequestUnsubscribe = jest.fn()

			local mockedSingleLink = ApolloLink.new(function()
				return Observable.new(function(observer)
					onRequestSubscribe()

					local timer = setTimeout(function()
						observer:next(mockedResponse.result)
						observer:complete()
					end, 0)

					return function()
						onRequestUnsubscribe()
						clearTimeout(timer)
					end
				end)
			end)

			local mockedQueryManger = QueryManager.new({
				link = mockedSingleLink,
				cache = InMemoryCache.new({ addTypename = false }),
			})

			local observableQuery = mockedQueryManger:watchQuery({
				query = request.query,
				variables = request.variables,
				notifyOnNetworkStatusChange = false,
			})

			local observerCallback = wrap(reject, function()
				reject(Error.new("Link subscription should have been cancelled"))
			end)

			local subscription = observableQuery:subscribe({
				next = observerCallback,
				error = observerCallback,
				complete = observerCallback,
			})

			subscription:unsubscribe()

			return Promise.new(
				-- Unsubscribing from the link happens after a microtask
				-- (Promise.resolve().then) delay, so we need to wait at least that
				-- long before verifying onRequestUnsubscribe was called.
				function(resolve)
					setTimeout(resolve, 0)
				end
			)
				:andThen(function()
					jestExpect(onRequestSubscribe).toHaveBeenCalledTimes(1)
					jestExpect(onRequestUnsubscribe).toHaveBeenCalledTimes(1)
				end)
				:andThen(resolve, reject)
		end)

		-- ROBLOX comment: RXJS tests not required
		-- itAsync(xit)(
		-- 	"supports interoperability with other Observable implementations like RxJS",
		-- 	function(resolve, reject)
		-- 		local expResult = {
		-- 			data = {
		-- 				allPeople = {
		-- 					people = { {
		-- 						name = "Luke Skywalker",
		-- 					} },
		-- 				},
		-- 			},
		-- 		}
		-- 		local handle = mockWatchQuery(reject, {
		-- 			request = {
		-- 				query = gql([[

		--   query people {
		--     allPeople(first: 1) {
		--       people {
		--         name
		--       }
		--     }
		--   }
		-- ]]),
		-- 			},
		-- 			result = expResult,
		-- 		})

		-- 		local observable = from(handle :: any)

		-- 		observable
		-- 			:pipe(map(function(result)
		-- 				return assign({ fromRx = true }, result)
		-- 			end))
		-- 			:subscribe({
		-- 				next = wrap(reject, function(newResult)
		-- 					local expectedResult = assign(
		-- 						{ fromRx = true, loading = false, networkStatus = 7 },
		-- 						expResult
		-- 					)
		-- 					jestExpect(stripSymbols(newResult)).toEqual(expectedResult)
		-- 					resolve()
		-- 				end),
		-- 			})
		-- 	end
		-- )

		itAsync(it)("allows you to subscribe twice to one query", function(resolve, reject)
			local request = {
				query = gql([[

					query fetchLuke($id: String) {
					  people_one(id: $id) {
						name
					  }
					}
				]]),
				variables = {
					id = "1",
				},
			}

			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local data2 = {
				people_one = {
					name = "Luke Skywalker has a new name",
				},
			}

			local data3 = {
				people_one = {
					name = "Luke Skywalker has another name",
				},
			}

			local queryManager = mockQueryManager(reject, {
				request = request,
				result = { data = data1 },
			}, {
				request = request,
				result = { data = data2 },
				-- Wait for both to subscribe
				delay = 100,
			}, {
				request = request,
				result = { data = data3 },
			})

			local subOneCount = 0

			-- pre populate data to avoid contention
			queryManager:query(request):andThen(function()
				local handle = queryManager:watchQuery(request)

				local subOne = handle:subscribe({
					next = function(_self, result)
						subOneCount += 1

						if subOneCount == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(data1)
						elseif subOneCount == 2 then
							jestExpect(stripSymbols(result.data)).toEqual(data2)
						end
					end,
				})

				local subTwoCount = 0
				handle:subscribe({
					next = function(_self, result)
						subTwoCount += 1
						if subTwoCount == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(data1)
							handle:refetch()
						elseif subTwoCount == 2 then
							jestExpect(stripSymbols(result.data)).toEqual(data2)
							setTimeout(function()
								xpcall(function()
									jestExpect(subOneCount).toBe(2)
									subOne:unsubscribe()
									handle:refetch()
								end, function(e)
									reject(e)
								end)
							end, 0)
						elseif subTwoCount == 3 then
							setTimeout(function()
								xpcall(function()
									jestExpect(subOneCount).toBe(2)
									resolve()
								end, function(e)
									reject(e)
								end)
							end, 0)
						end
					end,
				})
			end)
		end)

		itAsync(it)("resolves all queries when one finishes after another", function(resolve, reject)
			local request = {
				query = gql([[

        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]]),
				variables = {
					id = "1",
				},
				notifyOnNetworkStatusChange = true,
			}
			local request2 = {
				query = gql([[

        query fetchLeia($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]]),
				variables = {
					id = "2",
				},
				notifyOnNetworkStatusChange = true,
			}
			local request3 = {
				query = gql([[

        query fetchHan($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]]),
				variables = {
					id = "3",
				},
				notifyOnNetworkStatusChange = true,
			}
			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}
			local data2 = {
				people_one = {
					name = "Leia Skywalker",
				},
			}
			local data3 = {
				people_one = {
					name = "Han Solo",
				},
			}

			local queryManager = mockQueryManager(reject, {
				request = request,
				result = { data = data1 },
				delay = 10,
			} :: FIX_ANALYZE, {
				request = request2,
				result = { data = data2 },
				-- make the second request the slower one
				delay = 100,
			} :: FIX_ANALYZE, {
				request = request3,
				result = { data = data3 },
				delay = 10,
			} :: FIX_ANALYZE)

			local ob1 = queryManager:watchQuery(request)
			local ob2 = queryManager:watchQuery(request2)
			local ob3 = queryManager:watchQuery(request3)

			local finishCount = 0;
			(ob1 :: FIX_ANALYZE):subscribe(function(_self, result)
				jestExpect(stripSymbols(result.data)).toEqual(data1)
				finishCount += 1
			end);
			(ob2 :: FIX_ANALYZE):subscribe(function(_self, result)
				jestExpect(stripSymbols(result.data)).toEqual(data2)
				jestExpect(finishCount).toBe(2)
				resolve()
			end);
			(ob3 :: FIX_ANALYZE):subscribe(function(_self, result)
				jestExpect(stripSymbols(result.data)).toEqual(data3)
				finishCount += 1
			end)
		end)

		itAsync(it)("allows you to refetch queries", function(resolve, reject)
			local request = {
				query = gql([[

        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]]),
				variables = {
					id = "1",
				},
				notifyOnNetworkStatusChange = false,
			}
			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local data2 = {
				people_one = {
					name = "Luke Skywalker has a new name",
				},
			}

			local queryManager = mockRefetch({
				reject = reject,
				request = request,
				firstResult = { data = data1 },
				secondResult = { data = data2 },
			} :: FIX_ANALYZE)

			local observable = queryManager:watchQuery(request)
			return observableToPromise({ observable = observable }, function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data1)
				observable:refetch()
			end, function(result)
				return jestExpect(stripSymbols(result.data)).toEqual(data2)
			end):andThen(resolve, reject)
		end)

		itAsync(it)(
			"will return referentially equivalent data if nothing changed in a refetch",
			function(resolve, reject)
				local request = {
					query = gql([[

        {
          a
          b {
            c
          }
          d {
            e
            f {
              g
            }
          }
        }
      ]]),
					notifyOnNetworkStatusChange = false,
				}

				local data1 = {
					a = 1,
					b = { c = 2 },
					d = { e = 3, f = { g = 4 } },
				}

				local data2 = {
					a = 1,
					b = { c = 2 },
					d = { e = 30, f = { g = 4 } },
				}

				local data3 = {
					a = 1,
					b = { c = 2 },
					d = { e = 3, f = { g = 4 } },
				}

				local queryManager = mockRefetch({
					reject = reject,
					request = request,
					firstResult = { data = data1 },
					secondResult = { data = data2 },
					thirdResult = { data = data3 },
				} :: FIX_ANALYZE)

				local observable = queryManager:watchQuery(request)

				local count = 0
				local firstResultData: any

				observable:subscribe({
					next = function(_self, result)
						xpcall(function()
							local condition = count
							count += 1
							if condition == 0 then
								jestExpect(stripSymbols(result.data)).toEqual(data1)
								firstResultData = result.data
								observable:refetch()
							elseif condition == 1 then
								jestExpect(stripSymbols(result.data)).toEqual(data2)
								jestExpect(result.data).never.toEqual(firstResultData)
								jestExpect(result.data.b).toEqual(firstResultData.b)
								jestExpect(result.data.d).never.toEqual(firstResultData.d)
								jestExpect(result.data.d.f).toEqual(firstResultData.d.f)
								observable:refetch()
							elseif condition == 2 then
								jestExpect(stripSymbols(result.data)).toEqual(data3)
								jestExpect(result.data).toBe(firstResultData)
								resolve()
							else
								error(Error.new("Next run too many times."))
							end
						end, function(error_)
							reject(error_)
						end)
					end,
					error = reject,
				})
			end
		)

		itAsync(it)(
			"will return referentially equivalent data in getCurrentResult if nothing changed",
			function(resolve, reject)
				local request = {
					query = gql([[

        {
          a
          b {
            c
          }
          d {
            e
            f {
              g
            }
          }
        }
      ]]),
					notifyOnNetworkStatusChange = false,
				}

				local data1 = {
					a = 1,
					b = { c = 2 },
					d = { e = 3, f = { g = 4 } },
				}

				local queryManager = mockQueryManager(reject, {
					request = request,
					result = { data = data1 },
				} :: FIX_ANALYZE)

				local observable = queryManager:watchQuery(request)

				observable:subscribe({
					next = function(_self, result)
						xpcall(function()
							jestExpect(stripSymbols(result.data)).toEqual(data1)
							jestExpect(stripSymbols(result.data)).toEqual(
								stripSymbols(observable:getCurrentResult().data)
							)
							resolve()
						end, function(error_)
							reject(error_)
						end)
					end,
					error = reject,
				})
			end
		)

		itAsync(it)("sets networkStatus to `refetch` when refetching", function(resolve, reject)
			local request: WatchQueryOptions__ = {
				query = gql([[

        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]]),
				variables = {
					id = "1",
				},
				notifyOnNetworkStatusChange = true,
				-- This causes a loading:true result to be delivered from the cache
				-- before the final data2 result is delivered.
				fetchPolicy = "cache-and-network",
			}

			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local data2 = {
				people_one = {
					name = "Luke Skywalker has a new name",
				},
			}

			local queryManager = mockRefetch({
				reject = reject,
				request = request,
				firstResult = { data = data1 },
				secondResult = { data = data2 },
			})

			local observable = queryManager:watchQuery(request)
			return observableToPromise({ observable = observable }, function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data1)
				observable:refetch()
			end, function(result)
				return jestExpect(result.networkStatus).toBe(NetworkStatus.refetch)
			end, function(result)
				jestExpect(result.networkStatus).toBe(NetworkStatus.ready)
				jestExpect(stripSymbols(result.data)).toEqual(data2)
			end):andThen(resolve, reject)
		end)

		itAsync(it)("allows you to refetch queries with promises", function(resolve, reject)
			local request = {
				query = gql([[

        {
          people_one(id: 1) {
            name
          }
        }
      ]]),
			}

			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local data2 = {
				people_one = {
					name = "Luke Skywalker has a new name",
				},
			}

			local queryManager = mockRefetch({
				reject = reject,
				request = request,
				firstResult = { data = data1 },
				secondResult = { data = data2 },
			})

			local handle = queryManager:watchQuery(request)
			handle:subscribe({})

			return handle
				:refetch()
				:andThen(function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data2)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("allows you to refetch queries with new variables", function(resolve, reject)
			local query = gql([[

      {
        people_one(id: 1) {
          name
        }
      }
    ]])

			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local data2 = {
				people_one = {
					name = "Luke Skywalker has a new name",
				},
			}

			local data3 = {
				people_one = {
					name = "Luke Skywalker has a new name and age",
				},
			}

			local data4 = {
				people_one = {
					name = "Luke Skywalker has a whole new bag",
				},
			}

			local variables1 = {
				test = "I am your father",
			}

			local variables2 = {
				test = "No. No! That's not true! That's impossible!",
			}

			local queryManager = mockQueryManager(reject, {
				request = { query = query },
				result = { data = data1 },
			}, {
				request = { query = query },
				result = { data = data2 },
			}, {
				request = { query = query, variables = variables1 },
				result = { data = data3 },
			}, {
				request = { query = query, variables = variables2 },
				result = { data = data4 },
			})

			local observable = queryManager:watchQuery({
				query = query,
				notifyOnNetworkStatusChange = false,
			})

			return observableToPromise({ observable = observable }, function(result)
				jestExpect(result.loading).toBe(false)
				jestExpect(result.data).toEqual(data1)
				return observable:refetch()
			end, function(result)
				jestExpect(result.loading).toBe(false)
				jestExpect(result.data).toEqual(data2)
				return observable:refetch(variables1 :: FIX_ANALYZE)
			end, function(result)
				jestExpect(result.loading).toBe(false)
				jestExpect(result.data).toEqual(data3)
				return observable:refetch(variables2 :: FIX_ANALYZE)
			end, function(result)
				jestExpect(result.loading).toBe(false)
				jestExpect(result.data).toEqual(data4)
			end):andThen(resolve, reject)
		end)

		itAsync(it)("only modifies varaibles when refetching", function(resolve, reject)
			local query = gql([[

      {
        people_one(id: 1) {
          name
        }
      }
    ]])

			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local data2 = {
				people_one = {
					name = "Luke Skywalker has a new name",
				},
			}

			local queryManager = mockQueryManager(reject, {
				request = { query = query },
				result = { data = data1 },
			}, {
				request = { query = query },
				result = { data = data2 },
			})

			local observable = queryManager:watchQuery({
				query = query,
				notifyOnNetworkStatusChange = false,
			})
			local originalOptions = assign({}, observable.options)
			return observableToPromise({ observable = observable }, function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data1)
				observable:refetch()
			end, function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data2)
				local updatedOptions = assign({}, observable.options)
				originalOptions.variables = nil
				updatedOptions.variables = nil
				jestExpect(updatedOptions).toEqual(originalOptions)
			end):andThen(resolve, reject)
		end)

		itAsync(it)("continues to poll after refetch", function(resolve, reject)
			local query = gql([[

      {
        people_one(id: 1) {
          name
        }
      }
    ]])

			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local data2 = {
				people_one = {
					name = "Luke Skywalker has a new name",
				},
			}

			local data3 = {
				people_one = {
					name = "Patsy",
				},
			}

			local queryManager = mockQueryManager(reject, {
				request = { query = query },
				result = { data = data1 },
			}, {
				request = { query = query },
				result = { data = data2 },
			}, {
				request = { query = query },
				result = { data = data3 },
			})

			local observable = queryManager:watchQuery({
				query = query,
				pollInterval = 200,
				notifyOnNetworkStatusChange = false,
			})

			return observableToPromise({ observable = observable }, function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data1)
				observable:refetch()
			end, function(result)
				return jestExpect(stripSymbols(result.data)).toEqual(data2)
			end, function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data3)
				observable:stopPolling()
			end):andThen(resolve, reject)
		end)

		itAsync(it)("sets networkStatus to `poll` if a polling query is in flight", function(resolve, reject)
			local query = gql([[

      {
        people_one(id: 1) {
          name
        }
      }
    ]])

			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local data2 = {
				people_one = {
					name = "Luke Skywalker has a new name",
				},
			}

			local data3 = {
				people_one = {
					name = "Patsy",
				},
			}

			local queryManager = mockQueryManager(reject, {
				request = { query = query },
				result = { data = data1 },
			}, {
				request = { query = query },
				result = { data = data2 },
			}, {
				request = { query = query },
				result = { data = data3 },
			})

			local observable = queryManager:watchQuery({
				query = query,
				pollInterval = 30,
				notifyOnNetworkStatusChange = true,
			})

			local counter = 0

			local handle
			handle = observable:subscribe({
				next = function(_self, result)
					counter += 1

					if counter == 1 then
						jestExpect(result.networkStatus).toBe(NetworkStatus.ready)
					elseif counter == 2 then
						jestExpect(result.networkStatus).toBe(NetworkStatus.poll)
						handle:unsubscribe()
						resolve()
					end
				end,
			})
		end)

		itAsync(it)("can handle null values in arrays (#1551)", function(resolve, reject)
			local query = gql([[

     {
        list {
          value
        }
      }
    ]])

			local data = { list = { NULL, { value = 1 } } }
			local queryManager = mockQueryManager(reject, {
				request = { query = query },
				result = { data = data },
			})
			local observable = queryManager:watchQuery({ query = query })

			observable:subscribe({
				next = function(_self, result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(data)
					resolve()
				end,
			})
		end)

		itAsync(it)("supports cache-only fetchPolicy fetching only cached data", function(resolve, reject)
			local primeQuery = gql([[

      query primeQuery {
        luke: people_one(id: 1) {
          name
        }
      }
    ]])

			local complexQuery = gql([[

      query complexQuery {
        luke: people_one(id: 1) {
          name
        }
        vader: people_one(id: 4) {
          name
        }
      }
    ]])

			local data1 = {
				luke = {
					name = "Luke Skywalker",
				},
			}

			local queryManager = mockQueryManager(reject, {
				request = { query = primeQuery },
				result = { data = data1 },
			})

			-- First, prime the cache
			return queryManager
				:query({
					query = primeQuery,
				})
				:andThen(function()
					local handle = queryManager:watchQuery({
						query = complexQuery,
						fetchPolicy = "cache-only",
					})

					return handle:result():andThen(function(result)
						jestExpect(result.data["luke"].name).toBe("Luke Skywalker")
						jestExpect(result.data).never.toHaveProperty("vader")
					end)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("runs a mutation", function(resolve, reject)
			return assertMutationRoundtrip(resolve, {
				reject = reject,
				mutation = gql([[

        mutation makeListPrivate {
          makeListPrivate(id: "5")
        }
      ]]),
				data = { makeListPrivate = true },
			} :: FIX_ANALYZE)
		end)

		itAsync(it)("runs a mutation even when errors is empty array #2912", function(resolve, reject)
			return assertMutationRoundtrip(resolve, {
				reject = reject,
				mutation = gql([[
        mutation makeListPrivate {
          makeListPrivate(id: "5")
        }
      ]]),
				errors = {},
				data = { makeListPrivate = true },
			} :: FIX_ANALYZE)
		end)

		itAsync(it)('runs a mutation with default errorPolicy equal to "none"', function(resolve, reject)
			local errors = { GraphQLError.new("foo") }

			return mockMutation({
				reject = reject,
				mutation = gql([[

        mutation makeListPrivate {
          makeListPrivate(id: "5")
        }
      ]]),
				errors = errors,
			})
				:andThen(function(result)
					error(Error.new("Mutation should not be successful with default errorPolicy"))
				end, function(error_)
					jestExpect(error_.graphQLErrors).toEqual(errors)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("runs a mutation with variables", function(resolve, reject)
			return assertMutationRoundtrip(resolve, {
				reject = reject,
				mutation = gql([[

        mutation makeListPrivate($listId: ID!) {
          makeListPrivate(id: $listId)
        }
      ]]),
				variables = { listId = "1" },
				data = { makeListPrivate = true },
			} :: FIX_ANALYZE)
		end)

		local function getIdField(_self, ref)
			return ref.id
		end

		itAsync(it)("runs a mutation with object parameters and puts the result in the store", function(resolve, reject)
			local data = {
				makeListPrivate = {
					id = "5",
					isPrivate = true,
				},
			}
			return mockMutation({
				reject = reject,
				mutation = gql([[

        mutation makeListPrivate {
          makeListPrivate(input: { id: "5" }) {
            id
            isPrivate
          }
        }
      ]]),
				data = data,
				config = { dataIdFromObject = getIdField },
			} :: FIX_ANALYZE)
				:andThen(function(ref)
					local result, queryManager = ref.result, ref.queryManager
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(queryManager.cache:extract()["5"]).toEqual({
						id = "5",
						isPrivate = true,
					})
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("runs a mutation and puts the result in the store", function(resolve, reject)
			local data = {
				makeListPrivate = {
					id = "5",
					isPrivate = true,
				},
			}

			return mockMutation({
				reject = reject,
				mutation = gql([[

        mutation makeListPrivate {
          makeListPrivate(id: "5") {
            id
            isPrivate
          }
        }
      ]]),
				data = data,
				config = { dataIdFromObject = getIdField },
			} :: FIX_ANALYZE)
				:andThen(function(ref)
					local result, queryManager = ref.result, ref.queryManager
					jestExpect(stripSymbols(result.data)).toEqual(data)

					-- Make sure we updated the store with the new data
					jestExpect(queryManager.cache:extract()["5"]).toEqual({
						id = "5",
						isPrivate = true,
					})
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("runs a mutation and puts the result in the store with root key", function(resolve, reject)
			local mutation = gql([[

      mutation makeListPrivate {
        makeListPrivate(id: "5") {
          id
          isPrivate
        }
      }
    ]])

			local data = {
				makeListPrivate = {
					id = "5",
					isPrivate = true,
				},
			}

			local queryManager = createQueryManager({
				link = mockSingleLink({
					request = { query = mutation },
					result = { data = data },
				}):setOnError(reject),
				config = { dataIdFromObject = getIdField },
			} :: FIX_ANALYZE)

			return queryManager
				:mutate({
					mutation = mutation,
				})
				:andThen(function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)

					-- Make sure we updated the store with the new data
					jestExpect(queryManager.cache:extract()["5"]).toEqual({
						id = "5",
						isPrivate = true,
					})
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("doesn't return data while query is loading", function(resolve, reject)
			local query1 = gql([[

      {
        people_one(id: 1) {
          name
        }
      }
    ]])

			local data1 = {
				people_one = {
					name = "Luke Skywalker",
				},
			}

			local query2 = gql([[

      {
        people_one(id: 5) {
          name
        }
      }
    ]])

			local data2 = {
				people_one = {
					name = "Darth Vader",
				},
			}

			local queryManager = mockQueryManager(reject, {
				request = { query = query1 },
				result = { data = data1 },
				delay = 10,
			}, {
				request = { query = query2 },
				result = { data = data2 },
			})

			local observable1 = queryManager:watchQuery({ query = query1 })
			local observable2 = queryManager:watchQuery({ query = query2 })

			return Promise.all({
				observableToPromise({ observable = observable1 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data1)
				end),
				observableToPromise({ observable = observable2 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data2)
				end),
			}):andThen(resolve, reject)
		end)

		itAsync(it)("updates result of previous query if the result of a new query overlaps", function(resolve, reject)
			local query1 = gql([[

      {
        people_one(id: 1) {
          __typename
          id
          name
          age
        }
      }
    ]])

			local data1 = {
				people_one = {
					-- Correctly identifying this entity is necessary so that fields
					-- from query1 and query2 can be safely merged in the cache.
					__typename = "Human",
					id = 1,
					name = "Luke Skywalker",
					age = 50,
				},
			}

			local query2 = gql([[

      {
        people_one(id: 1) {
          __typename
          id
          name
          username
        }
      }
    ]])

			local data2 = {
				people_one = {
					__typename = "Human",
					id = 1,
					name = "Luke Skywalker has a new name",
					username = "luke",
				},
			}

			local queryManager = mockQueryManager(reject, {
				request = { query = query1 },
				result = { data = data1 },
			}, {
				request = { query = query2 },
				result = { data = data2 },
				delay = 10,
			})

			local observable = queryManager:watchQuery({ query = query1 })

			subscribeAndCount(reject, observable, function(handleCount, result)
				if handleCount == 1 then
					jestExpect(result.data).toEqual(data1)
					queryManager:query({ query = query2 })
				elseif handleCount == 2 then
					jestExpect(result.data).toEqual({
						people_one = {
							__typename = "Human",
							id = 1,
							name = "Luke Skywalker has a new name",
							age = 50,
						},
					})
					resolve()
				end
			end)
		end)

		itAsync(it)("warns if you forget the template literal tag", function(resolve, reject)
			local queryManager = mockQueryManager(reject)
			jestExpect(function()
				queryManager:query({
					-- Bamboozle TypeScript into letting us do this
					query = ("string" :: any) :: DocumentNode,
				})
			end).toThrowError(RegExp('wrap the query string in a "gql" tag'))

			-- ROBLOX deviation START: separate into multiple steps as jest-roblox doesn't support jestExpect(...).rejects functionality (https://jestjs.io/docs/tutorial-async#rejects)
			local mutatePromise = queryManager:mutate({
				-- Bamboozle TypeScript into letting us do this
				mutation = ("string" :: any) :: DocumentNode,
			})
			local resolved, error_ = mutatePromise:await()
			jestExpect(resolved).toBe(false)
			jestExpect(function()
				error(error_)
			end).toThrow(RegExp('wrap the query string in a "gql" tag'))
			-- ROBLOX deviation END

			jestExpect(function()
				queryManager:watchQuery({
					-- Bamboozle TypeScript into letting us do this
					query = ("string" :: any) :: DocumentNode,
				})
			end).toThrowError(RegExp('wrap the query string in a "gql" tag'))
			resolve()
		end)

		itAsync(it)("should transform queries correctly when given a QueryTransformer", function(resolve, reject)
			local query = gql([[

      query {
        author {
          firstName
          lastName
        }
      }
    ]])
			local transformedQuery = gql([[

      query {
        author {
          firstName
          lastName
          __typename
        }
      }
    ]])

			local transformedQueryResult = {
				author = {
					firstName = "John",
					lastName = "Smith",
					__typename = "Author",
				},
			}

			--make sure that the query is transformed within the query
			--manager
			createQueryManager({
				link = mockSingleLink({
					request = { query = transformedQuery },
					result = { data = transformedQueryResult },
				}):setOnError(reject),
				config = { addTypename = true },
			} :: FIX_ANALYZE)
				:query({ query = query })
				:andThen(function(result)
					jestExpect(stripSymbols(result.data)).toEqual(transformedQueryResult)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("should transform mutations correctly", function(resolve, reject)
			local mutation = gql([[

      mutation {
        createAuthor(firstName: "John", lastName: "Smith") {
          firstName
          lastName
        }
      }
    ]])
			local transformedMutation = gql([[

      mutation {
        createAuthor(firstName: "John", lastName: "Smith") {
          firstName
          lastName
          __typename
        }
      }
    ]])

			local transformedMutationResult = {
				createAuthor = {
					firstName = "It works!",
					lastName = "It works!",
					__typename = "Author",
				},
			}

			createQueryManager({
				link = mockSingleLink({
					request = { query = transformedMutation },
					result = { data = transformedMutationResult },
				}):setOnError(reject),
				config = { addTypename = true },
			} :: FIX_ANALYZE):mutate({ mutation = mutation }):andThen(function(result)
				jestExpect(stripSymbols(result.data)).toEqual(transformedMutationResult)
				resolve()
			end)
		end)

		itAsync(it)("should reject a query promise given a network error", function(resolve, reject)
			local query = gql([[

      query {
        author {
          firstName
          lastName
        }
      }
    ]])
			local networkError = Error.new("Network error")
			mockQueryManager(reject, {
				request = { query = query },
				error = networkError,
			})
				:query({ query = query })
				:andThen(function()
					reject(Error.new("Returned result on an errored fetchQuery"))
				end)
				:catch(function(error_)
					local apolloError = error_ :: ApolloError

					jestExpect(apolloError.message).toBeDefined()
					jestExpect(apolloError.networkError).toBe(networkError)
					jestExpect(apolloError.graphQLErrors).toEqual({})
					resolve()
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)("should reject a query promise given a GraphQL error", function(resolve, reject)
			local query = gql([[

      query {
        author {
          firstName
          lastName
        }
      }
    ]])
			local graphQLErrors = { GraphQLError.new("GraphQL error") }
			return mockQueryManager(reject, {
				request = { query = query },
				result = { errors = graphQLErrors },
			} :: FIX_ANALYZE)
				:query({ query = query })
				:andThen(
					function()
						error(Error.new("Returned result on an errored fetchQuery"))
					end,
					-- don't use .catch() for this or it will catch the above error
					function(error_)
						local apolloError = error_ :: ApolloError
						jestExpect(apolloError.graphQLErrors).toEqual(graphQLErrors)
						jestExpect(not Boolean.toJSBoolean(apolloError.networkError)).toBeTruthy()
					end
				)
				:andThen(resolve, reject)
		end)

		itAsync(it)(
			"should not empty the store when a non-polling query fails due to a network error",
			function(resolve, reject)
				local query = gql([[

      query {
        author {
          firstName
          lastName
        }
      }
    ]])

				local data = {
					author = {
						firstName = "Dhaivat",
						lastName = "Pandya",
					},
				}

				local queryManager = mockQueryManager(reject, {
					request = { query = query },
					result = { data = data },
				}, {
					request = { query = query },
					error = Error.new("Network error ocurred"),
				})

				queryManager
					:query({ query = query })
					:andThen(function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)

						queryManager
							:query({ query = query, fetchPolicy = "network-only" })
							:andThen(function()
								reject(Error.new("Returned a result when it was not supposed to."))
							end)
							:catch(function()
								-- make that the error thrown doesn't empty the state
								jestExpect((queryManager.cache:extract().ROOT_QUERY :: any).author).toEqual(data.author)
								resolve()
							end)
					end)
					:catch(function()
						reject(Error.new("Threw an error on the first query."))
					end)
			end
		)

		itAsync(it)("should be able to unsubscribe from a polling query subscription", function(resolve, reject)
			local query = gql([[

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

			local observable = mockQueryManager(reject, {
				request = { query = query },
				result = { data = data },
			}):watchQuery({
				query = query,
				pollInterval = 20,
			})

			local promise, subscription
			local ref = observableToPromiseAndSubscription({ observable = observable, wait = 60 }, function(result: any)
				jestExpect(stripSymbols(result.data)).toEqual(data)
				subscription:unsubscribe()
			end)
			promise, subscription = ref.promise, ref.subscription

			return promise:andThen(resolve, reject)
		end)

		itAsync(it)(
			"should not empty the store when a polling query fails due to a network error",
			function(resolve, reject)
				local query = gql([[

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

				local queryManager = mockQueryManager(reject, {
					request = { query = query },
					result = { data = data },
				}, {
					request = { query = query },
					error = Error.new("Network error occurred."),
				})
				local observable = queryManager:watchQuery({
					query = query,
					pollInterval = 20,
					notifyOnNetworkStatusChange = false,
				})

				return observableToPromise({
					observable = observable,
					errorCallbacks = {
						function()
							jestExpect((queryManager.cache:extract().ROOT_QUERY :: any).author).toEqual(data.author)
						end,
					},
				} :: FIX_ANALYZE, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect((queryManager.cache:extract().ROOT_QUERY :: any).author).toEqual(data.author)
				end):andThen(resolve, reject)
			end
		)

		itAsync(it)("should not fire next on an observer if there is no change in the result", function(resolve, reject)
			local query = gql([[

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

			local queryManager = mockQueryManager(reject, {
				request = { query = query },
				result = { data = data },
			}, {
				request = { query = query },
				result = { data = data },
			})

			local observable = queryManager:watchQuery({ query = query })
			return Promise.all({
				-- we wait for a little bit to ensure the result of the second query
				-- don't trigger another subscription event
				observableToPromise({ observable = observable, wait = 100 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
				end) :: Promise<any>,
				queryManager:query({ query = query }):andThen(function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
				end),
			}):andThen(resolve, reject)
		end)

		itAsync(it)(
			"should not return stale data when we orphan a real-id node in the store with a real-id node",
			function(resolve, reject)
				local query1 = gql([[

      query {
        author {
          name {
            firstName
            lastName
          }
          age
          id
          __typename
        }
      }
    ]])
				local query2 = gql([[

      query {
        author {
          name {
            firstName
          }
          id
          __typename
        }
      }
    ]])
				local data1 = {
					author = {
						name = {
							firstName = "John",
							lastName = "Smith",
						},
						age = 18,
						id = "187",
						__typename = "Author",
					},
				}
				local data2 = {
					author = {
						name = {
							firstName = "John",
						},
						id = "197",
						__typename = "Author",
					},
				}
				local reducerConfig = { dataIdFromObject = dataIdFromObject }
				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query1 },
						result = { data = data1 },
					}, {
						request = { query = query2 },
						result = { data = data2 },
					}, {
						request = { query = query1 },
						result = { data = data1 },
					}):setOnError(reject),
					config = reducerConfig,
				} :: FIX_ANALYZE)

				local observable1 = queryManager:watchQuery({ query = query1 })
				local observable2 = queryManager:watchQuery({ query = query2 })

				-- I'm not sure the waiting 60 here really is required, but the test used to do it
				return Promise.all({
					observableToPromise({ observable = observable1, wait = 60 }, function(result)
						jestExpect(stripSymbols(result)).toEqual({
							data = data1,
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
					end),
					observableToPromise({ observable = observable2, wait = 60 }, function(result)
						jestExpect(stripSymbols(result)).toEqual({
							data = data2,
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
					end),
				}):andThen(resolve, reject)
			end
		)

		itAsync(it)(
			"should return partial data when configured when we orphan a real-id node in the store with a real-id node",
			function(resolve, reject)
				local query1 = gql([[

      query {
        author {
          name {
            firstName
            lastName
          }
          age
          id
          __typename
        }
      }
    ]])
				local query2 = gql([[

      query {
        author {
          name {
            firstName
          }
          id
          __typename
        }
      }
    ]])
				local data1 = {
					author = {
						name = {
							firstName = "John",
							lastName = "Smith",
						},
						age = 18,
						id = "187",
						__typename = "Author",
					},
				}
				local data2 = {
					author = {
						name = {
							firstName = "John",
						},
						id = "197",
						__typename = "Author",
					},
				}

				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query1 },
						result = { data = data1 },
					}, {
						request = { query = query2 },
						result = { data = data2 },
					}):setOnError(reject),
				})

				local observable1 = queryManager:watchQuery({ query = query1, returnPartialData = true })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise.all({
					observableToPromise({
						observable = observable1,
					}, function(result)
						jestExpect(result).toEqual({
							data = {},
							loading = true,
							networkStatus = NetworkStatus.loading,
							partial = true,
						})
					end, function(result)
						jestExpect(result).toEqual({
							data = data1,
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
					end),
					observableToPromise({
						observable = observable2,
					}, function(result)
						jestExpect(result).toEqual({
							data = data2,
							loading = false,
							networkStatus = NetworkStatus.ready,
						})
					end),
				}):andThen(resolve, reject)
			end
		)

		itAsync(it)("should not write unchanged network results to cache", function(resolve, reject)
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							info = {
								merge = false,
							},
						},
					},
				},
			} :: FIX_ANALYZE)

			local client = ApolloClient.new({
				cache = cache,
				link = ApolloLink.new(function(_self, operation)
					return Observable.new(function(observer: Observer<FetchResult___>)
						local condition = operation.operationName
						if condition == "A" then
							(observer :: FIX_ANALYZE):next({ data = { info = { a = "ay" } } })
						elseif condition == "B" then
							(observer :: FIX_ANALYZE):next({ data = { info = { b = "bee" } } })
						end
						(observer :: FIX_ANALYZE):complete()
					end)
				end),
			})

			local queryA = gql([[query A { info { a } }]])
			local queryB = gql([[query B { info { b } }]])

			local obsA = client:watchQuery({
				query = queryA,
				returnPartialData = true,
			})
			local obsB = client:watchQuery({
				query = queryB,
				returnPartialData = true,
			})

			subscribeAndCount(reject, obsA, function(count, result)
				if count == 1 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = {},
						partial = true,
					})
				elseif count == 2 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = {
							info = {
								a = "ay",
							},
						},
					})
				elseif count == 3 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = {
							info = {},
						},
						partial = true,
					})
				elseif count == 4 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = {
							info = {
								a = "ay",
							},
						},
					})
					setTimeout(resolve, 100)
				else
					reject(
						Error.new(("Unexpected %s"):format(HttpService:JSONEncode({ count = count, result = result })))
					)
				end
			end)

			subscribeAndCount(reject, obsB, function(count, result)
				if count == 1 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = {},
						partial = true,
					})
				elseif count == 2 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = {
							info = {
								b = "bee",
							},
						},
					})
				elseif count == 3 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = {
							info = {},
						},
					})
				elseif count == 4 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = {
							info = {
								b = "bee",
							},
						},
					})
					setTimeout(resolve, 100)
				else
					reject(
						Error.new(("Unexpected %s"):format(HttpService:JSONEncode({ count = count, result = result })))
					)
				end
			end)
		end)

		itAsync(it)("should disable feud-stopping logic after evict or modify", function(resolve, reject)
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							info = {
								merge = false,
							},
						},
					},
				},
			} :: FIX_ANALYZE)

			local client = ApolloClient.new({
				cache = cache,
				link = ApolloLink.new(function(operation)
					return Observable.new(function(observer: Observer<FetchResult___>)
						(observer.next :: any)(observer, { data = { info = { c = "see" } } });
						(observer.complete :: any)(observer)
					end)
				end),
			})

			local query = gql([[query { info { c } }]])

			local obs = client:watchQuery({
				query = query,
				returnPartialData = true,
			})

			subscribeAndCount(reject, obs, function(count, result)
				if count == 1 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = {},
						partial = true,
					})
				elseif count == 2 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = {
							info = {
								c = "see",
							},
						},
					})

					cache:evict({
						fieldName = "info",
					})
				elseif count == 3 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = {},
						partial = true,
					})
				elseif count == 4 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = {
							info = {
								c = "see",
							},
						},
					})

					cache:modify({
						fields = {
							info = function(_self, _, ref)
								return ref.DELETE
							end,
						},
					})
				elseif count == 5 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = {},
						partial = true,
					})
				elseif count == 6 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = {
							info = {
								c = "see",
							},
						},
					})

					setTimeout(resolve, 100)
				else
					reject(
						Error.new(("Unexpected %s"):format(HttpService:JSONEncode({ count = count, result = result })))
					)
				end
			end)
		end)

		itAsync(it)("should not error when replacing unidentified data with a normalized ID", function(resolve, reject)
			local queryWithoutId = gql([[

      query {
        author {
          name {
            firstName
            lastName
          }
          age
          __typename
        }
      }
    ]])

			local queryWithId = gql([[

      query {
        author {
          name {
            firstName
          }
          id
          __typename
        }
      }
    ]])

			local dataWithoutId = {
				author = {
					name = {
						firstName = "John",
						lastName = "Smith",
					},
					age = "124",
					__typename = "Author",
				},
			}
			local dataWithId = {
				author = {
					name = {
						firstName = "Jane",
					},
					id = "129",
					__typename = "Author",
				},
			}
			local mergeCount = 0
			local queryManager = createQueryManager({
				link = mockSingleLink({
					request = { query = queryWithoutId },
					result = { data = dataWithoutId },
				}, {
					request = { query = queryWithId },
					result = { data = dataWithId },
				}):setOnError(reject),
				config = {
					typePolicies = {
						Query = {
							fields = {
								author = {
									merge = function(_self, existing, incoming, ref)
										mergeCount += 1
										local condition = mergeCount
										if condition == 1 then
											jestExpect(existing).toBeUndefined()
											jestExpect(ref:isReference(incoming)).toBe(false)
											jestExpect(incoming).toEqual(dataWithoutId.author)
										elseif condition == 2 then
											jestExpect(existing).toEqual(dataWithoutId.author)
											jestExpect(ref:isReference(incoming)).toBe(true)
											jestExpect(ref:readField("id", incoming)).toBe("129")
											jestExpect(ref:readField("name", incoming)).toEqual(dataWithId.author.name)
										else
											fail("unreached")
										end
										return incoming
									end,
								},
							},
						},
					},
				},
			} :: FIX_ANALYZE)

			local observableWithId = queryManager:watchQuery({
				query = queryWithId,
			})

			local observableWithoutId = queryManager:watchQuery({
				query = queryWithoutId,
			})

			return Promise.all({
				observableToPromise({ observable = observableWithoutId }, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(dataWithoutId)
				end),
				observableToPromise({ observable = observableWithId }, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(dataWithId)
				end),
			}):andThen(resolve, reject)
		end)

		itAsync(it)("exposes errors on a refetch as a rejection", function(resolve, reject)
			local request = {
				query = gql([[

        {
          people_one(id: 1) {
            name
          }
        }
      ]]),
			}
			local firstResult = {
				data = {
					people_one = {
						name = "Luke Skywalker",
					},
				},
			}
			local secondResult = {
				errors = {
					GraphQLError.new("This is not the person you are looking for."),
				},
			}

			local queryManager = mockRefetch({
				reject = reject,
				request = request,
				firstResult = firstResult,
				secondResult = secondResult,
			} :: FIX_ANALYZE)

			local handle = queryManager:watchQuery(request)

			local function checkError(error_)
				jestExpect(error_.graphQLErrors[1].message).toEqual("This is not the person you are looking for.")
			end

			handle:subscribe({
				error = function(_self, ...)
					return checkError(...)
				end,
			})

			handle
				:refetch()
				:andThen(function()
					reject(Error.new("Error on refetch should reject promise"))
				end)
				:catch(function(error_)
					checkError(error_)
				end)
				:andThen(resolve, reject)
		end)

		itAsync(it)(
			"does not return incomplete data when two queries for the same item are executed",
			function(resolve, reject)
				local queryA = gql([[

      query queryA {
        person(id: "abc") {
          __typename
          id
          firstName
          lastName
        }
      }
    ]])
				local queryB = gql([[

      query queryB {
        person(id: "abc") {
          __typename
          id
          lastName
          age
        }
      }
    ]])
				local dataA = {
					person = {
						__typename = "Person",
						id = "abc",
						firstName = "Luke",
						lastName = "Skywalker",
					},
				}
				local dataB = {
					person = {
						__typename = "Person",
						id = "abc",
						lastName = "Skywalker",
						age = "32",
					},
				}
				local queryManager = QueryManager.new({
					link = mockSingleLink(
						{ request = { query = queryA }, result = { data = dataA } },
						{ request = { query = queryB }, result = { data = dataB }, delay = 20 }
					):setOnError(reject),
					cache = InMemoryCache.new({}),
					ssrMode = true,
				})

				local observableA = queryManager:watchQuery({
					query = queryA,
				})
				local observableB = queryManager:watchQuery({
					query = queryB,
				})

				return Promise.all({
					observableToPromise({ observable = observableA }, function()
						jestExpect(stripSymbols(getCurrentQueryResult(observableA))).toEqual({
							data = dataA,
							partial = false,
						})
						jestExpect(getCurrentQueryResult(observableB)).toEqual({
							data = nil,
							partial = true,
						})
					end),
					observableToPromise({ observable = observableB }, function()
						jestExpect(stripSymbols(getCurrentQueryResult(observableA))).toEqual({
							data = dataA,
							partial = false,
						})
						jestExpect(getCurrentQueryResult(observableB)).toEqual({
							data = dataB,
							partial = false,
						})
					end),
				}):andThen(resolve, reject)
			end
		)

		itAsync(it)(
			'only increments "queryInfo.lastRequestId" when fetching data from network',
			function(resolve, reject)
				local query = gql([[

      query query($id: ID!) {
        people_one(id: $id) {
          name
        }
      }
    ]])
				local variables = { id = 1 }
				local dataOne = {
					people_one = { name = "Luke Skywalker" },
				}
				local mockedResponses = {
					{
						request = { query = query, variables = variables },
						result = { data = dataOne },
					},
				}

				local queryManager = mockQueryManager(reject, table.unpack(mockedResponses, 1, #mockedResponses))
				local queryOptions: WatchQueryOptions_<any> = {
					query = query,
					variables = variables,
					fetchPolicy = "cache-and-network",
				}
				local observable = queryManager:watchQuery(queryOptions)

				local mocks = mockFetchQuery(queryManager)
				local queryId = "1"
				local getQuery: QueryManager_getQuery = function(...)
					return (queryManager :: any).getQuery(queryManager, ...)
				end

				subscribeAndCount(reject, observable, function(handleCount)
					local query = getQuery(queryId)
					local fqbpCalls = mocks.fetchQueryByPolicy.mock.calls
					jestExpect(query.lastRequestId).toEqual(1)
					jestExpect(#fqbpCalls).toBe(1)

					-- Simulate updating the options of the query, which will trigger
					-- fetchQueryByPolicy, but it should just read from cache and not
					-- update "queryInfo.lastRequestId". For more information, see
					-- https://github.com/apollographql/apollo-client/pull/7956#issue-610298427
					observable:setOptions(Object.assign({}, queryOptions, { fetchPolicy = "cache-first" })):expect()

					-- "fetchQueryByPolicy" was called, but "lastRequestId" does not update
					-- since it was able to read from cache.
					jestExpect(query.lastRequestId).toEqual(1)
					jestExpect(#fqbpCalls).toBe(2)
					resolve()
				end)
			end
		)

		describe("polling queries", function()
			itAsync(it)("allows you to poll queries", function(resolve, reject)
				local query = gql([[

        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]])

				local variables = {
					id = "1",
				}

				local data1 = {
					people_one = {
						name = "Luke Skywalker",
					},
				}

				local data2 = {
					people_one = {
						name = "Luke Skywalker has a new name",
					},
				}

				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data1 },
				}, {
					request = { query = query, variables = variables },
					result = { data = data2 },
				})
				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					pollInterval = 50,
					notifyOnNetworkStatusChange = false,
				})

				return observableToPromise({ observable = observable }, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data1)
				end, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data2)
				end):andThen(resolve, reject)
			end)

			itAsync(it)("does not poll during SSR", function(resolve, reject)
				local query = gql([[

        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]])
				local variables = {
					id = "1",
				}

				local data1 = {
					people_one = {
						name = "Luke Skywalker",
					},
				}

				local data2 = {
					people_one = {
						name = "Luke Skywalker has a new name",
					},
				}

				local queryManager = QueryManager.new({
					link = mockSingleLink({
						request = { query = query, variables = variables },
						result = { data = data1 },
					}, {
						request = { query = query, variables = variables },
						result = { data = data2 },
					}, {
						request = { query = query, variables = variables },
						result = { data = data2 },
					}):setOnError(reject),
					cache = InMemoryCache.new({ addTypename = false }),
					ssrMode = true,
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
					pollInterval = 10 * TICK,
					notifyOnNetworkStatusChange = false,
				})

				local count = 1
				local subHandle
				subHandle = observable:subscribe({
					next = function(_self, result: any)
						local condition = count
						if condition == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(data1)
							setTimeout(
								function()
									subHandle:unsubscribe()
									resolve()
								end,
								-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
								15 * TICK
							)
							count += 1
						else
							reject(Error.new("Only expected one result, not multiple"))
						end
					end,
				})
			end)

			itAsync(it)(
				"should let you handle multiple polled queries and unsubscribe from one of them",
				function(resolve, reject)
					local query1 = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])
					local query2 = gql([[

        query {
          person {
            name
          }
        }
      ]])
					local data11 = {
						author = {
							firstName = "John",
							lastName = "Smith",
						},
					}
					local data12 = {
						author = {
							firstName = "Jack",
							lastName = "Smith",
						},
					}
					local data13 = {
						author = {
							firstName = "Jolly",
							lastName = "Smith",
						},
					}
					local data14 = {
						author = {
							firstName = "Jared",
							lastName = "Smith",
						},
					}
					local data21 = {
						person = {
							name = "Jane Smith",
						},
					}
					local data22 = {
						person = {
							name = "Josey Smith",
						},
					}
					local queryManager = mockQueryManager(reject, {
						request = { query = query1 },
						result = { data = data11 },
					}, {
						request = { query = query1 },
						result = { data = data12 },
					}, {
						request = { query = query1 },
						result = { data = data13 },
					}, {
						request = { query = query1 },
						result = { data = data14 },
					}, {
						request = { query = query2 },
						result = { data = data21 },
					}, {
						request = { query = query2 },
						result = { data = data22 },
					})
					local handle1Count = 0
					local handleCount = 0
					local setMilestone = false

					local subscription1
					subscription1 = queryManager
						:watchQuery({
							query = query1,
							pollInterval = 150,
						})
						:subscribe({
							next = function(_self)
								handle1Count += 1
								handleCount += 1
								if handle1Count > 1 and not setMilestone then
									subscription1:unsubscribe()
									setMilestone = true
								end
							end,
						})

					local subscription2 = queryManager
						:watchQuery({
							query = query2,
							pollInterval = 2000,
						})
						:subscribe({
							next = function(_self)
								handleCount += 1
							end,
						})

					setTimeout(function()
						jestExpect(handleCount).toBe(3)
						subscription1:unsubscribe()
						subscription2:unsubscribe()
						resolve()
					end, 400)
				end
			)

			itAsync(it)("allows you to unsubscribe from polled queries", function(resolve, reject)
				local query = gql([[

        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]])

				local variables = {
					id = "1",
				}
				local data1 = {
					people_one = {
						name = "Luke Skywalker",
					},
				}

				local data2 = {
					people_one = {
						name = "Luke Skywalker has a new name",
					},
				}

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data1 } },
					{ request = { query = query, variables = variables }, result = { data = data2 } }
				)
				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					pollInterval = 50,
					notifyOnNetworkStatusChange = false,
				})
				local promise, subscription
				local ref = observableToPromiseAndSubscription({ observable = observable, wait = 60 }, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data1)
				end, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data2)

					-- we unsubscribe here manually, rather than waiting for the timeout.
					subscription:unsubscribe()
				end)
				promise, subscription = ref.promise, ref.subscription

				return promise:andThen(resolve, reject)
			end)

			itAsync(it)("allows you to unsubscribe from polled query errors", function(resolve, reject)
				local query = gql([[

        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]])
				local variables = {
					id = "1",
				}
				local data1 = {
					people_one = {
						name = "Luke Skywalker",
					},
				}

				local data2 = {
					people_one = {
						name = "Luke Skywalker has a new name",
					},
				}

				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data1 },
				}, {
					request = { query = query, variables = variables },
					error = Error.new("Network error"),
				}, {
					request = { query = query, variables = variables },
					result = { data = data2 },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					pollInterval = 50,
					notifyOnNetworkStatusChange = false,
				})

				local isFinished = false
				process.once("unhandledRejection", function()
					if not isFinished then
						reject("unhandledRejection from network")
					end
				end)

				local promise, subscription
				local ref = observableToPromiseAndSubscription({
					observable = observable,
					-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
					wait = 60 * TICK,
					errorCallbacks = {
						function(error_)
							jestExpect(error_.message).toMatch("Network error")
							subscription:unsubscribe()
						end,
					},
				} :: FIX_ANALYZE, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data1)
				end)
				promise, subscription = ref.promise, ref.subscription

				promise:andThen(function()
					setTimeout(
						function()
							isFinished = true
							resolve()
						end,
						-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
						4 * TICK
					)
				end)
			end)

			itAsync(it)("exposes a way to start a polling query", function(resolve, reject)
				local query = gql([[

        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]])
				local variables = {
					id = "1",
				}

				local data1 = {
					people_one = {
						name = "Luke Skywalker",
					},
				}

				local data2 = {
					people_one = {
						name = "Luke Skywalker has a new name",
					},
				}

				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data1 },
				}, {
					request = { query = query, variables = variables },
					result = { data = data2 },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					notifyOnNetworkStatusChange = false,
				})
				observable:startPolling(50)

				return observableToPromise({ observable = observable }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data1)
				end, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data2)
				end):andThen(resolve, reject)
			end)

			itAsync(it)("exposes a way to stop a polling query", function(resolve, reject)
				local query = gql([[

        query fetchLeia($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]])
				local variables = {
					id = "2",
				}

				local data1 = {
					people_one = {
						name = "Leia Skywalker",
					},
				}

				local data2 = {
					people_one = {
						name = "Leia Skywalker has a new name",
					},
				}

				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data1 },
				}, {
					request = { query = query, variables = variables },
					result = { data = data2 },
				})
				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					pollInterval = 50,
				})

				return observableToPromise({ observable = observable, wait = 60 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data1)
					observable:stopPolling()
				end):andThen(resolve, reject)
			end)

			itAsync(it)("stopped polling queries still get updates", function(resolve, reject)
				local query = gql([[

        query fetchLeia($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]])
				local variables = {
					id = "2",
				}

				local data1 = {
					people_one = {
						name = "Leia Skywalker",
					},
				}

				local data2 = {
					people_one = {
						name = "Leia Skywalker has a new name",
					},
				}

				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data1 },
				}, {
					request = { query = query, variables = variables },
					result = { data = data2 },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
					pollInterval = 50 * TICK,
				})

				return Promise.all({
					observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data1)
						queryManager
							:query({
								query = query,
								variables = variables,
								fetchPolicy = "network-only",
							})
							:andThen(function(result)
								jestExpect(result.data).toEqual(data2)
							end)
							:catch(reject)
					end, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data2)
					end),
				}):andThen(resolve, reject)
			end)
		end)

		describe("store resets", function()
			itAsync(it)("returns a promise resolving when all queries have been refetched", function(resolve, reject)
				local query = gql([[

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

				local dataChanged = {
					author = {
						firstName = "John changed",
						lastName = "Smith",
					},
				}

				local query2 = gql([[

        query {
          author2 {
            firstName
            lastName
          }
        }
      ]])
				local data2 = {
					author2 = {
						firstName = "John",
						lastName = "Smith",
					},
				}

				local data2Changed = {
					author2 = {
						firstName = "John changed",
						lastName = "Smith",
					},
				}

				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query },
						result = { data = data },
					}, {
						request = { query = query2 },
						result = { data = data2 },
					}, {
						request = { query = query },
						result = { data = dataChanged },
					}, {
						request = { query = query2 },
						result = { data = data2Changed },
					}):setOnError(reject),
				})

				local observable = queryManager:watchQuery({ query = query })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise.all({
					observableToPromise({ observable = observable }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data)
					end),
					observableToPromise({ observable = observable2 }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data2)
					end),
				})
					:andThen(function()
						observable:subscribe({
							next = function(_self)
								return NULL
							end,
						})
						observable2:subscribe({
							next = function(_self)
								return NULL
							end,
						})

						return queryManager:resetStore():andThen(function()
							local result = getCurrentQueryResult(observable)
							jestExpect(result.partial).toBe(false)
							jestExpect(stripSymbols(result.data)).toEqual(dataChanged)

							local result2 = getCurrentQueryResult(observable2)
							jestExpect(result2.partial).toBe(false)
							jestExpect(stripSymbols(result2.data)).toEqual(data2Changed)
						end)
					end)
					:andThen(resolve, reject)
			end)

			itAsync(it)("should change the store state to an empty state", function(resolve, reject)
				local queryManager = createQueryManager({
					link = mockSingleLink():setOnError(reject),
				})

				queryManager:resetStore()

				jestExpect(queryManager.cache:extract()).toEqual({})
				jestExpect(queryManager:getQueryStore()).toEqual({})
				jestExpect(queryManager.mutationStore).toEqual({})

				resolve()
			end)

			it("should only refetch once when we store reset", function()
				local queryManager: QueryManager<NormalizedCacheObject>
				local query = gql([[

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

				local data2 = {
					author = {
						firstName = "Johnny",
						lastName = "Smith",
					},
				}

				local timesFired = 0
				local link: ApolloLink = ApolloLink.new(function(op)
					return Observable.new(function(observer)
						timesFired += 1
						if timesFired > 1 then
							observer:next({ data = data2 })
						else
							observer:next({ data = data })
						end
						observer:complete()
						return
					end)
				end)
				queryManager = createQueryManager({ link = link })
				local observable = queryManager:watchQuery({ query = query })

				-- wait just to make sure the observable doesn't fire again
				return observableToPromise({ observable = observable, wait = 0 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(timesFired).toBe(1)
					-- reset the store after data has returned
					queryManager:resetStore()
				end, function(result)
					-- only refetch once and make sure data has changed
					jestExpect(stripSymbols(result.data)).toEqual(data2)
					jestExpect(timesFired).toBe(2)
				end):timeout(3):expect()
			end)

			itAsync(it)("should not refetch torn-down queries", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local observable: ObservableQuery_<any>
				local query = gql([[

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
							return
						end)
					end,
				})

				queryManager = createQueryManager({ link = link })
				observable = queryManager:watchQuery({ query = query })

				observableToPromise({ observable = observable, wait = 0 }, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data)
				end):andThen(function()
					jestExpect(timesFired).toBe(1)

					-- at this point the observable query has been torn down
					-- because observableToPromise unsubscribe before resolving
					queryManager:resetStore()

					setTimeout(function()
						jestExpect(timesFired).toBe(1)
						resolve()
					end, 50)
				end)
			end)

			itAsync(it)("should not error when resetStore called", function(resolve, reject)
				local query = gql([[

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
				local link = ApolloLink.from({
					ApolloLink.new(function()
						return Observable.new(function(observer)
							timesFired += 1
							observer:next({ data = data })
							observer:complete()
							return
						end)
					end),
				})

				local queryManager = createQueryManager({ link = link })

				local observable = queryManager:watchQuery({
					query = query,
					notifyOnNetworkStatusChange = false,
				})

				-- wait to make sure store reset happened
				return observableToPromise({ observable = observable, wait = 20 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(timesFired).toBe(1)
					queryManager:resetStore():catch(reject)
				end, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(timesFired).toBe(2)
				end):andThen(resolve, reject)
			end)

			itAsync(it)("should not error on a stopped query()", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local query = gql([[

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

				local link = ApolloLink.new(function()
					return Observable.new(function(observer)
						observer:next({ data = data })
					end)
				end)

				queryManager = createQueryManager({ link = link })

				local queryId = "1"
				queryManager:fetchQuery(queryId, { query = query }):catch(function(e)
					return reject("Exception thrown for stopped query")
				end)

				queryManager:removeQuery(queryId)
				queryManager:resetStore():andThen(resolve, reject)
			end)

			itAsync(it)(
				"should throw an error on an inflight fetch query if the store is reset",
				function(resolve, reject)
					local query = gql([[

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
					local queryManager = mockQueryManager(reject, {
						request = { query = query },
						result = { data = data },
						delay = 10000, --i.e. forever
					})
					queryManager
						:fetchQuery("made up id", { query = query })
						:andThen(function()
							reject(Error.new("Returned a result."))
						end)
						:catch(function(error_)
							jestExpect(error_.message).toMatch("Store reset")
							resolve()
						end)
					-- Need to delay the reset at least until the fetchRequest method
					-- has had a chance to enter this request into fetchQueryRejectFns.
					setTimeout(function()
						return queryManager:resetStore()
					end, 100)
				end
			)

			itAsync(it)("should call refetch on a mocked Observable if the store is reset", function(resolve, reject)
				local query = gql([[

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
				local queryManager = mockQueryManager(reject, {
					request = { query = query },
					result = { data = data },
				})
				local obs = queryManager:watchQuery({ query = query })
				obs:subscribe({})
				-- ROBLOX deviation: as resolve doesn't return anything it causes execution error
				obs.refetch = function()
					resolve()
					return Promise.resolve()
				end :: any

				queryManager:resetStore()
			end)

			itAsync(it)(
				"should not call refetch on a cache-only Observable if the store is reset",
				function(resolve, reject)
					local query = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])

					local queryManager = createQueryManager({
						link = mockSingleLink():setOnError(reject),
					})

					local options = (
							{
								query = query,
								fetchPolicy = "cache-only",
							} :: FIX_ANALYZE
						) :: WatchQueryOptions__

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)
					obs:subscribe({})
					obs.refetch = function()
						refetchCount += 1
						return NULL :: any
					end

					queryManager:resetStore()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsync(it)(
				"should not call refetch on a standby Observable if the store is reset",
				function(resolve, reject)
					local query = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])
					local queryManager = createQueryManager({
						link = mockSingleLink():setOnError(reject),
					})

					local options = ({
						query = query,
						fetchPolicy = "standby",
					} :: FIX_ANALYZE) :: WatchQueryOptions__

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)
					obs:subscribe({})
					obs.refetch = function()
						refetchCount += 1
						return NULL :: any
					end

					queryManager:resetStore()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsync(it)(
				"should not call refetch on a non-subscribed Observable if the store is reset",
				function(resolve, reject)
					local query = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])

					local queryManager = createQueryManager({
						link = mockSingleLink():setOnError(reject),
					})

					local options = {
						query = query,
					} :: WatchQueryOptions__

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)

					obs.refetch = function()
						refetchCount += 1
						return NULL :: any
					end

					queryManager:resetStore()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsync(it)("should throw an error on an inflight query() if the store is reset", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local query = gql([[

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
				local link = ApolloLink.new(function()
					return Observable.new(function(observer)
						-- reset the store as soon as we hear about the query
						queryManager:resetStore()
						observer:next({ data = data })
						return
					end)
				end)

				queryManager = createQueryManager({ link = link })
				queryManager
					:query({ query = query })
					:andThen(function(result)
						reject(Error.new("query() gave results on a store reset"))
					end)
					:catch(function()
						resolve()
					end)
			end)
		end)

		describe("refetching observed queries", function()
			itAsync(it)("returns a promise resolving when all queries have been refetched_", function(resolve, reject)
				local query = gql([[

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

				local dataChanged = {
					author = {
						firstName = "John changed",
						lastName = "Smith",
					},
				}

				local query2 = gql([[

        query {
          author2 {
            firstName
            lastName
          }
        }
      ]])

				local data2 = {
					author2 = {
						firstName = "John",
						lastName = "Smith",
					},
				}

				local data2Changed = {
					author2 = {
						firstName = "John changed",
						lastName = "Smith",
					},
				}

				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query },
						result = { data = data },
					}, {
						request = { query = query2 },
						result = { data = data2 },
					}, {
						request = { query = query },
						result = { data = dataChanged },
					}, {
						request = { query = query2 },
						result = { data = data2Changed },
					}):setOnError(reject),
				})

				local observable = queryManager:watchQuery({ query = query })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise.all({
					observableToPromise({ observable = observable }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data)
					end),
					observableToPromise({ observable = observable2 }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data2)
					end),
				})
					:andThen(function()
						observable:subscribe({
							next = function(_self)
								return NULL
							end,
						})
						observable2:subscribe({
							next = function(_self)
								return NULL
							end,
						})

						return queryManager:reFetchObservableQueries():andThen(function()
							local result = getCurrentQueryResult(observable)
							jestExpect(result.partial).toBe(false)
							jestExpect(stripSymbols(result.data)).toEqual(dataChanged)

							local result2 = getCurrentQueryResult(observable2)
							jestExpect(result2.partial).toBe(false)
							jestExpect(stripSymbols(result2.data)).toEqual(data2Changed)
						end)
					end)
					:andThen(resolve, reject)
			end)

			itAsync(it)("should only refetch once when we refetch observable queries", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local query = gql([[

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

				local data2 = {
					author = {
						firstName = "Johnny",
						lastName = "Smith",
					},
				}

				local timesFired = 0
				local link: ApolloLink = ApolloLink.new(function(op)
					return Observable.new(function(observer)
						timesFired += 1
						if timesFired > 1 then
							observer:next({ data = data2 })
						else
							observer:next({ data = data })
						end
						observer:complete()
						return
					end)
				end)
				queryManager = createQueryManager({ link = link })
				local observable = queryManager:watchQuery({ query = query })

				-- wait just to make sure the observable doesn't fire again
				return observableToPromise({ observable = observable, wait = 0 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(timesFired).toBe(1)
					-- refetch the observed queries after data has returned
					queryManager:reFetchObservableQueries()
				end, function(result)
					-- only refetch once and make sure data has changed
					jestExpect(stripSymbols(result.data)).toEqual(data2)
					jestExpect(timesFired).toBe(2)
					resolve()
				end):catch(function(e)
					reject(e)
				end)
			end)

			itAsync(it)("should not refetch torn-down queries_", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local observable: ObservableQuery_<any>
				local query = gql([[

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
							return
						end)
					end,
				})

				queryManager = createQueryManager({ link = link })
				observable = queryManager:watchQuery({ query = query })

				observableToPromise({ observable = observable, wait = 0 }, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data)
				end):andThen(function()
					jestExpect(timesFired).toBe(1)

					-- at this point the observable query has been torn down
					-- because observableToPromise unsubscribe before resolving
					queryManager:reFetchObservableQueries()
					setTimeout(function()
						jestExpect(timesFired).toBe(1)
						resolve()
					end, 50)
				end)
			end)

			itAsync(it)("should not error after reFetchObservableQueries", function(resolve, reject)
				local query = gql([[

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
				local link = ApolloLink.from({
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
					query = query,
					notifyOnNetworkStatusChange = false,
				})

				-- wait to make sure store reset happened
				return observableToPromise({
					observable = observable,
					wait = 20,
				}, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(timesFired).toBe(1)
					queryManager:reFetchObservableQueries()
				end, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(timesFired).toBe(2)
				end):andThen(resolve, reject)
			end)

			itAsync(it)(
				"should NOT throw an error on an inflight fetch query if the observable queries are refetched",
				function(resolve, reject)
					local query = gql([[

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

					local queryManager = mockQueryManager(reject, {
						request = { query = query },
						result = { data = data },
						delay = 100,
					})
					queryManager:fetchQuery("made up id", { query = query }):andThen(resolve):catch(function(error_)
						reject(Error.new("Should not return an error"))
					end)
					queryManager:reFetchObservableQueries()
				end
			)

			itAsync(it)(
				"should call refetch on a mocked Observable if the observed queries are refetched",
				function(resolve, reject)
					local query = gql([[

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
					local queryManager = mockQueryManager(reject, {
						request = { query = query },
						result = { data = data },
					})

					local obs = queryManager:watchQuery({ query = query })
					obs:subscribe({})
					obs.refetch = resolve :: any

					queryManager:reFetchObservableQueries()
				end
			)

			itAsync(it)(
				"should not call refetch on a cache-only Observable if the observed queries are refetched",
				function(resolve, reject)
					local query = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])

					local queryManager = createQueryManager({
						link = mockSingleLink():setOnError(reject),
					})

					local options = (
							{
								query = query,
								fetchPolicy = "cache-only",
							} :: FIX_ANALYZE
						) :: WatchQueryOptions__

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)
					obs:subscribe({})
					obs.refetch = function()
						refetchCount += 1
						return NULL :: any
					end

					queryManager:reFetchObservableQueries()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsync(it)(
				"should not call refetch on a standby Observable if the observed queries are refetched",
				function(resolve, reject)
					local query = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])

					local queryManager = createQueryManager({
						link = mockSingleLink():setOnError(reject),
					})

					local options = ({
						query = query,
						fetchPolicy = "standby",
					} :: FIX_ANALYZE) :: WatchQueryOptions__

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)
					obs:subscribe({})
					obs.refetch = function()
						refetchCount += 1
						return NULL :: any
					end

					queryManager:reFetchObservableQueries()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsync(it)(
				"should refetch on a standby Observable if the observed queries are refetched and the includeStandby parameter is set to true",
				function(resolve, reject)
					local query = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])

					local queryManager = createQueryManager({
						link = mockSingleLink():setOnError(reject),
					})

					local options = ({
						query = query,
						fetchPolicy = "standby",
					} :: any) :: WatchQueryOptions__

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)
					obs:subscribe({})
					obs.refetch = function()
						refetchCount += 1
						return NULL :: any
					end

					local includeStandBy = true
					queryManager:reFetchObservableQueries(includeStandBy)

					setTimeout(function()
						jestExpect(refetchCount).toEqual(1)
						resolve()
					end, 50)
				end
			)

			itAsync(it)("should not call refetch on a non-subscribed Observable", function(resolve, reject)
				local query = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])

				local queryManager = createQueryManager({
					link = mockSingleLink():setOnError(reject),
				})

				local options = {
					query = query,
				} :: WatchQueryOptions__

				local refetchCount = 0

				local obs = queryManager:watchQuery(options)
				obs.refetch = function()
					refetchCount += 1
					return NULL :: any
				end

				queryManager:reFetchObservableQueries()

				setTimeout(function()
					jestExpect(refetchCount).toEqual(0)
					resolve()
				end, 50)
			end)

			itAsync(it)(
				"should NOT throw an error on an inflight query() if the observed queries are refetched",
				function(resolve, reject)
					local queryManager: QueryManager<NormalizedCacheObject>
					local query = gql([[

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
					local link = ApolloLink.new(function()
						return Observable.new(function(observer)
							-- refetch observed queries as soon as we hear about the query
							queryManager:reFetchObservableQueries()
							observer:next({ data = data })
							observer:complete()
						end)
					end)

					queryManager = createQueryManager({ link = link })
					queryManager
						:query({ query = query })
						:andThen(function()
							resolve()
						end)
						:catch(function(e)
							reject(Error.new("query() should not throw error when refetching observed queriest"))
						end)
				end
			)
		end)

		describe("refetching specified queries", function()
			itAsync(it)("returns a promise resolving when all queries have been refetched__", function(resolve, reject)
				local query = gql([[

        query GetAuthor {
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

				local dataChanged = {
					author = {
						firstName = "John changed",
						lastName = "Smith",
					},
				}

				local query2 = gql([[

        query GetAuthor2 {
          author2 {
            firstName
            lastName
          }
        }
      ]])

				local data2 = {
					author2 = {
						firstName = "John",
						lastName = "Smith",
					},
				}

				local data2Changed = {
					author2 = {
						firstName = "John changed",
						lastName = "Smith",
					},
				}

				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query },
						result = { data = data },
					}, {
						request = { query = query2 },
						result = { data = data2 },
					}, {
						request = { query = query },
						result = { data = dataChanged },
					}, {
						request = { query = query2 },
						result = { data = data2Changed },
					}):setOnError(reject),
				})

				local observable = queryManager:watchQuery({ query = query })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise.all({
					observableToPromise({ observable = observable }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data)
					end),
					observableToPromise({ observable = observable2 }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data2)
					end),
				})
					:andThen(function()
						observable:subscribe({
							next = function(_self)
								return NULL
							end,
						})
						observable2:subscribe({
							next = function(_self)
								return NULL
							end,
						})
						local results: Array<any> = {}
						-- ROBLOX FIXME: add Map.forEach (and Set.forEach) to polyfill and use it here
						mapForEach(
							queryManager:refetchQueries({ include = { "GetAuthor", "GetAuthor2" } }) :: FIX_ANALYZE,
							function(result)
								return table.insert(results, result)
							end
						)

						return Promise.all(results):andThen(function()
							local result = getCurrentQueryResult(observable)
							jestExpect(result.partial).toBe(false)
							jestExpect(stripSymbols(result.data)).toEqual(dataChanged)

							local result2 = getCurrentQueryResult(observable2)
							jestExpect(result2.partial).toBe(false)
							jestExpect(stripSymbols(result2.data)).toEqual(data2Changed)
						end)
					end)
					:andThen(resolve, reject)
			end)
		end)

		describe("loading state", function()
			itAsync(it)("should be passed as false if we are not watching a query", function(resolve, reject)
				local query = gql([[

        query {
          fortuneCookie
        }
      ]])
				local data = {
					fortuneCookie = "Buy it",
				}
				return mockQueryManager(reject, {
					request = { query = query },
					result = { data = data },
				})
					:query({ query = query })
					:andThen(function(result)
						jestExpect(not result.loading).toBeTruthy()
						jestExpect(stripSymbols(result.data)).toEqual(data)
					end)
					:andThen(resolve, reject)
			end)

			itAsync(it)(
				"should be passed to the observer as true if we are returning partial data",
				function(resolve, reject)
					local fortuneCookie = "You must stick to your goal but rethink your approach"
					local primeQuery = gql([[

        query {
          fortuneCookie
        }
      ]])
					local primeData = { fortuneCookie = fortuneCookie }

					local author = { name = "John" }
					local query = gql([[

        query {
          fortuneCookie
          author {
            name
          }
        }
      ]])
					local fullData = { fortuneCookie = fortuneCookie, author = author }

					local queryManager = mockQueryManager(reject, {
						request = { query = query },
						result = { data = fullData },
						delay = 5,
					}, {
						request = { query = primeQuery },
						result = { data = primeData },
					})

					return queryManager
						:query({ query = primeQuery })
						:andThen(function(primeResult)
							local observable = queryManager:watchQuery({
								query = query,
								returnPartialData = true,
							})
							return observableToPromise({ observable = observable }, function(result)
								jestExpect(result.loading).toBe(true)
								jestExpect(result.data).toEqual(primeData)
							end, function(result)
								jestExpect(result.loading).toBe(false)
								jestExpect(result.data).toEqual(fullData)
							end) :: Promise<any>
						end)
						:andThen(resolve, reject)
				end
			)

			itAsync(it)(
				"should be passed to the observer as false if we are returning all the data",
				function(resolve, reject)
					assertWithObserver({
						reject = reject,
						query = gql([[

          query {
            author {
              firstName
              lastName
            }
          }
        ]]),
						result = {
							data = {
								author = {
									firstName = "John",
									lastName = "Smith",
								},
							},
						},
						observer = {
							next = function(_self, result)
								jestExpect(not Boolean.toJSBoolean(result.loading)).toBeTruthy()
								resolve()
							end,
						},
					})
				end
			)

			itAsync(it)("will update on `resetStore`", function(resolve, reject)
				local testQuery = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])
				local data1 = {
					author = {
						firstName = "John",
						lastName = "Smith",
					},
				}
				local data2 = {
					author = {
						firstName = "John",
						lastName = "Smith 2",
					},
				}
				local queryManager = mockQueryManager(reject, {
					request = { query = testQuery },
					result = { data = data1 },
				}, {
					request = { query = testQuery },
					result = { data = data2 },
				})
				local count = 0

				queryManager:watchQuery({ query = testQuery, notifyOnNetworkStatusChange = false }):subscribe({
					next = function(_self, result)
						local condition = count
						count += 1
						if condition == 0 then
							jestExpect(result.loading).toBe(false)
							jestExpect(stripSymbols(result.data)).toEqual(data1)
							setTimeout(function()
								queryManager:resetStore()
							end, 0)
						elseif condition == 1 then
							jestExpect(result.loading).toBe(false)
							jestExpect(stripSymbols(result.data)).toEqual(data2)
							resolve()
						else
							reject(Error.new("`next` was called to many times."))
						end
					end,
					error = function(_self, error_)
						return reject(error_)
					end,
				})
			end)

			itAsync(it)("will be true when partial data may be returned", function(resolve, reject)
				local query1 = gql([[{
        a { x1 y1 z1 }
      }]])
				local query2 = gql([[{
        a { x1 y1 z1 }
        b { x2 y2 z2 }
      }]])
				local data1 = {
					a = { x1 = 1, y1 = 2, z1 = 3 },
				}
				local data2 = {
					a = { x1 = 1, y1 = 2, z1 = 3 },
					b = { x2 = 3, y2 = 2, z2 = 1 },
				}
				local queryManager = mockQueryManager(reject, {
					request = { query = query1 },
					result = { data = data1 },
				}, {
					request = { query = query2 },
					result = { data = data2 },
					delay = 5,
				})

				queryManager:query({ query = query1 }):andThen(function(result1)
					jestExpect(result1.loading).toBe(false)
					jestExpect(result1.data).toEqual(data1)

					local count = 0
					queryManager:watchQuery({ query = query2, returnPartialData = true }):subscribe({
						next = function(_self, result2)
							local condition = count
							count += 1
							if condition == 0 then
								jestExpect(result2.loading).toBe(true)
								jestExpect(result2.data).toEqual(data1)
							elseif condition == 1 then
								jestExpect(result2.loading).toBe(false)
								jestExpect(result2.data).toEqual(data2)
								resolve()
							else
								reject(Error.new("`next` was called to many times."))
							end
						end,
						error = reject,
					})
				end)
				-- ROBLOX deviation: commenting out the next line to allow for the watchQuery to execute and resolve on it's own
				-- :andThen(resolve, reject)
			end)
		end)

		describe("refetchQueries", function()
			local consoleWarnSpy: Function

			-- ROBLOX deviation: using jest.fn instead of jest.spyOn until spyOn is implemented
			local oldConsoleWarn
			beforeEach(function()
				--[[
					ROBLOX deviation:
					using jest.fn instead of jest.spyOn until spyOn is implemented
					original code:
					consoleWarnSpy = jest:spyOn(console, "warn"):mockImplementation()
					
				]]
				consoleWarnSpy = jest.fn()
				oldConsoleWarn = console.warn
				console.warn = consoleWarnSpy
			end)
			afterEach(function()
				--[[
					ROBLOX deviation:
					restoring original function manually
					original code:
					consoleWarnSpy:mockRestore()
				]]
				console.warn = oldConsoleWarn
			end)

			itAsync(it)(
				"should refetch the right query when a result is successfully returned",
				function(resolve, reject)
					local mutation = gql([[

        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        }
      ]])
					local mutationData = {
						changeAuthorName = {
							firstName = "Jack",
							lastName = "Smith",
						},
					}
					local query = gql([[

        query getAuthors($id: ID!) {
          author(id: $id) {
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
					local secondReqData = {
						author = {
							firstName = "Jane",
							lastName = "Johnson",
						},
					}
					local variables = { id = "1234" }
					local queryManager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = { data = data },
					}, {
						request = { query = query, variables = variables },
						result = { data = secondReqData },
					}, {
						request = { query = mutation },
						result = { data = mutationData },
					})
					local observable = queryManager:watchQuery({
						query = query,
						variables = variables,
						notifyOnNetworkStatusChange = false,
					})
					return observableToPromise({
						observable = observable,
					}, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						queryManager:mutate({ mutation = mutation, refetchQueries = { "getAuthors" } })
					end, function(result)
						jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(secondReqData)
						jestExpect(stripSymbols(result.data)).toEqual(secondReqData)
					end):andThen(resolve, reject)
				end
			)

			itAsync(it)(
				"should not warn and continue when an unknown query name is asked to refetch",
				function(resolve, reject)
					local mutation = gql([[

        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        }
      ]])
					local mutationData = {
						changeAuthorName = {
							firstName = "Jack",
							lastName = "Smith",
						},
					}
					local query = gql([[

        query getAuthors {
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
					local secondReqData = {
						author = {
							firstName = "Jane",
							lastName = "Johnson",
						},
					}
					local queryManager = mockQueryManager(reject, {
						request = { query = query },
						result = { data = data },
					}, {
						request = { query = query },
						result = { data = secondReqData },
					}, {
						request = { query = mutation },
						result = { data = mutationData },
					})
					local observable = queryManager:watchQuery({
						query = query,
						notifyOnNetworkStatusChange = false,
					})
					return observableToPromise({
						observable = observable,
					}, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						queryManager:mutate({
							mutation = mutation,
							refetchQueries = { "fakeQuery", "getAuthors" },
						})
					end, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(secondReqData)
						jestExpect(consoleWarnSpy).toHaveBeenLastCalledWith(
							'Unknown query named "fakeQuery" requested in refetchQueries options.include array'
						)
					end):andThen(resolve, reject)
				end
			)

			itAsync(it)(
				"should ignore (with warning) a query named in refetchQueries that has no active subscriptions",
				function(resolve, reject)
					local mutation = gql([[

        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        }
      ]])
					local mutationData = {
						changeAuthorName = {
							firstName = "Jack",
							lastName = "Smith",
						},
					}
					local query = gql([[

        query getAuthors {
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
					local secondReqData = {
						author = {
							firstName = "Jane",
							lastName = "Johnson",
						},
					}
					local queryManager = mockQueryManager(reject, {
						request = { query = query },
						result = { data = data },
					}, {
						request = { query = query },
						result = { data = secondReqData },
					}, {
						request = { query = mutation },
						result = { data = mutationData },
					})

					local observable = queryManager:watchQuery({ query = query })
					return observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
					end)
						:andThen(function()
							-- The subscription has been stopped already
							return queryManager:mutate({
								mutation = mutation,
								refetchQueries = { "getAuthors" },
							})
						end)
						:andThen(function()
							jestExpect(consoleWarnSpy).toHaveBeenLastCalledWith(
								'Unknown query named "getAuthors" requested in refetchQueries options.include array'
							)
						end)
						:andThen(resolve, reject)
				end
			)

			itAsync(it)("also works with a query document and variables", function(resolve, reject)
				local mutation = gql([[

        mutation changeAuthorName($id: ID!) {
          changeAuthorName(newName: "Jack Smith", id: $id) {
            firstName
            lastName
          }
        }
      ]])
				local mutationData = {
					changeAuthorName = {
						firstName = "Jack",
						lastName = "Smith",
					},
				}
				local query = gql([[

        query getAuthors($id: ID!) {
          author(id: $id) {
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
				local secondReqData = {
					author = {
						firstName = "Jane",
						lastName = "Johnson",
					},
				}

				local variables = { id = "1234" }
				local mutationVariables = { id = "2345" }
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data },
					delay = 10,
				}, {
					request = { query = query, variables = variables },
					result = { data = secondReqData },
					delay = 100,
				}, {
					request = { query = mutation, variables = mutationVariables },
					result = { data = mutationData },
					delay = 10,
				})
				local observable = queryManager:watchQuery({ query = query, variables = variables })

				subscribeAndCount(reject, observable, function(count, result)
					if count == 1 then
						jestExpect(result.data).toEqual(data)
						queryManager:mutate({
							mutation = mutation,
							variables = mutationVariables,
							refetchQueries = { { query = query, variables = variables } },
						})
					elseif count == 2 then
						jestExpect(result.data).toEqual(secondReqData)
						jestExpect(observable:getCurrentResult().data).toEqual(secondReqData)

						return Promise.new(function(res)
							setTimeout(
								res,
								-- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
								10 * TICK
							)
						end)
							:andThen(function()
								-- Make sure the QueryManager cleans up legacy one-time queries like
								-- the one we requested above using refetchQueries.
								-- ROBLOX FIXME: add Map.forEach (and Set.forEach) to polyfill and use it here
								mapForEach(queryManager["queries"], function(queryInfo, queryId)
									jestExpect(queryId).never.toContain("legacyOneTimeQuery")
								end)
							end)
							:andThen(resolve, reject)
					else
						reject("too many results")
					end
				end)
			end)

			itAsync(it)("also works with a conditional function that returns false", function(resolve, reject)
				local mutation = gql([[

        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        }
      ]])
				local mutationData = {
					changeAuthorName = {
						firstName = "Jack",
						lastName = "Smith",
					},
				}
				local query = gql([[

        query getAuthors {
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
				local secondReqData = {
					author = {
						firstName = "Jane",
						lastName = "Johnson",
					},
				}
				local queryManager = mockQueryManager(reject, {
					request = { query = query },
					result = { data = data },
				}, {
					request = { query = query },
					result = { data = secondReqData },
				}, {
					request = { query = mutation },
					result = { data = mutationData },
				})
				local observable = queryManager:watchQuery({ query = query })
				local function conditional(result: FetchResult__<any>)
					jestExpect(stripSymbols(result.data)).toEqual(mutationData)
					return {}
				end

				return observableToPromise({ observable = observable }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					-- ROBLOX deviation: need to wait for promise resolution to call refetch
					return queryManager:mutate({ mutation = mutation, refetchQueries = conditional })
				end):andThen(resolve, reject)
			end)

			itAsync(it)(
				"also works with a conditional function that returns an array of refetches",
				function(resolve, reject)
					local mutation = gql([[

        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        }
      ]])
					local mutationData = {
						changeAuthorName = {
							firstName = "Jack",
							lastName = "Smith",
						},
					}
					local query = gql([[

        query getAuthors {
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
					local secondReqData = {
						author = {
							firstName = "Jane",
							lastName = "Johnson",
						},
					}
					local queryManager = mockQueryManager(reject, {
						request = { query = query },
						result = { data = data },
					}, {
						request = { query = query },
						result = { data = secondReqData },
					}, {
						request = { query = mutation },
						result = { data = mutationData },
					})
					local observable = queryManager:watchQuery({ query = query })
					local function conditional(result: FetchResult__<any>)
						jestExpect(stripSymbols(result.data)).toEqual(mutationData)
						return { { query = query } }
					end
					return observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						queryManager:mutate({ mutation = mutation, refetchQueries = conditional })
					end, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(secondReqData)
					end):andThen(resolve, reject)
				end
			)

			itAsync(it)("should refetch using the original query context (if any)", function(resolve, reject)
				local mutation = gql([[

        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        }
      ]])
				local mutationData = {
					changeAuthorName = {
						firstName = "Jack",
						lastName = "Smith",
					},
				}
				local query = gql([[

        query getAuthors($id: ID!) {
          author(id: $id) {
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
				local secondReqData = {
					author = {
						firstName = "Jane",
						lastName = "Johnson",
					},
				}
				local variables = { id = "1234" }
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data },
				}, {
					request = { query = query, variables = variables },
					result = { data = secondReqData },
				}, {
					request = { query = mutation },
					result = { data = mutationData },
				})

				local headers = {
					someHeader = "some value",
				}
				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					context = { headers = headers },
					notifyOnNetworkStatusChange = false,
				})

				return observableToPromise({ observable = observable }, function(result)
					queryManager:mutate({
						mutation = mutation,
						refetchQueries = { "getAuthors" },
					})
				end, function(result)
					local context = ((queryManager.link :: MockApolloLink).operation :: any):getContext()
					jestExpect(context.headers).never.toBeUndefined()
					jestExpect(context.headers.someHeader).toEqual(headers.someHeader)
				end):andThen(resolve, reject)
			end)

			itAsync(it)("should refetch using the specified context, if provided", function(resolve, reject)
				local mutation = gql([[

        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        }
      ]])
				local mutationData = {
					changeAuthorName = {
						firstName = "Jack",
						lastName = "Smith",
					},
				}
				local query = gql([[

        query getAuthors($id: ID!) {
          author(id: $id) {
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
				local secondReqData = {
					author = {
						firstName = "Jane",
						lastName = "Johnson",
					},
				}
				local variables = { id = "1234" }
				local queryManager = mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data },
				}, {
					request = { query = query, variables = variables },
					result = { data = secondReqData },
				}, {
					request = { query = mutation },
					result = { data = mutationData },
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					notifyOnNetworkStatusChange = false,
				})

				local headers = {
					someHeader = "some value",
				}

				return observableToPromise({ observable = observable }, function(result)
					queryManager:mutate({
						mutation = mutation,
						refetchQueries = {
							{
								query = query,
								variables = variables,
								context = { headers = headers },
							},
						},
					})
				end, function(result)
					local context = ((queryManager.link :: MockApolloLink).operation :: any):getContext()
					jestExpect(context.headers).never.toBeUndefined()
					jestExpect(context.headers.someHeader).toEqual(headers.someHeader)
				end):andThen(resolve, reject)
			end)
		end)

		describe("onQueryUpdated", function()
			local mutation = gql([[

      mutation changeAuthorName {
        changeAuthorName(newName: "Jack Smith") {
          firstName
          lastName
        }
      }
    ]])

			local mutationData = {
				changeAuthorName = {
					firstName = "Jack",
					lastName = "Smith",
				},
			}

			local query = gql([[

      query getAuthors($id: ID!) {
        author(id: $id) {
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

			local secondReqData = {
				author = {
					firstName = "Jane",
					lastName = "Johnson",
				},
			}

			local variables = { id = "1234" }

			local function makeQueryManager(reject: ((reason: any?) -> ()))
				return mockQueryManager(reject, {
					request = { query = query, variables = variables },
					result = { data = data },
				}, {
					request = { query = query, variables = variables },
					result = { data = secondReqData },
				}, {
					request = { query = mutation },
					result = { data = mutationData },
				})
			end

			itAsync(it)(
				"should refetch the right query when a result is successfully returned",
				function(resolve, reject)
					local queryManager = makeQueryManager(reject)

					local observable = queryManager:watchQuery({
						query = query,
						variables = variables,
						notifyOnNetworkStatusChange = false,
					})

					local finishedRefetch = false

					return observableToPromise({
						observable = observable,
					}, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)

						return queryManager
							:mutate({
								mutation = mutation,
								update = function(_self, cache)
									cache:modify({
										fields = {
											author = function(_self, _, ref)
												return ref.INVALIDATE
											end,
										},
									})
								end,
								onQueryUpdated = function(_self, obsQuery)
									jestExpect(obsQuery.options.query).toBe(query)
									return obsQuery:refetch():andThen(function(result)
										-- Wait a bit to make sure the mutation really awaited the
										-- refetching of the query.
										return Promise.new(function(resolve)
											setTimeout(resolve, 100)
										end):andThen(function()
											finishedRefetch = true
											return result
										end)
									end)
								end,
							})
							:andThen(function()
								jestExpect(finishedRefetch).toBe(true)
							end)
					end, function(result)
						jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(secondReqData)
						jestExpect(stripSymbols(result.data)).toEqual(secondReqData)
						jestExpect(finishedRefetch).toBe(true)
					end):andThen(resolve, reject)
				end
			)

			itAsync(it)("should refetch using the original query context (if any)", function(resolve, reject)
				local queryManager = makeQueryManager(reject)

				local headers = {
					someHeader = "some value",
				}

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					context = {
						headers = headers,
					},
					notifyOnNetworkStatusChange = false,
				})

				return observableToPromise({
					observable = observable,
				}, function(result)
					jestExpect(result.data).toEqual(data)

					queryManager:mutate({
						mutation = mutation,
						update = function(_self, cache)
							cache:modify({
								fields = {
									author = function(__self, _, ref)
										return ref.INVALIDATE
									end,
								},
							})
						end,
						onQueryUpdated = function(_self, obsQuery)
							jestExpect(obsQuery.options.query).toBe(query)
							return obsQuery:refetch()
						end,
					})
				end, function(result)
					jestExpect(result.data).toEqual(secondReqData)
					local context = ((queryManager.link :: MockApolloLink).operation :: any):getContext()
					jestExpect(context.headers).never.toBeUndefined()
					jestExpect(context.headers.someHeader).toEqual(headers.someHeader)
				end):andThen(resolve, reject)
			end)

			-- ROBLOX FIXME: Passes intermittently. Observable cancelled prematurely
			itAsync(itFIXME)("should refetch using the specified context, if provided", function(resolve, reject)
				local queryManager = makeQueryManager(reject)

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					notifyOnNetworkStatusChange = false,
				})

				local headers = {
					someHeader = "some value",
				}

				return observableToPromise({
					observable = observable,
				}, function(result)
					jestExpect(result.data).toEqual(data)

					queryManager:mutate({
						mutation = mutation,
						update = function(_self, cache)
							cache:evict({ fieldName = "author" })
						end,
						onQueryUpdated = function(_self, obsQuery)
							jestExpect(obsQuery.options.query).toBe(query)
							return obsQuery:reobserve({
								fetchPolicy = "network-only",
								context = Object.assign({}, obsQuery.options.context, { headers = headers }),
							})
						end,
					})
				end, function(result)
					jestExpect(result.data).toEqual(secondReqData)
					local context = ((queryManager.link :: MockApolloLink).operation :: any):getContext()
					jestExpect(context.headers).never.toBeUndefined()
					jestExpect(context.headers.someHeader).toEqual(headers.someHeader)
				end):andThen(resolve, reject)
			end)
		end)

		describe("awaitRefetchQueries", function()
			local function awaitRefetchTest(ref: MutationBaseOptions_<any, any, any> & { testQueryError: boolean? })
				local awaitRefetchQueries = ref.awaitRefetchQueries
				local testQueryError: boolean
				if ref.testQueryError == nil then
					testQueryError = false
				else
					testQueryError = (ref.testQueryError :: any) :: boolean
				end
				return Promise.new(function(resolve, reject)
					local query = gql([[

        query getAuthors($id: ID!) {
          author(id: $id) {
            firstName
            lastName
          }
        }
      ]])

					local queryData = {
						author = {
							firstName = "John",
							lastName = "Smith",
						},
					}

					local mutation = gql([[

        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        }
      ]])
					local mutationData = {
						changeAuthorName = {
							firstName = "Jack",
							lastName = "Smith",
						},
					}

					local secondReqData = {
						author = {
							firstName = "Jane",
							lastName = "Johnson",
						},
					}

					local variables = { id = "1234" }

					local refetchError: Error | nil = testQueryError and Error.new("Refetch failed") or nil

					local queryManager = mockQueryManager(reject, {
						request = { query = query, variables = variables },
						result = { data = queryData },
					}, {
						request = { query = mutation },
						result = { data = mutationData },
					}, {
						request = { query = query, variables = variables },
						result = { data = secondReqData },
						error = refetchError,
					})

					local observable = queryManager:watchQuery({
						query = query,
						variables = variables,
						notifyOnNetworkStatusChange = false,
					})

					local isRefetchErrorCaught = false
					local mutationComplete = false
					return observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(queryData)
						local mutateOptions: MutationOptions_<any, any, any> = {
							mutation = mutation,
							refetchQueries = { "getAuthors" },
						}
						if awaitRefetchQueries then
							mutateOptions.awaitRefetchQueries = awaitRefetchQueries
						end
						queryManager
							:mutate(mutateOptions)
							:andThen(function()
								mutationComplete = true
							end)
							:catch(function(error_)
								jestExpect(error_).toBeDefined()
								isRefetchErrorCaught = true
							end)
					end, function(result)
						if awaitRefetchQueries then
							jestExpect(mutationComplete).never.toBeTruthy()
						else
							jestExpect(mutationComplete).toBeTruthy()
						end
						jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(secondReqData)
						jestExpect(stripSymbols(result.data)).toEqual(secondReqData)
					end)
						:andThen(function()
							return resolve()
						end)
						:catch(function(error_)
							local isRefetchError: boolean = awaitRefetchQueries
								and testQueryError
								and refetchError
								and string.find(error_.message, refetchError.message, 1, true) ~= nil

							if isRefetchError then
								setTimeout(
									function()
										jestExpect(isRefetchErrorCaught).toBe(true)
										resolve()
									end, -- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
									10 * TICK
								)
								return
							end
							reject(error_)
						end)
				end)
			end

			it(
				"should not wait for `refetchQueries` to complete before resolving "
					.. "the mutation, when `awaitRefetchQueries` is undefined",
				function()
					return awaitRefetchTest({ awaitRefetchQueries = nil }):timeout(3):expect()
				end
			)

			it(
				"should not wait for `refetchQueries` to complete before resolving "
					.. "the mutation, when `awaitRefetchQueries` is false",
				function()
					return awaitRefetchTest({ awaitRefetchQueries = false }):timeout(3):expect()
				end
			)

			it(
				"should wait for `refetchQueries` to complete before resolving "
					.. "the mutation, when `awaitRefetchQueries` is `true`",
				function()
					return awaitRefetchTest({ awaitRefetchQueries = true }):timeout(3):expect()
				end
			)

			it(
				"should allow catching errors from `refetchQueries` when " .. "`awaitRefetchQueries` is `true`",
				function()
					return awaitRefetchTest({ awaitRefetchQueries = true, testQueryError = true }):timeout(3):expect()
				end
			)
		end)

		describe("store watchers", function()
			itAsync(it)("does not fill up the store on resolved queries", function(resolve, reject)
				local query1 = gql([[

        query One {
          one
        }
      ]])
				local query2 = gql([[

        query Two {
          two
        }
      ]])
				local query3 = gql([[

        query Three {
          three
        }
      ]])
				local query4 = gql([[

        query Four {
          four
        }
      ]])

				local link = mockSingleLink(
					{ request = { query = query1 }, result = { data = { one = 1 } } },
					{ request = { query = query2 }, result = { data = { two = 2 } } },
					{ request = { query = query3 }, result = { data = { three = 3 } } },
					{ request = { query = query4 }, result = { data = { four = 4 } } }
				):setOnError(reject)
				local cache = InMemoryCache.new()

				local queryManager = QueryManager.new({
					link = link,
					cache = cache,
				})

				return queryManager
					:query({ query = query1 })
					:andThen(function(one)
						return queryManager:query({ query = query2 })
					end)
					:andThen(function()
						return queryManager:query({ query = query3 })
					end)
					:andThen(function()
						return queryManager:query({ query = query4 })
					end)
					:andThen(function()
						return Promise.new(function(r)
							setTimeout(
								r, -- ROBLOX deviation: using multiple of TICK for timeout as it looks like the minimum value to ensure the correct order of execution
								10 * TICK
							)
						end)
					end)
					:andThen(function()
						-- @ts-ignore
						jestExpect((cache :: any).watches.size).toBe(0)
					end)
					:andThen(resolve, reject)
			end)
		end)

		describe("`no-cache` handling", function()
			itAsync(it)(
				"should return a query result (if one exists) when a `no-cache` fetch policy is used",
				function(resolve, reject)
					local query = gql([[

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

					local queryManager = createQueryManager({
						link = mockSingleLink({
							request = { query = query },
							result = { data = data },
						}):setOnError(reject),
					})

					local observable = queryManager:watchQuery({
						query = query,
						fetchPolicy = "no-cache",
					})
					observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						local currentResult = getCurrentQueryResult(observable)
						jestExpect(currentResult.data).toEqual(data)
						resolve()
					end)
				end
			)
		end)

		describe("client awareness", function()
			itAsync(it)(
				"should pass client awareness settings into the link chain via context",
				function(resolve, reject)
					local query = gql([[

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

					local link = mockSingleLink({
						request = { query = query },
						result = { data = data },
					}):setOnError(reject) :: MockLink

					local clientAwareness = {
						name = "Test",
						version = "1.0.0",
					}

					local queryManager = createQueryManager({
						link = link,
						clientAwareness = clientAwareness,
					})

					local observable = queryManager:watchQuery({
						query = query,
						fetchPolicy = "no-cache",
					})

					observableToPromise({ observable = observable }, function(result)
						local context = (link.operation :: any):getContext()
						jestExpect(context.clientAwareness).toBeDefined()
						jestExpect(context.clientAwareness).toEqual(clientAwareness)
						resolve()
					end)
				end
			)
		end)

		describe("queryDeduplication", function()
			it("should be true when context is true, default is false and argument not provided", function()
				local query = gql([[

        query {
          author {
            firstName
          }
        }
      ]])
				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query },
						result = {
							data = {
								author = { firstName = "John" },
							},
						},
					}),
				})

				queryManager:query({ query = query, context = { queryDeduplication = true } })

				jestExpect(queryManager["inFlightLinkObservables"].size).toBe(1)
			end)

			it("should allow overriding global queryDeduplication: true to false", function()
				local query = gql([[

        query {
          author {
            firstName
          }
        }
      ]])
				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query },
						result = {
							data = {
								author = { firstName = "John" },
							},
						},
					}),
					queryDeduplication = true,
				})

				queryManager:query({ query = query, context = { queryDeduplication = false } })

				jestExpect(queryManager["inFlightLinkObservables"].size).toBe(0)
			end)
		end)

		describe("missing cache field warnings", function()
			local verbosity: ReturnType<typeof(setVerbosity)>
			local spy: any
			-- ROBLOX deviation: using jest.fn instead of jest.spyOn until spyOn is implemented
			local oldConsoleDebug
			beforeEach(function()
				verbosity = setVerbosity("debug")
				--[[
					ROBLOX deviation:
					using jest.fn instead of jest.spyOn until spyOn is implemented
					original code:
					spy = jest:spyOn(console, "debug"):mockImplementation()
				]]
				spy = jest.fn()
				oldConsoleDebug = console.debug
				console.debug = spy
			end)

			afterEach(function()
				setVerbosity(verbosity)
				--[[
					ROBLOX deviation:
					restoring original function manually
					original code:
					spy:mockRestore()
				]]
				console.debug = oldConsoleDebug
			end)

			local function validateWarnings(
				resolve: ((result: any?) -> ()),
				reject: ((reason: any?) -> ()),
				returnPartialData: boolean?,
				expectedWarnCount: number?
			)
				if returnPartialData == nil then
					returnPartialData = false
				end
				if expectedWarnCount == nil then
					expectedWarnCount = 1
				end

				local query1 = gql([[

        query {
          car {
            make
            model
            id
            __typename
          }
        }
      ]])

				local query2 = gql([[

        query {
          car {
            make
            model
            vin
            id
            __typename
          }
        }
      ]])

				local data1 = {
					car = {
						make = "Ford",
						model = "Pinto",
						id = 123,
						__typename = "Car",
					},
				}
				local queryManager = mockQueryManager(reject, {
					request = { query = query1 },
					result = { data = data1 },
				})

				local observable1 = queryManager:watchQuery({ query = query1 })
				local observable2 = queryManager:watchQuery({
					query = query2,
					fetchPolicy = "cache-only",
					returnPartialData = returnPartialData,
				})

				return observableToPromise({ observable = observable1 }, function(result)
					jestExpect(result).toEqual({
						loading = false,
						data = data1,
						networkStatus = NetworkStatus.ready,
					})
				end):andThen(function()
					observableToPromise({ observable = observable2 }, function(result)
						jestExpect(result).toEqual({
							data = data1,
							loading = false,
							networkStatus = NetworkStatus.ready,
							partial = true,
						})
						jestExpect(spy).toHaveBeenCalledTimes(expectedWarnCount)
					end):andThen(resolve, reject)
				end)
			end

			itAsync(it)(
				"should show missing cache result fields warning when returnPartialData is false",
				function(resolve, reject)
					validateWarnings(resolve, reject, false, 1)
				end
			)

			itAsync(it)(
				"should not show missing cache result fields warning when returnPartialData is true",
				function(resolve, reject)
					validateWarnings(resolve, reject, true, 0)
				end
			)
		end)
	end)
end
