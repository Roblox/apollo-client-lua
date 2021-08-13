-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/context/index.ts

local rootWorkspace = script.Parent.Parent.Parent
local Object = require(rootWorkspace.LuauPolyfill).Object

local exports = Object.assign(
	{},
	require(script.ApolloContext),
	require(script.ApolloConsumer),
	require(script.ApolloProvider)
)

return exports
