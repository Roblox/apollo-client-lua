-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/stripSymbols.ts

local exports = {}
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object

--[[
  * In order to make assertions easier, this function strips `symbol`'s from
  * the incoming data.
  *
  * This can be handy when running tests against `apollo-client` for example,
  * since it adds `symbol`'s to the data in the store. Jest's `toEqual`
  * function now covers `symbol`'s (https://github.com/facebook/jest/pull/3437),
  * which means all test data used in a `toEqual` comparison would also have to
  * include `symbol`'s, to pass. By stripping `symbol`'s from the cache data
  * we can compare against more simplified test data.
]]

local function stripSymbols<T>(data: T): T
	--[[
		ROBLOX deviation: 
		HTTPService will throw an error when trying to encode "userdata"
		original code:
		return JSON.parse(JSON.stringify(data));
	]]
	local copy = Object.assign({}, data)

	Array.forEach(Object.keys(copy), function(key)
		if typeof(key) == "userdata" and string.sub(tostring(key), 1, 7) == "Symbol(" and key ~= tostring(key) then
			copy[key] = nil
		elseif typeof(copy[key]) == "table" and not Array.isArray(copy) then
			copy[key] = stripSymbols(copy[key])
		end
	end)

	return copy
end
exports.stripSymbols = stripSymbols
return exports
