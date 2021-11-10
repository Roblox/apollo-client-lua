--!nocheck
--!nolint
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/__tests__/QueryManager/index.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Boolean, clearTimeout, console, Error, Object, setTimeout =
		LuauPolyfill.Boolean,
		LuauPolyfill.clearTimeout,
		LuauPolyfill.console,
		LuauPolyfill.Error,
		LuauPolyfill.Object,
		LuauPolyfill.setTimeout
	local Promise = require(rootWorkspace.Promise)
	local RegExp = require(rootWorkspace.LuauRegExp)

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest

	local HttpService = game:GetService("HttpService")

	-- ROBLOX comment: RXJS not ported
	-- local from = require(Packages.rxjs).from
	-- local map = require(Packages.rxjs.operators).map
	local assign = Object.assign
	local gql = require(rootWorkspace.Dev.GraphQLTag).default
	local graphqlModule = require(rootWorkspace.GraphQL)
	type DocumentNode = graphqlModule.DocumentNode
	local GraphQLError = graphqlModule.GraphQLError
	type GraphQLError = graphqlModule.GraphQLError
	-- ROBLOX TODO: port method
	-- local setVerbosity = require(rootWorkspace["ts-invariant"]).setVerbosity
	local setVerbosity = function(...) end
	local ObservableModule = require(srcWorkspace.utilities.observables.Observable)
	local Observable = ObservableModule.Observable
	type Observer<T> = ObservableModule.Observer<T>
	local coreModule = require(srcWorkspace.link.core)
	local ApolloLink = coreModule.ApolloLink
	local GraphQLRequest = coreModule.GraphQLRequest
	local FetchResult = coreModule.FetchResult
	local inMemoryCacheModule = require(srcWorkspace.cache.inmemory.inMemoryCache)
	local InMemoryCache = inMemoryCacheModule.InMemoryCache
	local InMemoryCacheConfig = inMemoryCacheModule.InMemoryCacheConfig
	local typesModule = require(srcWorkspace.cache.inmemory.types)
	type ApolloReducerConfig = typesModule.ApolloReducerConfig
	local NormalizedCacheObject = typesModule.NormalizedCacheObject
	-- local mockQueryManager = require(srcWorkspace.utilities.testing.mocking.mockQueryManager).default
	local mockQueryManager = function(...): ...any end
	-- local mockWatchQuery = require(srcWorkspace.utilities.testing.mocking.mockWatchQuery).default
	local mockLinkModule = require(srcWorkspace.utilities.testing.mocking.mockLink)
	-- local MockApolloLink = mockLinkModule.MockApolloLink
	local mockSingleLink = mockLinkModule.mockSingleLink
	-- local ApolloQueryResult = require(script.Parent.Parent.types).ApolloQueryResult
	local NetworkStatus = {} :: any
	-- local NetworkStatus = require(script.Parent.Parent.networkStatus).NetworkStatus
	-- local ObservableQuery = require(script.Parent.Parent.ObservableQuery).ObservableQuery
	-- local watchQueryOptionsModule = require(script.Parent.Parent.watchQueryOptions)
	-- local MutationBaseOptions = watchQueryOptionsModule.MutationBaseOptions
	-- local MutationOptions = watchQueryOptionsModule.MutationOptions
	-- local WatchQueryOptions = watchQueryOptionsModule.WatchQueryOptions
	local QueryManager = require(script.Parent.Parent.Parent.QueryManager).QueryManager
	local errorsModule = require(srcWorkspace.errors)
	type ApolloError = errorsModule.ApolloError
	local wrap = function(...): ...any end
	-- local wrap = require(srcWorkspace.utilities.testing.wrap).default
	-- local observableToPromiseModule = require(srcWorkspace.utilities.testing.observableToPromise)
	local observableToPromise = function(...): ...any end
	-- local observableToPromise = observableToPromiseModule.default
	local observableToPromiseAndSubscription = function(...): ...any end
	-- local observableToPromiseAndSubscription = observableToPromiseModule.observableToPromiseAndSubscription
	local subscribeAndCount = function(...): ...any end
	-- local subscribeAndCount = require(srcWorkspace.utilities.testing.subscribeAndCount).default
	local stripSymbols = require(srcWorkspace.utilities.testing.stripSymbols).stripSymbols
	local itAsyncModule = require(srcWorkspace.utilities.testing.itAsync)
	local itAsync = itAsyncModule(it)
	local itAsyncSkip = itAsyncModule(xit)
	local ApolloClient = require(srcWorkspace.core).ApolloClient
	local mockFetchQuery = require(script.Parent.Parent.Parent.ObservableQuery).mockFetchQuery

	-- ROBLOX TODO: not implemented
	local function fail(...) end
	local process = {
		once = function(...) end,
	}

	type MockedMutation = {
		reject: ((reason: any) -> any),
		mutation: DocumentNode,
		data: ({ [string]: any })?,
		errors: Array<GraphQLError>?,
		variables: ({ [string]: any })?,
		config: ApolloReducerConfig?,
	}

	xdescribe("QueryManager", function()
		-- Standard "get id from object" method.
		local function dataIdFromObject(object: any)
			if Boolean.toJSBoolean(object.__typename) and Boolean.toJSBoolean(object.id) then
				return tostring(object.__typename) .. "__" .. object.id
			end
			return nil
		end

		-- Helper method that serves as the constructor method for
		-- QueryManager but has defaults that make sense for these
		-- tests.
		local function createQueryManager(ref)
			local link, config, clientAwareness, queryDeduplication =
				ref.link, (function()
					if ref.config == nil then
						return {}
					else
						return ref.config
					end
				end)(), (function()
					if ref.clientAwareness == nil then
						return {}
					else
						return ref.clientAwareness
					end
				end)(), (function()
					if ref.queryDeduplication == nil then
						return false
					else
						return ref.queryDeduplication
					end
				end)()

			return QueryManager.new({
				link = link,
				cache = InMemoryCache.new(Object.assign({}, { addTypename = false }, config)),
				clientAwareness = clientAwareness,
				queryDeduplication = queryDeduplication,
				onBroadcast = function(self) end,
			})
		end

		-- Helper method that sets up a mockQueryManager and then passes on the
		-- results to an observer.
		local function assertWithObserver(ref)
			local reject, query, variables, queryOptions, result, error_, delay, observer =
				ref.reject, ref.query, (function()
					if ref.variables == nil then
						return {}
					else
						return ref.variables
					end
				end)(), (function()
					if ref.queryOptions == nil then
						return {}
					else
						return ref.queryOptions
					end
				end)(), ref.result, ref.error, ref.delay, ref.observer

			local queryManager = mockQueryManager(reject, {
				request = { query = query, variables = variables },
				result = result,
				["error"] = error_,
				delay = delay,
			})

			local finalOptions = assign({ query = query, variables = variables }, queryOptions) :: WatchQueryOptions

			return queryManager:watchQuery(finalOptions):subscribe({
				next = wrap(reject, observer.next),
				["error"] = observer.error_,
			})
		end

		local function mockMutation(ref)
			local reject, mutation, data, errors, variables, config =
				ref.reject, ref.mutation, ref.data, ref.errors, (function()
					if ref.variables == nil then
						return {}
					else
						return ref.variables
					end
				end)(), (function()
					if ref.config == nil then
						return {}
					else
						return ref.config
					end
				end)()

			local link = mockSingleLink({
				request = { query = mutation, variables = variables },
				result = { data = data, errors = errors },
			}):setOnError(reject)

			local queryManager = createQueryManager({ link = link, config = config })

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

		local function assertMutationRoundtrip(resolve: ((result: any) -> any), opts: MockedMutation)
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
		local function mockRefetch(ref)
			local reject, request, firstResult, secondResult, thirdResult =
				ref.reject, ref.request, ref.firstResult, ref.secondResult, ref.thirdResult
			local args = { { request = request, result = firstResult }, { request = request, result = secondResult } }
			if Boolean.toJSBoolean(thirdResult) then
				args:push({ request = request, result = thirdResult })
			end
			return mockQueryManager(reject, table.unpack(args, 1, #args))
		end

		local function getCurrentQueryResult(
			observableQuery: ObservableQuery<any, any>
		): { data: any, partial: boolean }
			local result = observableQuery:getCurrentResult()
			return { data = result.data, partial = Boolean.toJSBoolean(result.partial) }
		end

		itAsyncSkip("handles GraphQL errors", function(resolve, reject)
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
				result = { errors = { GraphQLError.new("This is an error message.") } },
				observer = {
					next = function(self)
						reject(Error.new("Returned a result when it was supposed to error out"))
					end,
					["error"] = function(self, apolloError)
						jestExpect(apolloError).toBeDefined()
						resolve()
					end,
				},
			})
		end)

		itAsyncSkip("handles GraphQL errors as data", function(resolve, reject)
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
					next = function(self, ref)
						local errors = ref.errors
						jestExpect(errors).toBeDefined()
						jestExpect(errors[1].message).toBe("This is an error message.")
						resolve()
					end,
					["error"] = function(self, apolloError)
						reject(Error.new("Called observer.error instead of passing errors to observer.next"))
					end,
				},
			})
		end)

		itAsyncSkip("handles GraphQL errors with data returned", function(resolve, reject)
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
					data = { allPeople = { people = { name = "Ada Lovelace" } } },
					errors = { GraphQLError.new("This is an error message.") },
				},
				observer = {
					next = function(self)
						reject(Error.new("Returned data when it was supposed to error out."))
					end,
					["error"] = function(self, apolloError)
						jestExpect(apolloError).toBeDefined()
						resolve()
					end,
				},
			})
		end)

		itAsyncSkip("empty error array (handle non-spec-compliant server) #156", function(resolve, reject)
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
				result = { data = { allPeople = { people = { name = "Ada Lovelace" } } }, errors = {} },
				observer = {
					next = function(self, result)
						jestExpect(result.data["allPeople"].people.name).toBe("Ada Lovelace")
						jestExpect(result["errors"]).toBeUndefined()
						resolve()
					end,
				},
			})
		end)

		-- Easy to get into this state if you write an incorrect `formatError`
		-- function with graphql-server or express-graphql
		itAsyncSkip("error array with nulls (handle non-spec-compliant server) #1185", function(resolve, reject)
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
				result = { errors = { nil :: any } },
				observer = {
					next = function(self)
						reject(Error.new("Should not fire next for an error"))
					end,
					["error"] = function(self, error_)
						jestExpect((error_ :: any).graphQLErrors).toEqual({ nil })
						jestExpect(error_.message).toBe("Error message not found.")
						resolve()
					end,
				},
			})
		end)

		itAsyncSkip("handles network errors", function(resolve, reject)
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
				["error"] = Error.new("Network error"),
				observer = {
					next = function()
						reject(Error.new("Should not deliver result"))
					end,
					["error"] = function(error_)
						local apolloError = error_ :: ApolloError
						jestExpect(apolloError.networkError).toBeDefined()
						jestExpect(apolloError.networkError.message).toMatch("Network error")
						resolve()
					end,
				},
			})
		end)

		itAsyncSkip("uses console.error to log unhandled errors", function(resolve, reject)
			local oldError = console.error_
			local printed: any
			console.error_ = function(...)
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
				["error"] = Error.new("Network error"),
				observer = {
					next = function()
						reject(Error.new("Should not deliver result"))
					end,
				},
			})

			setTimeout(function()
				jestExpect(printed[1]).toMatch(RegExp("error"))
				console.error_ = oldError
				resolve()
			end, 10)
		end)

		-- XXX this looks like a bug in zen-observable but we should figure
		-- out a solution for it
		itAsyncSkip("handles an unsubscribe action that happens before data returns", function(resolve, reject)
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
					next = function()
						reject(Error.new("Should not deliver result"))
					end,
					["error"] = function()
						reject(Error.new("Should not deliver result"))
					end,
				},
			})
			jestExpect(subscription.unsubscribe).never.toThrow()
		end)

		-- Query should be aborted on last .unsubscribe()
		itAsyncSkip("causes link unsubscription if unsubscribed", function(resolve, reject)
			local expResult = { data = { allPeople = { people = { { name = "Luke Skywalker" } } } } }

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

			local mockedResponse = { request = request, result = expResult }

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
				["error"] = observerCallback,
				complete = observerCallback,
			})

			subscription:unsubscribe()

			return Promise.new(
				-- Unsubscribing from the link happens after a microtask
				-- (Promise.resolve().then) delay, so we need to wait at least that
				-- long before verifying onRequestUnsubscribe was called.
				function(resolve)
					return setTimeout(resolve, 0)
				end
			)
				:andThen(function()
					jestExpect(onRequestSubscribe).toHaveBeenCalledTimes(1)
					jestExpect(onRequestUnsubscribe).toHaveBeenCalledTimes(1)
				end)
				:andThen(resolve, reject)
		end)

		-- ROBLOX comment: RXJS tests not required
		-- itAsyncSkip("supports interoperability with other Observable implementations like RxJS", function(resolve, reject)
		-- local expResult = {data = {allPeople = {people = {{name = "Luke Skywalker"}}}}}
		-- local handle = mockWatchQuery(reject, {request = {query = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
		--  --[[ gql`
		--           query people {
		--             allPeople(first: 1) {
		--               people {
		--                 name
		--               }
		--             }
		--           }
		--         ` ]]}, result = expResult})
		-- local observable = from(handle :: any)
		-- observable:pipe(map(function(result)
		-- return assign({fromRx = true}, result)
		-- end)):subscribe({next = wrap(reject, function(newResult)
		-- local expectedResult = assign({fromRx = true, loading = false, networkStatus = 7}, expResult)
		-- jestExpect(stripSymbols(newResult)).toEqual(expectedResult);
		-- resolve();
		-- end)});
		-- end);

		itAsyncSkip("allows you to subscribe twice to one query", function(resolve, reject)
			local request = {
				query = gql([[

					query fetchLuke($id: String) {
					  people_one(id: $id) {
						name
					  }
					}
				]]),
				variables = { id = "1" },
			}

			local data1 = { people_one = { name = "Luke Skywalker" } }

			local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

			local data3 = { people_one = { name = "Luke Skywalker has another name" } }

			local queryManager = mockQueryManager(reject, { request = request, result = { data = data1 } }, {
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
					next = function(self, result)
						(function()
							local result = subOneCount
							subOneCount += 1
							return result
						end)()
						if subOneCount == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(data1)
						elseif subOneCount == 2 then
							jestExpect(stripSymbols(result.data)).toEqual(data2)
						end
					end,
				})

				local subTwoCount = 0

				handle:subscribe({
					next = function(self, result)
						(function()
							local result = subTwoCount
							subTwoCount += 1
							return result
						end)()
						if subTwoCount == 1 then
							jestExpect(stripSymbols(result.data)).toEqual(data1)
							handle:refetch()
						elseif subTwoCount == 2 then
							jestExpect(stripSymbols(result.data)).toEqual(data2)
							setTimeout(function()
								do --[[ ROBLOX COMMENT: try-catch block conversion ]]
									xpcall(function()
										jestExpect(subOneCount).toBe(2)
										subOne:unsubscribe()
										handle:refetch()
									end, function(e)
										reject(e)
									end)
								end
							end, 0)
						elseif subTwoCount == 3 then
							setTimeout(function()
								do --[[ ROBLOX COMMENT: try-catch block conversion ]]
									local ok, result, hasReturned = xpcall(function()
										jestExpect(subOneCount).toBe(2)
										resolve()
									end, function(e)
										reject(e)
									end)
									if hasReturned then
										return result
									end
								end
							end, 0)
						end
					end,
				})
			end)
		end)

		itAsyncSkip("resolves all queries when one finishes after another", function(resolve, reject)
			local request = {
				query = gql([[
        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]]),
				variables = { id = "1" },
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
				variables = { id = "2" },
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
				variables = { id = "3" },
				notifyOnNetworkStatusChange = true,
			}
			local data1 = { people_one = { name = "Luke Skywalker" } }
			local data2 = { people_one = { name = "Leia Skywalker" } }
			local data3 = { people_one = { name = "Han Solo" } }

			local queryManager =
				mockQueryManager(
					reject,
					{ request = request, result = { data = data1 }, delay = 10 },
					{
						request = request2,
						result = { data = data2 },
						-- make the second request the slower one
						delay = 100,
					},
					{ request = request3, result = { data = data3 }, delay = 10 }
				)

			local ob1 = queryManager:watchQuery(request)
			local ob2 = queryManager:watchQuery(request2)
			local ob3 = queryManager:watchQuery(request3)

			local finishCount = 0
			ob1:subscribe(function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data1);
				(function()
					local result = finishCount
					finishCount += 1
					return result
				end)()
			end)
			ob2:subscribe(function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data2)
				jestExpect(finishCount).toBe(2)
				resolve()
			end)
			ob3:subscribe(function(result)
				jestExpect(stripSymbols(result.data)).toEqual(data3);
				(function()
					local result = finishCount
					finishCount += 1
					return result
				end)()
			end)
		end)

		itAsyncSkip("allows you to refetch queries", function(resolve, reject)
			local request = {
				query = gql([[
        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]]),
				variables = { id = "1" },
				notifyOnNetworkStatusChange = false,
			}
			local data1 = { people_one = { name = "Luke Skywalker" } }

			local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

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
				return jestExpect(stripSymbols(result.data)).toEqual(data2)
			end):andThen(resolve, reject)
		end)

		itAsyncSkip(
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

				local data1 = { a = 1, b = { c = 2 }, d = { e = 3, f = { g = 4 } } }

				local data2 = { a = 1, b = { c = 2 }, d = { e = 30, f = { g = 4 } } }

				local data3 = { a = 1, b = { c = 2 }, d = { e = 3, f = { g = 4 } } }

				local queryManager = mockRefetch({
					reject = reject,
					request = request,
					firstResult = { data = data1 },
					secondResult = { data = data2 },
					thirdResult = { data = data3 },
				})

				local observable = queryManager:watchQuery(request)

				local count = 0
				local firstResultData: any
				observable:subscribe({
					next = function(result)
						do --[[ ROBLOX COMMENT: try-catch block conversion ]]
							local _ok, result, hasReturned = xpcall(function()
								repeat --[[ ROBLOX comment: switch statement conversion ]]
									local entered_, break_ = false, false
									local condition_ = (function()
										local result = count
										count += 1
										return result
									end)()
									for _, v in ipairs({ 0, 1, 2 }) do
										if condition_ == v then
											if v == 0 then
												entered_ = true
												jestExpect(stripSymbols(result.data)).toEqual(data1)
												firstResultData = result.data
												observable:refetch()
												break_ = true
												break
											end
											if v == 1 or entered_ then
												entered_ = true
												jestExpect(stripSymbols(result.data)).toEqual(data2)
												jestExpect(result.data).not_.toEqual(firstResultData)
												jestExpect(result.data.b).toEqual(firstResultData.b)
												jestExpect(result.data.d).not_.toEqual(firstResultData.d)
												jestExpect(result.data.d.f).toEqual(firstResultData.d.f)
												observable:refetch()
												break_ = true
												break
											end
											if v == 2 or entered_ then
												entered_ = true
												jestExpect(stripSymbols(result.data)).toEqual(data3)
												jestExpect(result.data).toBe(firstResultData)
												resolve()
												break_ = true
												break
											end
										end
									end
									if not break_ then
										error(Error.new("Next run too many times."))
									end
								until true
							end, function(error_)
								reject(error_)
							end)
							if hasReturned then
								return result
							end
						end
					end,
					["error"] = reject,
				})
			end
		)

		itAsyncSkip(
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

				local data1 = { a = 1, b = { c = 2 }, d = { e = 3, f = { g = 4 } } }

				local queryManager = mockQueryManager(reject, { request = request, result = { data = data1 } })

				local observable = queryManager:watchQuery(request)

				observable:subscribe({
					next = function(result)
						do --[[ ROBLOX COMMENT: try-catch block conversion ]]
							local ok, result, hasReturned = xpcall(function()
								jestExpect(stripSymbols(result.data)).toEqual(data1)
								jestExpect(stripSymbols(result.data)).toEqual(
									stripSymbols(observable:getCurrentResult().data)
								)
								resolve()
							end, function(error_)
								reject(error_)
							end)
							if hasReturned then
								return result
							end
						end
					end,
					["error"] = reject,
				})
			end
		)

		itAsyncSkip("sets networkStatus to `refetch` when refetching", function(resolve, reject)
			local request: WatchQueryOptions = {
				query = gql([[
        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        }
      ]]),
				variables = { id = "1" },
				notifyOnNetworkStatusChange = true,
				-- This causes a loading:true result to be delivered from the cache
				-- before the final data2 result is delivered.
				fetchPolicy = "cache-and-network",
			}

			local data1 = { people_one = { name = "Luke Skywalker" } }

			local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

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

		itAsyncSkip("allows you to refetch queries with promises", function(resolve, reject)
			local request = {
				query = gql([[
          people_one(id: 1) {
            name
          }
        ]]),
			}

			local data1 = { people_one = { name = "Luke Skywalker" } }
			local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

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
					return jestExpect(stripSymbols(result.data)).toEqual(data2)
				end)
				:andThen(resolve, reject)
		end)

		itAsyncSkip("allows you to refetch queries with new variables", function(resolve, reject)
			local query = gql([[
      {
        people_one(id: 1) {
          name
        }
      ]])

			local data1 = { people_one = { name = "Luke Skywalker" } }
			local data2 = { people_one = { name = "Luke Skywalker has a new name" } }
			local data3 = { people_one = { name = "Luke Skywalker has a new name and age" } }
			local data4 = { people_one = { name = "Luke Skywalker has a whole new bag" } }

			local variables1 = { test = "I am your father" }
			local variables2 = { test = "No. No! That's not true! That's impossible!" }

			local queryManager = mockQueryManager(
				reject,
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data2 } },
				{ request = { query = query, variables = variables1 }, result = { data = data3 } },
				{ request = { query = query, variables = variables2 }, result = { data = data4 } }
			)

			local observable = queryManager:watchQuery({ query = query, notifyOnNetworkStatusChange = false })

			return observableToPromise({ observable = observable }, function(result)
				jestExpect(result.loading).toBe(false)
				jestExpect(result.data).toEqual(data1)
				return observable:refetch()
			end, function(result)
				jestExpect(result.loading).toBe(false)
				jestExpect(result.data).toEqual(data2)
				return observable:refetch(variables1)
			end, function(result)
				jestExpect(result.loading).toBe(false)
				jestExpect(result.data).toEqual(data3)
				return observable:refetch(variables2)
			end, function(result)
				jestExpect(result.loading).toBe(false)
				jestExpect(result.data).toEqual(data4)
			end):andThen(resolve, reject)
		end)

		itAsyncSkip("only modifies varaibles when refetching", function(resolve, reject)
			local query = gql([[
      {
        people_one(id: 1) {
          name
        }
      ]])

			local data1 = { people_one = { name = "Luke Skywalker" } }
			local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

			local queryManager = mockQueryManager(
				reject,
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data2 } }
			)

			local observable = queryManager:watchQuery({ query = query, notifyOnNetworkStatusChange = false })

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

		itAsyncSkip("continues to poll after refetch", function(resolve, reject)
			local query = gql([[
      {
        people_one(id: 1) {
          name
        }
      ]])

			local data1 = { people_one = { name = "Luke Skywalker" } }
			local data2 = { people_one = { name = "Luke Skywalker has a new name" } }
			local data3 = { people_one = { name = "Patsy" } }

			local queryManager = mockQueryManager(
				reject,
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data2 } },
				{ request = { query = query }, result = { data = data3 } }
			)

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

		itAsyncSkip("sets networkStatus to `poll` if a polling query is in flight", function(resolve, reject)
			local query = gql([[
      {
        people_one(id: 1) {
          name
        }
      ]])

			local data1 = { people_one = { name = "Luke Skywalker" } }
			local data2 = { people_one = { name = "Luke Skywalker has a new name" } }
			local data3 = { people_one = { name = "Patsy" } }

			local queryManager = mockQueryManager(
				reject,
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data2 } },
				{ request = { query = query }, result = { data = data3 } }
			)

			local observable = queryManager:watchQuery({
				query = query,
				pollInterval = 30,
				notifyOnNetworkStatusChange = true,
			})

			local counter = 0

			local handle = observable:subscribe({
				next = function(self, result)
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

		itAsyncSkip("can handle null values in arrays (#1551)", function(resolve, reject)
			local query = gql([[
      {
        list {
          value
        }
      ]])

			local data = { list = { nil, { value = 1 } } }

			local queryManager = mockQueryManager(reject, { request = { query = query }, result = { data = data } })

			local observable = queryManager:watchQuery({ query = query })

			observable:subscribe({
				next = function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(data)
					resolve()
				end,
			})
		end)

		itAsyncSkip("supports cache-only fetchPolicy fetching only cached data", function(resolve, reject)
			local spy = jest.spyOn(console, "warn"):mockImplementation()

			local primeQuery = gql([[
      query primeQuery {
        luke: people_one(id: 1) {
          name
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
      ]])

			local data1 = { luke = { name = "Luke Skywalker" } }

			local queryManager = mockQueryManager(
				reject,
				{ request = { query = primeQuery }, result = { data = data1 } }
			)

			return queryManager
				:query({ query = primeQuery })
				:andThen(function()
					local handle = queryManager:watchQuery({ query = complexQuery, fetchPolicy = "cache-only" })
					return handle:result():andThen(function(result)
						jestExpect(result.data["luke"].name).toBe("Luke Skywalker")
						jestExpect(result.data).not_.toHaveProperty("vader")
						jestExpect(spy).toHaveBeenCalledTimes(1)
					end)
				end)
				:finally(function()
					spy:mockRestore()
				end)
				:andThen(resolve, reject)
		end)

		itAsyncSkip("runs a mutation", function(resolve, reject)
			return assertMutationRoundtrip(resolve, {
				reject = reject,
				mutation = gql([[
        mutation makeListPrivate {
          makeListPrivate(id: "5")
        }
      ]]),
				data = { makeListPrivate = true },
			})
		end)

		itAsyncSkip("runs a mutation even when errors is empty array #2912", function(resolve, reject)
			return assertMutationRoundtrip(resolve, {
				reject = reject,
				mutation = gql([[
        mutation makeListPrivate {
          makeListPrivate(id: "5")
        }
      ]]),
				errors = {},
				data = { makeListPrivate = true },
			})
		end)

		itAsyncSkip('runs a mutation with default errorPolicy equal to "none"', function(resolve, reject)
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

		itAsyncSkip("runs a mutation with variables", function(resolve, reject)
			return assertMutationRoundtrip(resolve, {
				reject = reject,
				mutation = gql([[
        mutation makeListPrivate($listId: ID!) {
          makeListPrivate(id: $listId)
        }
      ]]),
				variables = { listId = "1" },
				data = { makeListPrivate = true },
			})
		end)

		local function getIdField(ref)
			local id = ref.id
			return id
		end

		itAsyncSkip("runs a mutation with object parameters and puts the result in the store", function(resolve, reject)
			local data = { makeListPrivate = { id = "5", isPrivate = true } }

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
			})
				:andThen(function(ref)
					local result, queryManager = ref.result, ref.queryManager
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(queryManager.cache:extract()["5"]).toEqual({ id = "5", isPrivate = true })
				end)
				:andThen(resolve, reject)
		end)

		itAsyncSkip("runs a mutation and puts the result in the store", function(resolve, reject)
			local data = { makeListPrivate = { id = "5", isPrivate = true } }
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
			})
				:andThen(function(ref)
					local result, queryManager = ref.result, ref.queryManager
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(queryManager.cache:extract()["5"]).toEqual({ id = "5", isPrivate = true })
				end)
				:andThen(resolve, reject)
		end)

		itAsyncSkip("runs a mutation and puts the result in the store with root key", function(resolve, reject)
			local mutation = gql([[
      mutation makeListPrivate {
        makeListPrivate(id: "5") {
          id
          isPrivate
        }
      ]])

			local data = { makeListPrivate = { id = "5", isPrivate = true } }

			local queryManager = createQueryManager({
				link = mockSingleLink({ request = { query = mutation }, result = { data = data } }):setOnError(reject),
				config = { dataIdFromObject = getIdField },
			})

			return queryManager
				:mutate({ mutation = mutation })
				:andThen(function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(queryManager.cache:extract()["5"]).toEqual({ id = "5", isPrivate = true })
				end)
				:andThen(resolve, reject)
		end)

		itAsyncSkip("doesn't return data while query is loading", function(resolve, reject)
			local query1 = gql([[
      {
        people_one(id: 1) {
          name
        }
      ]])

			local data1 = { people_one = { name = "Luke Skywalker" } }

			local query2 = gql([[
      {
        people_one(id: 5) {
          name
        }
      ]])

			local data2 = { people_one = { name = "Darth Vader" } }

			local queryManager = mockQueryManager(
				reject,
				{ request = { query = query1 }, result = { data = data1 }, delay = 10 },
				{ request = { query = query2 }, result = { data = data2 } }
			)

			local observable1 = queryManager:watchQuery({ query = query1 })
			local observable2 = queryManager:watchQuery({ query = query2 })

			return Promise
				:all({
					observableToPromise({ observable = observable1 }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data1)
					end),
					observableToPromise({ observable = observable2 }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data2)
					end),
				})
				:andThen(resolve, reject)
		end)

		itAsyncSkip("updates result of previous query if the result of a new query overlaps", function(resolve, reject)
			local query1 = gql([[
      {
        people_one(id: 1) {
          __typename
          id
          name
          age
        }
      ]])

			local data1 = { people_one = { __typename = "Human", id = 1, name = "Luke Skywalker", age = 50 } }

			local query2 = gql([[
      {
        people_one(id: 1) {
          __typename
          id
          name
          username
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

			local queryManager = mockQueryManager(
				reject,
				{ request = { query = query1 }, result = { data = data1 } },
				{ request = { query = query2 }, result = { data = data2 }, delay = 10 }
			)

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

		itAsyncSkip("warns if you forget the template literal tag", function(resolve, reject)
			local queryManager = mockQueryManager(reject)

			jestExpect(function()
				queryManager:query({
					-- Bamboozle TypeScript into letting us do this
					query = ("string" :: any) :: DocumentNode,
				})
			end).toThrowError(RegExp('wrap the query string in a "gql" tag'))

			jestExpect(queryManager:mutate({
				-- Bamboozle TypeScript into letting us do this
				mutation = ("string" :: any) :: DocumentNode,
			})).rejects.toThrow(RegExp('wrap the query string in a "gql" tag')):expect()

			jestExpect(function()
				queryManager:watchQuery({
					-- Bamboozle TypeScript into letting us do this
					query = ("string" :: any) :: DocumentNode,
				})
			end).toThrowError(RegExp('wrap the query string in a "gql" tag'))
			resolve()
		end)

		itAsyncSkip("should transform queries correctly when given a QueryTransformer", function(resolve, reject)
			local query = gql([[
      query {
        author {
          firstName
          lastName
        }
      ]])
			local transformedQuery = gql([[
      query {
        author {
          firstName
          lastName
          __typename
        }
      ]])

			local transformedQueryResult = {
				author = { firstName = "John", lastName = "Smith", __typename = "Author" },
			}

			createQueryManager({
				link = mockSingleLink({
					request = { query = transformedQuery },
					result = { data = transformedQueryResult },
				}):setOnError(reject),
				config = { addTypename = true },
			})
				:query({ query = query })
				:andThen(function(result)
					jestExpect(stripSymbols(result.data)).toEqual(transformedQueryResult)
				end)
				:andThen(resolve, reject)
		end)

		itAsyncSkip("should transform mutations correctly", function(resolve, reject)
			local mutation = gql([[
      mutation {
        createAuthor(firstName: "John", lastName: "Smith") {
          firstName
          lastName
        }
      ]])
			local transformedMutation = gql([[
      mutation {
        createAuthor(firstName: "John", lastName: "Smith") {
          firstName
          lastName
          __typename
        }
      ]])

			local transformedMutationResult = {
				createAuthor = { firstName = "It works!", lastName = "It works!", __typename = "Author" },
			}

			createQueryManager({
				link = mockSingleLink({
					request = { query = transformedMutation },
					result = { data = transformedMutationResult },
				}):setOnError(reject),
				config = { addTypename = true },
			}):mutate({ mutation = mutation }):andThen(function(result)
				jestExpect(stripSymbols(result.data)).toEqual(transformedMutationResult)
				resolve()
			end)
		end)

		itAsyncSkip("should reject a query promise given a network error", function(resolve, reject)
			local query = gql([[
      query {
        author {
          firstName
          lastName
        }
      ]])

			local networkError = Error.new("Network error")

			mockQueryManager(reject, { request = { query = query }, ["error"] = networkError })
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

		itAsyncSkip("should reject a query promise given a GraphQL error", function(resolve, reject)
			local query = gql([[
      query {
        author {
          firstName
          lastName
        }
      ]])

			local graphQLErrors = { GraphQLError.new("GraphQL error") }

			return mockQueryManager(reject, { request = { query = query }, result = { errors = graphQLErrors } })
				:query({ query = query })
				:andThen(function()
					error(Error.new("Returned result on an errored fetchQuery"))
				end, function(error_)
					local apolloError = error_ :: ApolloError
					jestExpect(apolloError.graphQLErrors).toEqual(graphQLErrors)
					jestExpect(not Boolean.toJSBoolean(apolloError.networkError)).toBeTruthy()
				end)
				:andThen(resolve, reject)
		end)

		itAsyncSkip(
			"should not empty the store when a non-polling query fails due to a network error",
			function(resolve, reject)
				local query = gql([[
      query {
        author {
          firstName
          lastName
        }
      ]])

				local data = { author = { firstName = "Dhaivat", lastName = "Pandya" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query }, result = { data = data } },
					{ request = { query = query }, ["error"] = Error.new("Network error ocurred") }
				)

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
								jestExpect(
									(
										error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ queryManager.cache.extract().ROOT_QUERY! ]]

									).author
								).toEqual(data.author)
								resolve()
							end)
					end)
					:catch(function()
						reject(Error.new("Threw an error on the first query."))
					end)
			end
		)

		itAsyncSkip("should be able to unsubscribe from a polling query subscription", function(resolve, reject)
			local query = gql([[
      query {
        author {
          firstName
          lastName
        }
      ]])

			local data = { author = { firstName = "John", lastName = "Smith" } }

			local observable =
				mockQueryManager(reject, { request = { query = query }, result = { data = data } }):watchQuery({
					query = query,
					pollInterval = 20,
				})

			local promise, subscription
			do
				local ref = observableToPromiseAndSubscription(
					{ observable = observable, wait = 60 },
					function(result: any)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						subscription:unsubscribe()
					end
				)
				promise, subscription = ref.promise, ref.subscription
			end

			return promise:andThen(resolve, reject)
		end)

		itAsyncSkip(
			"should not empty the store when a polling query fails due to a network error",
			function(resolve, reject)
				local query = gql([[
      query {
        author {
          firstName
          lastName
        }
      ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query }, result = { data = data } },
					{ request = { query = query }, ["error"] = Error.new("Network error occurred.") }
				)

				local observable = queryManager:watchQuery({
					query = query,
					pollInterval = 20,
					notifyOnNetworkStatusChange = false,
				})

				return observableToPromise({
					observable = observable,
					errorCallbacks = {
						function()
							jestExpect(
								(
									error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ queryManager.cache.extract().ROOT_QUERY! ]]

								).author
							).toEqual(data.author)
						end,
					},
				}, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(
						(
							error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ queryManager.cache.extract().ROOT_QUERY! ]]
						).author
					).toEqual(data.author)
				end):andThen(resolve, reject)
			end
		)

		itAsyncSkip("should not fire next on an observer if there is no change in the result", function(resolve, reject)
			local query = gql([[
      query {
        author {
          firstName
          lastName
        }
      ]])

			local data = { author = { firstName = "John", lastName = "Smith" } }

			local queryManager = mockQueryManager(
				reject,
				{ request = { query = query }, result = { data = data } },
				{ request = { query = query }, result = { data = data } }
			)

			local observable = queryManager:watchQuery({ query = query })

			return Promise
				:all({
					observableToPromise({ observable = observable, wait = 100 }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
					end),
					queryManager:query({ query = query }):andThen(function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
					end),
				})
				:andThen(resolve, reject)
		end)

		itAsyncSkip(
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
      ]])

				local data1 = {
					author = {
						name = { firstName = "John", lastName = "Smith" },
						age = 18,
						id = "187",
						__typename = "Author",
					},
				}
				local data2 = { author = { name = { firstName = "John" }, id = "197", __typename = "Author" } }

				local reducerConfig = { dataIdFromObject = dataIdFromObject }

				local queryManager = createQueryManager({
					link = mockSingleLink(
						{ request = { query = query1 }, result = { data = data1 } },
						{ request = { query = query2 }, result = { data = data2 } },
						{ request = { query = query1 }, result = { data = data1 } }
					):setOnError(reject),
					config = reducerConfig,
				})

				local observable1 = queryManager:watchQuery({ query = query1 })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise
					:all({
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
					})
					:andThen(resolve, reject)
			end
		)

		itAsyncSkip(
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
      ]])

				local data1 = {
					author = {
						name = { firstName = "John", lastName = "Smith" },
						age = 18,
						id = "187",
						__typename = "Author",
					},
				}
				local data2 = { author = { name = { firstName = "John" }, id = "197", __typename = "Author" } }

				local queryManager = createQueryManager({
					link = mockSingleLink(
						{ request = { query = query1 }, result = { data = data1 } },
						{ request = { query = query2 }, result = { data = data2 } }
					):setOnError(reject),
				})

				local observable1 = queryManager:watchQuery({ query = query1, returnPartialData = true })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise
					:all({
						observableToPromise({ observable = observable1 }, function(result)
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
						observableToPromise({ observable = observable2 }, function(result)
							jestExpect(result).toEqual({
								data = data2,
								loading = false,
								networkStatus = NetworkStatus.ready,
							})
						end),
					})
					:andThen(resolve, reject)
			end
		)

		itAsyncSkip("should not write unchanged network results to cache", function(resolve, reject)
			local cache = InMemoryCache.new({ typePolicies = { Query = { fields = { info = { merge = false } } } } })

			local client = ApolloClient.new({
				cache = cache,
				link = ApolloLink.new(function(operation)
					return Observable.new(function(observer: Observer<FetchResult>)
						repeat --[[ ROBLOX comment: switch statement conversion ]]
							local entered_, break_ = false, false
							local condition_ = operation.operationName
							for _, v in ipairs({ "A", "B" }) do
								if condition_ == v then
									if v == "A" then
										entered_ = true

										observer.next({ data = { info = { a = "ay" } } })
										break_ = true
										break
									end
									if v == "B" or entered_ then
										entered_ = true
										observer.next({ data = { info = { b = "bee" } } })
										break_ = true
										break
									end
								end
							end
						until true
						observer.complete()
					end)
				end),
			})

			local queryA = gql([[query A { info { a } }]])
			local queryB = gql([[query B { info { b } }]])

			local obsA = client:watchQuery({ query = queryA, returnPartialData = true })
			local obsB = client:watchQuery({ query = queryB, returnPartialData = true })

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
						data = { info = { a = "ay" } },
					})
				elseif count == 3 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = { info = {} },
						partial = true,
					})
				elseif count == 4 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = { info = { a = "ay" } },
					})
					setTimeout(resolve, 100)
				else
					reject(
						Error.new(("Unexpected %s"):format(HttpService.JSONEncode({ count = count, result = result })))
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
						data = { info = { b = "bee" } },
					})
				elseif count == 3 then
					jestExpect(result).toEqual({
						loading = true,
						networkStatus = NetworkStatus.loading,
						data = { info = {} },
					})
				elseif count == 4 then
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = { info = { b = "bee" } },
					})
					setTimeout(resolve, 100)
				else
					reject(
						Error.new(("Unexpected %s"):format(HttpService.JSONEncode({ count = count, result = result })))
					)
				end
			end)
		end)

		itAsyncSkip("should disable feud-stopping logic after evict or modify", function(resolve, reject)
			local cache = InMemoryCache.new({ typePolicies = { Query = { fields = { info = { merge = false } } } } })

			local client = ApolloClient.new({
				cache = cache,
				link = ApolloLink.new(function(operation)
					return Observable.new(function(observer: Observer<FetchResult>)
						(
							error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ observer.next! ]]
						)({ data = { info = { c = "see" } } });
						(
							error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ observer.complete! ]]
						)()
					end)
				end),
			})

			local query = gql([[query { info { c } }]])

			local obs = client:watchQuery({ query = query, returnPartialData = true })

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
						data = { info = { c = "see" } },
					})
					cache:evict({ fieldName = "info" })
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
						data = { info = { c = "see" } },
					})
					cache:modify({
						fields = {
							info = function(self, _, ref)
								local DELETE = ref.DELETE
								return DELETE
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
						data = { info = { c = "see" } },
					})
					setTimeout(resolve, 100)
				else
					reject(
						Error.new(("Unexpected %s"):format(HttpService.JSONEncode({ count = count, result = result })))
					)
				end
			end)
		end)

		itAsyncSkip("should not error when replacing unidentified data with a normalized ID", function(resolve, reject)
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
      ]])

			local dataWithoutId = {
				author = { name = { firstName = "John", lastName = "Smith" }, age = "124", __typename = "Author" },
			}
			local dataWithId = { author = { name = { firstName = "Jane" }, id = "129", __typename = "Author" } }

			local mergeCount = 0

			local queryManager = createQueryManager({
				link = mockSingleLink(
					{ request = { query = queryWithoutId }, result = { data = dataWithoutId } },
					{ request = { query = queryWithId }, result = { data = dataWithId } }
				):setOnError(reject),
				config = {
					typePolicies = {
						Query = {
							fields = {
								author = {
									merge = function(self, existing, incoming, ref)
										local isReference, readField = ref.isReference, ref.readField
										repeat --[[ ROBLOX comment: switch statement conversion ]]
											local entered_, break_ = false, false
											local condition_ = (function()
												mergeCount += 1
												return mergeCount
											end)()
											for _, v in ipairs({ 1, 2 }) do
												if condition_ == v then
													if v == 1 then
														entered_ = true
														jestExpect(existing).toBeUndefined()
														jestExpect(isReference(incoming)).toBe(false)
														jestExpect(incoming).toEqual(dataWithoutId.author)
														break_ = true
														break
													end
													if v == 2 or entered_ then
														entered_ = true
														jestExpect(existing).toEqual(dataWithoutId.author)
														jestExpect(isReference(incoming)).toBe(true)
														jestExpect(readField("id", incoming)).toBe("129")
														jestExpect(readField("name", incoming)).toEqual(
															dataWithId.author.name
														)
														break_ = true
														break
													end
												end
											end
											if not break_ then
												fail("unreached")
											end
										until true
										return incoming
									end,
								},
							},
						},
					},
				},
			})

			local observableWithId = queryManager:watchQuery({ query = queryWithId })

			local observableWithoutId = queryManager:watchQuery({ query = queryWithoutId })

			return Promise
				:all({
					observableToPromise({ observable = observableWithoutId }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(dataWithoutId)
					end),
					observableToPromise({ observable = observableWithId }, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(dataWithId)
					end),
				})
				:andThen(resolve, reject)
		end)

		itAsyncSkip("exposes errors on a refetch as a rejection", function(resolve, reject)
			local request = {
				query = gql([[
        {
          people_one(id: 1) {
            name
          }
        ]]),
			}

			local firstResult = { data = { people_one = { name = "Luke Skywalker" } } }
			local secondResult = { errors = { GraphQLError.new("This is not the person you are looking for.") } }

			local queryManager = mockRefetch({
				reject = reject,
				request = request,
				firstResult = firstResult,
				secondResult = secondResult,
			})

			local handle = queryManager:watchQuery(request)

			local function checkError(error_)
				jestExpect(error_.graphQLErrors[1].message).toEqual("This is not the person you are looking for.")
			end

			handle:subscribe({ ["error"] = checkError })

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

		itAsyncSkip(
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
      ]])
				local queryB = gql([[
      query queryB {
        person(id: "abc") {
          __typename
          id
          lastName
          age
        }
      ]])

				local dataA = {
					person = { __typename = "Person", id = "abc", firstName = "Luke", lastName = "Skywalker" },
				}
				local dataB = { person = { __typename = "Person", id = "abc", lastName = "Skywalker", age = "32" } }

				local queryManager = QueryManager.new({
					link = mockSingleLink(
						{ request = { query = queryA }, result = { data = dataA } },
						{ request = { query = queryB }, result = { data = dataB }, delay = 20 }
					):setOnError(reject),
					cache = InMemoryCache.new({}),
					ssrMode = true,
				})

				local observableA = queryManager:watchQuery({ query = queryA })
				local observableB = queryManager:watchQuery({ query = queryB })

				return Promise
					:all({
						observableToPromise({ observable = observableA }, function()
							jestExpect(stripSymbols(getCurrentQueryResult(observableA))).toEqual({
								data = dataA,
								partial = false,
							})
							jestExpect(getCurrentQueryResult(observableB)).toEqual({ data = nil, partial = true })
						end),
						observableToPromise({ observable = observableB }, function()
							jestExpect(stripSymbols(getCurrentQueryResult(observableA))).toEqual({
								data = dataA,
								partial = false,
							})
							jestExpect(getCurrentQueryResult(observableB)).toEqual({ data = dataB, partial = false })
						end),
					})
					:andThen(resolve, reject)
			end
		)

		itAsyncSkip(
			'only increments "queryInfo.lastRequestId" when fetching data from network',
			function(resolve, reject)
				local query = gql([[
      query query($id: ID!) {
        people_one(id: $id) {
          name
        }
      ]])

				local variables = { id = 1 }

				local dataOne = { people_one = { name = "Luke Skywalker" } }

				local mockedResponses = {
					{ request = { query = query, variables = variables }, result = { data = dataOne } },
				}

				local queryManager = mockQueryManager(reject, table.unpack(mockedResponses, 1, #mockedResponses))

				local queryOptions: WatchQueryOptions<any> = {
					query = query,
					variables = variables,
					fetchPolicy = "cache-and-network",
				}

				local observable = queryManager:watchQuery(queryOptions)

				local mocks = mockFetchQuery(queryManager)

				local queryId = "1"

				local getQuery: any --[[ QueryManager<any>["getQuery"] ]] = (queryManager :: any).getQuery:bind(
					queryManager
				)

				subscribeAndCount(reject, observable, function(handleCount)
					local query = getQuery(queryId)
					local fqbpCalls = mocks.fetchQueryByPolicy.mock.calls
					jestExpect(query.lastRequestId).toEqual(1)
					jestExpect(fqbpCalls.length).toBe(1)
					-- Simulate updating the options of the query, which will trigger
					-- fetchQueryByPolicy, but it should just read from cache and not
					-- update "queryInfo.lastRequestId". For more information, see
					-- https://github.com/apollographql/apollo-client/pull/7956#issue-610298427
					observable:setOptions(Object.assign({}, queryOptions, { fetchPolicy = "cache-first" })):expect()

					-- "fetchQueryByPolicy" was called, but "lastRequestId" does not update
					-- since it was able to read from cache.
					jestExpect(query.lastRequestId).toEqual(1)
					jestExpect(fqbpCalls.length).toBe(2)
					resolve()
				end)
			end
		)

		xdescribe("polling queries", function()
			itAsyncSkip("allows you to poll queries", function(resolve, reject)
				local query = gql([[
        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        ]])

				local variables = { id = "1" }

				local data1 = { people_one = { name = "Luke Skywalker" } }
				local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

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

				return observableToPromise({ observable = observable }, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data1)
				end, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data2)
				end):andThen(resolve, reject)
			end)

			itAsyncSkip("does not poll during SSR", function(resolve, reject)
				local query = gql([[
        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        ]])

				local variables = { id = "1" }

				local data1 = { people_one = { name = "Luke Skywalker" } }
				local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

				local queryManager = QueryManager.new({
					link = mockSingleLink(
						{ request = { query = query, variables = variables }, result = { data = data1 } },
						{ request = { query = query, variables = variables }, result = { data = data2 } },
						{ request = { query = query, variables = variables }, result = { data = data2 } }
					):setOnError(reject),
					cache = InMemoryCache.new({ addTypename = false }),
					ssrMode = true,
				})

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					pollInterval = 10,
					notifyOnNetworkStatusChange = false,
				})

				local count = 1

				local subHandle = observable:subscribe({
					next = function(result: any)
						repeat --[[ ROBLOX comment: switch statement conversion ]]
							local entered_, break_ = false, false
							local condition_ = count
							for _, v in ipairs({ 1, 2 }) do
								if condition_ == v then
									if v == 1 then
										entered_ = true
										jestExpect(stripSymbols(result.data)).toEqual(data1)
										setTimeout(function()
											subHandle:unsubscribe()
											resolve()
										end, 15);
										(function()
											local result = count
											count += 1
											return result
										end)()
										break_ = true
										break
									end
									if v == 2 or entered_ then
										entered_ = true
									end
								end
							end
							if not break_ then
								reject(Error.new("Only expected one result, not multiple"))
							end
						until true
					end,
				})
			end)

			itAsyncSkip(
				"should let you handle multiple polled queries and unsubscribe from one of them",
				function(resolve, reject)
					local query1 = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])
					local query2 = gql([[
        query {
          person {
            name
          }
        ]])

					local data11 = { author = { firstName = "John", lastName = "Smith" } }
					local data12 = { author = { firstName = "Jack", lastName = "Smith" } }
					local data13 = { author = { firstName = "Jolly", lastName = "Smith" } }
					local data14 = { author = { firstName = "Jared", lastName = "Smith" } }
					local data21 = { person = { name = "Jane Smith" } }
					local data22 = { person = { name = "Josey Smith" } }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query1 }, result = { data = data11 } },
						{ request = { query = query1 }, result = { data = data12 } },
						{ request = { query = query1 }, result = { data = data13 } },
						{ request = { query = query1 }, result = { data = data14 } },
						{ request = { query = query2 }, result = { data = data21 } },
						{ request = { query = query2 }, result = { data = data22 } }
					)

					local handle1Count = 0
					local handleCount = 0

					local setMilestone = false

					local subscription1 = queryManager:watchQuery({ query = query1, pollInterval = 150 }):subscribe({
						next = function(self)
							(function()
								local result = handle1Count
								handle1Count += 1
								return result
							end)();
							(function()
								local result = handleCount
								handleCount += 1
								return result
							end)()
							if handle1Count > 1 and not Boolean.toJSBoolean(setMilestone) then
								subscription1:unsubscribe()
								setMilestone = true
							end
						end,
					})

					local subscription2 = queryManager:watchQuery({ query = query2, pollInterval = 2000 }):subscribe({
						next = function(self)
							(function()
								local result = handleCount
								handleCount += 1
								return result
							end)()
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

			itAsyncSkip("allows you to unsubscribe from polled queries", function(resolve, reject)
				local query = gql([[
        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        ]])

				local variables = { id = "1" }

				local data1 = { people_one = { name = "Luke Skywalker" } }
				local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

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
				do
					local ref = observableToPromiseAndSubscription(
						{ observable = observable, wait = 60 },
						function(result)
							return jestExpect(stripSymbols(result.data)).toEqual(data1)
						end,
						function(result)
							jestExpect(stripSymbols(result.data)).toEqual(data2)

							-- we unsubscribe here manually, rather than waiting for the timeout.
							subscription:unsubscribe()
						end
					)
					promise, subscription = ref.promise, ref.subscription
				end
				return promise:andThen(resolve, reject)
			end)

			itAsyncSkip("allows you to unsubscribe from polled query errors", function(resolve, reject)
				local query = gql([[
        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        ]])

				local variables = { id = "1" }

				local data1 = { people_one = { name = "Luke Skywalker" } }
				local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data1 } },
					{ request = { query = query, variables = variables }, ["error"] = Error.new("Network error") },
					{ request = { query = query, variables = variables }, result = { data = data2 } }
				)

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					pollInterval = 50,
					notifyOnNetworkStatusChange = false,
				})

				local isFinished = false
				process:once("unhandledRejection", function()
					if not Boolean.toJSBoolean(isFinished) then
						reject("unhandledRejection from network")
					end
				end)

				local promise, subscription
				do
					local ref = observableToPromiseAndSubscription({
						observable = observable,
						wait = 60,
						errorCallbacks = {
							function(error_)
								jestExpect(error_.message).toMatch("Network error")
								subscription:unsubscribe()
							end,
						},
					}, function(result)
						return jestExpect(stripSymbols(result.data)).toEqual(data1)
					end)
					promise, subscription = ref.promise, ref.subscription
				end

				promise:andThen(function()
					setTimeout(function()
						isFinished = true
						resolve()
					end, 4)
				end)
			end)

			itAsyncSkip("exposes a way to start a polling query", function(resolve, reject)
				local query = gql([[
        query fetchLuke($id: String) {
          people_one(id: $id) {
            name
          }
        ]])

				local variables = { id = "1" }

				local data1 = { people_one = { name = "Luke Skywalker" } }
				local data2 = { people_one = { name = "Luke Skywalker has a new name" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data1 } },
					{ request = { query = query, variables = variables }, result = { data = data2 } }
				)

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					notifyOnNetworkStatusChange = false,
				})

				observable:startPolling(50)

				return observableToPromise({ observable = observable }, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data1)
				end, function(result)
					return jestExpect(stripSymbols(result.data)).toEqual(data2)
				end):andThen(resolve, reject)
			end)

			itAsyncSkip("exposes a way to stop a polling query", function(resolve, reject)
				local query = gql([[
        query fetchLeia($id: String) {
          people_one(id: $id) {
            name
          }
        ]])

				local variables = { id = "2" }

				local data1 = { people_one = { name = "Leia Skywalker" } }
				local data2 = { people_one = { name = "Leia Skywalker has a new name" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data1 } },
					{ request = { query = query, variables = variables }, result = { data = data2 } }
				)

				local observable = queryManager:watchQuery({ query = query, variables = variables, pollInterval = 50 })

				return observableToPromise({ observable = observable, wait = 60 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data1)
					observable:stopPolling()
				end):andThen(resolve, reject)
			end)

			itAsyncSkip("stopped polling queries still get updates", function(resolve, reject)
				local query = gql([[
        query fetchLeia($id: String) {
          people_one(id: $id) {
            name
          }
        ]])

				local variables = { id = "2" }

				local data1 = { people_one = { name = "Leia Skywalker" } }
				local data2 = { people_one = { name = "Leia Skywalker has a new name" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data1 } },
					{ request = { query = query, variables = variables }, result = { data = data2 } }
				)

				local observable = queryManager:watchQuery({ query = query, variables = variables, pollInterval = 50 })

				return Promise
					:all({
						observableToPromise({ observable = observable }, function(result)
							jestExpect(stripSymbols(result.data)).toEqual(data1)
							queryManager
								:query({ query = query, variables = variables, fetchPolicy = "network-only" })
								:andThen(function(result)
									jestExpect(result.data).toEqual(data2)
								end)
								:catch(reject)
						end, function(result)
							jestExpect(stripSymbols(result.data)).toEqual(data2)
						end),
					})
					:andThen(resolve, reject)
			end)
		end)

		xdescribe("store resets", function()
			itAsyncSkip("returns a promise resolving when all queries have been refetched", function(resolve, reject)
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])
				local data = { author = { firstName = "John", lastName = "Smith" } }
				local dataChanged = { author = { firstName = "John changed", lastName = "Smith" } }

				local query2 = gql([[
        query {
          author2 {
            firstName
            lastName
          }
        ]])

				local data2 = { author2 = { firstName = "John", lastName = "Smith" } }
				local data2Changed = { author2 = { firstName = "John changed", lastName = "Smith" } }

				local queryManager = createQueryManager({
					link = mockSingleLink(
						{ request = { query = query }, result = { data = data } },
						{ request = { query = query2 }, result = { data = data2 } },
						{ request = { query = query }, result = { data = dataChanged } },
						{ request = { query = query2 }, result = { data = data2Changed } }
					):setOnError(reject),
				})

				local observable = queryManager:watchQuery({ query = query })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise
					:all({
						observableToPromise({ observable = observable }, function(result)
							return jestExpect(stripSymbols(result.data)).toEqual(data)
						end),
						observableToPromise({ observable = observable2 }, function(result)
							return jestExpect(stripSymbols(result.data)).toEqual(data2)
						end),
					})
					:andThen(function()
						observable:subscribe({
							next = function()
								return nil
							end,
						})
						observable2:subscribe({
							next = function()
								return nil
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

			itAsyncSkip("should change the store state to an empty state", function(resolve, reject)
				local queryManager = createQueryManager({ link = mockSingleLink():setOnError(reject) })

				queryManager:resetStore()

				jestExpect(queryManager.cache:extract()).toEqual({})
				jestExpect(queryManager:getQueryStore()).toEqual({})
				jestExpect(queryManager.mutationStore).toEqual({})
				resolve()
			end)

			xit("should only refetch once when we store reset", function()
				local queryManager: QueryManager<NormalizedCacheObject>
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }
				local data2 = { author = { firstName = "Johnny", lastName = "Smith" } }

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
				end)
			end)

			itAsyncSkip("should not refetch torn-down queries", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>

				local observable: ObservableQuery<any>

				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local timesFired = 0

				local link: ApolloLink = ApolloLink:from({
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

			itAsyncSkip("should not error when resetStore called", function(resolve, reject)
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local timesFired = 0

				local link = ApolloLink:from({
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

				local observable = queryManager:watchQuery({ query = query, notifyOnNetworkStatusChange = false })

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

			itAsyncSkip("should not error on a stopped query()", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>

				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

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

			itAsyncSkip(
				"should throw an error on an inflight fetch query if the store is reset",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query }, result = { data = data }, delay = 10000 }
					)

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
			itAsyncSkip("should call refetch on a mocked Observable if the store is reset", function(resolve, reject)
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local queryManager = mockQueryManager(reject, { request = { query = query }, result = { data = data } })

				local obs = queryManager:watchQuery({ query = query })
				obs:subscribe({})
				obs.refetch = resolve :: any
				queryManager:resetStore()
			end)

			itAsyncSkip(
				"should not call refetch on a cache-only Observable if the store is reset",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local queryManager = createQueryManager({ link = mockSingleLink():setOnError(reject) })

					local options = { query = query, fetchPolicy = "cache-only" } :: WatchQueryOptions

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)

					obs:subscribe({})

					obs.refetch = function()
						(function()
							refetchCount += 1
							return refetchCount
						end)()
						return nil :: any --[[ never ]]
					end

					queryManager:resetStore()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsyncSkip(
				"should not call refetch on a standby Observable if the store is reset",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local queryManager = createQueryManager({ link = mockSingleLink():setOnError(reject) })

					local options = { query = query, fetchPolicy = "standby" } :: WatchQueryOptions

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)

					obs:subscribe({})

					obs.refetch = function()
						(function()
							refetchCount += 1
							return refetchCount
						end)()
						return nil :: any --[[ never ]]
					end

					queryManager:resetStore()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsyncSkip(
				"should not call refetch on a non-subscribed Observable if the store is reset",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local queryManager = createQueryManager({ link = mockSingleLink():setOnError(reject) })

					local options = { query = query } :: WatchQueryOptions

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)

					obs.refetch = function()
						(function()
							refetchCount += 1
							return refetchCount
						end)()
						return nil :: any --[[ never ]]
					end

					queryManager:resetStore()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsyncSkip("should throw an error on an inflight query() if the store is reset", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])
				local data = { author = { firstName = "John", lastName = "Smith" } }

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
					:andThen(function()
						reject(Error.new("query() gave results on a store reset"))
					end)
					:catch(function()
						resolve()
					end)
			end)
		end)

		xdescribe("refetching observed queries", function()
			itAsyncSkip("returns a promise resolving when all queries have been refetched_", function(resolve, reject)
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local dataChanged = { author = { firstName = "John changed", lastName = "Smith" } }

				local query2 = gql([[
        query {
          author2 {
            firstName
            lastName
          }
        ]])

				local data2 = { author2 = { firstName = "John", lastName = "Smith" } }
				local data2Changed = { author2 = { firstName = "John changed", lastName = "Smith" } }

				local queryManager = createQueryManager({
					link = mockSingleLink(
						{ request = { query = query }, result = { data = data } },
						{ request = { query = query2 }, result = { data = data2 } },
						{ request = { query = query }, result = { data = dataChanged } },
						{ request = { query = query2 }, result = { data = data2Changed } }
					):setOnError(reject),
				})

				local observable = queryManager:watchQuery({ query = query })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise
					:all({
						observableToPromise({ observable = observable }, function(result)
							return jestExpect(stripSymbols(result.data)).toEqual(data)
						end),
						observableToPromise({ observable = observable2 }, function(result)
							return jestExpect(stripSymbols(result.data)).toEqual(data2)
						end),
					})
					:andThen(function()
						observable:subscribe({
							next = function()
								return nil
							end,
						})
						observable2:subscribe({
							next = function()
								return nil
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

			itAsyncSkip("should only refetch once when we refetch observable queries", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>

				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }
				local data2 = { author = { firstName = "Johnny", lastName = "Smith" } }

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

			itAsyncSkip("should not refetch torn-down queries_", function(resolve, reject)
				local queryManager: QueryManager<NormalizedCacheObject>
				local observable: ObservableQuery<any>
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local timesFired = 0

				local link: ApolloLink = ApolloLink:from({
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

			itAsyncSkip("should not error after reFetchObservableQueries", function(resolve, reject)
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local timesFired = 0

				local link = ApolloLink:from({
					function()
						return Observable.new(function(observer)
							timesFired += 1
							observer:next({ data = data })
							observer:complete()
						end)
					end,
				})

				local queryManager = createQueryManager({ link = link })

				local observable = queryManager:watchQuery({ query = query, notifyOnNetworkStatusChange = false })

				-- wait to make sure store reset happened
				return observableToPromise({ observable = observable, wait = 20 }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(timesFired).toBe(1)
					queryManager:reFetchObservableQueries()
				end, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					jestExpect(timesFired).toBe(2)
				end):andThen(resolve, reject)
			end)

			itAsyncSkip(
				"should NOT throw an error on an inflight fetch query if the observable queries are refetched",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query }, result = { data = data }, delay = 100 }
					)

					queryManager:fetchQuery("made up id", { query = query }):andThen(resolve):catch(function(error_)
						reject(Error.new("Should not return an error"))
					end)

					queryManager:reFetchObservableQueries()
				end
			)

			itAsyncSkip(
				"should call refetch on a mocked Observable if the observed queries are refetched",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query }, result = { data = data } }
					)

					local obs = queryManager:watchQuery({ query = query })

					obs:subscribe({})

					obs.refetch = resolve :: any

					queryManager:reFetchObservableQueries()
				end
			)

			itAsyncSkip(
				"should not call refetch on a cache-only Observable if the observed queries are refetched",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local queryManager = createQueryManager({ link = mockSingleLink():setOnError(reject) })

					local options = { query = query, fetchPolicy = "cache-only" } :: WatchQueryOptions

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)

					obs:subscribe({})

					obs.refetch = function()
						(function()
							refetchCount += 1
							return refetchCount
						end)()
						return nil :: any --[[ never ]]
					end

					queryManager:reFetchObservableQueries()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsyncSkip(
				"should not call refetch on a standby Observable if the observed queries are refetched",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local queryManager = createQueryManager({ link = mockSingleLink():setOnError(reject) })

					local options = { query = query, fetchPolicy = "standby" } :: WatchQueryOptions

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)

					obs:subscribe({})

					obs.refetch = function()
						(function()
							refetchCount += 1
							return refetchCount
						end)()
						return nil :: any --[[ never ]]
					end

					queryManager:reFetchObservableQueries()

					setTimeout(function()
						jestExpect(refetchCount).toEqual(0)
						resolve()
					end, 50)
				end
			)

			itAsyncSkip(
				"should refetch on a standby Observable if the observed queries are refetched and the includeStandby parameter is set to true",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local queryManager = createQueryManager({ link = mockSingleLink():setOnError(reject) })

					local options = { query = query, fetchPolicy = "standby" } :: WatchQueryOptions

					local refetchCount = 0

					local obs = queryManager:watchQuery(options)

					obs:subscribe({})

					obs.refetch = function()
						(function()
							refetchCount += 1
							return refetchCount
						end)()
						return nil :: any --[[ never ]]
					end

					local includeStandBy = true

					queryManager:reFetchObservableQueries(includeStandBy)

					setTimeout(function()
						jestExpect(refetchCount).toEqual(1)
						resolve()
					end, 50)
				end
			)

			itAsyncSkip("should not call refetch on a non-subscribed Observable", function(resolve, reject)
				local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local queryManager = createQueryManager({ link = mockSingleLink():setOnError(reject) })

				local options = { query = query } :: WatchQueryOptions

				local refetchCount = 0

				local obs = queryManager:watchQuery(options)

				obs.refetch = function()
					(function()
						refetchCount += 1
						return refetchCount
					end)()
					return nil :: any --[[ never ]]
				end

				queryManager:reFetchObservableQueries()

				setTimeout(function()
					jestExpect(refetchCount).toEqual(0)
					resolve()
				end, 50)
			end)

			itAsyncSkip(
				"should NOT throw an error on an inflight query() if the observed queries are refetched",
				function(resolve, reject)
					local queryManager: QueryManager<NormalizedCacheObject>
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

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

		xdescribe("refetching specified queries", function()
			itAsyncSkip("returns a promise resolving when all queries have been refetched__", function(resolve, reject)
				local query = gql([[
        query GetAuthor {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local dataChanged = { author = { firstName = "John changed", lastName = "Smith" } }

				local query2 = gql([[
        query GetAuthor2 {
          author2 {
            firstName
            lastName
          }
        ]])

				local data2 = { author2 = { firstName = "John", lastName = "Smith" } }
				local data2Changed = { author2 = { firstName = "John changed", lastName = "Smith" } }

				local queryManager = createQueryManager({
					link = mockSingleLink(
						{ request = { query = query }, result = { data = data } },
						{ request = { query = query2 }, result = { data = data2 } },
						{ request = { query = query }, result = { data = dataChanged } },
						{ request = { query = query2 }, result = { data = data2Changed } }
					):setOnError(reject),
				})

				local observable = queryManager:watchQuery({ query = query })
				local observable2 = queryManager:watchQuery({ query = query2 })

				return Promise
					:all({
						observableToPromise({ observable = observable }, function(result)
							return jestExpect(stripSymbols(result.data)).toEqual(data)
						end),
						observableToPromise({ observable = observable2 }, function(result)
							return jestExpect(stripSymbols(result.data)).toEqual(data2)
						end),
					})
					:andThen(function()
						observable:subscribe({
							next = function()
								return nil
							end,
						})
						observable2:subscribe({
							next = function()
								return nil
							end,
						})

						local results: Array<any> = {}

						queryManager
							:refetchQueries({ include = { "GetAuthor", "GetAuthor2" } })
							:forEach(function(result)
								return results:push(result)
							end)

						return Promise:all(results):andThen(function()
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

		xdescribe("loading state", function()
			itAsyncSkip("should be passed as false if we are not watching a query", function(resolve, reject)
				local query = gql([[
        query {
          fortuneCookie
        ]])

				local data = { fortuneCookie = "Buy it" }

				return mockQueryManager(reject, { request = { query = query }, result = { data = data } })
					:query({ query = query })
					:andThen(function(result)
						jestExpect(not Boolean.toJSBoolean(result.loading)).toBeTruthy()
						jestExpect(stripSymbols(result.data)).toEqual(data)
					end)
					:andThen(resolve, reject)
			end)

			itAsyncSkip(
				"should be passed to the observer as true if we are returning partial data",
				function(resolve, reject)
					local fortuneCookie = "You must stick to your goal but rethink your approach"

					local primeQuery = gql([[
        query {
          fortuneCookie
        ]])

					local primeData = { fortuneCookie = fortuneCookie }

					local author = { name = "John" }

					local query = gql([[
        query {
          fortuneCookie
          author {
            name
          }
        ]])

					local fullData = { fortuneCookie = fortuneCookie, author = author }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query }, result = { data = fullData }, delay = 5 },
						{ request = { query = primeQuery }, result = { data = primeData } }
					)

					return queryManager
						:query({ query = primeQuery })
						:andThen(function(primeResult)
							local observable = queryManager:watchQuery({ query = query, returnPartialData = true })
							return observableToPromise({ observable = observable }, function(result)
								jestExpect(result.loading).toBe(true)
								jestExpect(result.data).toEqual(primeData)
							end, function(result)
								jestExpect(result.loading).toBe(false)
								jestExpect(result.data).toEqual(fullData)
							end)
						end)
						:andThen(resolve, reject)
				end
			)

			itAsyncSkip(
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
						result = { data = { author = { firstName = "John", lastName = "Smith" } } },
						observer = {
							next = function(self, result)
								jestExpect(not Boolean.toJSBoolean(result.loading)).toBeTruthy()
								resolve()
							end,
						},
					})
				end
			)

			itAsyncSkip("will update on `resetStore`", function(resolve, reject)
				local testQuery = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

				local data1 = { author = { firstName = "John", lastName = "Smith" } }
				local data2 = { author = { firstName = "John", lastName = "Smith 2" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = testQuery }, result = { data = data1 } },
					{ request = { query = testQuery }, result = { data = data2 } }
				)
				local count = 0

				queryManager:watchQuery({ query = testQuery, notifyOnNetworkStatusChange = false }):subscribe({
					next = function(result)
						repeat --[[ ROBLOX comment: switch statement conversion ]]
							local entered_, break_ = false, false
							local condition_ = (function()
								local result = count
								count += 1
								return result
							end)()
							for _, v in ipairs({ 0, 1 }) do
								if condition_ == v then
									if v == 0 then
										entered_ = true
										jestExpect(result.loading).toBe(false)
										jestExpect(stripSymbols(result.data)).toEqual(data1)
										setTimeout(function()
											queryManager:resetStore()
										end, 0)
										break_ = true
										break
									end
									if v == 1 or entered_ then
										entered_ = true
										jestExpect(result.loading).toBe(false)
										jestExpect(stripSymbols(result.data)).toEqual(data2)
										resolve()
										break_ = true
										break
									end
								end
							end
							if not break_ then
								reject(Error.new("`next` was called to many times."))
							end
						until true
					end,
					["error"] = function(error_)
						return reject(error_)
					end,
				})
			end)

			itAsyncSkip("will be true when partial data may be returned", function(resolve, reject)
				local query1 = gql([[{
        a { x1 y1 z1 }
      }]])
				local query2 = gql([[{
        a { x1 y1 z1 }
        b { x2 y2 z2 }
      }]])

				local data1 = { a = { x1 = 1, y1 = 2, z1 = 3 } }
				local data2 = { a = { x1 = 1, y1 = 2, z1 = 3 }, b = { x2 = 3, y2 = 2, z2 = 1 } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query1 }, result = { data = data1 } },
					{ request = { query = query2 }, result = { data = data2 }, delay = 5 }
				)

				queryManager
					:query({ query = query1 })
					:andThen(function(result1)
						jestExpect(result1.loading).toBe(false)
						jestExpect(result1.data).toEqual(data1)
						local count = 0
						queryManager:watchQuery({ query = query2, returnPartialData = true }):subscribe({
							next = function(result2)
								repeat --[[ ROBLOX comment: switch statement conversion ]]
									local entered_, break_ = false, false
									local condition_ = (function()
										local result = count
										count += 1
										return result
									end)()
									for _, v in ipairs({ 0, 1 }) do
										if condition_ == v then
											if v == 0 then
												entered_ = true
												jestExpect(result2.loading).toBe(true)
												jestExpect(result2.data).toEqual(data1)
												break_ = true
												break
											end
											if v == 1 or entered_ then
												entered_ = true
												jestExpect(result2.loading).toBe(false)
												jestExpect(result2.data).toEqual(data2)
												resolve()
												break_ = true
												break
											end
										end
									end
									if not break_ then
										reject(Error.new("`next` was called to many times."))
									end
								until true
							end,
							["error"] = reject,
						})
					end)
					:andThen(resolve, reject)
			end)
		end)

		xdescribe("refetchQueries", function()
			local consoleWarnSpy: undefined

			beforeEach(function()
				consoleWarnSpy = jest:spyOn(console, "warn"):mockImplementation()
			end)

			afterEach(function()
				consoleWarnSpy:mockRestore()
			end)

			itAsyncSkip(
				"should refetch the right query when a result is successfully returned",
				function(resolve, reject)
					local mutation = gql([[
        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        ]])

					local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

					local query = gql([[
        query getAuthors($id: ID!) {
          author(id: $id) {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

					local variables = { id = "1234" }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query, variables = variables }, result = { data = data } },
						{ request = { query = query, variables = variables }, result = { data = secondReqData } },
						{ request = { query = mutation }, result = { data = mutationData } }
					)

					local observable = queryManager:watchQuery({
						query = query,
						variables = variables,
						notifyOnNetworkStatusChange = false,
					})

					return observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						queryManager:mutate({ mutation = mutation, refetchQueries = { "getAuthors" } })
					end, function(result)
						jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(secondReqData)
						jestExpect(stripSymbols(result.data)).toEqual(secondReqData)
					end):andThen(resolve, reject)
				end
			)

			itAsyncSkip(
				"should not warn and continue when an unknown query name is asked to refetch",
				function(resolve, reject)
					local mutation = gql([[
        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        ]])

					local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

					local query = gql([[
        query getAuthors {
          author {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query }, result = { data = data } },
						{ request = { query = query }, result = { data = secondReqData } },
						{ request = { query = mutation }, result = { data = mutationData } }
					)

					local observable = queryManager:watchQuery({ query = query, notifyOnNetworkStatusChange = false })

					return observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						queryManager:mutate({ mutation = mutation, refetchQueries = { "fakeQuery", "getAuthors" } })
					end, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(secondReqData)
						jestExpect(consoleWarnSpy).toHaveBeenLastCalledWith(
							'Unknown query named "fakeQuery" requested in refetchQueries options.include array'
						)
					end):andThen(resolve, reject)
				end
			)

			itAsyncSkip(
				"should ignore (with warning) a query named in refetchQueries that has no active subscriptions",
				function(resolve, reject)
					local mutation = gql([[
        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        ]])

					local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

					local query = gql([[
        query getAuthors {
          author {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query }, result = { data = data } },
						{ request = { query = query }, result = { data = secondReqData } },
						{ request = { query = mutation }, result = { data = mutationData } }
					)

					local observable = queryManager:watchQuery({ query = query })

					return observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
					end)
						:andThen(function()
							-- The subscription has been stopped already
							return queryManager:mutate({ mutation = mutation, refetchQueries = { "getAuthors" } })
						end)
						:andThen(function()
							jestExpect(consoleWarnSpy).toHaveBeenLastCalledWith(
								'Unknown query named "getAuthors" requested in refetchQueries options.include array'
							)
						end)
						:andThen(resolve, reject)
				end
			)

			itAsyncSkip("also works with a query document and variables", function(resolve, reject)
				local mutation = gql([[
        mutation changeAuthorName($id: ID!) {
          changeAuthorName(newName: "Jack Smith", id: $id) {
            firstName
            lastName
          }
        ]])

				local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

				local query = gql([[
        query getAuthors($id: ID!) {
          author(id: $id) {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

				local variables = { id = "1234" }

				local mutationVariables = { id = "2345" }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data }, delay = 10 },
					{
						request = { query = query, variables = variables },
						result = { data = secondReqData },
						delay = 100,
					},
					{
						request = { query = mutation, variables = mutationVariables },
						result = { data = mutationData },
						delay = 10,
					}
				)

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
							return setTimeout(res, 10)
						end)
							:andThen(function()
								-- Make sure the QueryManager cleans up legacy one-time queries like
								-- the one we requested above using refetchQueries.
								queryManager["queries"]:forEach(function(queryInfo, queryId)
									jestExpect(queryId).not_.toContain("legacyOneTimeQuery")
								end)
							end)
							:andThen(resolve, reject)
					else
						reject("too many results")
					end
				end)
			end)

			itAsyncSkip("also works with a conditional function that returns false", function(resolve, reject)
				local mutation = gql([[
        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        ]])

				local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

				local query = gql([[
        query getAuthors {
          author {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query }, result = { data = data } },
					{ request = { query = query }, result = { data = secondReqData } },
					{ request = { query = mutation }, result = { data = mutationData } }
				)

				local observable = queryManager:watchQuery({ query = query })

				local function conditional(result: FetchResult<any>)
					jestExpect(stripSymbols(result.data)).toEqual(mutationData)
					return {}
				end

				return observableToPromise({ observable = observable }, function(result)
					jestExpect(stripSymbols(result.data)).toEqual(data)
					queryManager:mutate({ mutation = mutation, refetchQueries = conditional })
				end):andThen(resolve, reject)
			end)

			itAsyncSkip(
				"also works with a conditional function that returns an array of refetches",
				function(resolve, reject)
					local mutation = gql([[
        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        ]])

					local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

					local query = gql([[
        query getAuthors {
          author {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query }, result = { data = data } },
						{ request = { query = query }, result = { data = secondReqData } },
						{ request = { query = mutation }, result = { data = mutationData } }
					)

					local observable = queryManager:watchQuery({ query = query })

					local function conditional(result: FetchResult<any>)
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

			itAsyncSkip("should refetch using the original query context (if any)", function(resolve, reject)
				local mutation = gql([[
        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        ]])

				local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

				local query = gql([[
        query getAuthors($id: ID!) {
          author(id: $id) {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

				local variables = { id = "1234" }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data } },
					{ request = { query = query, variables = variables }, result = { data = secondReqData } },
					{ request = { query = mutation }, result = { data = mutationData } }
				)

				local headers = { someHeader = "some value" }

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					context = { headers = headers },
					notifyOnNetworkStatusChange = false,
				})

				return observableToPromise({ observable = observable }, function(result)
					queryManager:mutate({ mutation = mutation, refetchQueries = { "getAuthors" } })
				end, function(result)
					local context = (queryManager.link :: MockApolloLink).operation:getContext()
					jestExpect(context.headers).not_.toBeUndefined()
					jestExpect(context.headers.someHeader).toEqual(headers.someHeader)
				end):andThen(resolve, reject)
			end)

			itAsyncSkip("should refetch using the specified context, if provided", function(resolve, reject)
				local mutation = gql([[
        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        ]])

				local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

				local query = gql([[
        query getAuthors($id: ID!) {
          author(id: $id) {
            firstName
            lastName
          }
        ]])

				local data = { author = { firstName = "John", lastName = "Smith" } }

				local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

				local variables = { id = "1234" }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data } },
					{ request = { query = query, variables = variables }, result = { data = secondReqData } },
					{ request = { query = mutation }, result = { data = mutationData } }
				)

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					notifyOnNetworkStatusChange = false,
				})

				local headers = { someHeader = "some value" }

				return observableToPromise({ observable = observable }, function(result)
					queryManager:mutate({
						mutation = mutation,
						refetchQueries = {
							{ query = query, variables = variables, context = { headers = headers } },
						},
					})
				end, function(result)
					local context = (
						error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ (queryManager.link as MockApolloLink).operation! ]]

					):getContext()
					jestExpect(context.headers).not_.toBeUndefined()
					jestExpect(context.headers.someHeader).toEqual(headers.someHeader)
				end):andThen(resolve, reject)
			end)
		end)

		xdescribe("onQueryUpdated", function()
			local mutation = gql([[
      mutation changeAuthorName {
        changeAuthorName(newName: "Jack Smith") {
          firstName
          lastName
        }
	  }
      ]])

			local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

			local query = gql([[
      query getAuthors($id: ID!) {
        author(id: $id) {
          firstName
          lastName
        }
      }
      ]])

			local data = { author = { firstName = "John", lastName = "Smith" } }

			local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

			local variables = { id = "1234" }

			local function makeQueryManager(reject: ((reason: any?) -> ()))
				return mockQueryManager(
					reject,
					{ request = { query = query, variables = variables }, result = { data = data } },
					{ request = { query = query, variables = variables }, result = { data = secondReqData } },
					{ request = { query = mutation }, result = { data = mutationData } }
				)
			end

			itAsyncSkip(
				"should refetch the right query when a result is successfully returned_",
				function(resolve, reject)
					local queryManager = makeQueryManager(reject)

					local observable = queryManager:watchQuery({
						query = query,
						variables = variables,
						notifyOnNetworkStatusChange = false,
					})

					local finishedRefetch = false

					return observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						return queryManager
							:mutate({
								mutation = mutation,
								update = function(_self, cache)
									cache:modify({
										fields = {
											author = function(__self, _, ref)
												local INVALIDATE = ref.INVALIDATE
												return INVALIDATE
											end,
										},
									})
								end,
								onQueryUpdated = function(self, obsQuery)
									jestExpect(obsQuery.options.query).toBe(query)
									return obsQuery:refetch():andThen(function(result)
										-- Wait a bit to make sure the mutation really awaited the
										-- refetching of the query.
										Promise.new(function(resolve)
											return setTimeout(resolve, 100)
										end):expect()
										finishedRefetch = true
										return result
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

			itAsyncSkip("should refetch using the original query context (if any)_", function(resolve, reject)
				local queryManager = makeQueryManager(reject)

				local headers = { someHeader = "some value" }

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					context = { headers = headers },
					notifyOnNetworkStatusChange = false,
				})

				return observableToPromise({ observable = observable }, function(result)
					jestExpect(result.data).toEqual(data)
					queryManager:mutate({
						mutation = mutation,
						update = function(_self, cache)
							cache:modify({
								fields = {
									author = function(__self, _, ref)
										local INVALIDATE = ref.INVALIDATE
										return INVALIDATE
									end,
								},
							})
						end,
						onQueryUpdated = function(self, obsQuery)
							jestExpect(obsQuery.options.query).toBe(query)
							return obsQuery:refetch()
						end,
					})
				end, function(result)
					jestExpect(result.data).toEqual(secondReqData)
					local context = (
						error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ (queryManager.link as MockApolloLink).operation! ]]

					):getContext()
					jestExpect(context.headers).not_.toBeUndefined()
					jestExpect(context.headers.someHeader).toEqual(headers.someHeader)
				end):andThen(resolve, reject)
			end)

			itAsyncSkip("should refetch using the specified context, if provided_", function(resolve, reject)
				local queryManager = makeQueryManager(reject)

				local observable = queryManager:watchQuery({
					query = query,
					variables = variables,
					notifyOnNetworkStatusChange = false,
				})

				local headers = { someHeader = "some value" }

				return observableToPromise({ observable = observable }, function(result)
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
					local context = (
						error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ (queryManager.link as MockApolloLink).operation! ]]

					):getContext()
					jestExpect(context.headers).not_.toBeUndefined()
					jestExpect(context.headers.someHeader).toEqual(headers.someHeader)
				end):andThen(resolve, reject)
			end)
		end)

		xdescribe("awaitRefetchQueries", function()
			local function awaitRefetchTest(ref)
				local awaitRefetchQueries, testQueryError =
					ref.awaitRefetchQueries, (function()
						if ref.testQueryError == nil then
							return false
						else
							return ref.testQueryError
						end
					end)()

				return Promise.new(function(resolve, reject)
					local query = gql([[
        				query getAuthors($id: ID!) {
        				  author(id: $id) {
        				    firstName
        				    lastName
        				  }
        				]])

					local queryData = { author = { firstName = "John", lastName = "Smith" } }

					local mutation = gql([[
        mutation changeAuthorName {
          changeAuthorName(newName: "Jack Smith") {
            firstName
            lastName
          }
        ]])

					local mutationData = { changeAuthorName = { firstName = "Jack", lastName = "Smith" } }

					local secondReqData = { author = { firstName = "Jane", lastName = "Johnson" } }

					local variables = { id = "1234" }

					local refetchError = (function()
						if Boolean.toJSBoolean(testQueryError) then
							return Error.new("Refetch failed")
						else
							return nil
						end
					end)()

					local queryManager = mockQueryManager(
						reject,
						{ request = { query = query, variables = variables }, result = { data = queryData } },
						{ request = { query = mutation }, result = { data = mutationData } },
						{
							request = { query = query, variables = variables },
							result = { data = secondReqData },
							["error"] = refetchError,
						}
					)

					local observable = queryManager:watchQuery({
						query = query,
						variables = variables,
						notifyOnNetworkStatusChange = false,
					})

					local isRefetchErrorCaught = false

					local mutationComplete = false

					return observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(queryData)

						local mutateOptions: MutationOptions<any, any, any> = {
							mutation = mutation,
							refetchQueries = { "getAuthors" },
						}

						if Boolean.toJSBoolean(awaitRefetchQueries) then
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
						if Boolean.toJSBoolean(awaitRefetchQueries) then
							jestExpect(mutationComplete).not_.toBeTruthy()
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
							local isRefetchError

							if not awaitRefetchQueries then
								isRefetchError = awaitRefetchQueries
							elseif not testQueryError then
								isRefetchError = testQueryError
							else
								isRefetchError = error_.message:includes((function()
									if Boolean.toJSBoolean(refetchError) then
										return refetchError.message
									else
										return nil
									end
								end)())
							end

							if Boolean.toJSBoolean(isRefetchError) then
								return setTimeout(function()
									jestExpect(isRefetchErrorCaught).toBe(true)
									resolve()
								end, 10)
							end
							reject(error_)
						end)
				end)
			end
			it(
				"should not wait for `refetchQueries` to complete before resolving "
					.. "the mutation, when `awaitRefetchQueries` is undefined",
				function()
					return awaitRefetchTest({ awaitRefetchQueries = 0 and nil or nil })
				end
			)

			it(
				"should not wait for `refetchQueries` to complete before resolving "
					.. "the mutation, when `awaitRefetchQueries` is false",
				function()
					return awaitRefetchTest({ awaitRefetchQueries = false })
				end
			)

			it(
				"should wait for `refetchQueries` to complete before resolving "
					.. "the mutation, when `awaitRefetchQueries` is `true`",
				function()
					return awaitRefetchTest({ awaitRefetchQueries = true })
				end
			)

			it(
				"should allow catching errors from `refetchQueries` when " .. "`awaitRefetchQueries` is `true`",
				function()
					return awaitRefetchTest({ awaitRefetchQueries = true, testQueryError = true })
				end
			)
		end)

		xdescribe("store watchers", function()
			itAsyncSkip("does not fill up the store on resolved queries", function(resolve, reject)
				local query1 = gql([[
        query One {
          one
        ]])
				local query2 = gql([[
        query Two {
          two
        ]])
				local query3 = gql([[
        query Three {
          three
        ]])
				local query4 = gql([[
        query Four {
          four
        ]])

				local link = mockSingleLink(
					{ request = { query = query1 }, result = { data = { one = 1 } } },
					{ request = { query = query2 }, result = { data = { two = 2 } } },
					{ request = { query = query3 }, result = { data = { three = 3 } } },
					{ request = { query = query4 }, result = { data = { four = 4 } } }
				):setOnError(reject)

				local cache = InMemoryCache.new()

				local queryManager = QueryManager.new({ link = link, cache = cache })

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
							setTimeout(r, 10)
						end)
					end)
					:andThen(function()
						jestExpect(cache.watches.size).toBe(0)
					end)
					:andThen(resolve, reject)
			end)
		end)

		xdescribe("`no-cache` handling", function()
			itAsyncSkip(
				"should return a query result (if one exists) when a `no-cache` fetch policy is used",
				function(resolve, reject)
					local query = gql([[
          query {
            author {
              firstName
              lastName
            }
          ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local queryManager = createQueryManager({
						link = mockSingleLink({ request = { query = query }, result = { data = data } }):setOnError(
							reject
						),
					})

					local observable = queryManager:watchQuery({ query = query, fetchPolicy = "no-cache" })

					observableToPromise({ observable = observable }, function(result)
						jestExpect(stripSymbols(result.data)).toEqual(data)
						local currentResult = getCurrentQueryResult(observable)
						jestExpect(currentResult.data).toEqual(data)
						resolve()
					end)
				end
			)
		end)

		xdescribe("client awareness", function()
			itAsyncSkip(
				"should pass client awareness settings into the link chain via context",
				function(resolve, reject)
					local query = gql([[
        query {
          author {
            firstName
            lastName
          }
        ]])

					local data = { author = { firstName = "John", lastName = "Smith" } }

					local link = mockSingleLink({ request = { query = query }, result = { data = data } }):setOnError(
						reject
					)

					local clientAwareness = { name = "Test", version = "1.0.0" }

					local queryManager = createQueryManager({ link = link, clientAwareness = clientAwareness })

					local observable = queryManager:watchQuery({ query = query, fetchPolicy = "no-cache" })

					observableToPromise({ observable = observable }, function(result)
						local context = (
							error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TSNonNullExpression ]] --[[ link.operation! ]]

						):getContext()
						jestExpect(context.clientAwareness).toBeDefined()
						jestExpect(context.clientAwareness).toEqual(clientAwareness)
						resolve()
					end)
				end
			)
		end)

		xdescribe("queryDeduplication", function()
			it("should be true when context is true, default is false and argument not provided", function()
				local query = gql([[
        query {
          author {
            firstName
          }
        ]])

				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query },
						result = {
							data = { author = { firstName = "John" } },
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
        ]])

				local queryManager = createQueryManager({
					link = mockSingleLink({
						request = { query = query },
						result = {
							data = { author = { firstName = "John" } },
						},
					}),
					queryDeduplication = true,
				})
				queryManager:query({ query = query, context = { queryDeduplication = false } })
				jestExpect(queryManager["inFlightLinkObservables"].size).toBe(0)
			end)
		end)

		xdescribe("missing cache field warnings", function()
			local verbosity: ReturnType<any> --[[ typeof setVerbosity ]]
			local spy: any

			beforeEach(function()
				verbosity = setVerbosity("warn")
				spy = jest:spyOn(console, "warn"):mockImplementation()
			end)

			afterEach(function()
				setVerbosity(verbosity)
				spy:mockRestore()
			end)

			local function validateWarnings(
				resolve: ((result: any?) -> ()),
				reject: ((reason: any?) -> ()),
				returnPartialData,
				expectedWarnCount
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
        ]])

				local data1 = { car = { make = "Ford", model = "Pinto", id = 123, __typename = "Car" } }

				local queryManager = mockQueryManager(
					reject,
					{ request = { query = query1 }, result = { data = data1 } }
				)

				local observable1 = queryManager:watchQuery({ query = query1 })
				local observable2 = queryManager:watchQuery({
					query = query2,
					fetchPolicy = "cache-only",
					returnPartialData = returnPartialData,
				})

				return observableToPromise({ observable = observable1 }, function(result)
					jestExpect(result).toEqual({ loading = false, data = data1, networkStatus = NetworkStatus.ready })
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

			itAsyncSkip(
				"should show missing cache result fields warning when returnPartialData is false",
				function(resolve, reject)
					validateWarnings(resolve, reject, false, 1)
				end
			)

			itAsyncSkip(
				"should not show missing cache result fields warning when returnPartialData is true",
				function(resolve, reject)
					validateWarnings(resolve, reject, true, 0)
				end
			)
		end)
	end)
end
