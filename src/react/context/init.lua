-- upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.6/src/react/context/index.ts

--[[ ROBLOX TODO: Unhandled node for type: ExportAllDeclaration ]]
--[[ export * from './ApolloConsumer'; ]]

local ApolloContext = require(script.ApolloContext)
local ApolloConsumer = require(script.ApolloConsumer)
local ApolloProvider = require(script.ApolloProvider)

return {
	ApolloContext = ApolloContext,
	ApolloConsumer = ApolloConsumer,
	ApolloProvider = ApolloProvider,
}
