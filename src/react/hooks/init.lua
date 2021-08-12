-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/hooks/index.ts

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object
local exports: { [string]: any } = {}

Object.assign(exports, require(script.useApolloClient))

-- ROBLOX TODO: uncomment these exports as we implement them
-- Object.assign(exports, require(script.useLazyQuery))
-- Object.assign(exports, require(script.useMutation))
-- Object.assign(exports, require(script.useQuery))
-- Object.assign(exports, require(script.useSubscription))
-- Object.assign(exports, require(script.useReactiveVar))

return exports
