-- ROBLOX deviation: this doesn't have an upstream

local rootWorkspace = script.Parent.Parent.Parent.Parent
local React = require(rootWorkspace.Roact)
local ReactRoblox = require(rootWorkspace.ReactRoblox)

local function bootstrap(rootInstance, component, props)
	local root = ReactRoblox.createLegacyRoot(rootInstance)
	root:render(React.createElement(component, props))
	return function()
		root:unmount()
		rootInstance.Parent = nil
	end
end

return bootstrap
