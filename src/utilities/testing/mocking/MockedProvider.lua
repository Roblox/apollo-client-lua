-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/mocking/MockedProvider.tsx
local exports = {}
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean, Object = LuauPolyfill.Boolean, LuauPolyfill.Object
type Array<T> = LuauPolyfill.Array<T>
type Object = { [string]: any }

local React = require(rootWorkspace.React)
local coreModule = require(srcWorkspace.core)
local ApolloClient = coreModule.ApolloClient
type ApolloClient<TCacheShape> = coreModule.ApolloClient<TCacheShape>
type DefaultOptions = coreModule.DefaultOptions
-- ROBLOX TODO: needs implementation of InMemoryCache
-- local Cache = require(script.Parent.Parent.Parent.Parent.cache).InMemoryCache
local Cache = {
	new = function(obj)
		return obj
	end,
}
local ApolloProvider = require(srcWorkspace.react.context).ApolloProvider
local mockLinkModule = require(script.Parent.mockLink)
-- ROBLOX TODO: replace when implemented
--local MockLink = mockLinkModule.MockLink
local MockLink = {
	new = function(obj: Array<MockedResponse<any>>, addTypename: boolean)
		if addTypename == nil then
			addTypename = true
		end
		return Object.assign({}, { addTypename = addTypename })
	end,
}
type MockedResponse<TData> = mockLinkModule.MockedResponse<TData>
-- ROBLOX TODO: replace when implemented
-- type ApolloLink = require(script.Parent.Parent.Parent.Parent.link.core).ApolloLink
type ApolloLink = any
-- ROBLOX TODO: replace when implemented
-- type Resolvers = require(script.Parent.Parent.Parent.Parent.core).Resolvers
type Resolvers = any
-- ROBLOX TODO: replace when implemented
--type ApolloCache = require(script.Parent.Parent.Parent.Parent.cache).ApolloCache
type ApolloCache<TSerialized> = any

export type MockedProviderProps<TSerializedCache> = {
	mocks: Array<MockedResponse<any>>?,
	addTypename: boolean?,
	defaultOptions: DefaultOptions?,
	cache: ApolloCache<TSerializedCache>?,
	resolvers: Resolvers?,
	childProps: Object?,
	children: any?,
	link: ApolloLink?,
}

export type MockedProviderState = { client: ApolloClient<any> }

local MockedProvider = setmetatable({}, { __index = React.Component })
MockedProvider.__index = MockedProvider
MockedProvider.defaultProps = { addTypename = true }

export type MockedProvider = { render: () -> any, componentWillUnmount: () -> () }

function MockedProvider.new(props: MockedProviderProps<any>)
	local self = React.Component.new(props)
	local mocks, addTypename, defaultOptions, cache, resolvers, link =
		self.props.mocks,
		self.props.addTypename,
		self.props.defaultOptions,
		self.props.cache,
		self.props.resolvers,
		self.props.link
	local client = ApolloClient.new({
		cache = Boolean.toJSBoolean(cache) and cache or Cache.new({ addTypename = addTypename }),
		defaultOptions = defaultOptions,
		link = Boolean.toJSBoolean(link) and link or MockLink.new(
			Boolean.toJSBoolean(mocks) and mocks or {},
			addTypename
		),
		resolvers = resolvers,
	})
	self.state = { client = client }
	return self
end

function MockedProvider:render()
	local children, childProps = self.props.children, self.props.childProps
	return (function()
		if React.isValidElement(children) then
			return React.createElement(ApolloProvider, {
				client = self.state.client,
			}, React.cloneElement(
				React.Children.only(children),
				Object.assign({}, childProps)
			))
		else
			return nil
		end
	end)()
end

function MockedProvider:componentWillUnmount()
	--[[
      // Since this.state.client was created in the constructor, it's this
      // MockedProvider's responsibility to terminate it.
    ]]
	self.state.client:stop()
end

exports.MockedProvider = MockedProvider
return exports
