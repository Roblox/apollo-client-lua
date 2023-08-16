--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/testing/mocking/__tests__/MockedProvider.test.tsx
local srcWorkspace = script.Parent.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object
local Error = LuauPolyfill.Error
type Array<T> = LuauPolyfill.Array<T>
type ReadonlyArray<T> = Array<T>

type Function = (...any) -> ...any

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local React = require(rootWorkspace.React)
local reactTestUtilsModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = reactTestUtilsModule.render
local wait_ = require(srcWorkspace.testUtils.wait).wait
local gql = require(rootWorkspace.GraphQLTag).default

local itAsync = require(script.Parent.Parent.Parent.itAsync).itAsync
local MockedProvider = require(script.Parent.Parent.MockedProvider).MockedProvider
local mockLinkModule = require(script.Parent.Parent.mockLink)
type MockedResponse<TData> = mockLinkModule.MockedResponse<TData>
local MockLink = mockLinkModule.MockLink
local graphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphQLModule.DocumentNode

local useQuery = require(script.Parent.Parent.Parent.Parent.Parent.react.hooks.useQuery).useQuery

local InMemoryCache = require(srcWorkspace.cache.inmemory.inMemoryCache).InMemoryCache

local ApolloLink = require(srcWorkspace.link.core).ApolloLink

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

local variables = { username = "mock_username" }

local userWithoutTypeName = { id = "user_id" }

local user = Object.assign({}, { __typename = "User" }, userWithoutTypeName)

local query: DocumentNode = gql([[

  query GetUser($username: String!) {
    user(username: $username) {
      id
    }
  }
]])

local queryWithTypename: DocumentNode = gql([[

  query GetUser($username: String!) {
    user(username: $username) {
      id
      __typename
    }
  }
]])

local mocks: ReadonlyArray<MockedResponse<any>> = {
	{ request = { query = query, variables = variables }, result = { data = { user = user } } },
}

type Data = { user: { id: string } }

type Variables = { username: string }

local errorThrown = false
local errorLink = ApolloLink.new(function(_self, operation, forward)
	local observer = nil
	xpcall(function()
		observer = forward(operation)
	end, function(error_)
		errorThrown = true
	end)
	return observer
end)

