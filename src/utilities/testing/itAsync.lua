-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/itAsync.ts
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Promise = require(rootWorkspace.Promise)

-- ROBLOX deviation: wrapping in function to pass "it" as argument
return function(it)
	local function wrap(key: string?)
		return function(message: string, callback: any, timeout: number?)
			local fn: any
			if Boolean.toJSBoolean(key) then
				fn = it[key]
			else
				fn = it
			end
			return fn(message, function()
				return Promise.new(function(resolve, reject)
					return callback(resolve, reject)
				end):expect()
			end, timeout)
		end
	end

	local wrappedIt = wrap()

	return function(...)
		return wrappedIt(...)
	end
end
