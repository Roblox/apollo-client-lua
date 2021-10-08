-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/common/cloneDeep.ts

local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Map = LuauPolyfill.Map
local Object = LuauPolyfill.Object
type Array<T> = LuauPolyfill.Array<T>
type Map<T, V> = LuauPolyfill.Map<T, V>

-- ROBLOX deviation: type T_ is placeholder for cloneDeep's and cloneDeepHelper's generic variable T
type T_ = any

-- ROBLOX deviation: not using javascript toString logic for main logic
-- const { toString } = Object.prototype;

-- ROBLOX deviation: predeclaring cloneDeepHelper for use by cloneDeep
local cloneDeepHelper

--[[*
 * Deeply clones a value to create a new instance.
]]
local function cloneDeep(value: T_): T_
	return cloneDeepHelper(value)
end
exports.cloneDeep = cloneDeep

function cloneDeepHelper(val: T_, seen: Map<any, any>?): T_
	if Array.isArray(val) then
		seen = seen or Map.new(nil)
		if (seen :: Map<any, any>):has(val) then
			return (seen :: Map<any, any>):get(val)
		end
		local copy: Array<any> = Array.slice(val, 1);
		(seen :: Map<any, any>):set(val, copy)
		Array.forEach(copy, function(child, i)
			copy[i] = cloneDeepHelper(child, seen)
		end)
		return copy
	elseif typeof(val) == "table" then
		seen = seen or Map.new(nil)
		if (seen :: Map<any, any>):has(val) then
			return (seen :: Map<any, any>):get(val)
		end
		-- High fidelity polyfills of Object.create and Object.getPrototypeOf are
		-- possible in all JS environments, so we will assume they exist/work.
		local copy = Object.assign({}, val);
		(seen :: Map<any, any>):set(val, copy)
		Array.forEach(Object.keys(val), function(key)
			copy[key] = cloneDeepHelper(val[key], seen)
		end)
		return copy
	else
		return val
	end
end
return exports
