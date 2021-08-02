-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/common/maybe.ts
local exports = {}
local function maybe(thunk: () -> T): (T | nil)
	do --[[ ROBLOX COMMENT: try-catch block conversion ]]
		local _ok, result, hasReturned = xpcall(function()
			return thunk(), true
		end, function() end)
		if hasReturned then
			return result
		end
	end
end
exports.maybe = maybe
return exports
