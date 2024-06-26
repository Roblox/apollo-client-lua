--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/components/__tests__/client/Query.test.tsx

local srcWorkspace = script.Parent.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
local Object = LuauPolyfill.Object
local console = LuauPolyfill.console
local setTimeout = LuauPolyfill.setTimeout

type Array<T> = LuauPolyfill.Array<T>
type Error = LuauPolyfill.Error

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local beforeAll = JestGlobals.beforeAll
local afterAll = JestGlobals.afterAll
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest
type DoneFn = ((string | Error)?) -> ()

-- ROBLOX TODO: remove when unhandled errors are ... handled
local function rejectOnComponentThrow(reject, fn: (...any) -> ...any)
	local trace = debug.traceback()
	local ok, result = pcall(fn)
	if not ok then
		print(result.message .. "\n" .. trace)
		reject(result)
	end
	return result
end

-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
local TICK = 1000 / 30

local Promise = require(rootWorkspace.Promise)

local React = require(rootWorkspace.React)

local gql = require(rootWorkspace.GraphQLTag).default

local graphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphQLModule.DocumentNode

local testingLibraryModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = testingLibraryModule.render
local waitFor = testingLibraryModule.waitFor
local wait_ = require(srcWorkspace.testUtils.wait).wait

local coreModule = require(srcWorkspace.core)
local ApolloClient = coreModule.ApolloClient
local NetworkStatus = coreModule.NetworkStatus

local errorsModule = require(srcWorkspace.errors)
type ApolloError = errorsModule.ApolloError

local ApolloLink = require(srcWorkspace.link.core).ApolloLink
local Cache = require(srcWorkspace.cache).InMemoryCache
local ApolloProvider = require(script.Parent.Parent.Parent.Parent.context).ApolloProvider

local testingModule = require(srcWorkspace.testing)
local itAsync = testingModule.itAsync
local stripSymbols = testingModule.stripSymbols
local MockedProvider = testingModule.MockedProvider
local mockSingleLink = testingModule.mockSingleLink
local withErrorSpy = testingModule.withErrorSpy

local Query = require(script.Parent.Parent.Parent.Query).Query

local allPeopleQuery: DocumentNode = gql([[

  query people {
    allPeople(first: 1) {
      people {
        name
      }
    }
  }
]])

type Data = { allPeople: { people: Array<{ name: string }> } }

local allPeopleData: Data = { allPeople = { people = { { name = "Luke Skywalker" } } } }
local allPeopleMocks = { { request = { query = allPeopleQuery }, result = {
	data = allPeopleData,
} } }

local AllPeopleQuery = Query

