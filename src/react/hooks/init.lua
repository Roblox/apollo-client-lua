-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/hooks/index.ts
local exports: { [string]: any } = {}
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

-- ROBLOX TODO: uncomment these exports as we implement them
Object.assign(
	exports,
	require(script.useApolloClient),
	require(script.useLazyQuery),
	require(script.useMutation),
	require(script.useQuery),
	-- require(script.useSubscription),
	require(script.useReactiveVar)
)

return exports
