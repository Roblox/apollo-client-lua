-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/core/types/common.ts
local exports = {}

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Error = LuauPolyfill.Error
type Array<T> = LuauPolyfill.Array<T>

-- ROBLOX deviation: defining Record type from TypeScript
type Record<T, U> = { [T]: U }

local GraphQL = require(rootWorkspace.GraphQL)
type FieldNode = GraphQL.FieldNode
type DocumentNode = GraphQL.DocumentNode

local utilitiesModule = require(srcWorkspace.utilities)
type Reference = utilitiesModule.Reference
type StoreObject = utilitiesModule.StoreObject
type StoreValue = utilitiesModule.StoreValue
local isReference = utilitiesModule.isReference

-- ROBLOX TODO: uncomment when this portion is converted
-- local StorageType = require(script.Parent.Parent.Parent.inmemory.policies).StorageType
type StorageType = any

--[[
 * The Readonly<T> type only really works for object types, since it marks
 * all of the object's properties as readonly, but there are many cases when
 * a generic type parameter like TExisting might be a string or some other
 * primitive type, in which case we need to avoid wrapping it with Readonly.
 * SafeReadonly<string> collapses to just string, which makes string
 * assignable to SafeReadonly<any>, whereas string is not assignable to
 * Readonly<any>, somewhat surprisingly.
]]
export type SafeReadonly<T> = any

export type MissingFieldError = {
	message: string,
	path: Array<string | number>,
	query: DocumentNode,
	variables: Record<string, any>?,
}

local MissingFieldError = setmetatable({}, { __index = Error })
MissingFieldError.__index = MissingFieldError

function MissingFieldError.new(
	message: string,
	path: Array<string | number>,
	query: DocumentNode,
	variables: Record<string, any>?
): MissingFieldError
	local self = Error.new(message)
	self.message = message
	self.path = path
	self.query = query
	self.variables = variables

	-- We're not using `Object.setPrototypeOf` here as it isn't fully
	-- supported on Android (see issue #3236).
	-- ROBLOX deviation: luau is not a prototype based language
	-- (this as any).__proto__ = MissingFieldError.prototype;
	return (setmetatable(self, MissingFieldError) :: any) :: MissingFieldError
end
exports.MissingFieldError = MissingFieldError

export type FieldSpecifier = {
	typename: string?,
	fieldName: string,
	field: FieldNode?,
	args: Record<string, any>?,
	variables: Record<string, any>?,
}

export type ReadFieldOptions = FieldSpecifier & { from: (StoreObject | Reference)? }

-- ROBLOX deviation: luau doesnt support function generics yet. defining type to preserve information
type V = StoreValue
-- ROBLOX deviation: luau doesnt support function type overloading
export type ReadFieldFunction =
	((options: ReadFieldOptions) -> SafeReadonly<V>?)
	| ((fieldName: string, from: (StoreObject | Reference)?) -> SafeReadonly<V>?)

export type ToReferenceFunction = (
	objOrIdOrRef: StoreObject | string | Reference,
	mergeIntoStore: boolean?
) -> Reference?

export type CanReadFunction = (value: StoreValue) -> boolean

type ModifierDetails = {
	DELETE: any,
	INVALIDATE: any,
	fieldName: string,
	storeFieldName: string,
	readField: ReadFieldFunction,
	canRead: CanReadFunction,
	isReference: typeof(isReference),
	toReference: ToReferenceFunction,
	storage: StorageType,
}

export type Modifier<T> = (value: T, details: ModifierDetails) -> T

export type Modifiers = { [string]: Modifier<any> }

return exports
