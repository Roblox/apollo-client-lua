-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.6/src/react/context/__tests__/ApolloConsumer.test.tsx

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent
	local packagesWorkspace = rootWorkspace.Parent

	local JestRoblox = require(packagesWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local bootstrap = require(rootWorkspace.utilities.common.bootstrap)

	local LuauPolyfill = require(packagesWorkspace.Dev.LuauPolyfill)
	local Array = LuauPolyfill.Array

	local React = require(packagesWorkspace.Roact)

	local ApolloClient = require(rootWorkspace.core).ApolloClient

	local ContextModule = require(rootWorkspace.react.context)

	local ApolloContext = ContextModule.ApolloContext
	local getApolloContext = ApolloContext.getApolloContext

	local ApolloConsumer = ContextModule.ApolloConsumer
	local ApolloProvider = ContextModule.ApolloProvider

	describe("<ApolloConsumer /> component", function()
		local client = ApolloClient.new()
		local rootInstance
		local stop

		beforeEach(function()
			rootInstance = Instance.new("Folder")
			rootInstance.Name = "GuiRoot"
		end)

		afterEach(function()
			if stop ~= nil then
				stop()
			end
		end)

		it("has a render prop", function()
			local testApolloConsumerElement = React.createElement(ApolloConsumer, nil, function(clientRender)
				jestExpect(clientRender).toBe(client)
				return nil
			end)
			local testComponent = function()
				return React.createElement(ApolloProvider, { client = client }, testApolloConsumerElement)
			end
			stop = bootstrap(rootInstance, testComponent)
		end)

		it("renders the content in the children prop", function()
			local testComponent = function()
				return React.createElement(
					ApolloProvider,
					{ client = client },
					React.createElement(ApolloConsumer, nil, function()
						return React.createElement("TextLabel", { Text = "Test" })
					end)
				)
			end
			stop = bootstrap(rootInstance, testComponent)
			local descendants = rootInstance:GetDescendants()
			local count = #Array.filter(descendants, function(item)
				return item.Name == "TextLabel"
			end)
			jestExpect(count).toBe(1)
		end)

		it("errors if there is no client in the context", function()
			local ApolloContext = getApolloContext()
			jestExpect(function()
				local resetApolloContext = function()
					return React.createElement(
						ApolloContext.Provider,
						{ value = {} },
						React.createElement(ApolloConsumer, nil, function()
							return nil
						end)
					)
				end
				stop = bootstrap(rootInstance, resetApolloContext)
			end).toThrow(
				'Could not find "client" in the context of ApolloConsumer. '
					.. "Wrap the root component in an <ApolloProvider>."
			)
		end)
	end)
end
