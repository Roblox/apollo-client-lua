-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/mocking/__tests__/mockSubscriptionLink.test.tsx

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local React = require(rootWorkspace.React)
	local reactTestingModule = require(srcWorkspace.testUtils.react)(afterEach)
	local render = reactTestingModule.render
	local wait = reactTestingModule.wait
	local gql = require(rootWorkspace.GraphQLTag).default

	local MockSubscriptionLink = require(script.Parent.Parent.mockSubscriptionLink).MockSubscriptionLink
	local ApolloClient = require(script.Parent.Parent.Parent.Parent.Parent.core).ApolloClient
	local Cache = require(script.Parent.Parent.Parent.Parent.Parent.cache).InMemoryCache
	local ApolloProvider = require(script.Parent.Parent.Parent.Parent.Parent.react.context).ApolloProvider
	-- ROBLOX TODO: import real implementation when ready
	-- local useSubscription = require(script.Parent.Parent.Parent.Parent.Parent.react.hooks).useSubscription
	local useSubscription = function(...): ...any end

	xdescribe("mockSubscriptionLink", function()
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
				return { result = { data = { car = { make = make } } } }
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

			render(
				React.createElement(
					ApolloProvider,
					{ client = client },
					React.createElement(
						"div",
						nil,
						React.createElement(Component, nil),
						React.createElement(ComponentA, nil),
						React.createElement(ComponentB, nil)
					)
				)
			)

			return wait(function()
				jestExpect(renderCountA).toBe(#results + 1)
				jestExpect(renderCountB).toBe(#results + 1)
			end, {
				timeout = 1000,
			})
		end)
	end)
end
