-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/http/createSignalIfSupported.ts

local exports = {}

local AbortController = _G.AbortController

local function createSignalIfSupported()
	if typeof(AbortController) == "nil" then
		return { controller = false, signal = false }
	end
	local controller = AbortController.new()
	local signal = controller.signal
	return { controller = controller, signal = signal }
end
exports.createSignalIfSupported = createSignalIfSupported

return exports
