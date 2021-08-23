-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.6/src/react/context/ApolloContext.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)

local React = require(rootWorkspace.React)
local WeakMap = LuauPolyfill.WeakMap
local cache = WeakMap.new()

-- To make sure Apollo Client doesn't create more than one React context
-- (which can lead to problems like having an Apollo Client instance added
-- in one context, then attempting to retrieve it from another different
-- context), a single Apollo context is created and tracked in global state.
-- We use React.createContext as the key instead of just React to avoid
-- ambiguities between default and namespace React imports.
local function getApolloContext()
	local context = cache:get(React.createContext)
	if context == nil then
		context = React.createContext({})
		context.displayName = "ApolloContext"
		cache:set(React.createContext, context)
	end
	return context
end

return {
	getApolloContext = getApolloContext,
	resetApolloContext = function()
		cache = WeakMap.new()
	end,
}
