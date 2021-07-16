-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.6/src/react/context/ApolloConsumer.tsx

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local packagesWorkspace = rootWorkspace.Parent.Packages

local React = require(packagesWorkspace.Roact)
local getApolloContext = require(script.Parent.ApolloContext).getApolloContext
local invariant = require(srcWorkspace.jsutils.invariant).invariant

export type ApolloConsumerProps = { children: (ApolloClient<object>) -> React.ReactChild | null }

function ApolloConsumer(props: ApolloConsumerProps)
	local ApolloContext = getApolloContext()
	return React.createElement(ApolloContext.Consumer, nil, function(context)
		invariant(
			(context and context.client),
			'Could not find "client" in the context of ApolloConsumer. '
				.. "Wrap the root component in an <ApolloProvider>."
		)
		return props.children(context.client)
	end)
end

return ApolloConsumer