describe("Query component", function()
	beforeEach(function()
		jest.useRealTimers()
	end)

	itAsync("calls the children prop", function(resolve, reject)
		local link = mockSingleLink({
			request = { query = allPeopleQuery },
			result = { data = allPeopleData },
		})
		local client = ApolloClient.new({ link = link, cache = Cache.new({ addTypename = false }) })

		local function Component()
			return React.createElement(Query, { query = allPeopleQuery }, function(result: any)
				local clientResult, rest = result.client, Object.assign({}, result, { client = Object.None })
				rejectOnComponentThrow(reject, function()
					if result.loading then
						expect(rest).toMatchSnapshot("result in render prop while loading")
						expect(clientResult).toBe(client)
					else
						expect(stripSymbols(rest)).toMatchSnapshot("result in render prop")
					end
				end)
				return nil
			end)
		end

		render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

		return wait_():andThen(resolve, reject)
	end)

	itAsync("renders using the children prop", function(resolve, reject)
		local function Component()
			return React.createElement(Query, { query = allPeopleQuery }, function(_: any)
				-- ROBLOX deviation: using text element instead of div
				return React.createElement("TextLabel", { Text = "test" })
			end)
		end

		local getByText = render(
			React.createElement(MockedProvider, { mocks = allPeopleMocks }, React.createElement(Component, nil))
		).getByText

		return waitFor(function()
			expect(getByText("test")).toBeTruthy()
		end):andThen(resolve, reject)
	end)

	describe("result provides", function()
		local consoleWarn = console.warn
		beforeAll(function()
			console.warn = function()
				return nil
			end
		end)

		afterAll(function()
			console.warn = consoleWarn
		end)

		itAsync("client", function(resolve, reject)
			local queryWithVariables: DocumentNode = gql([[

        query people($first: Int) {
          allPeople(first: $first) {
            people {
              name
            }
          }
        }
      ]])

			local mocksWithVariable = {
				{
					request = { query = queryWithVariables, variables = { first = 1 } },
					result = { data = allPeopleData },
				},
			}

			local variables = { first = 1 }

			local function Component()
				return React.createElement(Query, { query = queryWithVariables, variables = variables }, function(ref)
					local client = ref.client
					local ok, res = pcall(function()
						expect(client).never.toBeFalsy()
						expect(client.version).never.toBeFalsy()
					end)
					if not ok then
						reject(res)
					end

					return nil
				end)
			end

			render(
				React.createElement(MockedProvider, { mocks = mocksWithVariable }, React.createElement(Component, nil))
			)

			return wait_():andThen(resolve, reject)
		end)

		itAsync("error", function(resolve, reject)
			local mockError = {
				{ request = { query = allPeopleQuery }, error = Error.new("error occurred") },
			}

			local function Component()
				return React.createElement(Query, { query = allPeopleQuery }, function(result: any)
					if result.loading then
						return nil
					end
					local ok, res = pcall(function()
						-- ROBLOX deviation: compare error message
						expect(result.error.message).toEqual(Error.new("error occurred").message)
					end)
					if not ok then
						reject(res)
					end

					return nil
				end)
			end

			render(React.createElement(MockedProvider, { mocks = mockError }, React.createElement(Component, nil)))

			return wait_():andThen(resolve, reject)
		end)

		itAsync("refetch", function(resolve, reject)
			local queryRefetch: DocumentNode = gql([[

        query people($first: Int) {
          allPeople(first: $first) {
            people {
              name
            }
          }
        }
      ]])

			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
			local data3 = { allPeople = { people = { { name = "Darth Vader" } } } }

			local refetchVariables = { first = 1 }

			local mocks = {
				{
					request = { query = queryRefetch, variables = refetchVariables },
					result = { data = data1 },
				},
				{
					request = { query = queryRefetch, variables = refetchVariables },
					result = { data = data2 },
				},
				{
					request = { query = queryRefetch, variables = { first = 2 } },
					result = { data = data3 },
				},
			}
			local count = 0
			local hasRefetched = false

			local function Component()
				return React.createElement(AllPeopleQuery, {
					query = queryRefetch,
					variables = refetchVariables,
					notifyOnNetworkStatusChange = true,
				}, function(result: any)
					local data, loading = result.data, result.loading
					if loading then
						count += 1
						return nil
					end

					local ok, res = pcall(function()
						if count == 1 then
							-- first data
							expect(stripSymbols(data)).toEqual(data1)
						end
						if count == 3 then
							-- second data
							expect(stripSymbols(data)).toEqual(data2)
						end
						if count == 5 then
							-- third data
							expect(stripSymbols(data)).toEqual(data3)
						end
					end)
					if not ok then
						reject(res)
					end

					count += 1

					if hasRefetched then
						return nil
					end

					hasRefetched = true
					setTimeout(function()
						result
							:refetch()
							:andThen(function(result1: any)
								expect(stripSymbols(result1.data)).toEqual(data2)
								return result:refetch({ first = 2 })
							end)
							:andThen(function(result2: any)
								expect(stripSymbols(result2.data)).toEqual(data3)
							end)
							:catch(reject)
					end)
					return nil
				end)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				expect(count).toBe(6)
			end):andThen(resolve, reject)
		end)

		itAsync("fetchMore", function(resolve, reject)
			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }

			local variables = { first = 2 }

			local mocks = {
				{
					request = { query = allPeopleQuery, variables = { first = 2 } },
					result = { data = data1 },
				},
				{
					request = { query = allPeopleQuery, variables = { first = 1 } },
					result = { data = data2 },
				},
			}

			local count = 0

			local function Component()
				return React.createElement(
					AllPeopleQuery,
					{ query = allPeopleQuery, variables = variables },
					function(result: any)
						if result.loading then
							return nil
						end
						if count == 0 then
							setTimeout(function()
								result
									:fetchMore({
										variables = { first = 1 },
										updateQuery = function(_self, prev: any, ref)
											local fetchMoreResult = ref.fetchMoreResult
											return fetchMoreResult
													and {
														allPeople = {
															people = Array.concat(
																{},
																prev.allPeople.people,
																fetchMoreResult.allPeople.people
															),
														},
													}
												or prev
										end,
									})
									:andThen(function(result2: any)
										expect(stripSymbols(result2.data)).toEqual(data2)
									end)
									:catch(reject)
							end)
						elseif count == 1 then
							local ok, res = pcall(function()
								expect(stripSymbols(result.data)).toEqual({
									allPeople = {
										people = Array.concat({}, data1.allPeople.people, data2.allPeople.people),
									},
								})
							end)
							if not ok then
								reject(res)
							end
						end

						count += 1
						return nil
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				expect(count).toBe(2)
			end):andThen(resolve, reject)
		end)

		itAsync("startPolling", function(resolve, reject)
			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
			local data3 = { allPeople = { people = { { name = "Darth Vader" } } } }

			local mocks = {
				{ request = { query = allPeopleQuery }, result = { data = data1 } },
				{ request = { query = allPeopleQuery }, result = { data = data2 } },
				{ request = { query = allPeopleQuery }, result = { data = data3 } },
			}

			local count = 0
			local isPolling = false

			-- ROBLOX deviation: min interval
			local POLL_INTERVAL = 5 * TICK

			local unmount: any

			local function Component()
				return React.createElement(Query, { query = allPeopleQuery }, function(result: any)
					if result.loading then
						return nil
					end
					if not isPolling then
						isPolling = true
						result:startPolling(POLL_INTERVAL)
					end
					local ok, res = pcall(function()
						if count == 0 then
							expect(stripSymbols(result.data)).toEqual(data1)
						elseif count == 1 then
							expect(stripSymbols(result.data)).toEqual(data2)
						elseif count == 2 then
							expect(stripSymbols(result.data)).toEqual(data3)
							setTimeout(unmount)
						end
					end)
					if not ok then
						reject(res)
					end

					count += 1

					return nil
				end)
			end

			unmount = render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			).unmount

			return waitFor(function()
				expect(count).toBe(3)
			end):andThen(resolve, reject)
		end)

		itAsync("stopPolling", function(resolve, reject)
			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
			local data3 = { allPeople = { people = { { name = "Darth Vader" } } } }

			local mocks = {
				{ request = { query = allPeopleQuery }, result = { data = data1 } },
				{ request = { query = allPeopleQuery }, result = { data = data2 } },
				{ request = { query = allPeopleQuery }, result = { data = data3 } },
			}

			local POLL_COUNT = 2

			-- ROBLOX deviation: min interval
			local POLL_INTERVAL = 5 * TICK
			local count = 0

			local function Component()
				return React.createElement(
					Query,
					{ query = allPeopleQuery, pollInterval = POLL_INTERVAL },
					function(result: any)
						if result.loading then
							return nil
						end
						if count == 0 then
							expect(stripSymbols(result.data)).toEqual(data1)
						elseif count == 1 then
							expect(stripSymbols(result.data)).toEqual(data2)
							result:stopPolling()
						end

						count += 1

						return nil
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				expect(count).toBe(POLL_COUNT)
			end):andThen(resolve, reject)
		end)

		itAsync("updateQuery", function(resolve, reject)
			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
			local variables = { first = 2 }
			local mocks = {
				{
					request = { query = allPeopleQuery, variables = variables },
					result = { data = data1 },
				},
			}

			local isUpdated = false

			local count = 0

			local function Component()
				return React.createElement(
					AllPeopleQuery,
					{ query = allPeopleQuery, variables = variables },
					function(result: any)
						if result.loading then
							return nil
						end
						if isUpdated then
							local ok, res = pcall(function()
								expect(stripSymbols(result.data)).toEqual(data2)
							end)
							if not ok then
								reject(res)
							end

							return nil
						end

						isUpdated = true

						setTimeout(function()
							result:updateQuery(function(prev: any, ref)
								local variablesUpdate = ref.variables
								count += 1
								local ok, res = pcall(function()
									expect(stripSymbols(prev)).toEqual(data1)
									expect(variablesUpdate).toEqual({ first = 2 })
								end)
								if not ok then
									reject(res)
								end

								return data2
							end)
						end)
						return nil
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				expect(count).toBe(1)
			end):andThen(resolve, reject)
		end)
	end)

	describe("props allow", function()
		it("custom fetch-policy", function()
			local count = 0

			local function Component()
				return React.createElement(
					Query,
					{ query = allPeopleQuery, fetchPolicy = "cache-only" },
					function(result: any)
						if not result.loading then
							expect(result.networkStatus).toBe(NetworkStatus.ready)
						end
						count += 1
						return nil
					end
				)
			end

			render(React.createElement(MockedProvider, { mocks = allPeopleMocks }, React.createElement(Component, nil)))

			return waitFor(function()
				expect(count).toBe(2)
			end):expect()
		end)

		it("default fetch-policy", function()
			local count = 0

			local function Component()
				return React.createElement(Query, { query = allPeopleQuery }, function(result: any)
					if not result.loading then
						expect(result.networkStatus).toBe(NetworkStatus.ready)
					end
					count += 1
					return nil
				end)
			end

			render(React.createElement(MockedProvider, {
				defaultOptions = { watchQuery = { fetchPolicy = "cache-only" } },
				mocks = allPeopleMocks,
			}, React.createElement(Component, nil)))

			return waitFor(function()
				expect(count).toBe(2)
			end)
		end)

		itAsync("notifyOnNetworkStatusChange", function(resolve, reject)
			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }

			local mocks = {
				{ request = { query = allPeopleQuery }, result = { data = data1 } },
				{ request = { query = allPeopleQuery }, result = { data = data2 } },
			}

			local count = 0

			local function Component()
				return React.createElement(
					Query,
					{ query = allPeopleQuery, notifyOnNetworkStatusChange = true },
					function(result: any)
						local ok, res = pcall(function()
							if count == 0 then
								expect(result.loading).toBeTruthy()
							end
							if count == 1 then
								expect(result.loading).toBeFalsy()
								setTimeout(function()
									result:refetch()
								end)
							end
							if count == 2 then
								expect(result.loading).toBeTruthy()
							end
							if count == 3 then
								expect(result.loading).toBeFalsy()
							end

							count += 1
						end)
						if not ok then
							reject(res)
						end

						return nil
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				return expect(count).toBe(4)
			end):andThen(resolve, reject)
		end)

		itAsync("pollInterval", function(resolve, reject)
			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
			local data3 = { allPeople = { people = { { name = "Darth Vader" } } } }

			local mocks = {
				{ request = { query = allPeopleQuery }, result = { data = data1 } },
				{ request = { query = allPeopleQuery }, result = { data = data2 } },
				{ request = { query = allPeopleQuery }, result = { data = data3 } },
			}

			local count = 0
			local POLL_COUNT = 3

			-- ROBLOX deviation: min interval
			local POLL_INTERVAL = 30 * TICK

			local function Component()
				return React.createElement(
					Query,
					{ query = allPeopleQuery, pollInterval = POLL_INTERVAL },
					function(result: any)
						if result.loading then
							return nil
						end
						if count == 0 then
							expect(stripSymbols(result.data)).toEqual(data1)
						elseif count == 1 then
							expect(stripSymbols(result.data)).toEqual(data2)
						elseif count == 2 then
							expect(stripSymbols(result.data)).toEqual(data3)
							result:stopPolling()
						end

						count += 1

						return nil
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				return expect(count).toBe(POLL_COUNT)
			end, { timeout = 3000 }):andThen(resolve, reject)
		end)

		it("skip", function(_, done: DoneFn)
			local function Component()
				return React.createElement(Query, { query = allPeopleQuery, skip = true }, function(result: any)
					local ok, res = pcall(function()
						expect(result.loading).toBeFalsy()
						expect(result.data).toBe(nil)
						expect(result.error).toBe(nil)
						done()
					end)
					if not ok then
						-- ROBLOX deviation START: using done(error) instead of done.fail(error)
						done(res)
						-- ROBLOX deviation END
					end

					return nil
				end)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = allPeopleMocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)
		end)

		it("onCompleted with data", function()
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
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
			local mocks = {
				{ request = { query = query, variables = { first = 1 } }, result = { data = data1 } },
				{ request = { query = query, variables = { first = 2 } }, result = { data = data2 } },
			}

			local count = 0

			local Component = React.Component:extend("Component")

			function Component:init()
				self.state = {
					variables = {
						first = 1,
					},
				}

				self.onCompleted = function(data: Data | {})
					if count == 0 then
						expect(stripSymbols(data)).toEqual(data1)
					end
					if count == 1 then
						expect(stripSymbols(data)).toEqual(data2)
					end
					count += 1
				end
			end

			function Component:componentDidMount()
				setTimeout(
					function()
						self:setState({ variables = { first = 2 } })
					end,
					-- ROBLOX deviation: min interval
					10 * TICK
				)
			end

			function Component:render()
				local variables = self.state.variables

				return React.createElement(
					AllPeopleQuery,
					{ query = query, variables = variables, onCompleted = self.onCompleted },
					function()
						return nil
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				expect(count).toBe(2)
			end):expect()
		end)

		itAsync("onError with data", function(resolve, reject)
			local data = { allPeople = { people = { { name = "Luke Skywalker" } } } }

			local mocks = { { request = { query = allPeopleQuery }, result = { data = data } } }

			local function onErrorFunc(queryError: ApolloError)
				expect(queryError).toEqual(nil)
			end

			local onError = jest.fn()

			local function Component()
				return React.createElement(Query, { query = allPeopleQuery, onError = onErrorFunc }, function(ref)
					local loading = ref.loading
					rejectOnComponentThrow(reject, function()
						if not loading then
							expect(onError).never.toHaveBeenCalled()
						end
					end)
					return nil
				end)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return wait_():andThen(resolve, reject)
		end)
	end)

	describe("props disallow", function()
		it("Mutation provided as query", function()
			local mutation = gql([[

        mutation submitRepository {
          submitRepository(repoFullName: "apollographql/apollo-client") {
            createdAt
          }
        }
      ]])

			-- Prevent error from being logged in console of test.
			local errorLogger = console.error
			console.error = function() end

			expect(function()
				render(
					React.createElement(
						MockedProvider,
						nil,
						React.createElement(Query, { query = mutation }, function()
							return nil
						end)
					)
				)
			end).toThrowError("Running a Query requires a graphql Query, but a Mutation was used " .. "instead.")

			console.error = errorLogger
		end)

		it("Subscription provided as query", function()
			local subscription = gql([[

        subscription onCommentAdded($repoFullName: String!) {
          commentAdded(repoFullName: $repoFullName) {
            id
            content
          }
        }
      ]])

			-- Prevent error from being logged in console of test.
			local errorLogger = console.error
			console.error = function() end

			expect(function()
				render(
					React.createElement(
						MockedProvider,
						nil,
						React.createElement(Query, { query = subscription }, function()
							return nil
						end)
					)
				)
			end).toThrowError("Running a Query requires a graphql Query, but a Subscription was " .. "used instead.")

			console.error = errorLogger
		end)

		itAsync("onCompleted with error", function(resolve, reject)
			local mockError = {
				{ request = { query = allPeopleQuery }, error = Error.new("error occurred") },
			}

			local onCompleted = jest.fn()

			local function Component()
				return React.createElement(Query, { query = allPeopleQuery, onCompleted = onCompleted }, function(ref)
					local error_ = ref.error
					rejectOnComponentThrow(reject, function()
						if Boolean.toJSBoolean(error_) then
							expect(onCompleted).never.toHaveBeenCalled()
						end
					end)
					return nil
				end)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mockError, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return wait_():andThen(resolve, reject)
		end)

		it("onError with error", function()
			-- ROBLOX deviation: wrapping in promise to handle assertion error
			Promise.new(function(resolve, reject)
				local error_ = Error.new("error occurred")
				local mockError = { { request = { query = allPeopleQuery }, error = error_ } }

				local function onErrorFunc(queryError: ApolloError)
					rejectOnComponentThrow(reject, function()
						expect(queryError.networkError).toEqual(error_)
					end)
				end

				local function Component()
					return React.createElement(Query, { query = allPeopleQuery, onError = onErrorFunc }, function()
						return nil
					end)
				end

				render(
					React.createElement(
						MockedProvider,
						{ mocks = mockError, addTypename = false },
						React.createElement(Component, nil)
					)
				)

				wait_():andThen(resolve, reject)
			end):expect()
		end)
	end)

	describe("should update", function()
		itAsync("if props change", function(resolve, reject)
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
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
			local mocks = {
				{ request = { query = query, variables = { first = 1 } }, result = { data = data1 } },
				{ request = { query = query, variables = { first = 2 } }, result = { data = data2 } },
			}

			local count = 0

			local Component = React.Component:extend("Component")

			function Component:init()
				self.state = {
					variables = {
						first = 1,
					},
				}
			end

			function Component:componentDidMount()
				setTimeout(
					function()
						self:setState({ variables = { first = 2 } })
					end,
					-- ROBLOX deviation: min interval
					50
						* TICK
						/ 10
				)
			end

			function Component:render()
				local variables = self.state.variables
				return React.createElement(
					AllPeopleQuery,
					{ query = query, variables = variables },
					function(result: any)
						if result.loading then
							return nil
						end
						local ok, res = pcall(function()
							if count == 0 then
								expect(variables).toEqual({ first = 1 })
								expect(stripSymbols(result.data)).toEqual(data1)
							end
							if count == 1 then
								expect(variables).toEqual({ first = 2 })
								expect(stripSymbols(result.data)).toEqual(data2)
							end
						end)
						if not ok then
							reject(res)
						end

						count += 1
						return nil
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				return expect(count).toBe(2)
			end):andThen(resolve, reject)
		end)

		itAsync("if the query changes", function(resolve, reject)
			local query1 = allPeopleQuery

			local query2 = gql([[

        query people {
          allPeople(first: 1) {
            people {
              id
              name
            }
          }
        }
      ]])

			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local data2 = { allPeople = { people = { { name = "Han Solo", id = "1" } } } }
			local mocks = {
				{ request = { query = query1 }, result = { data = data1 } },
				{ request = { query = query2 }, result = { data = data2 } } :: any,
			}

			local count = 0

			local Component = React.Component:extend("Component")

			function Component:init()
				self.state = {
					query = query1,
				}
			end

			function Component:render()
				local query = self.state.query

				return React.createElement(Query, { query = query }, function(result: any)
					if result.loading then
						return nil
					end
					local ok, res = pcall(function()
						if count == 0 then
							expect(stripSymbols(result.data)).toEqual(data1)
							setTimeout(function()
								self:setState({ query = query2 })
							end)
						end
						if count == 1 then
							expect(stripSymbols(result.data)).toEqual(data2)
						end
					end)
					if not ok then
						reject(res)
					end

					count += 1
					return nil
				end)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				return expect(count).toBe(2)
			end):andThen(resolve, reject)
		end)

		itAsync("with data while loading", function(resolve, reject)
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
			local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
			local mocks = {
				{ request = { query = query, variables = { first = 1 } }, result = { data = data1 } },
				{ request = { query = query, variables = { first = 2 } }, result = { data = data2 } },
			}

			local count = 0

			type Component = { state: any, componentDidMount: any, render: any } --[[ ROBLOX TODO: replace 'any' type/ add missing ]]

			local Component = React.Component:extend("Component")

			function Component:init()
				self.state = {
					variables = {
						first = 1,
					},
				}
			end

			function Component:componentDidMount()
				setTimeout(
					function()
						self:setState({ variables = { first = 2 } })
					end,
					-- ROBLOX deviation: min interval
					10 * TICK
				)
			end

			function Component:render()
				local variables = self.state.variables

				return React.createElement(
					AllPeopleQuery,
					{ query = query, variables = variables },
					function(result: any)
						if count == 0 then
							expect(result.loading).toBe(true)
							expect(result.data).toBeUndefined()
							expect(result.networkStatus).toBe(NetworkStatus.loading)
						elseif count == 1 then
							expect(result.loading).toBe(false)
							expect(result.data).toEqual(data1)
							expect(result.networkStatus).toBe(NetworkStatus.ready)
						elseif count == 2 then
							expect(result.loading).toBe(true)
							expect(result.data).toBeUndefined()
							expect(result.networkStatus).toBe(NetworkStatus.setVariables)
						elseif count == 3 then
							expect(result.loading).toBe(false)
							expect(result.data).toEqual(data2)
							expect(result.networkStatus).toBe(NetworkStatus.ready)
						end

						count += 1
						return nil
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = mocks, addTypename = false },
					React.createElement(Component, nil)
				)
			)

			return waitFor(function()
				return expect(count).toBe(4)
			end):andThen(resolve, reject)
		end)

		itAsync("should update if a manual `refetch` is triggered after a state change", function(resolve, reject)
			local query: DocumentNode = gql([[

        query {
          allPeople {
            people {
              name
            }
          }
        }
      ]])
			local data1 = { allPeople = { people = { { name = "Luke Skywalker" } } } }

			local link = mockSingleLink(
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data1 } },
				{ request = { query = query }, result = { data = data1 } }
			)

			local client = ApolloClient.new({
				link = link,
				cache = Cache.new({ addTypename = false }),
			})

			local count = 0

			local SomeComponent = React.Component:extend("SomeComponent")

			function SomeComponent:init(props: any)
				self.props = props
				self.state = { open = false }

				-- ROBLOX deviation: binding is not required
				-- self.toggle = self.toggle
			end

			function SomeComponent:toggle()
				self:setState(function(prevState: any)
					return { open = not Boolean.toJSBoolean(prevState.open) }
				end)
			end

			function SomeComponent:render()
				local open = self.state.open

				return React.createElement(
					Query,
					{ client = client, query = query, notifyOnNetworkStatusChange = true },
					function(props: any)
						local ok, res = pcall(function()
							local condition_ = count
							if condition_ == 0 then
								-- Loading first response
								expect(props.loading).toBe(true)
								expect(open).toBe(false)
							elseif condition_ == 1 then
								-- First response loaded, change state value
								expect(stripSymbols(props.data)).toEqual(data1)
								expect(open).toBe(false)
								setTimeout(function()
									self:toggle()
								end)
							elseif condition_ == 2 then
								-- State value changed, fire a refetch
								expect(open).toBe(true)
								setTimeout(function()
									props:refetch()
								end)
							elseif condition_ == 3 then
								-- Second response loading
								expect(props.loading).toBe(true)
							elseif condition_ == 4 then
								-- Second response received, fire another refetch
								expect(stripSymbols(props.data)).toEqual(data1)
								setTimeout(function()
									props:refetch()
								end)
							elseif condition_ == 5 then
								-- Third response loading
								expect(props.loading).toBe(true)
							elseif condition_ == 6 then
								-- Third response received
								expect(stripSymbols(props.data)).toEqual(data1)
							else
								reject("Unknown count")
							end
							count += 1
						end)
						if not ok then
							reject(res)
						end

						return nil
					end
				)
			end

			render(React.createElement(SomeComponent, nil))

			return waitFor(function()
				return expect(count).toBe(7)
			end):andThen(resolve, reject)
		end)
	end)

	itAsync("should error if the query changes type to a subscription", function(resolve, reject)
		local subscription = gql([[

      subscription onCommentAdded($repoFullName: String!) {
        commentAdded(repoFullName: $repoFullName) {
          id
          content
        }
      }
    ]])

		-- Prevent error from showing up in console.
		local errorLog = console.error
		console.error = function() end

		local Component = React.Component:extend("Component")

		function Component:init()
			self.state = { query = allPeopleQuery }
		end

		function Component:componentDidCatch(error_)
			local expectedError =
				Error.new("Running a Query requires a graphql Query, but a Subscription was " .. "used instead.")
			-- ROBLOX deviation: compare error message and not whole error
			expect(error_.message).toEqual(expectedError.message)
		end

		function Component:componentDidMount()
			setTimeout(function()
				self:setState({ query = subscription })
			end)
		end

		function Component:render()
			local query = self.state.query

			return React.createElement(Query, { query = query }, function()
				return nil
			end)
		end

		render(
			React.createElement(
				MockedProvider,
				{ mocks = allPeopleMocks, addTypename = false },
				React.createElement(Component, nil)
			)
		)

		return wait_()
			:andThen(function()
				console.error = errorLog
			end)
			:andThen(resolve, reject)
	end)

	itAsync("should be able to refetch after there was a network error", function(resolve, reject)
		local query: DocumentNode = gql([[

      query somethingelse {
        allPeople(first: 1) {
          people {
            name
          }
        }
      }
    ]])

		local data = { allPeople = { people = { { name = "Luke Skywalker" } } } }
		local dataTwo = { allPeople = { people = { { name = "Princess Leia" } } } }
		local link = mockSingleLink(
			{ request = { query = query }, result = { data = data } },
			{ request = { query = query }, error = Error.new("This is an error!") },
			{ request = { query = query }, result = { data = dataTwo } }
		)
		local client = ApolloClient.new({ link = link, cache = Cache.new({ addTypename = false }) })

		local count = 0

		local function noop()
			return nil
		end

		local AllPeopleQuery2 = Query

		local function Container()
			return React.createElement(
				AllPeopleQuery2,
				{ query = query, notifyOnNetworkStatusChange = true },
				function(result: any)
					local ok, res = pcall(function()
						local condition_ = (function()
							local result = count
							count += 1
							return result
						end)()
						if condition_ == 0 then
							-- Waiting for the first result to load
							expect(result.loading).toBeTruthy()
						elseif condition_ == 1 then
							if not (Boolean.toJSBoolean((result.data :: any).allPeople)) then
								reject("Should have data by this point")
							else
								-- First result is loaded, run a refetch to get the second result
								-- which is an error.
								expect(stripSymbols((result.data :: any).allPeople)).toEqual(data.allPeople)
								setTimeout(function()
									result:refetch():andThen(function()
										reject("Expected error value on first refetch.")
									end, noop)
								end, 0)
							end
						elseif condition_ == 2 then
							-- Waiting for the second result to load
							expect(result.loading).toBeTruthy()
						elseif condition_ == 3 then
							-- The error arrived, run a refetch to get the third result
							-- which should now contain valid data.
							expect(result.loading).toBeFalsy()
							expect(result.error).toBeTruthy()
							setTimeout(function()
								result:refetch():catch(function()
									reject("Expected good data on second refetch.")
								end)
							end, 0)
						elseif condition_ == 4 then
							expect(result.loading).toBeTruthy()
							expect(result.error).toBeFalsy()
						elseif condition_ == 5 then
							expect(result.loading).toBeFalsy()
							expect(result.error).toBeFalsy()
							if not Boolean.toJSBoolean(result.data) then
								reject("Should have data by this point")
							else
								expect(stripSymbols(result.data.allPeople)).toEqual(dataTwo.allPeople)
							end
						else
							error(Error.new("Unexpected fall through"))
						end
					end)

					if not ok then
						reject(res)
					end

					return nil
				end
			)
		end

		render(React.createElement(ApolloProvider, { client = client }, React.createElement(Container, nil)))

		return waitFor(function()
			return expect(count).toBe(6)
		end):andThen(resolve, reject)
	end)

	itAsync(
		"should not persist previous result errors when a subsequent valid result is received",
		function(resolve, reject)
			local query: DocumentNode = gql([[

        query somethingelse($variable: Boolean) {
          allPeople(first: 1, yetisArePeople: $variable) {
            people {
              name
            }
          }
        }
      ]])

			local data = { allPeople = { people = { { name = "Luke Skywalker" } } } }
			local variableGood = { variable = true }
			local variableBad = { variable = false }

			local link = mockSingleLink(
				{ request = { query = query, variables = variableGood }, result = { data = data } },
				{
					request = { query = query, variables = variableBad },
					result = { errors = { Error.new("This is an error!") } },
				},
				{ request = { query = query, variables = variableGood }, result = { data = data } }
			)

			local client = ApolloClient.new({
				link = link,
				cache = Cache.new({ addTypename = false }),
			})

			local count = 0

			local function DummyComp(props: any)
				local ok, res = pcall(function()
					local condition_ = (function()
						local result = count
						count += 1
						return result
					end)()
					if condition_ == 0 then
						expect(props.loading).toBeTruthy()
					elseif condition_ == 1 then
						expect(props.data.allPeople).toBeTruthy()
						expect(props.error).toBeFalsy()
						-- Change query variables to trigger bad result.
						setTimeout(function()
							render(React.createElement(Query, {
								client = client,
								query = query,
								variables = variableBad,
							}, function(result: any)
								return React.createElement(DummyComp, Object.assign({}, result))
							end))
						end)
					elseif condition_ == 2 then
						expect(props.loading).toBeTruthy()
					elseif condition_ == 3 then
						-- Error should be received.
						expect(props.error).toBeTruthy()
						-- Change query variables to trigger a good result.
						setTimeout(function()
							render(React.createElement(Query, {
								client = client,
								query = query,
								variables = variableGood,
							}, function(result: any)
								return React.createElement(DummyComp, Object.assign({}, result))
							end))
						end)
					elseif condition_ == 4 then
						-- Good result should be received without any errors.
						expect(props.error).toBeFalsy()
						expect(props.data.allPeople).toBeTruthy()
					else
						reject("Unknown count")
					end
				end)
				if not ok then
					reject(res)
				end

				return nil
			end

			render(
				React.createElement(
					Query,
					{ client = client, query = query, variables = variableGood },
					function(result: any)
						return React.createElement(DummyComp, Object.assign({}, result))
					end
				)
			)

			return waitFor(function()
				return expect(count).toBe(5)
			end):andThen(resolve, reject)
		end
	)

	itAsync("should support mixing setState and onCompleted", function(resolve, reject)
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
		local data2 = { allPeople = { people = { { name = "Han Solo" } } } }
		local mocks = {
			{ request = { query = query, variables = { first = 1 } }, result = { data = data1 } },
			{ request = { query = query, variables = { first = 2 } }, result = { data = data2 } },
		}

		local renderCount = 0
		local onCompletedCallCount = 0
		local unmount: any

		local Component = React.Component:extend("Component")

		function Component:init()
			self.state = {
				variables = {
					first = 1,
				},
			}
		end

		function Component:componentDidMount()
			setTimeout(
				function()
					self:setState({ variables = { first = 2 } })
				end,
				-- ROBLOX deviation: min interval
				10 * TICK
			)
		end

		function Component:onCompleted()
			onCompletedCallCount += 1
		end

		function Component:render()
			local variables = self.state.variables

			return React.createElement(
				AllPeopleQuery,
				{ query = query, variables = variables, onCompleted = self.onCompleted },
				function(ref)
					local loading, data = ref.loading, ref.data
					rejectOnComponentThrow(reject, function()
						local condition_ = renderCount
						if condition_ == 0 then
							expect(loading).toBeTruthy()
						elseif condition_ == 1 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(data1)
						elseif condition_ == 2 then
							expect(loading).toBeTruthy()
						elseif condition_ == 3 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(data2)
							setTimeout(function()
								return self:setState({ variables = { first = 1 } })
							end)
						elseif condition_ == 4 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(data1)
							setTimeout(unmount)
						else
							-- ROBLOX comment: Do nothing
						end
						renderCount += 1
					end)

					return nil
				end
			)
		end

		unmount = render(
			React.createElement(
				MockedProvider,
				{ mocks = mocks, addTypename = false },
				React.createElement(Component, nil)
			)
		).unmount

		return waitFor(function()
			expect(onCompletedCallCount).toBe(3)
		end):andThen(resolve, reject)
	end)

	itAsync("should not repeatedly call onError if setState in it", function(resolve, reject)
		local mockError = {
			{
				request = { query = allPeopleQuery, variables = { first = 1 } },
				error = Error.new("error occurred"),
			},
		}

		local unmount: any
		local onErrorCallCount = 0

		local Component = React.Component:extend("Component")

		function Component:init()
			self.state = {
				variables = {
					first = 1,
				},
			}

			self.onError = function()
				onErrorCallCount += 1
				self:setState({ causeUpdate = true })
			end
		end

		function Component:render()
			return React.createElement(
				Query,
				{ query = allPeopleQuery, variables = self.state.variables, onError = self.onError },
				function(ref)
					local loading = ref.loading
					if not loading then
						setTimeout(unmount)
					end
					return nil
				end
			)
		end

		unmount = render(
			React.createElement(
				MockedProvider,
				{ mocks = mockError, addTypename = false },
				React.createElement(Component, nil)
			)
		).unmount

		return waitFor(function()
			expect(onErrorCallCount).toBe(1)
		end):andThen(resolve, reject)
	end)

	describe("Partial refetching", function()
		local origConsoleWarn = console.warn

		beforeAll(function()
			console.warn = function()
				return nil
			end
		end)

		afterAll(function()
			console.warn = origConsoleWarn
		end)

		withErrorSpy(
			itAsync,
			"should attempt a refetch when the query result was marked as being "
				.. "partial, the returned data was reset to an empty Object by the "
				.. "Apollo Client QueryManager (due to a cache miss), and the "
				.. "`partialRefetch` prop is `true`",
			function(resolve, reject)
				local query = allPeopleQuery
				local link = mockSingleLink(
					{ request = { query = query }, result = { data = {} } },
					{ request = { query = query }, result = { data = allPeopleData } }
				)

				local client = ApolloClient.new({
					link = link,
					cache = Cache.new({ addTypename = false }),
				})

				local function Component()
					return React.createElement(
						Query,
						{ query = allPeopleQuery, partialRefetch = true },
						function(result: any)
							local data, loading = result.data, result.loading
							rejectOnComponentThrow(reject, function()
								if not loading then
									expect(stripSymbols(data)).toEqual(allPeopleData)
								end
							end)
							return nil
						end
					)
				end

				render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

				return wait_():andThen(resolve, reject)
			end
		)

		itAsync(
			"should not refetch when an empty partial is returned if the " .. "`partialRefetch` prop is false/not set",
			function(resolve, reject)
				local query = allPeopleQuery
				local link = mockSingleLink({ request = { query = query }, result = { data = {} } })

				local client = ApolloClient.new({
					link = link,
					cache = Cache.new({ addTypename = false }),
				})

				local function Component()
					return React.createElement(Query, { query = allPeopleQuery }, function(result: any)
						local data, loading = result.data, result.loading
						rejectOnComponentThrow(reject, function()
							if not loading then
								expect(data).toBeUndefined()
							end
						end)
						return nil
					end)
				end

				render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

				return wait_():andThen(resolve, reject)
			end
		)
	end)

	itAsync(
		"should keep data for a `Query` component using `no-cache` when the " .. "tree is re-rendered",
		function(resolve, reject)
			local query1 = allPeopleQuery

			local query2: DocumentNode = gql([[

        query Things {
          allThings {
            thing {
              description
            }
          }
        }
      ]])

			type ThingData = { allThings: { thing: Array<{ description: string }> } }

			local allThingsData: ThingData = {
				allThings = { thing = { { description = "Thing 1" }, { description = "Thing 2" } } },
			}

			local link = mockSingleLink(
				{ request = { query = query1 }, result = { data = allPeopleData } },
				{ request = { query = query2 }, result = { data = allThingsData } },
				{ request = { query = query1 }, result = { data = allPeopleData } }
			)

			local client = ApolloClient.new({
				link = link,
				cache = Cache.new({ addTypename = false }),
			})

			local expectCount = 0

			local function People()
				local renderCount = 0
				return React.createElement(Query, { query = query1, fetchPolicy = "no-cache" }, function(ref)
					local data, loading = ref.data, ref.loading
					if renderCount > 0 and not loading then
						expect(data).toEqual(allPeopleData)
						expectCount += 1
					end
					renderCount += 1
					return nil
				end)
			end

			local function Things()
				return React.createElement(Query, { query = query2 }, function(ref)
					local data, loading = ref.data, ref.loading
					if not loading then
						expect(data).toEqual(allThingsData)
						expectCount += 1
					end
					return nil
				end)
			end

			local function App()
				return React.createElement(
					ApolloProvider,
					{ client = client },
					React.createElement(People, nil),
					React.createElement(Things, nil)
				)
			end

			render(React.createElement(App, nil))

			return waitFor(function()
				return expect(expectCount).toBe(2)
			end):andThen(resolve, reject)
		end
	)

	describe("Return partial data", function()
		local origConsoleWarn = console.warn

		beforeAll(function()
			console.warn = function()
				return nil
			end
		end)

		afterAll(function()
			console.warn = origConsoleWarn
		end)

		it("should not return partial cache data when `returnPartialData` is false", function()
			local cache = Cache.new()
			local client = ApolloClient.new({ cache = cache, link = ApolloLink.empty() })

			local fullQuery = gql([[

        query {
          cars {
            make
            model
            repairs {
              date
              description
            }
          }
        }
      ]])

			cache:writeQuery({
				query = fullQuery,
				data = {
					cars = {
						{
							__typename = "Car",
							make = "Ford",
							model = "Mustang",
							vin = "PONY123",
							repairs = {
								{
									__typename = "Repair",
									date = "2019-05-08",
									description = "Could not get after it.",
								},
							},
						},
					},
				},
			})

			local partialQuery = gql([[

        query {
          cars {
            repairs {
              date
              cost
            }
          }
        }
      ]])

			local function App()
				return React.createElement(
					ApolloProvider,
					{ client = client },
					React.createElement(Query, { query = partialQuery }, function(ref)
						local data = ref.data
						expect(data).toBeUndefined()
						return nil
					end)
				)
			end

			render(React.createElement(App, nil))
		end)

		it("should return partial cache data when `returnPartialData` is true", function()
			local cache = Cache.new()
			local client = ApolloClient.new({ cache = cache, link = ApolloLink.empty() })

			local fullQuery = gql([[

        query {
          cars {
            make
            model
            repairs {
              date
              description
            }
          }
        }
      ]])

			cache:writeQuery({
				query = fullQuery,
				data = {
					cars = {
						{
							__typename = "Car",
							make = "Ford",
							model = "Mustang",
							vin = "PONY123",
							repairs = {
								{
									__typename = "Repair",
									date = "2019-05-08",
									description = "Could not get after it.",
								},
							},
						},
					},
				},
			})

			local partialQuery = gql([[

        query {
          cars {
            repairs {
              date
              cost
            }
          }
        }
      ]])

			local function App()
				return React.createElement(
					ApolloProvider,
					{ client = client },
					React.createElement(Query, { query = partialQuery, returnPartialData = true }, function(ref)
						local loading, data = ref.loading, ref.data

						if not loading then
							expect(data).toEqual({
								cars = {
									{
										__typename = "Car",
										repairs = {
											{ __typename = "Repair", date = "2019-05-08" },
										},
									},
								},
							})
						end
						return nil
					end)
				)
			end

			render(React.createElement(App, nil))

			return wait_():expect()
		end)
	end)
end)

return {}
