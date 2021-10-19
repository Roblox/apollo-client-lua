-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/policies.ts
-- ROBLOX deviation: extracted types to avoid circular dependencies

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
type Array<T> = LuauPolyfill.Array<T>
type Object = LuauPolyfill.Object
type Set<T> = LuauPolyfill.Set<T>
type Map<K, V> = LuauPolyfill.Map<K, V>
type Function = (...any) -> ...any
type Record<T, U> = { [T]: U }
type ReturnType<T> = any
type Exclude<T, V> = any
type Readonly<T> = any

local graphqlModule = require(rootWorkspace.GraphQL)
type InlineFragmentNode = graphqlModule.InlineFragmentNode
type FragmentDefinitionNode = graphqlModule.FragmentDefinitionNode
type SelectionSetNode = graphqlModule.SelectionSetNode
type FieldNode = graphqlModule.FieldNode

local utilitiesModule = require(script.Parent.Parent.Parent.utilities)
-- ROBLOX TODO: fragments not currently implemented, so stub type
type FragmentMap = Object -- utilitiesModule.FragmentMap
type StoreValue = utilitiesModule.StoreValue
type StoreObject = utilitiesModule.StoreObject
type Reference = utilitiesModule.Reference
-- ROBLOX TODO: circular dependency
-- local typesModule = require(script.Parent.types)
type IdGetter = (any) -> string | nil -- typesModule.IdGetter
type MergeInfo = { field: FieldNode, typename: string | nil, merge: Function } -- typesModule.MergeInfo
type NormalizedCache = { [string]: any } -- typesModule.NormalizedCache
type ReadMergeModifyContext = { [string]: any } -- typesModule.ReadMergeModifyContext
-- local inMemoryCacheModule = require(script.Parent.inMemoryCache)
-- local InMemoryCache = inMemoryCacheModule.InMemoryCache
type InMemoryCache = any -- inMemoryCacheModule.InMemoryCache
-- ROBLOX TODO: use real dependency when implemented
-- local commonModule = require(script.Parent.Parent.core.types.common)
-- ROBLOX TODO: use real dependency when implemented
type SafeReadonly<T> = any -- commonModule.SafeReadonly
-- ROBLOX TODO: use real dependency when implemented
type FieldSpecifier = any -- commonModule.FieldSpecifier
-- ROBLOX TODO: use real dependency when implemented
type ToReferenceFunction = any -- commonModule.ToReferenceFunction
-- ROBLOX TODO: use real dependency when implemented
type ReadFieldFunction = any -- commonModule.ReadFieldFunction
-- ROBLOX TODO: use real dependency when implemented
type ReadFieldOptions = any -- commonModule.ReadFieldOptions
-- ROBLOX TODO: use real dependency when implemented
type CanReadFunction = any -- commonModule.CanReadFunction
-- ROBLOX TODO: use real dependency when implemented
-- local writeToStoreModule = require(script.Parent.writeToStore)
-- ROBLOX TODO: use real dependency when implemented
type WriteContext = any -- writeToStoreModule.WriteContext

-- Upgrade to a faster version of the default stable JSON.stringify function
-- used by getStoreKeyName. This function is used when computing storeFieldName
-- strings (when no keyArgs has been configured for a field).
-- ROBLOX TODO: use real dependency when implemented
-- local canonicalStringify = require(script.Parent["object-canon"]).canonicalStringify
-- getStoreKeyName:setStringify(canonicalStringify)

export type TypePolicies = {
	[string]: TypePolicy, -- [__typename: string]
}

-- TypeScript 3.7 will allow recursive type aliases, so this should work:
-- type KeySpecifier = (string | KeySpecifier)[]
export type KeySpecifier = Array<string | Array<any>>
export type KeyFieldsContext = {
	typename: string?,
	selectionSet: SelectionSetNode?,
	fragmentMap: FragmentMap?,
	-- May be set by the KeyFieldsFunction to report fields that were involved
	-- in computing the ID. Never passed in by the caller.
	keyObject: Record<string, any>?,
}
export type KeyFieldsFunction = (
	object: Readonly<StoreObject>,
	context: KeyFieldsContext
) -> KeySpecifier | boolean | ReturnType<IdGetter> -- ROBLOX deviation: KeySpecifier | false | ReturnType<IdGetter>

export type KeyFieldsResult = Exclude<ReturnType<KeyFieldsFunction>, KeySpecifier>

-- TODO Should TypePolicy be a generic type, with a TObject or TEntity
-- type parameter?
export type TypePolicy = {
	-- Allows defining the primary key fields for this type, either using an
	-- array of field names or a function that returns an arbitrary string.
	keyFields: (KeySpecifier | KeyFieldsFunction | boolean)?, -- ROBLOX deviation: KeySpecifier | KeyFieldsFunction | false

	-- Allows defining a merge function (or merge:true/false shorthand) to
	-- be used for merging objects of this type wherever they appear, unless
	-- the parent field also defines a merge function/boolean (that is,
	-- parent field merge functions take precedence over type policy merge
	-- functions). In many cases, defining merge:true for a given type
	-- policy can save you from specifying merge:true for all the field
	-- policies where that type might be encountered.
	merge: (FieldMergeFunction<any, any> | boolean)?,

	-- In the rare event that your schema happens to use a different
	-- __typename for the root Query, Mutation, and/or Schema types, you can
	-- express your deviant preferences by enabling one of these options.
	queryType: boolean?, -- ROBLOX deviation: true
	mutationType: boolean?, -- ROBLOX deviation: true
	subscriptionType: boolean?, -- ROBLOX deviation: true

	fields: ({ [string]: FieldPolicy<any, any, any> | FieldReadFunction<any, any> })?,
}

