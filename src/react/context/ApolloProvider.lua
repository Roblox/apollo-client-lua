-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/context/ApolloProvider.tsx

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local packagesWorkspace = rootWorkspace.Parent.Packages

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
type Array<T> = LuauPolyfill.Array<T>

local React = require(packagesWorkspace.React)
local getApolloContext = require(script.Parent.ApolloContext).getApolloContext
local invariant = require(srcWorkspace.jsutils.invariant).invariant

local apolloClientModule = require(srcWorkspace.core.ApolloClient)
type ApolloClient<TCacheShape> = apolloClientModule.ApolloClient<TCacheShape>

local SharedModule = require(rootWorkspace.Shared)
type ReactNode = SharedModule.ReactNodeList

export type ApolloProviderProps<TCacheShape> = {
	client: ApolloClient<TCacheShape>,
	children: ReactNode | Array<ReactNode> | nil,
}

function ApolloProvider(props: ApolloProviderProps<{ [string]: any }>)
	local ApolloContext = getApolloContext()
	return React.createElement(ApolloContext.Consumer, nil, function(context: any)
		if context == nil then
			context = {}
		end
		if props.client and context.client ~= props.client then
			context.client = props.client
		end
		invariant(
			context.client,
			"ApolloProvider was not passed a client instance. Make "
				.. 'sure you pass in your client via the "client" prop.'
		)
		return React.createElement(ApolloContext.Provider, { value = context }, props.children)
	end)
end

return {
	ApolloProvider = ApolloProvider,
}
