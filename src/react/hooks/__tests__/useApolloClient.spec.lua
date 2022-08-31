-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/hooks/__tests__/useApolloClient.test.tsx

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local afterEach = JestGlobals.afterEach
local expect = JestGlobals.expect
local it = JestGlobals.it

local React = require(rootWorkspace.React)
local testingLibrary = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = testingLibrary.render
local cleanup = testingLibrary.cleanup
local invariantModule = require(srcWorkspace.jsutils.invariant)
local InvariantError = invariantModule.InvariantError

local ApolloClient = require(srcWorkspace.core).ApolloClient
local ApolloLink = require(script.Parent.Parent.Parent.Parent.link.core).ApolloLink
local contextModule = require(srcWorkspace.react.context)
local ApolloProvider = contextModule.ApolloProvider
local resetApolloContext = contextModule.resetApolloContext
local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache).InMemoryCache
local useApolloClient = require(srcWorkspace.react.hooks).useApolloClient

describe("useApolloClient Hook", function()
	afterEach(function()
		cleanup()
		resetApolloContext()
	end)

	it("should return a client instance from the context if available", function()
		local client = ApolloClient.new({ cache = InMemoryCache.new(), link = ApolloLink.empty() })
		local function App()
			expect(useApolloClient()).toEqual(client)
			return nil
		end
		render(React.createElement(ApolloProvider, { client = client }, React.createElement(App, nil)))
	end)

	it("should error if a client instance can't be found in the context", function()
		local function App()
			expect(function()
				return useApolloClient()
			end).toThrow(InvariantError)
			return nil
		end
		render(React.createElement(App, nil))
	end)
end)

return {}
