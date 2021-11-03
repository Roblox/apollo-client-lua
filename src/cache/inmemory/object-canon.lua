-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/object-canon.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Set = LuauPolyfill.Set
local WeakMap = LuauPolyfill.WeakMap
local Map = LuauPolyfill.Map

local Object = require(srcWorkspace.luaUtils.Object)

type Array<T> = LuauPolyfill.Array<T>
type Set<T> = LuauPolyfill.Set<T>
type WeakMap<K, V> = LuauPolyfill.WeakMap<K, V>
type Map<K, V> = LuauPolyfill.Map<K, V>
type Object = { [string]: any }
type Record<T, U> = { [T]: U }

local HttpService = game:GetService("HttpService")

--[[
  ROBLOX deviation: no generic params for functions are supported.
  T_, is placeholder for generic T param
]]
type T_ = any

local exports = {}
local trieModule = require(srcWorkspace.wry.trie)
local Trie = trieModule.Trie
type Trie<Data> = trieModule.Trie<Data>
local utilitiesModule = require(script.Parent.Parent.Parent.utilities)
local canUseWeakMap = utilitiesModule.canUseWeakMap
-- local canUseWeakSet = utilitiesModule.canUseWeakSet
local isObjectOrArray = utilitiesModule.isNonNullObject

-- ROBLOX deviation: predeclare variables
local stringifyCanon
local stringifyCache

local function shallowCopy(value: T_): T_
	if isObjectOrArray(value) then
		if Array.isArray(value) then
			return (Array.slice(value, 1) :: any) :: T_
		else
			-- ROBLOX TODO: handle proto?
			return Object.assign(
				{}, --[[{ __proto__ = Object.getPrototypeOf(value) },]]
				value
			)
		end
	end
	return value
end

-- When programmers talk about the "canonical form" of an object, they
-- usually have the following meaning in mind, which I've copied from
-- https://en.wiktionary.org/wiki/canonical_form:
--
-- 1. A standard or normal presentation of a mathematical entity [or
--    object]. A canonical form is an element of a set of representatives
--    of equivalence classes of forms such that there is a function or
--    procedure which projects every element of each equivalence class
--    onto that one element, the canonical form of that equivalence
--    class. The canonical form is expected to be simpler than the rest of
--    the forms in some way.
--
-- That's a long-winded way of saying any two objects that have the same
-- canonical form may be considered equivalent, even if they are !==,
-- which usually means the objects are structurally equivalent (deeply
-- equal), but don't necessarily use the same memory.
--
-- Like a literary or musical canon, this ObjectCanon class represents a
-- collection of unique canonical items (JavaScript objects), with the
-- important property that canon.admit(a) === canon.admit(b) if a and b
-- are deeply equal to each other. In terms of the definition above, the
-- canon.admit method is the "function or procedure which projects every"
-- object "onto that one element, the canonical form."
--
-- In the worst case, the canonicalization process may involve looking at
-- every property in the provided object tree, so it takes the same order
-- of time as deep equality checking. Fortunately, already-canonicalized
-- objects are returned immediately from canon.admit, so the presence of
-- canonical subtrees tends to speed up canonicalization.
--
-- Since consumers of canonical objects can check for deep equality in
-- constant time, canonicalizing cache results can massively improve the
-- performance of application code that skips re-rendering unchanged
-- results, such as "pure" UI components in a framework like React.
--
-- Of course, since canonical objects may be shared widely between
-- unrelated consumers, it's important to think of them as immutable, even
-- though they are not actually frozen with Object.freeze in production,
-- due to the extra performance overhead that comes with frozen objects.
--
-- Custom scalar objects whose internal class name is neither Array nor
-- Object can be included safely in the admitted tree, but they will not
-- be replaced with a canonical version (to put it another way, they are
-- assumed to be canonical already).
--
-- If we ignore custom objects, no detection of cycles or repeated object
-- references is currently required by the StoreReader class, since
-- GraphQL result objects are JSON-serializable trees (and thus contain
-- neither cycles nor repeated subtrees), so we can avoid the complexity
-- of keeping track of objects we've already seen during the recursion of
-- the admit method.
--
-- In the future, we may consider adding additional cases to the switch
-- statement to handle other common object types, such as "[object Date]"
-- objects, as needed.
export type ObjectCanon = {
	isKnown: (self: ObjectCanon, value: any) -> boolean,
	pass: (self: ObjectCanon, value: any) -> any,
	admit: (self: ObjectCanon, value: any) -> any,
	empty: any,
}

type ObjectCanonPrivate = ObjectCanon & {
	-- Set of all canonical objects this ObjectCanon has admitted, allowing
	-- canon.admit to return previously-canonicalized objects immediately.
	known: Set<Object>,
	-- Efficient storage/lookup structure for canonical objects.
	pool: Trie<{ array: Array<any>?, object: Record<string, any>?, keys: SortedKeysInfo? }>,
	-- Make the ObjectCanon assume this value has already been
	-- canonicalized.
	passes: WeakMap<Object, Object>,

	sortedKeys: (self: ObjectCanonPrivate, obj: Object) -> any,
	-- Arrays that contain the same elements in a different order can share
	-- the same SortedKeysInfo object, to save memory.
	keysByJSON: Map<string, SortedKeysInfo>,
}

local ObjectCanon = {}

ObjectCanon.__index = ObjectCanon

function ObjectCanon.new(): ObjectCanon
	local self = setmetatable({}, ObjectCanon)

	-- ROBLOX deviation: no WeakSet implementation available
	self.known = Set.new()
	self.pool = Trie.new(canUseWeakMap)
	self.passes = WeakMap.new()
	self.keysByJSON = Map.new(nil)
	-- This has to come last because it depends on keysByJSON.
	self.empty = self:admit({})

	return (self :: any) :: ObjectCanon