export type KeyArgsFunction = (
	args: Record<string, any> | nil,
	context: { typename: string, fieldName: string, field: FieldNode | nil, variables: Record<string, any>? }
) -> KeySpecifier | boolean | ReturnType<IdGetter> -- ROBLOX deviation: KeySpecifier | false | ReturnType<IdGetter>

export type KeyArgsResult = Exclude<ReturnType<KeyArgsFunction>, KeySpecifier>

-- The internal representation used to store the field's data in the
-- cache. Must be JSON-serializable if you plan to serialize the result
-- of cache.extract() using JSON.
-- ROBLOX deviation: TExisting = any
-- TExisting,
-- The type of the incoming parameter passed to the merge function,
-- typically matching the GraphQL response format, but with Reference
-- objects substituted for any identifiable child objects. Often the
-- same as TExisting, but not necessarily.
-- ROBLOX deviation: TIncoming = TExisting,
-- TIncoming,
-- The type that the read function actually returns, using TExisting
-- data and options.args as input. Usually the same as TIncoming.
-- ROBLOX deviation: TReadResult = TIncoming,
-- TReadResult
export type FieldPolicy<TExisting, TIncoming, TReadResult> = {
	keyArgs: (KeySpecifier | KeyArgsFunction | boolean)?, -- ROBLOX deviation: KeySpecifier | KeyArgsFunction | false
	read: FieldReadFunction<TExisting, TReadResult>?,
	merge: (FieldMergeFunction<TExisting, TIncoming> | boolean)?,
}

export type StorageType = Record<string, any>

export type FieldFunctionOptions<TArgs, TVars> = {
	args: TArgs | nil,

	-- The name of the field, equal to options.field.name.value when
	-- options.field is available. Useful if you reuse the same function for
	-- multiple fields, and you need to know which field you're currently
	-- processing. Always a string, even when options.field is null.
	fieldName: string,

	-- The full field key used internally, including serialized key arguments.
	storeFieldName: string,

	-- The FieldNode object used to read this field. Useful if you need to
	-- know about other attributes of the field, such as its directives. This
	-- option will be null when a string was passed to options.readField.
	field: FieldNode | nil,

	variables: TVars?,

	-- Utilities for dealing with { __ref } objects.
	isReference: (obj: any) -> boolean, -- typeof(isReference)
	toReference: ToReferenceFunction,

	-- A handy place to put field-specific data that you want to survive
	-- across multiple read function calls. Useful for field-level caching,
	-- if your read function does any expensive work.
	storage: StorageType,

	cache: InMemoryCache,

	-- Helper function for reading other fields within the current object.
	-- If a foreign object or reference is provided, the field will be read
	-- from that object instead of the current object, so this function can
	-- be used (together with isReference) to examine the cache outside the
	-- current object. If a FieldNode is passed instead of a string, and
	-- that FieldNode has arguments, the same options.variables will be used
	-- to compute the argument values. Note that this function will invoke
	-- custom read functions for other fields, if defined. Always returns
	-- immutable data (enforced with Object.freeze in development).
	readField: ReadFieldFunction,

	-- Returns true for non-normalized StoreObjects and non-dangling
	-- References, indicating that readField(name, objOrRef) has a chance of
	-- working. Useful for filtering out dangling references from lists.
	canRead: CanReadFunction,

	-- Instead of just merging objects with { ...existing, ...incoming }, this
	-- helper function can be used to merge objects in a way that respects any
	-- custom merge functions defined for their fields.
	mergeObjects: MergeObjectsFunction,
}

export type MergeObjectsFunction = any --[[ ROBLOX TODO: Unhandled node for type: TSFunctionType ]]
--[[ <T extends StoreObject | Reference>(existing: T, incoming: T) => T ]]
export type FieldReadFunction<T, V> = any --[[ ROBLOX TODO: Unhandled node for type: TSFunctionType ]]
--[[ ( // When reading a field, one often needs to know about any existing
// value stored for that field. If the field is read before any value
// has been written to the cache, this existing parameter will be
// undefined, which makes it easy to use a default parameter expression
// to supply the initial value. This parameter is positional (rather
// than one of the named options) because that makes it possible for the
// developer to annotate it with a type, without also having to provide
// a whole new type for the options object.
existing: SafeReadonly<TExisting> | undefined, options: FieldFunctionOptions) => TReadResult | undefined ]]
export type FieldMergeFunction<T, V> = any --[[ ROBLOX TODO: Unhandled node for type: TSFunctionType ]]
--[[ (existing: SafeReadonly<TExisting> | undefined, // The incoming parameter needs to be positional as well, for the same
// reasons discussed in FieldReadFunction above.
incoming: SafeReadonly<TIncoming>, options: FieldFunctionOptions) => SafeReadonly<TExisting> ]]

return {}