describe("General use", function()
	beforeEach(function()
		errorThrown = false
	end)

	itAsync("should mock the data", function(resolve, reject)
		local function Component(ref: Variables)
			local _username = ref.username

			local ref_ = useQuery(query, { variables = variables })

			rejectOnComponentThrow(reject, function()
				local loading, data = ref_.loading, ref_.data
				if not loading then
					expect((data :: any).user).toMatchSnapshot()
				end
			end)
			return nil
		end

		render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, variables)))
		return wait_():andThen(resolve, reject)
	end)

	itAsync("should allow querying with the typename", function(resolve, reject)
		local function Component(ref: Variables)
			local _username = ref.username

			local ref_ = useQuery(query, { variables = variables })
			rejectOnComponentThrow(reject, function()
				local loading, data = ref_.loading, ref_.data
				if not loading then
					expect((data :: any).user).toMatchSnapshot()
				end
			end)
			return nil
		end

		local mocksWithTypename = {
			{
				request = { query = queryWithTypename, variables = variables },
				result = { data = { user = user } },
			},
		}

		render(
			React.createElement(
				MockedProvider,
				{ mocks = mocksWithTypename },
				React.createElement(Component, variables)
			)
		)

		return wait_():andThen(resolve, reject)
	end)

	itAsync("should allow using a custom cache", function(resolve, reject)
		local cache = InMemoryCache.new()
		cache:writeQuery({ query = query, variables = variables, data = { user = user } })

		local function Component(ref: Variables)
			local _username = ref.username

			local ref_ = useQuery(query, { variables = variables })
			rejectOnComponentThrow(reject, function()
				local loading, data = ref_.loading, ref_.data

				if not loading then
					expect(data).toMatchObject({ user = user })
				end
			end)
			return nil
		end

		render(
			React.createElement(
				MockedProvider,
				{ mocks = {}, cache = cache },
				React.createElement(Component, variables)
			)
		)

		return wait_():andThen(resolve, reject)
	end)

	itAsync("should error if the variables in the mock and component do not match", function(resolve, reject)
		local function Component(ref)
			local variables = Object.assign({}, ref, {})

			local ref_ = useQuery(query, { variables = variables })
			rejectOnComponentThrow(reject, function()
				local loading, error_ = ref_.loading, ref_.error

				if not loading then
					-- ROBLOX deviation: must use error message (otherwise we get a table id)
					expect(error_.message).toMatchSnapshot()
				end
			end)
			return nil
		end

		local variables2 = { username = "other_user", age = nil }

		render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, variables2)))

		return wait_():andThen(resolve, reject)
	end)

	itAsync("should error if the variables do not deep equal", function(resolve, reject)
		local function Component(ref: Variables)
			local variables = Object.assign({}, ref, {})

			local ref_ = useQuery(query, { variables = variables })

			rejectOnComponentThrow(reject, function()
				local loading, error_ = ref_.loading, ref_.error

				if not loading then
					-- ROBLOX deviation: must use error message (otherwise we get a table id)
					expect(error_.message).toMatchSnapshot()
				end
			end)
			return nil
		end

		local mocks2 = {
			{
				request = { query = query, variables = { age = 13, username = "some_user" } },
				result = { data = { user = user } },
			},
		}

		local variables2 = { username = "some_user", age = 42 }

		render(React.createElement(MockedProvider, { mocks = mocks2 }, React.createElement(Component, variables2)))

		return wait_():andThen(resolve, reject)
	end)

	itAsync("should not error if the variables match but have different order", function(resolve, reject)
		local function Component(ref)
			local variables = Object.assign({}, ref, {})

			local ref_ = useQuery(query, { variables = variables })
			rejectOnComponentThrow(reject, function()
				local loading, data = ref_.loading, ref_.data

				if not loading then
					expect(data).toMatchSnapshot()
				end
			end)
			return nil
		end

		local mocks2 = {
			{
				request = { query = query, variables = { age = 13, username = "some_user" } },
				result = { data = { user = user } },
			},
		}

		local variables2 = { username = "some_user", age = 13 }

		render(React.createElement(MockedProvider, { mocks = mocks2 }, React.createElement(Component, variables2)))

		return wait_():andThen(resolve, reject)
	end)

	itAsync("should support mocking a network error", function(resolve, reject)
		local function Component(ref)
			local variables = Object.assign({}, ref, {})

			local ref_ = useQuery(query, { variables = variables })

			rejectOnComponentThrow(reject, function()
				local loading, error_ = ref_.loading, ref_.error

				if not loading then
					-- ROBLOX deviation: comparing error messages
					expect(error_.message).toEqual(Error.new("something went wrong").message)
				end
			end)
			return nil
		end

		local mocksError = {
			{
				request = { query = query, variables = variables },
				error = Error.new("something went wrong"),
			},
		}

		render(React.createElement(MockedProvider, { mocks = mocksError }, React.createElement(Component, variables)))

		return wait_():andThen(resolve, reject)
	end)

	itAsync("should error if the query in the mock and component do not match", function(resolve, reject)
		local function Component(ref: Variables)
			local variables = Object.assign({}, ref, {})

			local ref_ = useQuery(query, { variables = variables })

			rejectOnComponentThrow(reject, function()
				local loading, error_ = ref_.loading, ref_.error

				if not loading then
					-- ROBLOX deviation: must use error message (otherwise we get a table id)
					expect(error_.message).toMatchSnapshot()
				end
			end)
			return nil
		end

		local mocksDifferentQuery = {
			{
				request = {
					query = gql([[

            query OtherQuery {
              otherQuery {
                id
              }
            }
          ]]),
					variables = variables,
				},
				result = { data = { user = user } },
			},
		}

		render(
			React.createElement(
				MockedProvider,
				{ mocks = mocksDifferentQuery },
				React.createElement(Component, variables)
			)
		)

		return wait_():andThen(resolve, reject)
	end)

	it("should pass down props prop in mock as props for the component", function()
		local function Component(ref)
			local variables = Object.assign({}, ref, {})
			expect(variables.foo).toBe("bar")
			expect(variables.baz).toBe("qux")
			return nil
		end

		render(
			React.createElement(
				MockedProvider,
				{ mocks = mocks, childProps = { foo = "bar", baz = "qux" } },
				React.createElement(Component, variables)
			)
		)
	end)

	it("should not crash on unmount if there is no query manager", function()
		local function Component()
			return nil
		end

		local ref = render(React.createElement(MockedProvider, nil, React.createElement(Component, nil)))
		local unmount = ref.unmount

		unmount()
	end)

	itAsync("should support returning mocked results from a function", function(resolve, reject)
		local resultReturned = false

		local testUser = { __typename = "User", id = 12345 }

		local function Component(ref: Variables)
			local variables = Object.assign({}, ref, {})

			local ref_ = useQuery(query, { variables = variables })

			rejectOnComponentThrow(reject, function()
				local loading, data = ref_.loading, ref_.data

				if not loading then
					expect((data :: any).user).toEqual(testUser)
					expect(resultReturned).toBe(true)
				end
			end)
			return nil
		end

		local testQuery: DocumentNode = gql([[

      query GetUser($username: String!) {
        user(username: $username) {
          id
        }
      }
    ]])

		local testVariables = { username = "jsmith" }
		local testMocks = {
			{
				request = { query = testQuery, variables = testVariables },
				result = function(self)
					resultReturned = true
					return { data = { user = { __typename = "User", id = 12345 } } }
				end,
			},
		}

		render(
			React.createElement(MockedProvider, { mocks = testMocks }, React.createElement(Component, testVariables))
		)

		return wait_():andThen(resolve, reject)
	end)

	itAsync('should return "No more mocked responses" errors in response', function(resolve, reject)
		local function Component()
			local ref = useQuery(query)
			rejectOnComponentThrow(reject, function()
				local loading, error_ = ref.loading, ref.error

				if not loading then
					-- ROBLOX deviation: must use error message (otherwise we get a table id)
					expect(error_.message).toMatchSnapshot()
				end
			end)
			return nil
		end

		local link = ApolloLink.from({ errorLink, MockLink.new({}) })

		render(React.createElement(MockedProvider, { link = link }, React.createElement(Component, nil)))

		return wait_(function()
			-- The "No more mocked responses" error should not be thrown as an
			-- uncaught exception.
			expect(errorThrown).toBeFalsy()
		end):andThen(resolve, reject)
	end)

	itAsync('should return "Mocked response should contain" errors in response', function(resolve, reject)
		local function Component(ref: Variables)
			local variables = Object.assign({}, ref, {})

			local ref_ = useQuery(query, { variables = variables })

			rejectOnComponentThrow(reject, function()
				local loading, error_ = ref_.loading, ref_.error

				if not loading then
					-- ROBLOX deviation: must use error message (otherwise we get a table id)
					expect(error_.message).toMatchSnapshot()
				end
			end)
			return nil
		end

		local link = ApolloLink.from({
			errorLink,
			MockLink.new({ { request = { query = query, variables = variables } } }),
		})

		render(React.createElement(MockedProvider, { link = link }, React.createElement(Component, variables)))

		return wait_(function()
			-- The "Mocked response should contain" error should not be thrown as an
			-- uncaught exception.
			expect(errorThrown).toBeFalsy()
		end):andThen(resolve, reject)
	end)

	itAsync("should support custom error handling using setOnError", function(resolve, reject)
		local function Component(ref: Variables)
			local variables = Object.assign({}, ref, {})
			useQuery(query, { variables = variables })
			return nil
		end

		local mockLink = MockLink.new({})
		mockLink:setOnError(function(_self, error_)
			-- ROBLOX deviation: must use error message (otherwise we get a table id)
			expect(error_.message).toMatchSnapshot()
		end)

		local link = ApolloLink.from({ errorLink, mockLink })

		render(React.createElement(MockedProvider, { link = link }, React.createElement(Component, variables)))

		return wait_():andThen(resolve, reject)
	end)

	itAsync(
		"should pipe exceptions thrown in custom onError functions through the link chain",
		function(resolve, reject)
			local function Component(ref: Variables)
				local variables = Object.assign({}, ref, {})

				local ref_ = useQuery(query, { variables = variables })

				rejectOnComponentThrow(reject, function()
					local loading, error_ = ref_.loading, ref_.error

					if not loading then
						-- ROBLOX deviation: must use error message (otherwise we get a table id)
						expect(error_.message).toMatchSnapshot()
					end
				end)
				return nil
			end

			local mockLink = MockLink.new({})
			mockLink:setOnError(function()
				error(Error.new("oh no!"))
			end)

			local link = ApolloLink.from({ errorLink, mockLink })

			render(React.createElement(MockedProvider, { link = link }, React.createElement(Component, variables)))

			return wait_():andThen(resolve, reject)
		end
	)
