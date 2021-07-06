-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.6/src/react/context/ApolloProvider.tsx

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local packagesWorkspace = rootWorkspace.Parent.Packages

local React = require(packagesWorkspace.Roact)
local getApolloContext = require(script.Parent.ApolloContext).getApolloContext
local invariant = require(srcWorkspace.jsutils.invariant).invariant

export type ApolloProviderProps<TCache> = {
	client: ApolloClient<TCache>,
	children: React.ReactNode | Array<React.ReactNode> | nil,
}

function ApolloProvider(props: ApolloProviderProps)
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

return ApolloProvider
