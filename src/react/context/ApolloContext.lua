-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.6/src/react/context/ApolloContext.ts

local rootWorkspace = script.Parent.Parent.Parent
local packagesWorkspace = rootWorkspace.Parent.Parent.Packages

local React = require(packagesWorkspace.React)
local WeakMap = require(rootWorkspace.luaUtils.WeakMap)
local cache = WeakMap.new()

function getApolloContext()
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
	resetApolloContext = getApolloContext,
}
