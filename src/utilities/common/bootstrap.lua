-- ROBLOX deviation: this doesn't have an upstream

local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent
local PackagesWorkspace = rootWorkspace.Packages
local React = require(PackagesWorkspace.Roact)

local function bootstrap(rootInstance, component, props)
	local root = React.createLegacyRoot(rootInstance)
	root:render(React.createElement(component, props))
	return function()
		root:unmount()
		rootInstance.Parent = nil
	end
end

return bootstrap
