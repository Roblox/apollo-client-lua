-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/hooks/__tests__/useQuery.test.tsx

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array, Boolean, console, Error, Object, Set, setTimeout =
	LuauPolyfill.Array,
	LuauPolyfill.Boolean,
	LuauPolyfill.console,
	LuauPolyfill.Error,
	LuauPolyfill.Object,
	LuauPolyfill.Set,
	LuauPolyfill.setTimeout
type Array<T> = LuauPolyfill.Array<T>
type Function = (...any) -> ...any

-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
local TICK = 1000 / 30

local Promise = require(rootWorkspace.Promise)
local RegExp = require(rootWorkspace.LuauRegExp)

local stringIndexOf = require(srcWorkspace.luaUtils.stringIndexOf).stringIndexOf

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local beforeAll = JestGlobals.beforeAll
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest

local React = require(rootWorkspace.React)
local useState = React.useState
local useReducer = React.useReducer
local Fragment = React.Fragment
local useEffect = React.useEffect

local GraphQL = require(rootWorkspace.GraphQL)
type DocumentNode = GraphQL.DocumentNode
local GraphQLError = GraphQL.GraphQLError
type GraphQLError = GraphQL.GraphQLError

local gql = require(rootWorkspace.GraphQLTag).gql

local reactTestingModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = reactTestingModule.render
local cleanup = reactTestingModule.cleanup
local act = reactTestingModule.act
local waitFor = reactTestingModule.waitFor
local wait_ = require(srcWorkspace.testUtils.wait).wait

local coreModule = require(srcWorkspace.core)
local ApolloClient = coreModule.ApolloClient
local NetworkStatus = coreModule.NetworkStatus
type TypedDocumentNode<Result, Variables> = coreModule.TypedDocumentNode<Result, Variables>
type WatchQueryFetchPolicy = coreModule.WatchQueryFetchPolicy

local InMemoryCache = require(srcWorkspace.cache.inmemory.inMemoryCache).InMemoryCache
local ApolloProvider = require(script.Parent.Parent.Parent.context).ApolloProvider

local utilitiesModule = require(srcWorkspace.utilities)
local Observable = utilitiesModule.Observable
type Reference = utilitiesModule.Reference
local concatPagination = require(srcWorkspace.utilities.policies.pagination).concatPagination
local ApolloLink = require(script.Parent.Parent.Parent.Parent.link.core).ApolloLink

local testingModule = require(srcWorkspace.testing)
local itAsync = testingModule.itAsync
local MockLink = testingModule.MockLink
local MockedProvider = testingModule.MockedProvider
local mockSingleLink = testingModule.mockSingleLink
local withErrorSpy = testingModule.withErrorSpy
type MockedResponse<T> = testingModule.MockedResponse<T>

local useQuery = require(script.Parent.Parent.useQuery).useQuery

local useMutation = require(script.Parent.Parent.useMutation).useMutation

local reactModule = require(script.Parent.Parent.Parent)
type QueryFunctionOptions<TData, TVariables> = reactModule.QueryFunctionOptions<TData, TVariables>

local typesModule = require(script.Parent.Parent.Parent.types.types)
type MutationTupleFirst<TData, TVariables, TContext, TCache> = typesModule.MutationTupleFirst<
	TData,
	TVariables,
	TContext,
	TCache
>
type MutationTupleSecond<TData, TVariables, TContext, TCache> = typesModule.MutationTupleSecond<
	TData,
	TVariables,
	TContext,
	TCache
>

type FIX_ANALYZE = any

-- ROBLOX deviation: replaces Jasmine's fail global
local function fail(message: string)
	expect(nil).toBe(("ROBLOX deviation - fail() was called with message: (%s)"):format(message))
end

-- ROBLOX TODO: remove when unhandled errors are ... handled
local function rejectOnComponentThrow(reject, fn: Function)
	local trace = debug.traceback()
	local ok, result = pcall(fn)
	if not ok then
		print(result.message .. "\n" .. trace)
		reject(result)
	end
	return result
end

