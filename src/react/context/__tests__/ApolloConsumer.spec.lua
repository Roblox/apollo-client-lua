--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/context/__tests__/ApolloConsumer.test.tsx

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local console = LuauPolyfill.console
type Error = LuauPolyfill.Error

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
type DoneFn = ((string | Error)?) -> ()

local React = require(rootWorkspace.React)

local testingLibraryModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = testingLibraryModule.render
local cleanup = testingLibraryModule.cleanup

local ApolloLink = require(srcWorkspace.link.core).ApolloLink
local ApolloClient = require(srcWorkspace.core).ApolloClient
local Cache = require(srcWorkspace.cache.inmemory.inMemoryCache).InMemoryCache

local ContextModule = require(srcWorkspace.react.context)
local getApolloContext = ContextModule.getApolloContext
local ApolloConsumer = ContextModule.ApolloConsumer
local ApolloProvider = ContextModule.ApolloProvider

describe("<ApolloConsumer /> component", function()
	local client = ApolloClient.new({
		cache = Cache.new(),
		link = ApolloLink.new(function(_self, o, f)
			if Boolean.toJSBoolean(f) then
				return f(o)
			else
				return nil
			end
		end),
	})

	afterEach(cleanup)

	it("has a render prop", function(_, done: DoneFn)
		render(
			React.createElement(
				ApolloProvider,
				{ client = client },
				React.createElement(ApolloConsumer, nil, function(clientRender)
					local ok, res = pcall(function()
						expect(clientRender).toBe(client)
						done()
					end)
					if not ok then
						-- ROBLOX deviation START: using done(error) instead of done.fail(error)
						done(res)
						-- ROBLOX deviation END
					end
					return nil
				end)
			)
		)
	end)

	it("renders the content in the children prop", function()
		local ref = render(
			React.createElement(
				ApolloProvider,
				{ client = client },
				React.createElement(ApolloConsumer, nil, function()
					return React.createElement("TextLabel", { Text = "Test" })
				end)
			)
		)
		expect(ref.getByText("Test")).toBeTruthy()
	end)

	it("errors if there is no client in the context", function()
		-- Prevent Error about missing context type from appearing in the console.
		local errorLogger = console.error
		console.error = function() end
		expect(function()
			-- We're wrapping the `ApolloConsumer` component in a
			-- `ApolloContext.Provider` component, to reset the context before
			-- testing.
			local ApolloContext = getApolloContext()

			render(
				React.createElement(
					ApolloContext.Provider,
					{ value = {} },
					React.createElement(ApolloConsumer, nil, function()
						return nil
					end)
				)
			)
		end).toThrowError(
			'Could not find "client" in the context of ApolloConsumer. '
				.. "Wrap the root component in an <ApolloProvider>."
		)
		console.error = errorLogger
	end)
end)

return {}
