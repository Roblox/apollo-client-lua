-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.6/src/react/context/__tests__/ApolloProvider.test.tsx
--!nocheck

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent
	local packagesWorkspace = rootWorkspace.Parent.Parent.Packages

	local JestRoblox = require(packagesWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local bootstrap = require(rootWorkspace.utilities.common.bootstrap)

	local LuauPolyfill = require(packagesWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array

	local React = require(packagesWorkspace.React)
	local useContext = React.useContext

	local ApolloClient = require(rootWorkspace.core).ApolloClient

	local ApolloContextModule = require(script.Parent.Parent)
	local ApolloProvider = ApolloContextModule.ApolloProvider
	local getApolloContext = ApolloContextModule.ApolloContext.getApolloContext

	describe("<ApolloProvider /> Component", function()
		local client = ApolloClient.new({ cache = nil })
		local rootInstance
		local stop: (() -> ())?
		local TestTextLabelElement = React.createElement("TextLabel", { Text = "Test" })

		beforeEach(function()
			rootInstance = Instance.new("Folder")
			rootInstance.Name = "GuiRoot"
		end)

		afterEach(function()
			if typeof(stop) == "function" then
				stop()
			end
		end)

		it("should render children components", function()
			local testApolloProvider = function()
				return React.createElement(ApolloProvider, { client = client }, TestTextLabelElement)
			end
			stop = bootstrap(rootInstance, testApolloProvider)
			local descendants = rootInstance:GetDescendants()
			local count = #Array.filter(descendants, function(item)
				return item.Name == "TextLabel"
			end, nil)
			jestExpect(count).toBe(1)
		end)

		it("should support the 2.0", function()
			local testApolloProvider = function()
				return React.createElement(ApolloProvider, { client = {} }, TestTextLabelElement)
			end
			stop = bootstrap(rootInstance, testApolloProvider)
			local descendants = rootInstance:GetDescendants()
			local count = #Array.filter(descendants, function(item)
				return item.Name == "TextLabel"
			end, nil)
			jestExpect(count).toBe(1)
		end)

		it("should require a client", function()
			local ApolloContext = getApolloContext()
			jestExpect(function()
				local resetApolloContext = function()
					return React.createElement(ApolloContext.Provider, { value = {} }, {
						React.createElement(ApolloProvider, { client = nil }, TestTextLabelElement),
					})
				end
				stop = bootstrap(rootInstance, resetApolloContext)
			end).toThrow(
				"ApolloProvider was not passed a client instance. Make "
					.. 'sure you pass in your client via the "client" prop.'
			)
		end)

		it("should not require a store", function()
			local testApolloProvider = function()
				return React.createElement(ApolloProvider, { client = client }, TestTextLabelElement)
			end
			stop = bootstrap(rootInstance, testApolloProvider)
			local descendants = rootInstance:GetDescendants()
			local count = #Array.filter(descendants, function(item)
				return item.Name == "TextLabel"
			end, nil)
			jestExpect(count).toBe(1)
		end)

		it("should add the client to the children context", function()
			local TestChild = function()
				local context = useContext(getApolloContext(), nil, nil)
				jestExpect(context.client).toBe(client)
				return nil
			end
			local testApolloProvider = function()
				return React.createElement(ApolloProvider, { client = client }, React.createElement(TestChild))
			end
			stop = bootstrap(rootInstance, testApolloProvider)
		end)

		it("should update props when the client changes", function()
			local clientToCheck = client
			local TestChild = function()
				local context = useContext(getApolloContext(), nil, nil)
				jestExpect(context.client).toBe(clientToCheck)
				return nil
			end
			local testApolloProvider = function()
				return React.createElement(ApolloProvider, { client = clientToCheck }, React.createElement(TestChild))
			end
			stop = bootstrap(rootInstance, testApolloProvider)
			clientToCheck = ApolloClient.new({ cache = nil })
			local stopRerender = bootstrap(rootInstance, testApolloProvider)
			stopRerender()
		end)
	end)
end