describe("useQuery Hook", function()
	-- ROBLOX deviation: resetting ObservableQuery behaviour
	beforeAll(function()
		_G.__WARNED_ABOUT_OBSERVABLE_QUERY_UPDATE_QUERY__ = false
	end)

	local CAR_QUERY: DocumentNode = gql([[

			query {
				cars {
					make
					model
					vin
				}
    		}
		]])

	local CAR_RESULT_DATA = {
		cars = { { make = "Audi", model = "RS8", vin = "DOLLADOLLABILL", __typename = "Car" } },
	}

	local CAR_MOCKS = { { request = { query = CAR_QUERY }, result = { data = CAR_RESULT_DATA } } }

	afterEach(cleanup)

	describe("General use", function()
		itAsync("should handle a simple query properly", function(resolve, reject)
			local function Component()
				local queryResult = useQuery(CAR_QUERY)
				rejectOnComponentThrow(reject, function()
					local data, loading = queryResult.data, queryResult.loading
					if not Boolean.toJSBoolean(loading) then
						expect(data).toEqual(CAR_RESULT_DATA)
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { mocks = CAR_MOCKS }, React.createElement(Component, nil)))

			return wait_():andThen(resolve, reject)
		end)

		itAsync("should keep data as undefined until data is actually returned", function(resolve, reject)
			local function Component()
				local queryResult = useQuery(CAR_QUERY)
				rejectOnComponentThrow(reject, function()
					local data, loading = queryResult.data, queryResult.loading
					if Boolean.toJSBoolean(loading) then
						expect(data).toBeUndefined()
					else
						expect(data).toEqual(CAR_RESULT_DATA)
					end
				end)
				return nil
			end
			render(React.createElement(MockedProvider, {
				mocks = CAR_MOCKS,
			}, React.createElement(Component, nil)))
			return wait_():andThen(resolve, reject)
		end)

		itAsync("should return a result upon first call, if data is available", function(resolve, reject)
			-- This test verifies that the `useQuery` hook returns a result upon its first
			-- invocation if the data is available in the cache. This is essential for SSR
			-- to work properly, since effects are not run during SSR.
			local function Component(ref)
				local expectData = ref.expectData
				local queryResult = useQuery(CAR_QUERY)
				rejectOnComponentThrow(reject, function()
					local data = queryResult.data
					if Boolean.toJSBoolean(expectData) then
						expect(data).toEqual(CAR_RESULT_DATA)
					end
				end)
				return nil
			end
			-- Common cache instance to use across render passes.
			-- The cache will be warmed with the result of the query on the second pass.
			local cache = InMemoryCache.new()

			render(React.createElement(
				MockedProvider,
				{
					mocks = CAR_MOCKS,
					cache = cache,
				},
				React.createElement(Component, {
					expectData = false,
				})
			))

			wait_():expect()

			render(React.createElement(
				MockedProvider,
				{
					mocks = CAR_MOCKS,
					cache = cache,
				},
				React.createElement(Component, {
					expectData = true,
				})
			))
			return wait_():andThen(resolve, reject)
		end)

		itAsync("should ensure ObservableQuery fields have a stable identity", function(resolve, reject)
			local refetchFn: any
			local fetchMoreFn: any
			local updateQueryFn: any
			local startPollingFn: any
			local stopPollingFn: any
			local subscribeToMoreFn: any

			local function Component()
				local queryResult = useQuery(CAR_QUERY)
				rejectOnComponentThrow(reject, function()
					local loading, refetch, fetchMore, updateQuery, startPolling, stopPolling, subscribeToMore =
						queryResult.loading,
						queryResult.refetch,
						queryResult.fetchMore,
						queryResult.updateQuery,
						queryResult.startPolling,
						queryResult.stopPolling,
						queryResult.subscribeToMore

					if Boolean.toJSBoolean(loading) then
						refetchFn = refetch
						fetchMoreFn = fetchMore
						updateQueryFn = updateQuery
						startPollingFn = startPolling
						stopPollingFn = stopPolling
						subscribeToMoreFn = subscribeToMore
					else
						expect(refetch).toBe(refetchFn)
						expect(fetchMore).toBe(fetchMoreFn)
						expect(updateQuery).toBe(updateQueryFn)
						expect(startPolling).toBe(startPollingFn)
						expect(stopPolling).toBe(stopPollingFn)
						expect(subscribeToMore).toBe(subscribeToMoreFn)
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, {
				mocks = CAR_MOCKS,
			}, React.createElement(Component, nil)))
			return wait_():andThen(resolve, reject)
		end)

		itAsync("should update result when query result change", function(resolve, reject)
			local CAR_QUERY_BY_ID = gql([[

					query($id: Int) {
					  car(id: $id) {
						make
						model
					  }
					}
				]])
			local CAR_DATA_A4 = { car = { make = "Audi", model = "A4", __typename = "Car" } }
			local CAR_DATA_RS8 = { car = { make = "Audi", model = "RS8", __typename = "Car" } }
			local mocks = {
				{
					request = { query = CAR_QUERY_BY_ID, variables = { id = 1 } },
					result = { data = CAR_DATA_A4 },
				},
				{
					request = { query = CAR_QUERY_BY_ID, variables = { id = 2 } },
					result = { data = CAR_DATA_RS8 },
				},
			}

			local hookResponse = jest.fn().mockReturnValue(nil)

			local function Component(ref)
				local id, children = ref.id, ref.children
				local queryResult = useQuery(CAR_QUERY_BY_ID, {
					variables = { id = id },
				})
				local data, loading, error_ = queryResult.data, queryResult.loading, queryResult.error
				return children({ data = data, loading = loading, ["error"] = error_ })
			end

			local rerender = render(React.createElement(
				MockedProvider,
				{
					mocks = mocks,
				},
				React.createElement(Component, {
					id = 1,
				} :: FIX_ANALYZE, hookResponse)
			)).rerender

			waitFor(function()
				expect(hookResponse).toHaveBeenLastCalledWith({
					data = CAR_DATA_A4,
					loading = false,
					error = nil,
				})
			end):expect()

			rerender(React.createElement(
				MockedProvider,
				{
					mocks = mocks,
				},
				React.createElement(Component, {
					id = 2,
				} :: FIX_ANALYZE, hookResponse)
			))
			waitFor(function()
				expect(hookResponse).toHaveBeenLastCalledWith({
					data = CAR_DATA_RS8,
					loading = false,
					error = nil,
				})
			end):expect()

			resolve()
		end)

		itAsync("should return result when result is equivalent", function(resolve, reject)
			local CAR_QUERY_BY_ID = gql([[

						query($id: Int) {
						  car(id: $id) {
							make
							model
						  }
						}
					]])
			local CAR_DATA_A4 = { car = { make = "Audi", model = "A4", __typename = "Car" } }
			local mocks = {
				{
					request = { query = CAR_QUERY_BY_ID, variables = { id = 1 } },
					result = { data = CAR_DATA_A4 },
				},
				{
					request = { query = CAR_QUERY_BY_ID, variables = { id = 2 } },
					result = { data = CAR_DATA_A4 },
				},
			}
			local hookResponse = jest.fn().mockReturnValue(nil)

			local function Component(ref)
				local id, children, skip =
					ref.id, ref.children, (function()
						if ref.skip == nil then
							return false
						else
							return ref.skip
						end
					end)()

				local queryResult = useQuery(CAR_QUERY_BY_ID, {
					variables = { id = id },
					skip,
				})

				local data, loading, error_ = queryResult.data, queryResult.loading, queryResult.error
				return children({ data = data, loading = loading, ["error"] = error_ })
			end

			local rerender = render(React.createElement(
				MockedProvider,
				{
					mocks = mocks,
				},
				React.createElement(Component, {
					id = 1,
				} :: FIX_ANALYZE, hookResponse)
			)).rerender

			wait_(function()
				expect(hookResponse).toHaveBeenLastCalledWith({
					data = CAR_DATA_A4,
					loading = false,
					error = nil,
				})
			end):expect()

			rerender(React.createElement(
				MockedProvider,
				{
					mocks = mocks,
				},
				React.createElement(Component, {
					id = 2,
					skip = true,
				} :: FIX_ANALYZE, hookResponse)
			))

			hookResponse:mockClear()

			rerender(React.createElement(
				MockedProvider,
				{
					mocks = mocks,
				},
				React.createElement(Component, {
					id = 2,
				} :: FIX_ANALYZE, hookResponse)
			))

			waitFor(function()
				expect(hookResponse).toHaveBeenLastCalledWith({
					data = CAR_DATA_A4,
					loading = false,
					error = nil,
				})
			end):expect()
			resolve()
		end)

		itAsync("should not error when forcing an update with React >= 16.13.0", function(resolve, reject)
			local wasUpdateErrorLogged = false
			local consoleError = console.error
			console.error = function(msg: string)
				console.log(msg)
				wasUpdateErrorLogged = stringIndexOf(msg, "Cannot update a component") > -1
			end
			local CAR_MOCKS = Array.map({ 1, 2, 3, 4, 5, 6 }, function(something)
				return {
					request = { query = CAR_QUERY, variables = { something = something } },
					result = { data = CAR_RESULT_DATA },
					delay = 1000,
				} :: MockedResponse<any>
			end)
			local renderCount = 0

			local function InnerComponent(ref)
				local something = ref.something
				local queryResult = useQuery(CAR_QUERY, {
					fetchPolicy = "network-only",
					variables = { something = something },
				})
				rejectOnComponentThrow(reject, function()
					local loading, data = queryResult.loading, queryResult.data
					renderCount += 1
					if Boolean.toJSBoolean(loading) then
						return nil
					end
					expect(wasUpdateErrorLogged).toBeFalsy()
					expect(data).toEqual(CAR_RESULT_DATA)
				end)
				return nil
			end

			local function WrapperComponent(ref): React.ReactElement<any, any>?
				local something = ref.something
				local loading = useQuery(CAR_QUERY, {
					variables = { something = something },
				}).loading
				if loading then
					return nil
				else
					return React.createElement(InnerComponent, {
						something = (something :: number) + 1,
					})
				end
			end

			render(React.createElement(
				MockedProvider,
				{
					link = MockLink.new(CAR_MOCKS):setOnError(reject),
				},
				React.createElement(
					Fragment,
					nil,
					React.createElement(WrapperComponent, {
						something = 1,
					}),
					React.createElement(WrapperComponent, {
						something = 3,
					}),
					React.createElement(WrapperComponent, {
						something = 5,
					})
				)
			))

			wait_(function()
					expect(renderCount).toBe(3)
				end)
				-- ROBLOX deviation START: Roblox promise finally works different. We must handle successs and error
				:andThen(
					function()
						console.error = consoleError
					end
				)
				:catch(function(e)
					console.error = consoleError
					error(e)
				end)
				-- ROBLOX deviation END
				:andThen(resolve, reject)
		end)

		itAsync(
			"should update with proper loading state when variables change for cached queries",
			function(resolve, reject)
				local peopleQuery = gql([[
					query AllPeople($search: String!) {
				  		people(search: $search) {
							id
							name
				  		}
					}
				]])

				local peopleData = {
					people = {
						{ id = 1, name = "John Smith" },
						{ id = 2, name = "Sara Smith" },
						{ id = 3, name = "Budd Deey" },
					},
				}

				local mocks = {
					{
						request = { query = peopleQuery, variables = { search = "" } },
						result = { data = peopleData },
					},
					{
						request = { query = peopleQuery, variables = { search = "z" } },
						result = { data = { people = {} } },
					},
					{
						request = { query = peopleQuery, variables = { search = "zz" } },
						result = { data = { people = {} } },
					},
				}
				local renderCount = 0

				local function Component()
					local search, setSearch = useState("")
					local queryResult = useQuery(peopleQuery, {
						variables = {
							search = search,
						},
					})
					rejectOnComponentThrow(reject, function()
						local loading, data = queryResult.loading, queryResult.data
						--[[ ROBLOX comment: switch statement conversion ]]
						renderCount += 1
						local condition_ = renderCount
						if condition_ == 1 then
							expect(loading).toBeTruthy()
						elseif condition_ == 2 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(peopleData)
							setTimeout(function()
								return setSearch("z")
							end)
						elseif condition_ == 3 then
							expect(loading).toBeTruthy()
						elseif condition_ == 4 then
							expect(loading).toBeFalsy()
							expect(data).toEqual({ people = {} })
							setTimeout(function()
								return setSearch("")
							end)
						elseif condition_ == 5 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(peopleData)
							setTimeout(function()
								return setSearch("z")
							end)
						elseif condition_ == 6 then
							expect(loading).toBeFalsy()
							expect(data).toEqual({ people = {} })
							setTimeout(function()
								return setSearch("zz")
							end)
						elseif condition_ == 7 then
							expect(loading).toBeTruthy()
						elseif condition_ == 8 then
							expect(loading).toBeFalsy()
							expect(data).toEqual({ people = {} })
						end
					end)
					return nil
				end

				render(React.createElement(MockedProvider, {
					mocks = mocks,
				}, React.createElement(Component, nil)))

				return wait_(function()
					expect(renderCount).toBe(8)
				end):andThen(resolve, reject)
			end
		)
	end)

	describe("Polling", function()
		itAsync("should support polling", function(resolve, reject)
			local renderCount = 0

			local function Component()
				local queryResult = useQuery(CAR_QUERY, {
					-- ROBLOX deviation: using tick multiplier
					pollInterval = 10 * TICK,
				})

				rejectOnComponentThrow(reject, function()
					local data, loading, networkStatus, stopPolling =
						queryResult.data, queryResult.loading, queryResult.networkStatus, queryResult.stopPolling
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(networkStatus).toBe(NetworkStatus.loading)
					elseif condition_ == 2 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(CAR_RESULT_DATA)
						expect(networkStatus).toBe(NetworkStatus.ready)
						stopPolling(queryResult)
					else
						error(Error.new("Uh oh - we should have stopped polling!"))
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, {
				mocks = CAR_MOCKS,
			}, React.createElement(Component, nil)))

			return wait_(function()
				expect(renderCount).toBe(2)
			end):andThen(resolve, reject)
		end)

		itAsync("should stop polling when skip is true", function(resolve, reject)
			local renderCount = 0

			local function Component()
				local shouldSkip, setShouldSkip = useState(false)
				local queryResult = useQuery(CAR_QUERY, {
					-- ROBLOX deviation: using tick multiplier
					pollInterval = 100 * TICK / 10,
					skip = shouldSkip,
				})
				rejectOnComponentThrow(reject, function()
					local data, loading = queryResult.data, queryResult.loading
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
					elseif condition_ == 2 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(CAR_RESULT_DATA)
						setShouldSkip(true)
					elseif condition_ == 3 then
						expect(loading).toBeFalsy()
						expect(data).toBeUndefined()
					elseif condition_ == 4 then
						error(Error.new("Uh oh - we should have stopped polling!"))
					else
						-- Do nothing
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, {
				link = MockLink.new(CAR_MOCKS):setOnError(reject),
			}, React.createElement(Component, nil)))

			return wait_(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)

		itAsync("should start polling when skip goes from true to false", function(resolve, reject)
			local query = gql([[

					query car {
					  car {
						id
						make
					  }
					}
				]])
			local data1 = { car = { id = 1, make = "Venturi", __typename = "Car" } }
			local data2 = { car = { id = 2, make = "Wiesmann", __typename = "Car" } }
			local mocks = {
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data2 } },
			}
			local renderCount = 0

			local function Component()
				local shouldSkip, setShouldSkip = useState(false)
				local queryResult = useQuery(query, {
					-- ROBLOX deviation: using tick multiplier
					pollInterval = 100 * TICK / 10,
					skip = shouldSkip,
				})

				rejectOnComponentThrow(reject, function()
					local data, loading, stopPolling = queryResult.data, queryResult.loading, queryResult.stopPolling

					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(data).toBeUndefined()
					elseif condition_ == 2 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(data1)
						setShouldSkip(true)
					elseif condition_ == 3 then
						expect(loading).toBeFalsy()
						expect(data).toBeUndefined()
						setShouldSkip(false)
					elseif condition_ == 4 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(data1)
					elseif condition_ == 5 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(data2)
						stopPolling(queryResult)
					else
						reject(Error.new("too many updates"))
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, {
				link = MockLink.new(mocks):setOnError(reject),
			}, React.createElement(Component, nil)))

			return wait_(function()
				expect(renderCount).toBe(5)
			end):andThen(resolve, reject)
		end)

		local function useStatefulUnmount()
			local queryMounted, setQueryMounted = useState(true)
			local mounted = false
			useEffect(function()
				mounted = true
				expect(queryMounted).toBe(true)
				return function()
					mounted = false
				end
			end, {})
			return {
				mounted = queryMounted,
				unmount = function(_self)
					if Boolean.toJSBoolean(mounted) then
						setQueryMounted((function()
							mounted = false
							return mounted
						end)())
					end
				end,
			}
		end

		itAsync("should stop polling when the component is unmounted", function(resolve, reject)
			local mocks = Array.concat({}, CAR_MOCKS, CAR_MOCKS, CAR_MOCKS, CAR_MOCKS)
			local mockLink = MockLink.new(mocks):setOnError(reject)

			-- ROBLOX deviation: using jest.fn instead of spyOn (not available)
			local linkRequestSpy: any = jest.fn(mockLink.request)
			mockLink.request = linkRequestSpy

			local renderCount = 0

			local function QueryComponent(ref)
				local unmount = ref.unmount
				local queryResult = useQuery(CAR_QUERY, {
					-- ROBLOX deviation: using tick multiplier
					pollInterval = 10 * TICK,
				})
				rejectOnComponentThrow(reject, function()
					local data, loading = queryResult.data, queryResult.loading

					renderCount += 1
					local condition_ = renderCount

					if condition_ == 1 then
						expect(loading).toBeTruthy()
					elseif condition_ == 2 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(CAR_RESULT_DATA)
						expect(linkRequestSpy).toHaveBeenCalledTimes(1)
						setTimeout(function()
							unmount(ref)
							-- ROBLOX deviation: using tick multiplier
						end, 10 * TICK)
					else
						reject("unreached")
					end
				end)
				return nil
			end

			local function Component()
				local ref = useStatefulUnmount()
				local mounted, unmount = ref.mounted, ref.unmount

				return React.createElement(
					React.Fragment,
					nil,
					Boolean.toJSBoolean(mounted)
							and React.createElement(QueryComponent, {
								unmount = function()
									unmount(ref)
								end,
							})
						or nil
				)
			end

			render(React.createElement(MockedProvider, {
				mocks = CAR_MOCKS,
				link = mockLink,
			}, React.createElement(Component, nil)))

			return wait_(function()
				expect(linkRequestSpy).toHaveBeenCalledTimes(1)
				expect(renderCount).toBe(2)
			end):andThen(resolve, reject)
		end)

		itAsync("should stop polling when the component is unmounted when using StrictMode", function(resolve, reject)
			local mocks = Array.concat({}, CAR_MOCKS, CAR_MOCKS, CAR_MOCKS, CAR_MOCKS)
			local mockLink = MockLink.new(mocks):setOnError(reject)

			-- ROBLOX deviation: using jest.fn instead of spyOn (not available)
			local linkRequestSpy: any = jest.fn(mockLink.request)
			mockLink.request = linkRequestSpy

			local renderCount = 0

			local function QueryComponent(ref)
				local unmount = ref.unmount
				local queryResult = useQuery(CAR_QUERY, {
					-- ROBLOX deviation: using tick multiplier
					pollInterval = 10 * TICK,
				})
				local data, loading = queryResult.data, queryResult.loading

				renderCount += 1
				local condition_ = renderCount
				if condition_ == 1 or condition_ == 2 then
					expect(loading).toBeTruthy()
				elseif condition_ == 3 or condition_ == 4 then
					expect(loading).toBeFalsy()
					expect(data).toEqual(CAR_RESULT_DATA)
					expect(linkRequestSpy).toHaveBeenCalledTimes(1)
					if renderCount == 3 then
						setTimeout(function()
							unmount(ref)
							-- ROBLOX deviation: using tick multiplier
						end, 10 * TICK)
					end
				else
					reject("unreached")
				end
				return nil
			end

			local function Component()
				local ref = useStatefulUnmount()
				local mounted, unmount = ref.mounted, ref.unmount

				return React.createElement(
					React.Fragment,
					nil,
					Boolean.toJSBoolean(mounted)
							and React.createElement(QueryComponent, {
								unmount = function()
									unmount(ref)
								end,
							})
						or nil
				)
			end

			render(React.createElement(
				React.StrictMode,
				nil,
				React.createElement(MockedProvider, {
					mocks = CAR_MOCKS,
					link = mockLink,
				}, React.createElement(Component, nil))
			))

			return wait_(function()
				expect(linkRequestSpy).toHaveBeenCalledTimes(1)
				expect(renderCount).toBe(4)
			end):andThen(resolve, reject)
		end)

		itAsync(
			"should not throw an error if `stopPolling` is called manually after "
				.. "a component has unmounted (even though polling has already been "
				.. "stopped automatically)",
			function(resolve, reject)
				local unmount: any
				local renderCount = 0

				local function Component()
					local queryResult = useQuery(CAR_QUERY, {
						pollInterval = 10 * TICK,
					})
					rejectOnComponentThrow(reject, function()
						local data, loading, stopPolling =
							queryResult.data, queryResult.loading, queryResult.stopPolling

						--[[ ROBLOX comment: switch statement conversion ]]
						if renderCount == 0 then
							expect(loading).toBeTruthy()
						elseif renderCount == 1 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(CAR_RESULT_DATA)
							setTimeout(function()
								unmount()
								stopPolling(queryResult)
							end)
						end
						renderCount += 1
					end)
					return nil
				end

				local mocks = Array.concat({}, CAR_MOCKS, CAR_MOCKS)

				local rendered = render(React.createElement(MockedProvider, {
					link = MockLink.new(mocks):setOnError(reject),
				}, React.createElement(Component, nil)))

				unmount = function()
					rendered.unmount()
				end

				return wait_(function()
					expect(renderCount).toBe(2)
				end):andThen(resolve, reject)
			end
		)

		itAsync("stop polling and start polling should work with StrictMode", function(resolve, reject)
			local query = gql([[

					query car {
					  car {
						id
						make
					  }
					}
				]])
			local data1 = { car = { id = 1, make = "Venturi", __typename = "Car" } }
			local mocks = { { request = { query = query }, result = { data = data1 } } }
			local renderCount = 0

			local function Component()
				local queryResult = useQuery(query, {
					pollInterval = 100 * TICK / 10,
				})
				rejectOnComponentThrow(reject, function()
					local data, loading, stopPolling = queryResult.data, queryResult.loading, queryResult.stopPolling

					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 or condition_ == 2 then
						expect(loading).toBeTruthy()
						expect(data).toBeUndefined()
					elseif condition_ == 3 or condition_ == 4 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(data1)
						stopPolling(queryResult)
					else
						reject(Error.new("Unexpected render count"))
					end
				end)
				return nil
			end

			render(React.createElement(
				React.StrictMode,
				nil,
				React.createElement(MockedProvider, {
					link = MockLink.new(mocks):setOnError(reject),
				}, React.createElement(Component, nil))
			))

			return wait_(function()
				expect(renderCount).toBe(4)
			end):andThen(function()
				setTimeout(resolve, 300)
			end, reject)
		end)

		it("should set called to true by default", function()
			local function Component()
				local queryResult = useQuery(CAR_QUERY)
				local loading, called = queryResult.loading, queryResult.called
				expect(loading).toBeTruthy()
				expect(called).toBeTruthy()
				return nil
			end

			render(React.createElement(MockedProvider, {
				mocks = CAR_MOCKS,
			}, React.createElement(Component, nil)))
		end)
	end)

	describe("Error handling", function()
		itAsync("should render GraphQLError's", function(resolve, reject)
			local query = gql([[

					query TestQuery {
					  rates(currency: "USD") {
						rate
					  }
					}
				]])

			local mocks = {
				{ request = { query = query }, result = { errors = { GraphQLError.new("forced error") } } },
			}

			local function Component()
				local queryResult = useQuery(query)
				rejectOnComponentThrow(reject, function()
					local loading, error_ = queryResult.loading, queryResult.error

					if not Boolean.toJSBoolean(loading) then
						expect(error_).toBeDefined()
						expect(error_.message).toEqual("forced error")
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, {
				mocks = mocks,
			}, React.createElement(Component, nil)))
			return wait_():andThen(resolve, reject)
		end)

		itAsync("should only call onError callbacks once", function(resolve, reject)
			local query = gql([[

						query SomeQuery {
						  stuff {
							thing
						  }
						}
					]])

			local resultData = { stuff = { thing = "it!", __typename = "Stuff" } }
			local callCount = 0

			local link = ApolloLink.new(function()
				if not Boolean.toJSBoolean(callCount) then
					callCount += 1
					return Observable.new(function(observer)
						observer:error(Error.new("Oh no!"))
					end)
				else
					return Observable.of({ data = resultData })
				end
			end)
			local client = ApolloClient.new({ link = link, cache = InMemoryCache.new() })
			local onError: any
			local onErrorPromise = Promise.new(function(resolve)
				onError = resolve
				return onError
			end)
			local renderCount = 0
			local function Component()
				local queryResult = useQuery(query, {
					onError = onError,
					notifyOnNetworkStatusChange = true,
				})

				rejectOnComponentThrow(reject, function()
					local loading, error_, refetch, data, networkStatus =
						queryResult.loading,
						queryResult.error,
						queryResult.refetch,
						queryResult.data,
						queryResult.networkStatus

					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
					elseif condition_ == 2 then
						expect(loading).toBeFalsy()
						expect(error_).toBeDefined()
						expect(error_.message).toEqual("Oh no!")
						onErrorPromise:andThen(function()
							return refetch(queryResult)
						end)
					elseif condition_ == 3 then
						expect(loading).toBeTruthy()
						expect(networkStatus).toBe(NetworkStatus.refetch)
					elseif condition_ == 4 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(resultData)
					else
						-- Do nothing
					end
				end)
				return nil
			end

			render(React.createElement(ApolloProvider, {
				client = client,
			}, React.createElement(Component, nil)))

			return wait_(function()
				expect(renderCount).toBe(4)
			end):andThen(resolve, reject)
		end)

		itAsync("should persist errors on re-render if they are still valid", function(resolve, reject)
			local query = gql([[

					query SomeQuery {
					  stuff {
						thing
					  }
					}
				]])

			local mocks = {
				{
					request = { query = query },
					result = { errors = { GraphQLError.new("forced error") } },
				},
			}
			local renderCount = 0
			local function App()
				local _tick, forceUpdate = useReducer(function(x: number)
					return x + 1
				end, 0, nil)

				local queryRef = useQuery(query)

				rejectOnComponentThrow(reject, function()
					local loading, error_ = queryRef.loading, queryRef.error

					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount

					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(error_).toBeUndefined()
					elseif condition_ == 2 then
						expect(error_).toBeDefined()
						expect(error_.message).toEqual("forced error")
						setTimeout(function()
							-- ROBLOX TODO: upstream this more correct invocation that actually typechecks
							forceUpdate(0)
						end)
					elseif condition_ == 3 then
						expect(error_).toBeDefined()
						expect(error_.message).toEqual("forced error")
					else
						-- Do nothing
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, {
				mocks = mocks,
			}, React.createElement(App, nil)))

			return wait_(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)

		itAsync(
			"should persist errors on re-render when inlining onError and/or " .. "onCompleted callbacks",
			function(resolve, reject)
				local query = gql([[

								query SomeQuery {
								  stuff {
									thing
								  }
								}
							]])

				local mocks = {
					{
						request = { query = query },
						result = { errors = { GraphQLError.new("forced error") } },
					},
				}

				Array.forEach(mocks, function(item)
					table.insert(mocks, item)
				end)

				Array.forEach(mocks, function(item)
					table.insert(mocks, item)
				end)

				-- ROBLOX FIXME Luau: Type '{{| request: {| query: any |}, result: {| errors: {any} |} |}}' could not be converted into 'Array<MockedResponse>'
				local link = MockLink.new(mocks :: Array<any>):setOnError(reject)
				local renderCount = 0

				local function App()
					local _tick, forceUpdate = useReducer(function(x: number)
						return x + 1
					end, 0, nil)

					local queryRef = useQuery(query, {
						onError = function() end,
						onCompleted = function() end,
					})

					rejectOnComponentThrow(reject, function()
						local loading, error_ = queryRef.loading, queryRef.error

						--[[ ROBLOX comment: switch statement conversion ]]
						renderCount += 1
						local condition_ = renderCount
						if condition_ == 1 then
							expect(loading).toBeTruthy()
							expect(error_).toBeUndefined()
						elseif condition_ == 2 then
							expect(error_).toBeDefined()
							expect(error_.message).toEqual("forced error")
							setTimeout(function()
								-- ROBLOX TODO: upstream this more correct invocation that actually typechecks
								forceUpdate(0)
							end)
						elseif condition_ == 3 then
							expect(error_).toBeDefined()
							expect(error_.message).toEqual("forced error")
						else
							-- Do nothing
						end
					end)
					return nil
				end

				render(React.createElement(MockedProvider, {
					link = link,
				}, React.createElement(App, nil)))

				return wait_(function()
					expect(renderCount).toBe(3)
				end):andThen(resolve, reject)
			end
		)

		itAsync(
			"should render errors (different error messages) with loading done on refetch",
			function(resolve, reject)
				local query = gql([[

								query SomeQuery {
								  stuff {
									thing
								  }
								}
							]])

				local mocks = {
					{
						request = { query = query },
						result = {
							errors = { GraphQLError.new("an error 1") },
						},
					},
					{
						request = { query = query },
						result = {
							errors = { GraphQLError.new("an error 2") },
						},
					},
				}
				local renderCount = 0

				local function App()
					local queryRef = useQuery(query, {
						notifyOnNetworkStatusChange = true,
					})

					rejectOnComponentThrow(reject, function()
						local loading, error_, refetch = queryRef.loading, queryRef.error, queryRef.refetch

						--[[ ROBLOX comment: switch statement conversion ]]
						renderCount += 1
						local condition_ = renderCount
						if condition_ == 1 then
							expect(loading).toBeTruthy()
							expect(error_).toBeUndefined()
						elseif condition_ == 2 then
							expect(loading).toBeFalsy()
							expect(error_).toBeDefined()
							expect(error_.message).toEqual("an error 1")
							setTimeout(function()
								-- catch here to avoid failing due to 'uncaught promise rejection'
								refetch(queryRef):catch(function() end)
							end)
						elseif condition_ == 3 then
							expect(loading).toBeTruthy()
							expect(error_).toBeUndefined()
						elseif condition_ == 4 then
							expect(loading).toBeFalsy()
							expect(error_).toBeDefined()
							expect(error_.message).toEqual("an error 2")
						else
							-- Do nothing
						end
					end)
					return nil
				end

				render(React.createElement(MockedProvider, {
					mocks = mocks,
				}, React.createElement(App, nil)))

				return wait_(function()
					expect(renderCount).toBe(4)
				end):andThen(resolve, reject)
			end
		)

		itAsync("should not re-render same error message on refetch", function(resolve, reject)
			local query = gql([[

						query SomeQuery {
						  stuff {
							thing
						  }
						}
					]])

			local mocks = {
				{
					request = { query = query },
					result = { errors = { GraphQLError.new("same error message") } },
				},
				{
					request = { query = query },
					result = { errors = { GraphQLError.new("same error message") } },
				},
			}
			local renderCount = 0

			local function App()
				local queryRef = useQuery(query, {
					notifyOnNetworkStatusChange = true,
				})

				rejectOnComponentThrow(reject, function()
					local loading, error_, refetch = queryRef.loading, queryRef.error, queryRef.refetch

					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount

					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(error_).toBeUndefined()
					elseif condition_ == 2 then
						expect(loading).toBeFalsy()
						expect(error_).toBeDefined()
						expect(error_.message).toEqual("same error message")
						refetch(queryRef):catch(function(error_)
							if error_.message ~= "same error message" then
								reject(error_)
							end
						end)
					end
					if condition_ == 3 then
						expect(loading).toBeTruthy()
						expect(error_).toBeUndefined()
					end
					if condition_ == 4 then
						expect(loading).toBeFalsy()
						expect(error_).toBeDefined()
						expect(error_.message).toEqual("same error message")
					else
						-- Do nothing
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, {
				mocks = mocks,
			}, React.createElement(App, nil)))

			return wait_(function()
				expect(renderCount).toBe(4)
			end):andThen(resolve, reject)
		end)

		itAsync(
			"should render both success and errors (same error messages) with loading done on refetch",
			function(resolve, reject)
				local mocks = {
					{
						request = { query = CAR_QUERY },
						result = { errors = { GraphQLError.new("same error message") } },
					},
					{ request = { query = CAR_QUERY }, result = { data = CAR_RESULT_DATA } } :: any,
					{
						request = { query = CAR_QUERY },
						result = { errors = { GraphQLError.new("same error message") } },
					},
				}
				local renderCount = 0

				local function App()
					local queryRef = useQuery(CAR_QUERY, {
						notifyOnNetworkStatusChange = true,
					})

					rejectOnComponentThrow(reject, function()
						local loading, data, error_, refetch =
							queryRef.loading, queryRef.data, queryRef.error, queryRef.refetch

						--[[ ROBLOX comment: switch statement conversion ]]
						renderCount += 1
						local condition_ = renderCount

						if condition_ == 1 then
							expect(loading).toBeTruthy()
							expect(error_).toBeUndefined()
						elseif condition_ == 2 then
							expect(loading).toBeFalsy()
							expect(error_).toBeDefined()
							expect(error_.message).toEqual("same error message")
							setTimeout(function()
								-- catch here to avoid failing due to 'uncaught promise rejection'
								refetch(queryRef):catch(function() end)
							end)
						elseif condition_ == 3 then
							expect(loading).toBeTruthy()
						elseif condition_ == 4 then
							expect(loading).toBeFalsy()
							expect(error_).toBeUndefined()
							expect(data).toEqual(CAR_RESULT_DATA)
							setTimeout(function()
								-- catch here to avoid failing due to 'uncaught promise rejection'
								refetch(queryRef):catch(function() end)
							end)
						elseif condition_ == 5 then
							expect(loading).toBeTruthy()
						elseif condition_ == 6 then
							expect(loading).toBeFalsy()
							expect(error_).toBeDefined()
							expect(error_.message).toEqual("same error message")
						else
							-- Do nothing
						end
					end)
					return nil
				end
				render(React.createElement(MockedProvider, {
					mocks = mocks,
				}, React.createElement(App, nil)))
				return wait_(function()
					expect(renderCount).toBe(6)
				end):andThen(resolve, reject)
			end
		)
	end)

	describe("Pagination", function()
		-- Because fetchMore with updateQuery is deprecated, this setup/teardown
		-- code is used to squash deprecation notices.
		-- TODO: delete me after fetchMore with updateQuery is removed.
		local spy: any
		local warned = false
		local originalFn
		beforeEach(function()
			if not warned then
				originalFn = console.warn
				-- ROBLOX deviation: using jest.fn instead of spyOn (not available)
				spy = jest.fn(function()
					warned = true
				end)
				console.warn = spy
			end
		end)
		afterEach(function()
			if spy then
				console.warn = originalFn
				spy = nil
			end
		end)
		describe(
			"should render fetchMore-updated results with proper loading status, when `notifyOnNetworkStatusChange` is true",
			function()
				local carQuery: DocumentNode = gql([[

					query cars($limit: Int) {
					  cars(limit: $limit) {
						id
						make
						model
						vin
						__typename
					  }
					}
				]])

				local carResults = {
					cars = {
						{
							id = 1,
							make = "Audi",
							model = "RS8",
							vin = "DOLLADOLLABILL",
							__typename = "Car",
						},
					},
				}
				local moreCarResults = {
					cars = {
						{
							id = 2,
							make = "Audi",
							model = "eTron",
							vin = "TREESRGOOD",
							__typename = "Car",
						},
					},
				}
				local mocks = {
					{
						request = { query = carQuery, variables = { limit = 1 } },
						result = { data = carResults },
					},
					{
						request = { query = carQuery, variables = { limit = 1 } },
						result = { data = moreCarResults },
					},
				}

				itAsync("updateQuery", function(resolve, reject)
					local renderCount = 0

					local function App()
						local ref =
							useQuery(carQuery, { variables = { limit = 1 }, notifyOnNetworkStatusChange = true })
						rejectOnComponentThrow(reject, function()
							local loading, networkStatus, data, fetchMore =
								ref.loading, ref.networkStatus, ref.data, ref.fetchMore

							renderCount += 1
							local condition_ = renderCount
							if condition_ == 1 then
								expect(loading).toBeTruthy()
								expect(networkStatus).toBe(NetworkStatus.loading)
								expect(data).toBeUndefined()
							elseif condition_ == 2 then
								expect(loading).toBeFalsy()
								expect(networkStatus).toBe(NetworkStatus.ready)
								expect(data).toEqual(carResults)
								fetchMore(ref, {
									variables = { limit = 1 },
									updateQuery = function(_self, prev, ref_)
										local fetchMoreResult = ref_.fetchMoreResult
										return {
											cars = Array.concat({}, prev.cars, fetchMoreResult.cars),
										}
									end,
								})
							elseif condition_ == 3 then
								expect(loading).toBeTruthy()
								expect(networkStatus).toBe(NetworkStatus.fetchMore)
								expect(data).toEqual(carResults)
							elseif condition_ == 4 then
								expect(loading).toBeFalsy()
								expect(networkStatus).toBe(NetworkStatus.ready)
								expect(data).toEqual({
									cars = {
										carResults.cars[1],
										moreCarResults.cars[1],
									},
								})
							else
								reject("too many updates")
							end
						end)
						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(App, nil)))

					return wait_(function()
						expect(renderCount).toBe(4)
						-- TODO: delete me after fetchMore with updateQuery is removed.
						if spy then
							expect(spy).toHaveBeenCalledTimes(1)
							console.warn = originalFn
						end
					end):andThen(resolve, reject)
				end)

				itAsync("field policy", function(resolve, reject)
					local renderCount = 0
					local function App()
						local ref =
							useQuery(carQuery, { variables = { limit = 1 }, notifyOnNetworkStatusChange = true })
						local loading, networkStatus, data, fetchMore =
							ref.loading, ref.networkStatus, ref.data, ref.fetchMore
						renderCount += 1
						local condition_ = renderCount
						if condition_ == 1 then
							expect(loading).toBeTruthy()
							expect(networkStatus).toBe(NetworkStatus.loading)
							expect(data).toBeUndefined()
						elseif condition_ == 2 then
							expect(loading).toBeFalsy()
							expect(networkStatus).toBe(NetworkStatus.ready)
							expect(data).toEqual(carResults)
							fetchMore(ref, { variables = { limit = 1 } })
						elseif condition_ == 3 then
							expect(loading).toBeTruthy()
							expect(networkStatus).toBe(NetworkStatus.fetchMore)
							expect(data).toEqual(carResults)
						elseif condition_ == 4 then
							expect(loading).toBeFalsy()
							expect(networkStatus).toBe(NetworkStatus.ready)
							expect(data).toEqual({
								cars = {
									carResults.cars[1],
									moreCarResults.cars[1],
								},
							})
						else
							reject("too many updates")
						end
						return nil
					end
					local cache = InMemoryCache.new({
						typePolicies = { Query = { fields = { cars = concatPagination() } } },
					} :: any)

					render(
						React.createElement(
							MockedProvider,
							{ mocks = mocks, cache = cache },
							React.createElement(App, nil)
						)
					)

					return wait_(function()
						expect(renderCount).toBe(4)
						-- TODO: delete me after fetchMore with updateQuery is removed.
						if spy then
							expect(spy).toHaveBeenCalledTimes(1)
							console.warn = originalFn
						end
					end):andThen(resolve, reject)
				end)
			end
		)

		describe(
			"should render fetchMore-updated results with no loading status, when `notifyOnNetworkStatusChange` is false",
			function()
				local carQuery: DocumentNode = gql([[

					query cars($limit: Int) {
					  cars(limit: $limit) {
						id
						make
						model
						vin
						__typename
					  }
					}
				]])

				local carResults = {
					cars = {
						{
							id = 1,
							make = "Audi",
							model = "RS8",
							vin = "DOLLADOLLABILL",
							__typename = "Car",
						},
					},
				}

				local moreCarResults = {
					cars = {
						{
							id = 2,
							make = "Audi",
							model = "eTron",
							vin = "TREESRGOOD",
							__typename = "Car",
						},
					},
				}

				local mocks = {
					{
						request = { query = carQuery, variables = { limit = 1 } },
						result = { data = carResults },
					},
					{
						request = { query = carQuery, variables = { limit = 1 } },
						result = { data = moreCarResults },
					},
				}

				itAsync("updateQuery_", function(resolve, reject)
					local renderCount = 0
					local function App()
						local ref =
							useQuery(carQuery, { variables = { limit = 1 }, notifyOnNetworkStatusChange = false })
						local loading, data, fetchMore = ref.loading, ref.data, ref.fetchMore

						local condition_ = renderCount
						if condition_ == 0 then
							expect(loading).toBeTruthy()
						elseif condition_ == 1 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(carResults)
							fetchMore(ref, {
								variables = { limit = 1 },
								updateQuery = function(_self, prev, ref_)
									local fetchMoreResult = ref_.fetchMoreResult
									return {
										cars = Array.concat({}, prev.cars, fetchMoreResult.cars),
									}
								end,
							})
						elseif condition_ == 2 then
							expect(loading).toBeFalsy()
							expect(data).toEqual({
								cars = {
									carResults.cars[1],
									moreCarResults.cars[1],
								},
							})
						end
						renderCount += 1
						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(App, nil)))

					return wait_(function()
						expect(renderCount).toBe(3)
					end):andThen(resolve, reject)
				end)

				itAsync("field policy_", function(resolve, reject)
					local renderCount = 0
					local function App()
						local ref =
							useQuery(carQuery, { variables = { limit = 1 }, notifyOnNetworkStatusChange = false })
						local loading, data, fetchMore = ref.loading, ref.data, ref.fetchMore
						if renderCount == 0 then
							expect(loading).toBeTruthy()
						elseif renderCount == 1 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(carResults)
							fetchMore(ref, { variables = { limit = 1 } })
						elseif renderCount == 2 then
							expect(loading).toBeFalsy()
							expect(data).toEqual({
								cars = {
									carResults.cars[1],
									moreCarResults.cars[1],
								},
							})
						end
						renderCount += 1
						return nil
					end

					local cache = InMemoryCache.new({
						typePolicies = { Query = { fields = { cars = concatPagination() } } },
					} :: any)

					render(
						React.createElement(
							MockedProvider,
							{ mocks = mocks, cache = cache },
							React.createElement(App, nil)
						)
					)

					return wait_(function()
						expect(renderCount).toBe(3)
					end):andThen(resolve, reject)
				end)
			end
		)
	end)

	describe("Refetching", function()
		itAsync("should properly handle refetching with different variables", function(resolve, reject)
			local carQuery: DocumentNode = gql([[

					query cars($id: Int) {
					  cars(id: $id) {
						id
						make
						model
						vin
						__typename
					  }
					}
				]])
			local carData1 = {
				cars = {
					{
						id = 1,
						make = "Audi",
						model = "RS8",
						vin = "DOLLADOLLABILL",
						__typename = "Car",
					},
				},
			}
			local carData2 = {
				cars = {
					{
						id = 2,
						make = "Audi",
						model = "eTron",
						vin = "TREESRGOOD",
						__typename = "Car",
					},
				},
			}
			local mocks = {
				{
					request = { query = carQuery, variables = { id = 1 } },
					result = {
						data = carData1,
					},
				},
				{
					request = { query = carQuery, variables = { id = 2 } },
					result = {
						data = carData2,
					},
				},
				{
					request = { query = carQuery, variables = { id = 1 } },
					result = {
						data = carData1,
					},
				},
			}
			local renderCount = 0

			local function App()
				local ref = useQuery(carQuery, { variables = { id = 1 }, notifyOnNetworkStatusChange = true })
				local loading, data, refetch = ref.loading, ref.data, ref.refetch

				--[[ ROBLOX comment: switch statement conversion ]]
				if renderCount == 0 then
					expect(loading).toBeTruthy()
				elseif renderCount == 1 then
					expect(loading).toBeFalsy()
					expect(data).toEqual(carData1)
					refetch(ref, { id = 2 })
				elseif renderCount == 2 then
					expect(loading).toBeTruthy()
				elseif renderCount == 3 then
					expect(loading).toBeFalsy()
					expect(data).toEqual(carData2)
					refetch(ref, { id = 1 })
				elseif renderCount == 4 then
					expect(loading).toBeTruthy()
				elseif renderCount == 5 then
					expect(loading).toBeFalsy()
					expect(data).toEqual(carData1)
				end

				renderCount += 1
				return nil
			end
			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(App, nil)))
			return wait_(function()
				expect(renderCount).toBe(6)
			end):andThen(resolve, reject)
		end)
	end)

	describe("options.refetchWritePolicy", function()
		local query = gql([[

				query GetPrimes ($min: number, $max: number) {
				  primes(min: $min, max: $max)
				}
			]])

		local mocks = {
			{
				request = { query = query, variables = { min = 0, max = 12 } },
				result = { data = { primes = { 2, 3, 5, 7, 11 } } },
			},
			{
				request = { query = query, variables = { min = 12, max = 30 } },
				result = { data = { primes = { 13, 17, 19, 23, 29 } } },
			},
		}

		itAsync('should support explicit "overwrite"', function(resolve, reject)
			local mergeParams: Array<Array<any>> = {}
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							primes = {
								keyArgs = false,
								merge = function(_self, existing, incoming)
									table.insert(mergeParams, { existing, incoming })
									return Boolean.toJSBoolean(existing) and Array.concat({}, existing, incoming)
										or incoming
								end,
							},
						},
					},
				},
			} :: any)
			local renderCount = 0

			local function App()
				local ref = useQuery(query, {
					variables = { min = 0, max = 12 },
					notifyOnNetworkStatusChange = true,
					-- This is the key line in this test.
					refetchWritePolicy = "overwrite",
				})

				rejectOnComponentThrow(reject, function()
					local loading, networkStatus, data, error_, refetch =
						ref.loading, ref.networkStatus, ref.data, ref.error, ref.refetch
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(error_).toBeUndefined()
						expect(data).toBeUndefined()
						expect(typeof(refetch)).toBe("function")
					elseif condition_ == 2 then
						expect(loading).toBe(false)
						expect(error_).toBeUndefined()
						expect(data).toEqual({ primes = { 2, 3, 5, 7, 11 } })
						expect(mergeParams).toEqual({ { nil, { 2, 3, 5, 7, 11 } :: any } })
						act(function()
							refetch(ref, { min = 12, max = 30 }):andThen(function(result)
								expect(result).toEqual({
									loading = false,
									networkStatus = NetworkStatus.ready,
									data = { primes = { 13, 17, 19, 23, 29 } },
								})
							end)
						end)
					elseif condition_ == 3 then
						expect(loading).toBe(true)
						expect(error_).toBeUndefined()
						expect(data).toEqual({
							-- We get the stale data because we configured keyArgs: false.
							primes = { 2, 3, 5, 7, 11 },
						})
						-- This networkStatus is setVariables instead of refetch because
						-- we called refetch with new variables.
						expect(networkStatus).toBe(NetworkStatus.setVariables)
					elseif condition_ == 4 then
						expect(loading).toBe(false)
						expect(error_).toBeUndefined()
						expect(data).toEqual({ primes = { 13, 17, 19, 23, 29 } })
						expect(mergeParams).toEqual({
							{ nil, { 2, 3, 5, 7, 11 } :: any },
							-- Without refetchWritePolicy: "overwrite", this array will be
							-- all 10 primes (2 through 29) together.
							{ nil, { 13, 17, 19, 23, 29 } :: any },
						})
					else
						reject("too many renders")
					end
				end)

				return nil
			end
			render(React.createElement(MockedProvider, { cache = cache, mocks = mocks }, React.createElement(App, nil)))
			return wait_(function()
				expect(renderCount).toBe(4)
			end):andThen(resolve, reject)
		end)

		itAsync('should support explicit "merge"', function(resolve, reject)
			local mergeParams: Array<any> = {}
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							primes = {
								keyArgs = false,
								merge = function(_self, existing, incoming)
									table.insert(mergeParams, { existing, incoming })
									return Boolean.toJSBoolean(existing) and Array.concat({}, existing, incoming)
										or incoming
								end,
							},
						},
					},
				},
			} :: any)
			local renderCount = 0

			local function App()
				local ref = useQuery(query, {
					variables = { min = 0, max = 12 },
					notifyOnNetworkStatusChange = true,
					-- This is the key line in this test.
					refetchWritePolicy = "merge",
				})

				rejectOnComponentThrow(reject, function()
					local loading, networkStatus, data, error_, refetch =
						ref.loading, ref.networkStatus, ref.data, ref.error, ref.refetch

					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(error_).toBeUndefined()
						expect(data).toBeUndefined()
						expect(typeof(refetch)).toBe("function")
					elseif condition_ == 2 then
						expect(loading).toBe(false)
						expect(error_).toBeUndefined()
						expect(data).toEqual({ primes = { 2, 3, 5, 7, 11 } })
						expect(mergeParams).toEqual({ { nil, { 2, 3, 5, 7, 11 } :: any } })
						act(function()
							refetch(ref, { min = 12, max = 30 }):andThen(function(result)
								expect(result).toEqual({
									loading = false,
									networkStatus = NetworkStatus.ready,
									data = { primes = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29 } },
								})
							end)
						end)
					elseif condition_ == 3 then
						expect(loading).toBe(true)
						expect(error_).toBeUndefined()
						expect(data).toEqual({
							-- We get the stale data because we configured keyArgs: false.
							primes = { 2, 3, 5, 7, 11 },
						})
						-- This networkStatus is setVariables instead of refetch because
						-- we called refetch with new variables.
						expect(networkStatus).toBe(NetworkStatus.setVariables)
					elseif condition_ == 4 then
						expect(loading).toBe(false)
						expect(error_).toBeUndefined()
						expect(data).toEqual({
							-- Thanks to refetchWritePolicy: "merge".
							primes = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29 },
						})
						expect(mergeParams).toEqual({
							{ nil, { 2, 3, 5, 7, 11 } :: any },
							-- This indicates concatenation happened.
							{ { 2, 3, 5, 7, 11 } :: any, { 13, 17, 19, 23, 29 } :: any },
						})
					else
						reject("too many renders")
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { cache = cache, mocks = mocks }, React.createElement(App, nil)))

			return wait_(function()
				expect(renderCount).toBe(4)
			end):andThen(resolve, reject)
		end)

		itAsync('should assume default refetchWritePolicy value is "overwrite"', function(resolve, reject)
			local mergeParams: Array<Array<any>> = {}
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							primes = {
								keyArgs = false,
								merge = function(_self, existing, incoming)
									table.insert(mergeParams, { existing, incoming })
									return Boolean.toJSBoolean(existing) and Array.concat({}, existing, incoming)
										or incoming
								end,
							},
						},
					},
				},
			} :: any)
			local renderCount = 0

			local function App()
				local ref = useQuery(query, {
					variables = { min = 0, max = 12 },
					notifyOnNetworkStatusChange = true,
					-- Intentionally not passing refetchWritePolicy.
				})
				rejectOnComponentThrow(reject, function()
					local loading, networkStatus, data, error_, refetch =
						ref.loading, ref.networkStatus, ref.data, ref.error, ref.refetch

					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(error_).toBeUndefined()
						expect(data).toBeUndefined()
						expect(typeof(refetch)).toBe("function")
					elseif condition_ == 2 then
						expect(loading).toBe(false)
						expect(error_).toBeUndefined()
						expect(data).toEqual({ primes = { 2, 3, 5, 7, 11 } })
						expect(mergeParams).toEqual({
							{ nil, { 2, 3, 5, 7, 11 } :: any },
						})
						act(function()
							refetch(ref, { min = 12, max = 30 }):andThen(function(result)
								expect(result).toEqual({
									loading = false,
									networkStatus = NetworkStatus.ready,
									data = { primes = { 13, 17, 19, 23, 29 } },
								})
							end)
						end)
					elseif condition_ == 3 then
						expect(loading).toBe(true)
						expect(error_).toBeUndefined()
						expect(data).toEqual({
							-- We get the stale data because we configured keyArgs: false.
							primes = { 2, 3, 5, 7, 11 },
						})
						-- This networkStatus is setVariables instead of refetch because
						-- we called refetch with new variables.
						expect(networkStatus).toBe(NetworkStatus.setVariables)
					elseif condition_ == 4 then
						expect(loading).toBe(false)
						expect(error_).toBeUndefined()
						expect(data).toEqual({ primes = { 13, 17, 19, 23, 29 } })
						expect(mergeParams).toEqual({
							{ nil, { 2, 3, 5, 7, 11 } :: any },
							-- Without refetchWritePolicy: "overwrite", this array will be
							-- all 10 primes (2 through 29) together.
							{ nil, { 13, 17, 19, 23, 29 } :: any },
						})
					else
						reject("too many renders")
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { cache = cache, mocks = mocks }, React.createElement(App, nil)))

			return wait_(function()
				expect(renderCount).toBe(4)
			end):andThen(resolve, reject)
		end)
	end)

	describe("Partial refetching", function()
		-- ROBLOX FIXME: Test leaking to the next one
		-- ROBLOX FIXME Luau: could not be converted into '(...any) -> a'
		withErrorSpy(
			itAsync.skip :: any,
			"should attempt a refetch when the query result was marked as being "
				.. "partial, the returned data was reset to an empty Object by the "
				.. "Apollo Client QueryManager (due to a cache miss), and the "
				.. "`partialRefetch` prop is `true`",
			function(resolve, reject)
				local query: DocumentNode = gql([[

						query AllPeople($name: String!) {
						  allPeople(name: $name) {
							people {
							  name
							}
						  }
						}
					]])
				type Data = { allPeople: { people: Array<{ name: string }> } }

				local peopleData: Data = { allPeople = { people = { { name = "Luke Skywalker" } } } }

				local link = mockSingleLink({
					request = { query = query, variables = { someVar = "abc123" } },
					result = { data = nil },
				}, {
					request = { query = query, variables = { someVar = "abc123" } },
					result = { data = peopleData },
				})
				local client = ApolloClient.new({ link = link, cache = InMemoryCache.new() })
				local renderCount = 0

				local function Component()
					local loading, data, networkStatus
					do
						local ref = useQuery(query, {
							variables = { someVar = "abc123" },
							partialRefetch = true,
							notifyOnNetworkStatusChange = true,
						})
						loading, data, networkStatus = ref.loading, ref.data, ref.networkStatus
					end

					rejectOnComponentThrow(reject, function()
						--[[ ROBLOX comment: switch statement conversion ]]
						renderCount += 1
						local condition_ = renderCount
						if condition_ == 1 then
							-- Initial loading render
							expect(loading).toBeTruthy()
							expect(data).toBeUndefined()
							expect(networkStatus).toBe(NetworkStatus.loading)
						elseif condition_ == 2 then
							-- `data` is missing and `partialRetch` is true, so a refetch
							-- is triggered and loading is set as true again
							expect(loading).toBeTruthy()
							expect(data).toBeUndefined()
							expect(networkStatus).toBe(NetworkStatus.loading)
						elseif condition_ == 3 then
							expect(loading).toBeTruthy()
							expect(data).toBeUndefined()
							expect(networkStatus).toBe(NetworkStatus.refetch)
						elseif condition_ == 4 then
							-- Refetch has completed
							expect(loading).toBeFalsy()
							expect(data).toEqual(peopleData)
							expect(networkStatus).toBe(NetworkStatus.ready)
						end
					end)
					return nil
				end

				render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

				return waitFor(function()
					expect(renderCount).toBe(4)
				end):andThen(resolve, reject)
			end
		)
	end)

	describe("Callbacks", function()
		itAsync(
			"should pass loaded data to onCompleted when using the cache-only " .. "fetch policy",
			function(resolve, reject)
				local cache = InMemoryCache.new()
				local client = ApolloClient.new({ cache = cache, resolvers = {} })
				cache:writeQuery({ query = CAR_QUERY, data = CAR_RESULT_DATA })
				local onCompletedCalled = false

				local function Component()
					local loading, data
					do
						local ref = useQuery(CAR_QUERY, {
							fetchPolicy = "cache-only",
							onCompleted = function(data)
								onCompletedCalled = true
								expect(data).toBeDefined()
							end,
						})
						loading, data = ref.loading, ref.data
					end

					rejectOnComponentThrow(reject, function()
						if not Boolean.toJSBoolean(loading) then
							expect(data).toEqual(CAR_RESULT_DATA)
						end
					end)
					return nil
				end
				render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

				return wait_(function()
					expect(onCompletedCalled).toBeTruthy()
				end):andThen(resolve, reject)
			end
		)

		itAsync("should only call onCompleted once per query run", function(resolve, reject)
			local cache = InMemoryCache.new()
			local client = ApolloClient.new({ cache = cache, resolvers = {} })
			cache:writeQuery({ query = CAR_QUERY, data = CAR_RESULT_DATA })
			local onCompletedCount = 0
			local function Component()
				local ref = useQuery(CAR_QUERY, {
					fetchPolicy = "cache-only",
					onCompleted = function()
						onCompletedCount += 1
					end,
				})
				rejectOnComponentThrow(reject, function()
					local loading, data = ref.loading, ref.data

					if not Boolean.toJSBoolean(loading) then
						expect(data).toEqual(CAR_RESULT_DATA)
					end
				end)
				return nil
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

			return wait_(function()
				expect(onCompletedCount).toBe(1)
			end):andThen(resolve, reject)
		end)

		itAsync("should not repeatedly call onCompleted if it alters state", function(resolve, reject)
			local query = gql([[

					query people($first: Int) {
					  allPeople(first: $first) {
						people {
						  name
						}
					  }
					}
				]])
			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local mocks = {
				{ request = { query = query, variables = { first = 1 } }, result = { data = data1 } },
			}
			local renderCount = 0

			local function Component()
				local onCompletedCallCount, setOnCompletedCallCount = useState(0)
				local ref = useQuery(query, {
					variables = { first = 1 },
					onCompleted = function()
						setOnCompletedCallCount(onCompletedCallCount + 1)
					end,
				})

				rejectOnComponentThrow(reject, function()
					local loading, data = ref.loading, ref.data

					if renderCount == 0 then
						expect(loading).toBeTruthy()
					elseif renderCount == 1 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(data1)
					elseif renderCount == 2 then
						expect(loading).toBeFalsy()
						expect(onCompletedCallCount).toBe(1)
					else
						-- ROBLOX deviation: rejecting if too many renders
						reject("too many renders")
					end
					renderCount += 1
				end)
				return nil
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return wait_(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)

		itAsync("should not call onCompleted if skip is true", function(resolve, reject)
			local function Component()
				local ref = useQuery(CAR_QUERY, {
					skip = true,
					onCompleted = function()
						fail("should not call onCompleted!")
					end,
				})

				rejectOnComponentThrow(reject, function()
					local loading = ref.loading
					expect(loading).toBeFalsy()
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { mocks = CAR_MOCKS }, React.createElement(Component, nil)))

			return wait_():andThen(resolve, reject)
		end)

		itAsync(
			"should not make extra network requests when `onCompleted` is "
				.. "defined with a `network-only` fetch policy",
			function(resolve, reject)
				local renderCount = 0
				local function Component()
					local ref = useQuery(CAR_QUERY, {
						fetchPolicy = "network-only",
						onCompleted = function()
							return nil
						end,
					})

					rejectOnComponentThrow(reject, function()
						local loading, data = ref.loading, ref.data

						--[[ ROBLOX comment: switch statement conversion ]]
						renderCount += 1
						local condition_ = renderCount
						if condition_ == 1 then
							expect(loading).toBeTruthy()
						elseif condition_ == 2 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(CAR_RESULT_DATA)
						elseif condition_ == 3 then
							fail("Too many renders")
						end
					end)
					return nil
				end

				render(React.createElement(MockedProvider, { mocks = CAR_MOCKS }, React.createElement(Component, nil)))

				return wait_(function()
					expect(renderCount).toBe(2)
				end):andThen(resolve, reject)
			end
		)
	end)

	describe("Optimistic data", function()
		-- ROBLOX TODO: fragments are not supported yet
		itAsync.skip("should display rolled back optimistic data when an error occurs", function(resolve, reject)
			local query = gql([[

					query AllCars {
					  cars {
						id
						make
						model
					  }
					}
				]])
			local carsData = {
				cars = { { id = 1, make = "Audi", model = "RS8", __typename = "Car" } },
			}
			local mutation = gql([[

					mutation AddCar {
					  addCar {
						id
						make
						model
					  }
					}
				]])
			local carData = { id = 2, make = "Ford", model = "Pinto", __typename = "Car" }
			local allCarsData = {
				cars = {
					carsData.cars[1],
					carData,
				},
			}
			local mocks = {
				{ request = { query = query }, result = { data = carsData } },
				{ request = { query = mutation }, ["error"] = Error.new("Oh no!") } :: any,
			}
			local renderCount = 0
			local function Component()
				local mutate, mutationLoading
				do
					local ref = useMutation(mutation, {
						optimisticResponse = { addCar = carData },
						update = function(_self, cache, ref)
							local data = ref.data
							cache:modify({
								fields = {
									cars = function(_self, existing, ref)
										local readField = ref.readField
										local newCarRef = cache:writeFragment({
											data = data.addCar,
											fragment = gql([[
								fragment NewCar on Car {
									id
									make
									model
							  	}
							  ]]),
										})
										if
											Array.some(existing, function(ref: Reference)
												return readField("id", ref) == data.addCar.id
											end)
										then
											return existing
										end
										return Array.concat({}, existing, { newCarRef })
									end,
								},
							})
						end,
						onError = function(self)
							-- Swallow error
						end,
					})
					mutate, mutationLoading =
						ref[1] :: MutationTupleFirst<any, any, any, any>,
						(ref[2] :: MutationTupleSecond<any, any, any, any>).loading
				end

				local ref = useQuery(query)
				local data, queryLoading = ref.data, ref.loading
				renderCount += 1
				local condition_ = renderCount
				if condition_ == 1 then
					-- The query ran and is loading the result.
					expect(queryLoading).toBeTruthy()
				elseif condition_ == 2 then
					-- The query has completed.
					expect(queryLoading).toBeFalsy()
					expect(data).toEqual(carsData)
					-- Trigger a mutation (with optimisticResponse data).
					mutate()
				elseif condition_ == 3 then
					-- The mutation ran and is loading the result. The query stays at
					-- not loading as nothing has changed for the query.
					expect(mutationLoading).toBeTruthy()
					expect(queryLoading).toBeFalsy()
				elseif condition_ == 4 then
					-- The first part of the mutation has completed using the defined
					-- optimisticResponse data. This means that while the mutation
					-- stays in a loading state, it has made its optimistic data
					-- available to the query. New optimistic data doesn't trigger a
					-- query loading state.
					expect(mutationLoading).toBeTruthy()
					expect(queryLoading).toBeFalsy()
					expect(data).toEqual(allCarsData)
				elseif condition_ == 5 then
					-- The mutation wasn't able to fulfill its network request so it
					-- errors, which means the initially returned optimistic data is
					-- rolled back, and the query no longer has access to it.
					expect(mutationLoading).toBeTruthy()
					expect(queryLoading).toBeFalsy()
					expect(data).toEqual(carsData)
				elseif condition_ == 6 then
					-- The mutation has completely finished, leaving the query
					-- with access to the original cache data.
					expect(mutationLoading).toBeFalsy()
					expect(queryLoading).toBeFalsy()
					expect(data).toEqual(carsData)
				end
				return nil
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))

			return wait_(function()
				expect(renderCount).toBe(6)
			end):andThen(resolve, reject)
		end)
	end)

	describe("Client Resolvers", function()
		-- ROBLOX TODO: fragments are not supported yet
		itAsync.skip(
			"should receive up to date @client(always: true) fields on entity update",
			function(resolve, reject)
				local query = gql([[

					query GetClientData($id: ID) {
					  clientEntity(id: $id) @client(always: true) {
						id
						title
						titleLength @client(always: true)
					  }
					}
				]])

				local mutation = gql([[

					mutation AddOrUpdate {
					  addOrUpdate(id: $id, title: $title) @client
					}
				]])
				local fragment = gql([[

					fragment ClientDataFragment on ClientData {
					  id
					  title
					}
				]])
				local client = ApolloClient.new({
					cache = InMemoryCache.new(),
					link = ApolloLink.new(function()
						return Observable.of({ data = {} })
					end),
					resolvers = {
						ClientData = {
							titleLength = function(self, data)
								return string.len(data.title)
							end,
						},
						Query = {
							clientEntity = function(self, _root, ref, ref_)
								local id = ref.id
								local cache = ref_.cache
								return cache:readFragment({
									id = cache:identify({ id = id, __typename = "ClientData" }),
									fragment = fragment,
								})
							end,
						},
						Mutation = {
							addOrUpdate = function(self, _root, ref, ref_)
								local id, title = ref.id, ref.title
								local cache = ref_.cache
								return cache:writeFragment({
									id = cache:identify({ id = id, __typename = "ClientData" }),
									fragment = fragment,
									data = { id = id, title = title, __typename = "ClientData" },
								})
							end,
						},
					},
				})
				local entityId = 1
				local shortTitle = "Short"
				local longerTitle = "A little longer"
				client:mutate({ mutation = mutation, variables = { id = entityId, title = shortTitle } } :: any)
				local renderCount = 0
				local function App()
					local data
					do
						local ref = useQuery(query, { variables = { id = entityId } })
						data = ref.data
					end
					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 2 then
						expect(data.clientEntity).toEqual({
							id = entityId,
							title = shortTitle,
							titleLength = string.len(shortTitle),
							__typename = "ClientData",
						})
						setTimeout(function()
							client:mutate({
								mutation = mutation,
								variables = { id = entityId, title = longerTitle },
							} :: any)
						end)
					elseif condition_ == 3 then
						expect(data.clientEntity).toEqual({
							id = entityId,
							title = longerTitle,
							titleLength = string.len(longerTitle),
							__typename = "ClientData",
						})
					else
						-- Do nothing
					end
					return nil
				end
				render(React.createElement(ApolloProvider, { client = client }, React.createElement(App, nil)))
				return wait_(function()
					expect(renderCount).toBe(3)
				end):andThen(resolve, reject)
			end
		)
	end)

	describe("Skipping", function()
		itAsync("should skip running a query when `skip` is `true`", function(resolve, reject)
			local renderCount = 0
			local function Component()
				local skip, setSkip = useState(true)

				local ref = useQuery(CAR_QUERY, { skip = skip })

				rejectOnComponentThrow(reject, function()
					local loading, data = ref.loading, ref.data
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeFalsy()
						expect(data).toBeUndefined()
						setTimeout(function()
							return setSkip(false)
						end)
					elseif condition_ == 2 then
						expect(loading).toBeTruthy()
						expect(data).toBeUndefined()
					elseif condition_ == 3 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(CAR_RESULT_DATA)
					else
						reject("too many renders")
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { mocks = CAR_MOCKS }, React.createElement(Component, nil)))

			return waitFor(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)

		itAsync("should not make network requests when `skip` is `true`", function(resolve, reject)
			local networkRequestCount = 0
			local link = ApolloLink.new(function(_self, o, f)
				networkRequestCount += 1
				if Boolean.toJSBoolean(f) then
					return f(o)
				else
					return nil
				end
			end):concat(mockSingleLink({
				request = { query = CAR_QUERY, variables = { someVar = true } },
				result = { data = CAR_RESULT_DATA },
			}))

			local client = ApolloClient.new({ link = link, cache = InMemoryCache.new() })

			local renderCount = 0

			local function Component()
				local skip, setSkip = useState(false)

				local ref = useQuery(CAR_QUERY, {
					fetchPolicy = "no-cache",
					skip = skip,
					variables = { someVar = not Boolean.toJSBoolean(skip) },
				})
				rejectOnComponentThrow(reject, function()
					local loading, data = ref.loading, ref.data
					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(data).toBeUndefined()
					elseif condition_ == 2 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(CAR_RESULT_DATA)
						expect(networkRequestCount).toBe(1)
						setTimeout(function()
							return setSkip(true)
						end)
					elseif condition_ == 3 then
						expect(loading).toBeFalsy()
						expect(data).toBeUndefined()
						expect(networkRequestCount).toBe(1)
					else
						reject("too many renders")
					end
				end)
				return nil
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

			return wait_(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)

		it("should tear down the query if `skip` is `true`", function()
			local client = ApolloClient.new({
				link = ApolloLink.new(),
				cache = InMemoryCache.new(),
			})
			local function Component()
				useQuery(CAR_QUERY, { skip = true })
				return nil
			end

			local app =
				render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

			expect(client["queryManager"]["queries"].size).toBe(1)

			app.unmount()

			return wait_(function()
				expect(client["queryManager"]["queries"].size).toBe(0)
			end):expect()
		end)
	end)

	describe("Missing Fields", function()
		itAsync("should have errors populated with missing field errors from the cache", function(resolve, reject)
			local carQuery: DocumentNode = gql([[

					query cars($id: Int) {
					  cars(id: $id) {
						id
						make
						model
						vin
						__typename
					  }
					}
				]])

			local carData = {
				cars = {
					{
						id = 1,
						make = "Audi",
						model = "RS8",
						vine = "DOLLADOLLABILL",
						__typename = "Car",
					},
				},
			}

			local mocks = {
				{
					request = { query = carQuery, variables = { id = 1 } },
					result = {
						data = carData,
					},
				},
			}

			local renderCount = 0

			local function App()
				local ref = useQuery(carQuery, { variables = { id = 1 } })

				rejectOnComponentThrow(reject, function()
					local loading, data, error_ = ref.loading, ref.data, ref.error
					--[[ ROBLOX comment: switch statement conversion ]]
					if renderCount == 0 then
						expect(loading).toBeTruthy()
						expect(data).toBeUndefined()
						expect(error_).toBeUndefined()
					elseif renderCount == 1 then
						expect(loading).toBeFalsy()
						expect(data).toBeUndefined()
						expect(error_).toBeDefined()
						-- TODO: ApolloError.name is Error for some reason
						-- expect(error!.name).toBe(ApolloError);
						expect(#error_.clientErrors).toEqual(1)
						expect(error_.message).toMatch(RegExp("Can't find field 'vin' on Car:1"))
					else
						error(Error.new("Unexpected render"))
					end
					renderCount += 1
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(App, nil)))

			return wait_(function()
				expect(renderCount).toBe(2)
			end):andThen(resolve, reject)
		end)
	end)

	describe("Previous data", function()
		itAsync("should persist previous data when a query is re-run", function(resolve, reject)
			local query = gql([[

					query car {
					  car {
						id
						make
					  }
					}
				]])
			local data1 = { car = { id = 1, make = "Venturi", __typename = "Car" } }
			local data2 = { car = { id = 2, make = "Wiesmann", __typename = "Car" } }
			local mocks = {
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data2 } },
			}
			local renderCount = 0

			local function App()
				local ref = useQuery(query, { notifyOnNetworkStatusChange = true })

				rejectOnComponentThrow(reject, function()
					local loading, data, previousData, refetch = ref.loading, ref.data, ref.previousData, ref.refetch

					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBeTruthy()
						expect(data).toBeUndefined()
						expect(previousData).toBeUndefined()
					elseif condition_ == 2 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(data1)
						expect(previousData).toBeUndefined()
						setTimeout(refetch)
					elseif condition_ == 3 then
						expect(loading).toBeTruthy()
						expect(data).toEqual(data1)
						expect(previousData).toEqual(data1)
					elseif condition_ == 4 then
						expect(loading).toBeFalsy()
						expect(data).toEqual(data2)
						expect(previousData).toEqual(data1)
					else
						-- Do nothing
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(App, nil)))

			return wait_(function()
				expect(renderCount).toBe(4)
			end):andThen(resolve, reject)
		end)

		-- ROBLOX FIXME: timing issue. Promise/setTimeout not deterministic
		itAsync.skip("should persist result.previousData across multiple results", function(resolve, reject)
			local query: TypedDocumentNode<{ car: { id: string, make: string } }, { vin: string }> = gql([[

					query car($vin: String) {
					  car(vin: $vin) {
						id
						make
					  }
					}
				]])
			local data1 = { car = { id = 1, make = "Venturi", __typename = "Car" } }
			local data2 = { car = { id = 2, make = "Wiesmann", __typename = "Car" } }
			local data3 = { car = { id = 3, make = "Beetle", __typename = "Car" } }
			local mocks = {
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data2 } },
				{
					request = { query = query, variables = { vin = "ABCDEFG0123456789" } } :: any,
					result = { data = data3 },
				},
			}
			local renderCount = 0

			local function App()
				local ref = useQuery(query, { notifyOnNetworkStatusChange = true })

				rejectOnComponentThrow(reject, function()
					local loading, data, previousData, refetch = ref.loading, ref.data, ref.previousData, ref.refetch

					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(loading).toBe(true)
						expect(data).toBeUndefined()
						expect(previousData).toBeUndefined()
					elseif condition_ == 2 then
						expect(loading).toBe(false)
						expect(data).toEqual(data1)
						expect(previousData).toBeUndefined()
						setTimeout(function()
							refetch(ref)
						end)
					elseif condition_ == 3 then
						expect(loading).toBe(true)
						expect(data).toEqual(data1)
						expect(previousData).toEqual(data1)
						-- Interrupt the first refetch by refetching again with
						-- variables the cache has not seen before, thereby skipping
						-- data2 entirely.
						refetch(ref, { vin = "ABCDEFG0123456789" })
					elseif condition_ == 4 then
						expect(loading).toBe(true)
						expect(data).toBeUndefined()
						expect(previousData).toEqual(data1)
					elseif condition_ == 5 then
						expect(loading).toBe(false)
						expect(data).toEqual(data3)
						expect(previousData).toEqual(data1)
					else
						-- Do nothing
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(App, nil)))

			return waitFor(function()
				expect(renderCount).toBe(5)
			end):andThen(resolve, reject)
		end)

		itAsync("should be cleared when variables change causes cache miss", function(resolve, reject)
			local peopleData = {
				{ id = 1, name = "John Smith", gender = "male" },
				{ id = 2, name = "Sara Smith", gender = "female" },
				{ id = 3, name = "Budd Deey", gender = "nonbinary" },
				{ id = 4, name = "Johnny Appleseed", gender = "male" },
				{ id = 5, name = "Ada Lovelace", gender = "female" },
			}
			local link = ApolloLink.new(function(_self, operation)
				return Observable.new(function(observer)
					local gender
					do
						local ref = operation.variables
						gender = ref.gender
					end
					Promise.new(function(resolve)
						setTimeout(resolve, 300)
					end):andThen(function()
						observer:next({
							data = {
								people = (function()
									if gender == "all" then
										return peopleData
									else
										return (function()
											if Boolean.toJSBoolean(gender) then
												return Array.filter(peopleData, function(person)
													return person.gender == gender
												end)
											else
												return peopleData
											end
										end)()
									end
								end)(),
							},
						})
						observer:complete()
					end)
				end)
			end)
			type Person = { __typename: string, id: string, name: string }
			local ALL_PEOPLE: TypedDocumentNode<{ people: Array<Person> }, { [string]: any }> = gql([[

					query AllPeople($gender: String!) {
					  people(gender: $gender) {
						id
						name
					  }
					}
				]])
			local renderCount = 0

			local function App()
				local gender, setGender = useState("all")
				local ref = useQuery(ALL_PEOPLE, { variables = { gender = gender }, fetchPolicy = "network-only" })
				rejectOnComponentThrow(reject, function()
					local loading, networkStatus, data = ref.loading, ref.networkStatus, ref.data
					local currentPeopleNames = data
							and data.people
							and Array.map(data.people, function(person)
								return person.name
							end, nil)
						or nil

					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						expect(gender).toBe("all")
						expect(loading).toBe(true)
						expect(networkStatus).toBe(NetworkStatus.loading)
						expect(data).toBeUndefined()
						expect(currentPeopleNames).toBeUndefined()
					elseif condition_ == 2 then
						expect(gender).toBe("all")
						expect(loading).toBe(false)
						expect(networkStatus).toBe(NetworkStatus.ready)
						expect(data).toEqual({
							people = Array.map(peopleData, function(ref)
								local _gender, person = ref.gender, Object.assign({}, ref, { gender = Object.None })
								return person
							end, nil),
						})
						expect(currentPeopleNames).toEqual({
							"John Smith",
							"Sara Smith",
							"Budd Deey",
							"Johnny Appleseed",
							"Ada Lovelace",
						})
						act(function()
							setGender("female")
						end)
					elseif condition_ == 3 then
						expect(gender).toBe("female")
						expect(loading).toBe(true)
						expect(networkStatus).toBe(NetworkStatus.setVariables)
						expect(data).toBeUndefined()
						expect(currentPeopleNames).toBeUndefined()
					elseif condition_ == 4 then
						expect(gender).toBe("female")
						expect(loading).toBe(false)
						expect(networkStatus).toBe(NetworkStatus.ready)
						expect(#data.people).toBe(2)
						expect(currentPeopleNames).toEqual({ "Sara Smith", "Ada Lovelace" })
						act(function()
							setGender("nonbinary")
						end)
					elseif condition_ == 5 then
						expect(gender).toBe("nonbinary")
						expect(loading).toBe(true)
						expect(networkStatus).toBe(NetworkStatus.setVariables)
						expect(data).toBeUndefined()
						expect(currentPeopleNames).toBeUndefined()
					elseif condition_ == 6 then
						expect(gender).toBe("nonbinary")
						expect(loading).toBe(false)
						expect(networkStatus).toBe(NetworkStatus.ready)
						expect(#data.people).toBe(1)
						expect(currentPeopleNames).toEqual({ "Budd Deey" })
						act(function()
							setGender("male")
						end)
					elseif condition_ == 7 then
						expect(gender).toBe("male")
						expect(loading).toBe(true)
						expect(networkStatus).toBe(NetworkStatus.setVariables)
						expect(data).toBeUndefined()
						expect(currentPeopleNames).toBeUndefined()
					elseif condition_ == 8 then
						expect(gender).toBe("male")
						expect(loading).toBe(false)
						expect(networkStatus).toBe(NetworkStatus.ready)
						expect(#data.people).toBe(2)
						expect(currentPeopleNames).toEqual({
							"John Smith",
							"Johnny Appleseed",
						})
						act(function()
							setGender("female")
						end)
					elseif condition_ == 9 then
						expect(gender).toBe("female")
						expect(loading).toBe(true)
						expect(networkStatus).toBe(NetworkStatus.setVariables)
						expect(#data.people).toBe(2)
						expect(currentPeopleNames).toEqual({ "Sara Smith", "Ada Lovelace" })
					elseif condition_ == 10 then
						expect(gender).toBe("female")
						expect(loading).toBe(false)
						expect(networkStatus).toBe(NetworkStatus.ready)
						expect(#data.people).toBe(2)
						expect(currentPeopleNames).toEqual({ "Sara Smith", "Ada Lovelace" })
						act(function()
							setGender("all")
						end)
					elseif condition_ == 11 then
						expect(gender).toBe("all")
						expect(loading).toBe(true)
						expect(networkStatus).toBe(NetworkStatus.setVariables)
						expect(#data.people).toBe(5)
						expect(currentPeopleNames).toEqual({
							"John Smith",
							"Sara Smith",
							"Budd Deey",
							"Johnny Appleseed",
							"Ada Lovelace",
						})
					elseif condition_ == 12 then
						expect(gender).toBe("all")
						expect(loading).toBe(false)
						expect(networkStatus).toBe(NetworkStatus.ready)
						expect(#data.people).toBe(5)
						expect(currentPeopleNames).toEqual({
							"John Smith",
							"Sara Smith",
							"Budd Deey",
							"Johnny Appleseed",
							"Ada Lovelace",
						})
					else
						reject(("too many (%s) renders"):format(tostring(renderCount)))
					end
				end)
				return nil
			end

			local client = ApolloClient.new({ cache = InMemoryCache.new(), link = link })

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(App, nil)))

			return waitFor(function()
				expect(renderCount).toBe(12)
			end, { timeout = 3000 }):andThen(resolve, reject)
		end)
	end)

	describe("canonical cache results", function()
		itAsync("can be disabled via useQuery options", function(resolve, reject)
			local cache = InMemoryCache.new({ typePolicies = { Result = { keyFields = false } } } :: any)
			local query = gql([[

					query {
					  results {
						value
					  }
					}
				]])
			local results = {
				{ __typename = "Result", value = 0 },
				{ __typename = "Result", value = 1 },
				{ __typename = "Result", value = 1 },
				{ __typename = "Result", value = 2 },
				{ __typename = "Result", value = 3 },
				{ __typename = "Result", value = 5 },
			}
			cache:writeQuery({ query = query, data = { results = results } })
			local renderCount = 0

			local function App()
				local canonizeResults, setCanonize = useState(false)

				local ref = useQuery(query, { fetchPolicy = "cache-only", canonizeResults = canonizeResults })

				rejectOnComponentThrow(reject, function()
					local loading, data = ref.loading, ref.data
					--[[ ROBLOX comment: switch statement conversion ]]
					renderCount += 1
					local condition_ = renderCount
					if condition_ == 1 then
						do
							expect(loading).toBe(false)
							expect(data).toEqual({ results = results })
							expect(#data.results).toBe(6)
							local resultSet = Set.new(data.results :: any)
							-- Since canonization is not happening, the duplicate 1 results are
							-- returned as distinct objects.
							expect(resultSet.size).toBe(6)
							act(function()
								return setCanonize(true)
							end)
						end
					elseif condition_ == 2 then
						do
							expect(loading).toBe(false)
							expect(data).toEqual({ results = results })
							expect(#data.results).toBe(6)
							local resultSet = Set.new(data.results :: any)
							-- Since canonization is happening now, the duplicate 1 results are
							-- returned as identical (===) objects.
							expect(resultSet.size).toBe(5)
							local values: Array<number> = {}
							for _, result in resultSet do
								table.insert(values, result.value)
							end
							expect(values).toEqual({ 0, 1, 2, 3, 5 })
							act(function()
								table.insert(results, { __typename = "Result", value = 8 })
								-- Append another element to the results array, invalidating the
								-- array itself, triggering another render (below).
								cache:writeQuery({
									query = query,
									overwrite = true,
									data = { results = results },
								})
							end)
						end
					elseif condition_ == 3 then
						do
							expect(loading).toBe(false)
							expect(data).toEqual({ results = results })
							expect(#data.results).toBe(7)
							local resultSet = Set.new(data.results :: any)
							-- Since canonization is happening now, the duplicate 1 results are
							-- returned as identical (===) objects.
							expect(resultSet.size).toBe(6)
							local values: Array<number> = {}
							for _, result in resultSet do
								table.insert(values, result.value)
							end
							expect(values).toEqual({ 0, 1, 2, 3, 5, 8 })
						end
					else
						do
							reject("too many renders")
						end
					end
				end)
				return nil
			end

			render(React.createElement(MockedProvider, { cache = cache }, React.createElement(App, nil)))

			return waitFor(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)
	end)

	describe("multiple useQuery calls per component", function()
		type ABFields = { id: number, name: string }
		local aQuery: TypedDocumentNode<{ a: ABFields }, { [string]: any }> = gql([[query A { a { id name }}]])
		local bQuery: TypedDocumentNode<{ b: ABFields }, { [string]: any }> = gql([[query B { b { id name }}]])
		local aData = { a = { __typename = "A", id = 65, name = "ay" } }
		local bData = { b = { __typename = "B", id = 66, name = "bee" } }

		local function makeClient()
			return ApolloClient.new({
				cache = InMemoryCache.new(),
				link = ApolloLink.new(function(_self, operation)
					return Observable.new(function(observer)
						--[[ ROBLOX comment: switch statement conversion ]]
						local condition_ = operation.operationName
						if condition_ == "A" then
							observer:next({ data = aData } :: any)
						elseif condition_ == "B" then
							observer:next({ data = bData } :: any)
						end

						observer:complete()
					end)
				end),
			})
		end

		local function check(aFetchPolicy: WatchQueryFetchPolicy, bFetchPolicy: WatchQueryFetchPolicy)
			return function(resolve: ((result: any) -> any), reject: ((reason: any) -> any))
				local renderCount = 0

				local function App()
					local a = useQuery(aQuery, { fetchPolicy = aFetchPolicy })
					local b = useQuery(bQuery, { fetchPolicy = bFetchPolicy })
					rejectOnComponentThrow(reject, function()
						--[[ ROBLOX comment: switch statement conversion ]]
						renderCount += 1
						local condition_ = renderCount
						if condition_ == 1 then
							expect(a.loading).toBe(true)
							expect(b.loading).toBe(true)
							expect(a.data).toBeUndefined()
							expect(b.data).toBeUndefined()
						elseif condition_ == 2 then
							expect(a.loading).toBe(false)
							expect(b.loading).toBe(true)
							expect(a.data).toEqual(aData)
							expect(b.data).toBeUndefined()
						elseif condition_ == 3 then
							expect(a.loading).toBe(false)
							expect(b.loading).toBe(false)
							expect(a.data).toEqual(aData)
							expect(b.data).toEqual(bData)
						else
							reject("too many renders: " .. tostring(renderCount))
						end
					end)
					return nil
				end

				render(React.createElement(ApolloProvider, { client = makeClient() }, React.createElement(App, nil)))

				return waitFor(function()
					expect(renderCount).toBe(3)
				end):andThen(resolve, reject)
			end
		end

		itAsync("cache-first for both", check("cache-first", "cache-first"))
		itAsync("cache-first first, cache-and-network second", check("cache-first", "cache-and-network"))
		itAsync("cache-first first, network-only second", check("cache-first", "network-only"))
		itAsync("cache-and-network for both", check("cache-and-network", "cache-and-network"))
		itAsync("cache-and-network first, cache-first second", check("cache-and-network", "cache-first"))
		itAsync("cache-and-network first, network-only second", check("cache-and-network", "network-only"))
		itAsync("network-only for both", check("network-only", "network-only"))
		itAsync("network-only first, cache-first second", check("network-only", "cache-first"))
		itAsync("network-only first, cache-and-network second", check("network-only", "cache-and-network"))
	end)
end)

return {}