end

function ObjectCanon:isKnown(value: any): boolean
	return isObjectOrArray(value) and self.known:has(value)
end

function ObjectCanon:pass(value: any)
	if isObjectOrArray(value) then
		local copy = shallowCopy(value)
		self.passes:set(copy, value)
		return copy
	end

	return value
end

-- Returns the canonical version of value.
function ObjectCanon:admit(value: any?): any?
	if isObjectOrArray(value) and value ~= nil then
		local original = self.passes:get(value)
		if Boolean.toJSBoolean(original) then
			return original
		end

		-- ROBLOX deviation: Array and Object are not distinguishable as they are in JS
		if Object.getPrototypeOf(value) == nil then
			if Array.isArray(value) then
				if self.known:has(value) then
					return value
				end
				-- ROBLOX FIXME: Luau needs extra help to coerce self into an { [string]: any }, which seems like a bug
				local array: Array<any> = Array.map(value :: Array<any>, self.admit, (self :: any) :: Object)
				-- Arrays are looked up in the Trie using their recursively
				-- canonicalized elements, and the known version of the array is
				-- preserved as node.array.
				local node = self.pool:lookupArray(array)

				if not Boolean.toJSBoolean(node.array) then
					node.array = array
					self.known:add(node.array)
					-- Since canonical arrays may be shared widely between
					-- unrelated consumers, it's important to regard them as
					-- immutable, even if they are not frozen in production.
					if Boolean.toJSBoolean(_G.__DEV__) then
						Object.freeze(array)
					end
				end

				return node.array
			else
				if self.known:has(value) then
					return value
				end
				local proto = Object.getPrototypeOf(value)
				local array = { proto }
				local keys = self:sortedKeys(value)
				table.insert(array, keys.json)
				local firstValueIndex = #array
				Array.forEach(keys.sorted, function(key)
					table.insert(array, self:admit((value :: any)[key]))
				end)
				-- Objects are looked up in the Trie by their prototype (which
				-- is *not* recursively canonicalized), followed by a JSON
				-- representation of their (sorted) keys, followed by the
				-- sequence of recursively canonicalized values corresponding to
				-- those keys. To keep the final results unambiguous with other
				-- sequences (such as arrays that just happen to contain [proto,
				-- keys.json, value1, value2, ...]), the known version of the
				-- object is stored as node.object.
				local node = self.pool:lookupArray(array)
				if not Boolean.toJSBoolean(node.object) then
					node.object = Object.create(proto)
					local obj = node.object
					self.known:add(obj)
					Array.forEach(keys.sorted, function(key, i)
						obj[key] = array[firstValueIndex + i]
					end)
					-- Since canonical objects may be shared widely between
					-- unrelated consumers, it's important to regard them as
					-- immutable, even if they are not frozen in production.
					if _G.__DEV__ then
						Object.freeze(obj)
					end
				end

				return node.object
			end
		end
	end

	return value
end

-- It's worthwhile to cache the sorting of arrays of strings, since the
-- same initial unsorted arrays tend to be encountered many times.
-- Fortunately, we can reuse the Trie machinery to look up the sorted
-- arrays in linear time (which is faster than sorting large arrays).
function ObjectCanon:sortedKeys(obj: Object): { json: string, sorted: Array<string> }
	local keys: Array<string> = Object.keys(obj)
	local node = self.pool:lookupArray(keys)

	if not Boolean.toJSBoolean(node.keys) then
		Array.sort(keys)
		local json = HttpService:JSONEncode(keys)

		node.keys = self.keysByJSON:get(json)
		if not Boolean.toJSBoolean(node.keys) then
			node.keys = {
				sorted = keys,
				json = json,
			}
			self.keysByJSON:set(json, node.keys)
		end
	end

	return node.keys
end

exports.ObjectCanon = ObjectCanon

type SortedKeysInfo = { sorted: Array<string>, json: string }

-- ROBLOX deviation: canonical will not be encoded the same in Lua, because keys order is not respected
function sortedEncode(toEncode: any)
	if not Array.isArray(toEncode) and typeof(toEncode) == "table" then
		local encodedKeyValues = Array.map(Array.sort(Object.keys(toEncode)), function(key)
			return HttpService:JSONEncode(key) .. ":" .. sortedEncode(toEncode[key])
		end)
		return "{" .. Array.join(encodedKeyValues, ",") .. "}"
	end
	return HttpService:JSONEncode(toEncode)
end

-- Since the keys of canonical objects are always created in lexicographically
-- sorted order, we can use the ObjectCanon to implement a fast and stable
-- version of JSON.stringify, which automatically sorts object keys.
local canonicalStringify = Object.assign(
	setmetatable({}, {
		__call = function(_self, value: any): string
			if isObjectOrArray(value) then
				local canonical = stringifyCanon:admit(value)
				local json = stringifyCache:get(canonical)
				if json == nil then
					stringifyCache:set(
						canonical,
						(function()
							json = sortedEncode(canonical)
							return json
						end)()
					)
				end
				return json
			end
			return HttpService:JSONEncode(value)
		end,
	}),
	{
		reset = function(self)
			stringifyCanon = ObjectCanon.new()
		end,
	}
)
exports.canonicalStringify = canonicalStringify

-- Can be reset by calling canonicalStringify.reset().
stringifyCanon = ObjectCanon.new()

--Needs no resetting, thanks to weakness.
stringifyCache = WeakMap.new()
return exports
