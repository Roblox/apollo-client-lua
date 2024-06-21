--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/testing/mocking/__tests__/mockSubscriptionLink.test.tsx

local srcWorkspace = script.Parent.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect
local describe = JestGlobals.describe
local it = JestGlobals.it

local React = require(rootWorkspace.React)
local reactTestingModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = reactTestingModule.render
local wait_ = require(srcWorkspace.testUtils.wait).wait
local gql = require(rootWorkspace.GraphQLTag).default

local mockedSubscriptionModule = require(script.Parent.Parent.mockSubscriptionLink)
local MockSubscriptionLink = mockedSubscriptionModule.MockSubscriptionLink
type MockedSubscriptionResult = mockedSubscriptionModule.MockedSubscriptionResult
local ApolloClient = require(script.Parent.Parent.Parent.Parent.Parent.core).ApolloClient
local Cache = require(script.Parent.Parent.Parent.Parent.Parent.cache).InMemoryCache
local ApolloProvider = require(script.Parent.Parent.Parent.Parent.Parent.react.context).ApolloProvider
-- ROBLOX TODO: import real implementation when ready
-- local useSubscription = require(script.Parent.Parent.Parent.Parent.Parent.react.hooks).useSubscription
local useSubscription = function(...): ...any end

describe.skip("mockSubscriptionLink", function()
	it("should work with multiple subscribers to the same mock websocket", function()
		local subscription = gql([[

      subscription {
        car {
          make
        }
      }
    ]])

		local link = MockSubscriptionLink.new()
		local client = ApolloClient.new({
			link = link,
			cache = Cache.new({ addTypename = false }),
		})

		local renderCountA = 0
		local function ComponentA()
			useSubscription(subscription)
			renderCountA += 1
			return nil
		end

		local renderCountB = 0
		local function ComponentB()
			useSubscription(subscription)
			renderCountB += 1
			return nil
		end

		local results = Array.map({ "Audi", "BMW", "Mercedes", "Hyundai" }, function(make)
			return { result = { data = { car = { make = make } } } } :: MockedSubscriptionResult
		end)

		local function Component()
			local index, setIndex = React.useState(0)
			React.useEffect(function()
				if index >= #results then
					return
				end
				link:simulateResult(results[index])
				setIndex(index + 1)
			end, {
				index,
			})
			return nil
		end

		render(React.createElement(
			ApolloProvider,
			{ client = client },
			React.createElement(
				-- ROBLOX deviation: `div` is not a valid instance type:
				React.Fragment,
				nil,
				React.createElement(Component, nil),
				React.createElement(ComponentA, nil),
				React.createElement(ComponentB, nil)
			)
		))

		return wait_(function()
			expect(renderCountA).toBe(#results + 1)
			expect(renderCountB).toBe(#results + 1)
		end, {
			timeout = 1000,
		})
	end)
end)

return {}
