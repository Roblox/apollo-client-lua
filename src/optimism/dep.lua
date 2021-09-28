-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/dep.ts

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Map = LuauPolyfill.Map
local Boolean = LuauPolyfill.Boolean
local Set = LuauPolyfill.Set
local Array = LuauPolyfill.Array

--[[
  ROBLOX deviation: no generic params for functions are supported.
  TKey_, is placeholder for generic TKey param
]]
type TKey_ = any

local exports = {}

local entryTypesModule = require(script.Parent.entryTypes)
type AnyEntry = entryTypesModule.AnyEntry
local initTypesModule = require(script.Parent.initTypes)
type OptimisticWrapOptions<TArgs, TKeyArgs, TCacheKey> = initTypesModule.OptimisticWrapOptions<TArgs, TKeyArgs, TCacheKey>
local parentEntrySlot = require(script.Parent.context).parentEntrySlot
local helpersModule = require(script.Parent.helpers)
local hasOwnProperty = helpersModule.hasOwnProperty
type Unsubscribable = helpersModule.Unsubscribable
local maybeUnsubscribe = helpersModule.maybeUnsubscribe
local toArray = helpersModule.toArray

--[[
	ROBLOX deviation:
	original type
	keyof typeof EntryMethods
]]
type EntryMethodName = string
local EntryMethods = {
	setDirty = true, -- Mark parent Entry as needing to be recomputed (default)
	dispose = true, -- Detach parent Entry from parents and children, but leave in LRU cache
	forget = true, -- Fully remove parent Entry from LRU cache and computation graph
}

--[[
	ROBLOX deviation
	original type
	((key: TKey) => void) & {
	  dirty: (key: TKey, entryMethodName?: EntryMethodName) => void;
	} 
]]
export type OptimisticDependencyFunction<TKey> = any

-- ROBLOX deviation: types are moved to separate file to avoid circular dependencies
local depTypesModule = require(script.Parent.depTypes)
export type Dep<TKey> = depTypesModule.Dep<TKey>
-- ROBLOX deviation: no TSIndexedAccessType equivalent in Lua
type Dep_Subscribe = any

local function dep(options: { subscribe: Dep_Subscribe }?)
	local depsByKey = Map.new(nil)
	local subscribe
	if Boolean.toJSBoolean(options) then
		subscribe = (options :: any).subscribe
	else
		subscribe = options
	end

	local depend = setmetatable({}, {
		__call = function(_self, key: TKey_)
			local parent = parentEntrySlot:getValue()
			if Boolean.toJSBoolean(parent) then
				local dep = depsByKey:get(key)
				if not Boolean.toJSBoolean(dep) then
					dep = Set.new() :: Dep<TKey_>
					depsByKey:set(key, dep)
				end
				parent:dependOn(dep)
				if typeof(subscribe) == "function" then
					maybeUnsubscribe(dep)
					dep.unsubscribe = subscribe(key)
				end
			end
		end,
	})

	depend.dirty = function(_self, key: TKey_, entryMethodName: EntryMethodName)
		local dep = depsByKey:get(key)
		if Boolean.toJSBoolean(dep) then
			local m: EntryMethodName = (function()
				if Boolean.toJSBoolean(entryMethodName) and hasOwnProperty(EntryMethods, entryMethodName) then
					return entryMethodName
				else
					return "setDirty"
				end
			end)()
			-- We have to use toArray(dep).forEach instead of dep.forEach, because
			-- modifying a Set while iterating over it can cause elements in the Set
			-- to be removed from the Set before they've been iterated over.
			Array.forEach(toArray(dep), function(entry)
				entry[m](entry)
			end)
			depsByKey:delete(key)
			maybeUnsubscribe(dep)
		end
	end
	return depend :: OptimisticDependencyFunction<TKey_>
end

exports.dep = dep

return exports
