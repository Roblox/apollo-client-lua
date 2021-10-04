-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/common/maybeDeepFreeze.ts
local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object
local Set = LuauPolyfill.Set
local Boolean = LuauPolyfill.Boolean
local Array = LuauPolyfill.Array
-- Roblox TODO: Replace undefined generics
type T_ = any

require(script.Parent.Parent.globals) -- For __DEV__

local isNonNullObject = require(script.Parent.objects).isNonNullObject

-- ROBLOX deviation: no real way to check for this currently.
-- This is executed only if _DEV_ is true and it will do nothing
local function isFrozen(obj): boolean
	return true
end

local function deepFreeze(value: any)
	local workSet = Set.new({ value })
	for _, obj in workSet:ipairs() do
		if isNonNullObject(obj) then
			if not isFrozen(obj) then
				Object.freeze(obj)
			end
			Array.forEach(Object.keys(obj), function(name)
				if isNonNullObject(obj[name]) then
					workSet:add(obj[name])
				end
			end)
		end
	end
	return value
end

local function maybeDeepFreeze(obj: T_): T_
	if Boolean.toJSBoolean(_G.__DEV__) then
		deepFreeze(obj)
	end
	return obj
end

exports.maybeDeepFreeze = maybeDeepFreeze

return exports
