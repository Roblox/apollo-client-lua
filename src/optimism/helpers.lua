-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/helpers.ts

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)

type Set<T> = LuauPolyfill.Set<T>
type Array<T> = LuauPolyfill.Array<T>

local exports = {}
exports.hasOwnProperty = require(srcWorkspace.luaUtils.hasOwnProperty)

local function toArray(collection: Set<any>): Array<any>
	local array: Array<any> = {}
	-- ROBLOX deviation: can't use Array.map on a Set in Lua
	for _, item in collection:ipairs() do
		table.insert(array, item)
	end
	return array
end

exports.toArray = toArray

export type Unsubscribable = { unsubscribe: (() -> any)? }

local function maybeUnsubscribe(entryOrDep: Unsubscribable)
	local unsubscribe = entryOrDep.unsubscribe
	if typeof(unsubscribe) == "function" then
		entryOrDep.unsubscribe = nil;
		(unsubscribe :: any)()
	end
end
exports.maybeUnsubscribe = maybeUnsubscribe

return exports
