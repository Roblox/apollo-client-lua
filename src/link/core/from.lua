-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/core/from.ts

local ApolloLink = require(script.Parent.ApolloLink).ApolloLink

return {
	from = ApolloLink.from,
}
