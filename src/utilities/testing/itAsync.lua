-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/testing/itAsync.ts
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Promise = require(rootWorkspace.Promise)

-- ROBLOX deviation: wrapping in function to pass "it" as argument
return function(it: any)
	local function wrap(key: string?)
		return function(message: string, callback: any, timeout: number?)
			local fn: any
			if Boolean.toJSBoolean(key) then
				fn = it[key]
			else
				fn = it
			end
			return fn(message, function()
				local promise = Promise.new(function(resolve, reject)
					callback(resolve, reject)
				end)
				if timeout ~= nil then
					return promise:timeout(timeout / 1000):expect()
				else
					return promise:timeout(3):expect()
				end
			end, timeout)
		end
	end

	local wrappedIt = wrap()

	return function(...)
		return wrappedIt(...)
	end
end