end)

describe("@client testing", function()
	itAsync("should support @client fields with a custom cache", function(resolve, reject)
		local cache = InMemoryCache.new()

		cache:writeQuery({
			query = gql([[{
        networkStatus {
          isOnline
        }
      }]]),
			data = { networkStatus = { __typename = "NetworkStatus", isOnline = true } },
		})

		local function Component()
			local ref = useQuery(gql([[{
        networkStatus @client {
          isOnline
        }
      }]]))

			rejectOnComponentThrow(reject, function()
				local loading, data = ref.loading, ref.data

				if not loading then
					expect((data :: any).networkStatus.__typename).toEqual("NetworkStatus")
					expect((data :: any).networkStatus.isOnline).toEqual(true)
				end
			end)
			return nil
		end

		render(React.createElement(MockedProvider, { cache = cache }, React.createElement(Component, nil)))

		return wait_():andThen(resolve, reject)
	end)

	itAsync("should support @client fields with field policies", function(resolve, reject)
		local cache = InMemoryCache.new({
			typePolicies = {
				Query = {
					fields = {
						networkStatus = function(_self)
							return { __typename = "NetworkStatus", isOnline = true }
						end,
					},
				},
			},
		} :: any)

		local function Component()
			local ref = useQuery(gql([[{
        networkStatus @client {
          isOnline
        }
      }]]))

			rejectOnComponentThrow(reject, function()
				local loading, data = ref.loading, ref.data

				if not loading then
					expect((data :: any).networkStatus.__typename).toEqual("NetworkStatus")
					expect((data :: any).networkStatus.isOnline).toEqual(true)
				end
			end)
			return nil
		end

		render(React.createElement(MockedProvider, { cache = cache }, React.createElement(Component, nil)))

		return wait_():andThen(resolve, reject)
	end)
end)

return {}
