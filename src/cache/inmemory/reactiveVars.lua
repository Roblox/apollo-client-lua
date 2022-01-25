-- upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/reactiveVars.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local exports = {}
local optimismModule = require(srcWorkspace.optimism)
local dep = optimismModule.dep
type OptimisticDependencyFunction<TKey> = optimismModule.OptimisticDependencyFunction<TKey>
local Slot = require(srcWorkspace.wry.context).Slot
-- local inMemoryCacheModule = require(script.Parent.inMemoryCache)
-- type InMemoryCache = inMemoryCacheModule.InMemoryCache
-- ROBLOX TODO: use real implementation when available
type InMemoryCache = any
type InMemoryCache_broadcastWatches = typeof((({} :: any) :: InMemoryCache).broadcastWatches)
local coreCacheModule = require(script.Parent.Parent.core.cache)
type ApolloCache<T> = coreCacheModule.ApolloCache<T>

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Set = LuauPolyfill.Set
local WeakMap = LuauPolyfill.WeakMap

type Set<T> = LuauPolyfill.Set<T>
type WeakMap<K, V> = LuauPolyfill.WeakMap<K, V>

--[[
  ROBLOX deviation: no generic params for functions are supported.
  T_, is placeholder for generic T param
]]
type T_ = any

-- ROBLOX deviation: predefine function
local broadcast

export type ReactiveVar<T> = typeof(setmetatable(
	{},
	{ __call = (function() end :: any) :: ((self: any, newValue: T?) -> T) }
)) & {
	onNextChange: (self: ReactiveVar<T>, listener: ReactiveListener<T>) -> (() -> ()),
	attachCache: (self: ReactiveVar<T>, cache: ApolloCache<any>) -> any,
	forgetCache: (self: ReactiveVar<T>, cache: ApolloCache<any>) -> boolean,
}

export type ReactiveListener<T> = (value: T) -> any

-- Contextual Slot that acquires its value when custom read functions are
-- called in Policies#readField.
local cacheSlot = Slot.new()
exports.cacheSlot = cacheSlot

local cacheInfoMap: WeakMap<ApolloCache<any>, { vars: Set<ReactiveVar<any>>, dep: OptimisticDependencyFunction<ReactiveVar<any>> }> =
	WeakMap.new()

local function getCacheInfo(cache: ApolloCache<any>)
	local info = cacheInfoMap:get(cache)
	if not Boolean.toJSBoolean(info) then
		info = { vars = Set.new(), dep = dep() }
		cacheInfoMap:set(cache, info)
	end
	return info
end

local function forgetCache(cache: ApolloCache<any>)
	-- ROBLOX deviation: can't use Array.forEach on a Set in Lua
	for _, rv in getCacheInfo(cache).vars:ipairs() do
		rv:forgetCache(cache)
	end
end
exports.forgetCache = forgetCache

-- Calling forgetCache(cache) serves to silence broadcasts and allows the
-- cache to be garbage collected. However, the varsByCache WeakMap
-- preserves the set of reactive variables that were previously associated
-- with this cache, which makes it possible to "recall" the cache at a
-- later time, by reattaching it to those variables. If the cache has been
-- garbage collected in the meantime, because it is no longer reachable,
-- you won't be able to call recallCache(cache), and the cache will
-- automatically disappear from the varsByCache WeakMap.
local function recallCache(cache: ApolloCache<any>)
	-- ROBLOX deviation: can't use Array.forEach on a Set in Lua
	for _, rv in getCacheInfo(cache).vars:ipairs() do
		rv:attachCache(cache)
	end
end
exports.recallCache = recallCache

local function makeVar<T>(value: T): ReactiveVar<T>
	local caches: Set<ApolloCache<any>> = Set.new()
	local listeners: Set<ReactiveListener<T>> = Set.new()
	local rv: ReactiveVar<T>
	-- ROBLOX deviation: predefine function
	local attach

	rv = (
			setmetatable({}, {
				__call = function(_self: any, ...: T?): ...T?
					if select("#", ...) >= 1 then
						local arguments = { ... }
						local newValue = arguments[1] :: T
						if value ~= newValue then
							value = newValue
							-- ROBLOX deviation: can't use Array.forEach on a Set in Lua
							for _, cache in caches:ipairs() do
								-- Invalidate any fields with custom read functions that
								-- consumed this variable, so query results involving those
								-- fields will be recomputed the next time we read them.
								getCacheInfo(cache).dep:dirty(rv)
								-- Broadcast changes to any caches that have previously read
								-- from this variable.
								broadcast(cache)
							end
							-- Finally, notify any listeners added via rv.onNextChange.
							local oldListeners = Array.from(listeners)
							listeners:clear()
							Array.forEach(oldListeners, function(listener)
								listener(value)
							end)
						end
					else
						-- When reading from the variable, obtain the current cache from
						-- context via cacheSlot. This isn't entirely foolproof, but it's
						-- the same system that powers varDep.
						local cache = cacheSlot:getValue()
						if Boolean.toJSBoolean(cache) then
							attach(cache)
							getCacheInfo(cache).dep(rv)
						end
					end

					return value
				end,
			}) :: any
		) :: ReactiveVar<T>

	rv.onNextChange = function(_self, listener)
		listeners:add(listener)
		return function()
			listeners:delete(listener)
		end
	end

	-- ROBLOX deviation: change order to simplify self handling
	attach = function(cache: ApolloCache<any>)
		caches:add(cache)
		getCacheInfo(cache).vars:add(rv)
		return rv
	end
	rv.attachCache = function(_self: ReactiveVar<any>, cache: ApolloCache<any>)
		return attach(cache)
	end

	rv.forgetCache = function(_self: ReactiveVar<any>, cache: ApolloCache<any>)
		return caches:delete(cache)
	end

	return rv
end
exports.makeVar = makeVar

type Broadcastable = ApolloCache<any> & {
	-- This method is protected in InMemoryCache, which we are ignoring, but
	-- we still want some semblance of type safety when we call it.
	broadcastWatches: InMemoryCache_broadcastWatches?,
}

function broadcast(cache: Broadcastable)
	if Boolean.toJSBoolean(cache.broadcastWatches) then
		cache:broadcastWatches()
	end
end

return exports
