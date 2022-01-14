-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/common/mergeDeep.ts

local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object
local Set = LuauPolyfill.Set
local Boolean = LuauPolyfill.Boolean
local Array = LuauPolyfill.Array
type Array<T> = LuauPolyfill.Array<T>
type Set<T> = LuauPolyfill.Set<T>
type Record<T, U> = { [T]: U }
type Object = { [string]: any }

-- ROBLOX deviation: need None table to allow for nil values to be handled merge
local NONE = newproxy(true)
getmetatable(NONE :: any).__tostring = function()
	return "Value.None"
end

local isNonNullObject = require(script.Parent.objects).isNonNullObject
local hasOwnProperty = require(srcWorkspace.luaUtils.hasOwnProperty)

-- These mergeDeep and mergeDeepArray utilities merge any number of objects
-- together, sharing as much memory as possible with the source objects, while
-- remaining careful to avoid modifying any source objects.

-- Logically, the return type of mergeDeep should be the intersection of
-- all the argument types. The binary call signature is by far the most
-- common, but we support 0- through 5-ary as well. After that, the
-- resulting type is just the inferred array element type. Note to nerds:
-- there is a more clever way of doing this that converts the tuple type
-- first to a union type (easy enough: T[number]) and then converts the
-- union to an intersection type using distributive conditional type
-- inference, but that approach has several fatal flaws (boolean becomes
-- true & false, and the inferred type ends up as unknown in many cases),
-- in addition to being nearly impossible to explain/understand.
-- ROBLOX deviation: Luau doesn't support type type constraints, nor does it support the infer keyword
-- export type TupleToIntersection<T extends any[]> =
--   T extends [infer A] ? A :
--   T extends [infer A, infer B] ? A & B :
--   T extends [infer A, infer B, infer C] ? A & B & C :
--   T extends [infer A, infer B, infer C, infer D] ? A & B & C & D :
--   T extends [infer A, infer B, infer C, infer D, infer E] ? A & B & C & D & E :
--   T extends (infer U)[] ? U : any;
export type TupleToIntersection<T> = any

-- ROBLOX deviation: pre-declaring mergeDeepArray function variable
local mergeDeepArray

-- ROBLOX deviation: Luau doesn't support function generics.
type T_ = any
local function mergeDeep(...: T_): TupleToIntersection<T_>
	return mergeDeepArray({ ... })
end
exports.mergeDeep = mergeDeep

-- ROBLOX deviation: pre-declaring DeepMerger class
local DeepMerger = {}

-- In almost any situation where you could succeed in getting the
-- TypeScript compiler to infer a tuple type for the sources array, you
-- could just use mergeDeep instead of mergeDeepArray, so instead of
-- trying to convert T[] to an intersection type we just infer the array
-- element type, which works perfectly when the sources array has a
-- consistent element type.
function mergeDeepArray(sources: Array<T_>): T_
	local target = Boolean.toJSBoolean(sources[1]) and sources[1] or ({} :: T_)
	local count = #sources
	if count > 1 then
		local merger = DeepMerger.new()
		for i = 2, count do
			target = merger:merge(target, sources[i])
		end
	end
	return target
end
exports.mergeDeepArray = mergeDeepArray

-- ROBLOX deviation: declaring TContextArgs as function generic type
type TContextArgs = Array<any>
export type ReconcilerFunction = (
	self: DeepMerger,
	target: Record<string | number, any>,
	source: Record<string | number, any>,
	property: string | number,
	...TContextArgs
) -> any

-- ROBLOX deviation: need to pass in self as first arg to have access to `this`
local defaultReconciler: ReconcilerFunction = function(self, target, source, property)
	return self:merge(target[property], source[property])
end

type DeepMergerPrivate = { reconciler: ReconcilerFunction, pastCopies: Set<any> }

export type DeepMerger = DeepMergerPrivate & {
	merge: (self: DeepMerger, target: any, source: any, ...TContextArgs) -> any,
	isObject: typeof(isNonNullObject),
	shallowCopyForMerge: (self: DeepMerger, value: T_) -> T_,
}

DeepMerger.__index = DeepMerger

function DeepMerger.new(reconciler: ReconcilerFunction?)
	local self = setmetatable({}, DeepMerger)
	if reconciler == nil then
		reconciler = defaultReconciler
	end
	self.reconciler = reconciler

	self.isObject = isNonNullObject
	self.pastCopies = Set.new()

	return (self :: any) :: DeepMerger
end

function DeepMerger:merge(target: any, source: any, ...: TContextArgs): any
	local context = { ... }
	if isNonNullObject(source) and isNonNullObject(target) then
		Array.forEach(Object.keys(source), function(sourceKey)
			if hasOwnProperty(target, sourceKey) then
				local targetValue = target[sourceKey]
				if source[sourceKey] ~= targetValue then
					local result = self:reconciler(target, source, sourceKey, table.unpack(context))
					-- A well-implemented reconciler may return targetValue to indicate
					-- the merge changed nothing about the structure of the target.
					if result ~= targetValue then
						target = self:shallowCopyForMerge(target)
						target[sourceKey] = result
					end
				end
			else
				-- If there is no collision, the target can safely share memory with
				-- the source, and the recursion can terminate here.
				target = self:shallowCopyForMerge(target)
				target[sourceKey] = source[sourceKey]
			end
			-- ROBLOX deviation
			if target[sourceKey] == NONE then
				target[sourceKey] = nil
			end
		end)

		return target
	end

	-- If source (or target) is not an object, let source replace target.
	return source
end

-- ROBLOX deviation: create shallow copy function for lua tables
local function shallowCopy(table: Object): Object
	local table_type = type(table)
	local table_copy
	if table_type == "table" then
		table_copy = {}
		for key, value in pairs(table) do
			table_copy[key] = value
		end
	else
		table_copy = table
	end
	return table_copy
end

function DeepMerger:shallowCopyForMerge(value: T_): T_
	if isNonNullObject(value) and not self.pastCopies:has(value) then
		if Array.isArray(value) then
			value = Array.slice((value :: Array<any>), 1)
		else
			-- ROBLOX deviation: no spread operator, nor prototypes exists in lua
			-- value = {
			--   __proto__: Object.getPrototypeOf(value),
			--   ...value,
			-- };
			value = shallowCopy(value)
		end
		self.pastCopies:add(value)
	end
	return value
end

DeepMerger.None = NONE

exports.DeepMerger = DeepMerger

return exports
