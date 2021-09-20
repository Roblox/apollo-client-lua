-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/policies.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local HttpService = game:GetService("HttpService")

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object
local Set = LuauPolyfill.Set
local Map = LuauPolyfill.Map
type Array<T> = LuauPolyfill.Array<T>
type Set<T> = LuauPolyfill.Set<T>
type Map<K, V> = LuauPolyfill.Map<K, V>
export type Record<T, U> = { [T]: U }
export type ReturnType<T> = any
export type Exclude<T, V> = any
export type Readonly<T> = any

local RegExp = require(rootWorkspace.LuauRegExp)
type RegExp = RegExp.RegExp

local exports = {}

-- ROBLOX deviation: predefine functions
local makeFieldFunctionOptions
local makeMergeObjectsFunction
local keyArgsFnFromSpecifier
local keyFieldsFnFromSpecifier
local makeAliasMap
local computeKeyObject

local graphqlModule = require(rootWorkspace.GraphQL)
type InlineFragmentNode = graphqlModule.InlineFragmentNode
type FragmentDefinitionNode = graphqlModule.FragmentDefinitionNode
type SelectionSetNode = graphqlModule.SelectionSetNode
type FieldNode = graphqlModule.FieldNode

local Trie = require(srcWorkspace.wry.trie).Trie
local invariantModule = require(srcWorkspace.jsutils.invariant)
local invariant = invariantModule.invariant
local InvariantError = invariantModule.InvariantError

local utilitiesModule = require(script.Parent.Parent.Parent.utilities)
-- ROBLOX TODO: use real dependency when implemented
type FragmentMap = any -- utilitiesModule.FragmentMap
local getFragmentFromSelection = utilitiesModule.getFragmentFromSelection
local isField = utilitiesModule.isField
local getTypenameFromResult = utilitiesModule.getTypenameFromResult
local storeKeyNameFromField = utilitiesModule.storeKeyNameFromField
-- ROBLOX TODO: use real dependency when implemented
type StoreValue = any -- utilitiesModule.StoreValue
-- ROBLOX TODO: use real dependency when implemented
type StoreObject = any -- utilitiesModule.StoreObject
local argumentsObjectFromField = utilitiesModule.argumentsObjectFromField
-- ROBLOX TODO: use real dependency when implemented
type Reference = any -- utilitiesModule.Reference
local isReference = utilitiesModule.isReference
local getStoreKeyName = utilitiesModule.getStoreKeyName
local canUseWeakMap = utilitiesModule.canUseWeakMap
local isNonNullObject = utilitiesModule.isNonNullObject
-- ROBLOX TODO: use real dependency when implemented
-- local typesModule = require(script.Parent.types)
-- ROBLOX TODO: use real dependency when implemented
type IdGetter = any -- typesModule.IdGetter
-- ROBLOX TODO: use real dependency when implemented
type MergeInfo = any -- typesModule.MergeInfo
-- ROBLOX TODO: use real dependency when implemented
type NormalizedCache = any -- typesModule.NormalizedCache
-- ROBLOX TODO: use real dependency when implemented
type ReadMergeModifyContext = any -- typesModule.ReadMergeModifyContext
-- ROBLOX TODO: use real dependency when implemented
-- local helpersModule = require(script.Parent.helpers)
-- ROBLOX deviation: using luaUtils implementation instead of one from helpers
local hasOwn = require(srcWorkspace.luaUtils.hasOwnProperty)
-- local fieldNameFromStoreName = helpersModule.fieldNameFromStoreName
local fieldNameFromStoreName = function(...)
	return ""
end
-- local storeValueIsStoreObject = helpersModule.storeValueIsStoreObject
local storeValueIsStoreObject = function(...)
	return false
end
-- local selectionSetMatchesResult = helpersModule.selectionSetMatchesResult
local selectionSetMatchesResult = function(...)
	return nil
end
-- local TypeOrFieldNameRegExp = helpersModule.TypeOrFieldNameRegExp
local TypeOrFieldNameRegExp = RegExp("^[_a-z][_0-9a-z]*", "i")
-- ROBLOX TODO: use real dependency when implemented
-- local cacheSlot = require(script.Parent.reactiveVars).cacheSlot
local cacheSlot = { withValue = function(...) end }
-- ROBLOX TODO: use real dependency when implemented
-- local InMemoryCache = require(script.Parent.inMemoryCache).InMemoryCache
type InMemoryCache = any
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
type KeySpecifier = Array<string | Array<any>>
type KeyFieldsContext = {
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

type KeyFieldsResult = Exclude<ReturnType<KeyFieldsFunction>, KeySpecifier>

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

type KeyArgsResult = Exclude<ReturnType<KeyArgsFunction>, KeySpecifier>

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

local function argsFromFieldSpecifier(spec: FieldSpecifier)
	return (function()
		if spec.args ~= nil then
			return spec.args
		else
			return (function()
				if Boolean.toJSBoolean(spec.field) then
					return argumentsObjectFromField(spec.field, spec.variables)
				else
					return nil
				end
			end)()
		end
	end)()
end
type FieldFunctionOptions<TArgs, TVars> = any
--[[ ROBLOX TODO: Unhandled node for type: TSInterfaceDeclaration ]]
--[[ interface FieldFunctionOptions<TArgs = Record<string, any>, TVars = Record<string, any>> {
  args: TArgs | null; // The name of the field, equal to options.field.name.value when
  // options.field is available. Useful if you reuse the same function for
  // multiple fields, and you need to know which field you're currently
  // processing. Always a string, even when options.field is null.

  fieldName: string; // The full field key used internally, including serialized key arguments.

  storeFieldName: string; // The FieldNode object used to read this field. Useful if you need to
  // know about other attributes of the field, such as its directives. This
  // option will be null when a string was passed to options.readField.

  field: FieldNode | null;
  variables?: TVars; // Utilities for dealing with { __ref } objects.

  isReference: typeof isReference;
  toReference: ToReferenceFunction; // A handy place to put field-specific data that you want to survive
  // across multiple read function calls. Useful for field-level caching,
  // if your read function does any expensive work.

  storage: StorageType;
  cache: InMemoryCache; // Helper function for reading other fields within the current object.
  // If a foreign object or reference is provided, the field will be read
  // from that object instead of the current object, so this function can
  // be used (together with isReference) to examine the cache outside the
  // current object. If a FieldNode is passed instead of a string, and
  // that FieldNode has arguments, the same options.variables will be used
  // to compute the argument values. Note that this function will invoke
  // custom read functions for other fields, if defined. Always returns
  // immutable data (enforced with Object.freeze in development).

  readField: ReadFieldFunction; // Returns true for non-normalized StoreObjects and non-dangling
  // References, indicating that readField(name, objOrRef) has a chance of
  // working. Useful for filtering out dangling references from lists.

  canRead: CanReadFunction; // Instead of just merging objects with { ...existing, ...incoming }, this
  // helper function can be used to merge objects in a way that respects any
  // custom merge functions defined for their fields.

  mergeObjects: MergeObjectsFunction;
} ]]
type MergeObjectsFunction = any --[[ ROBLOX TODO: Unhandled node for type: TSFunctionType ]]
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
local function defaultDataIdFromObject(ref, context: KeyFieldsContext?): string | nil
	local __typename, id, _id = ref.__typename, ref.id, ref._id
	if typeof(__typename) == "string" then
		if Boolean.toJSBoolean(context) then
			if id ~= nil then
				(context :: any).keyObject = { id = id }
			elseif _id ~= nil then
				(context :: any).keyObject = { _id = _id }
			else
				(context :: any).keyObject = nil
			end
		end
		if id == nil then
			id = _id
		end
		if id ~= nil then
			return ("%s:%s"):format(
				__typename,
				(function()
					if
						Boolean.toJSBoolean(
							Boolean.toJSBoolean(typeof(id) == "number") and typeof(id) == "number"
								or typeof(id) == "string"
						)
					then
						return id
					else
						return HttpService:JSONEncode(id)
					end
				end)()
			)
		end
	end
	return nil
end
exports.defaultDataIdFromObject = defaultDataIdFromObject
local function nullKeyFieldsFn() -- : KeyFieldsFunction
	return nil
end
local function simpleKeyArgsFn(_args, context) -- : KeyArgsFunction
	return context.fieldName
end
local function mergeTrueFn(existing, incoming, ref) -- : FieldMergeFunction<any>
	local mergeObjects = ref.mergeObjects
	return mergeObjects(existing, incoming)
end
local function mergeFalseFn(_, incoming) -- : FieldMergeFunction<any>
	return incoming
end
export type PossibleTypesMap = { [string]: Array<string> }

export type Policies = {
	cache: InMemoryCache,
	rootIdsByTypename: Record<string, string>,
	rootTypenamesById: Record<string, string>,
	usingPossibleTypes: boolean,

	identify: (
		self: Policies,
		object: StoreObject,
		selectionSet: SelectionSetNode?,
		fragmentMap: FragmentMap?
	) -> any, -- ROBLOX TODO: original return type [string?, StoreObject?]
	addTypePolicies: (self: Policies, typePolicies: TypePolicies) -> (),
	addPossibleTypes: (self: Policies, possibleTypes: PossibleTypesMap) -> (),
	fragmentMatches: (
		self: Policies,
		fragment: InlineFragmentNode | FragmentDefinitionNode,
		typename: string | nil,
		result: Record<string, any>,
		variables: Record<string, any>
	) -> boolean,
	hasKeyArgs: (self: Policies, typename: string | nil, fieldName: string) -> boolean,
	getStoreFieldName: (self: Policies, fieldSpec: FieldSpecifier) -> string,
	readField--[[<V = StoreValue>]]: (
		self: Policies,
		options: ReadFieldOptions,
		context: ReadMergeModifyContext
	) -> SafeReadonly<V> | nil,
	getMergeFunction: (
		self: Policies,
		parentTypename: string | nil,
		fieldName: string,
		childTypename: string | nil
	) -> FieldMergeFunction<any, any> | nil,
	runMergeFunction: (
		self: Policies,
		existing: StoreValue,
		incoming: StoreValue,
		ref: MergeInfo,
		context: WriteContext,
		storage: StorageType
	) -> any,
}

export type PoliciesPrivate = Policies & {
	typePolicies: {
		[string]: { -- [__typename: string]
			keyFn: KeyFieldsFunction?,
			merge: FieldMergeFunction<any, any>?,
			fields: {
				[string]: { -- [fieldName: string]
					keyFn: KeyArgsFunction?,
					read: FieldReadFunction<any, any>?,
					merge: FieldMergeFunction<any, any>?,
				},
			},
		},
	},
	toBeAdded: {
		[string]: Array<TypePolicy>, -- [__typename: string]
	},

	-- Map from subtype names to sets of supertype names. Note that this
	-- representation inverts the structure of possibleTypes (whose keys are
	-- supertypes and whose values are arrays of subtypes) because it tends
	-- to be much more efficient to search upwards than downwards.
	supertypeMap: Map<string, Set<string>>,

	-- Any fuzzy subtypes specified by possibleTypes will be converted to
	-- RegExp objects and recorded here. Every key of this map can also be
	-- found in supertypeMap. In many cases this Map will be empty, which
	-- means no fuzzy subtype checking will happen in fragmentMatches.
	fuzzySubtypes: Map<string, RegExp>,

	config: {
		cache: InMemoryCache,
		dataIdFromObject: KeyFieldsFunction?,
		possibleTypes: PossibleTypesMap?,
		typePolicies: TypePolicies?,
	},

	updateTypePolicy: (self: PoliciesPrivate, typename: string, incoming: TypePolicy) -> (),
	setRootTypename: (
		self: PoliciesPrivate,
		which: string --[[ ROBLOX TODO: "Query" | "Mutation" | "Subscription" ]],
		typename: string?
	) -> (),
	getTypePolicy: (typename: string) -> any, --[[ ROBLOX TODO: Policies["typePolicies"][string] ]]
	getFieldPolicy: (
		self: PoliciesPrivate,
		typename: string | nil,
		fieldName: string,
		createIfMissing: boolean
	) -> { keyFn: KeyArgsFunction?, read: FieldReadFunction<any, any>?, merge: FieldMergeFunction<any, any>? } | nil,
	getSupertypeSet: (self: PoliciesPrivate, subtype: string, createIfMissing: boolean) -> Set<string> | nil,
}

local Policies = {}
Policies.__index = Policies

function Policies.new(
	config: {
	cache: InMemoryCache,
	dataIdFromObject: KeyFieldsFunction?,
	possibleTypes: PossibleTypesMap?,
	typePolicies: TypePolicies?,
}
): Policies
	local self = (setmetatable({}, Policies) :: any) :: PoliciesPrivate

	self.typePolicies = {}
	self.toBeAdded = {}
	self.supertypeMap = Map.new(nil)
	self.fuzzySubtypes = Map.new(nil)

	self.cache = nil
	self.rootIdsByTypename = {}
	self.rootTypenamesById = {}
	self.usingPossibleTypes = false

	self.config = config
	self.config = Object.assign({
		dataIdFromObject = defaultDataIdFromObject,
	}, config)
	self.cache = self.config.cache
	self:setRootTypename("Query")
	self:setRootTypename("Mutation")
	self:setRootTypename("Subscription")

	if Boolean.toJSBoolean(config.possibleTypes) then
		self:addPossibleTypes(config.possibleTypes :: any)
	end
	if Boolean.toJSBoolean(config.typePolicies) then
		self:addTypePolicies(config.typePolicies :: any)
	end

	return (self :: any) :: Policies
end

function Policies:identify(
	object: StoreObject,
	selectionSet: SelectionSetNode?,
	fragmentMap: FragmentMap?
): any -- ROBLOX TODO: original return type [string?, StoreObject?]
	-- TODO Use an AliasMap here?
	local typename
	if Boolean.toJSBoolean(selectionSet) and Boolean.toJSBoolean(fragmentMap) then
		typename = getTypenameFromResult(object, selectionSet, fragmentMap)
	else
		typename = object.__typename
	end

	-- It should be possible to write root Query fields with
	-- writeFragment, using { __typename: "Query", ... } as the data, but
	-- it does not make sense to allow the same identification behavior
	-- for the Mutation and Subscription types, since application code
	-- should never be writing directly to (or reading directly from)
	-- those root objects.
	if typename == self.rootTypenamesById.ROOT_QUERY then
		return { "ROOT_QUERY" }
	end

	local context: KeyFieldsContext = { typename = typename, selectionSet = selectionSet, fragmentMap = fragmentMap }

	local id: KeyFieldsResult

	local policy
	if Boolean.toJSBoolean(typename) then
		policy = self:getTypePolicy(typename)
	else
		policy = typename
	end
	local keyFn
	if Boolean.toJSBoolean(policy) and Boolean.toJSBoolean(policy.keyFn) then
		keyFn = policy.keyFn
	else
		keyFn = self.config.dataIdFromObject
	end
	while Boolean.toJSBoolean(keyFn) do
		local specifierOrId = keyFn(object, context)
		if Array.isArray(specifierOrId) then
			keyFn = keyFieldsFnFromSpecifier(specifierOrId)
		else
			id = specifierOrId
			break
		end
	end

	if Boolean.toJSBoolean(id) then
		id = tostring(id)
	else
		id = nil
	end
	return Boolean.toJSBoolean(context.keyObject) and { id, context.keyObject } or { id }
end

function Policies:addTypePolicies(typePolicies: TypePolicies): ()
	-- ROBLOX deviation: using Array.map instead of forEach
	Array.map(Object.keys(typePolicies), function(typename)
		local ref = typePolicies[typename]
		local queryType, mutationType, subscriptionType = ref.queryType, ref.mutationType, ref.subscriptionType
		local incoming = Object.assign({}, ref, {
			queryType = Object.None,
			mutationType = Object.None,
			subscriptionType = Object.None,
		})

		-- Though {query,mutation,subscription}Type configurations are rare,
		-- it's important to call setRootTypename as early as possible,
		-- since these configurations should apply consistently for the
		-- entire lifetime of the cache. Also, since only one __typename can
		-- qualify as one of these root types, these three properties cannot
		-- be inherited, unlike the rest of the incoming properties. That
		-- restriction is convenient, because the purpose of this.toBeAdded
		-- is to delay the processing of type/field policies until the first
		-- time they're used, allowing policies to be added in any order as
		-- long as all relevant policies (including policies for supertypes)
		-- have been added by the time a given policy is used for the first
		-- time. In other words, since inheritance doesn't matter for these
		-- properties, there's also no need to delay their processing using
		-- the this.toBeAdded queue.
		if Boolean.toJSBoolean(queryType) then
			self:setRootTypename("Query", typename)
		end
		if Boolean.toJSBoolean(mutationType) then
			self:setRootTypename("Mutation", typename)
		end
		if Boolean.toJSBoolean(subscriptionType) then
			self:setRootTypename("Subscription", typename)
		end

		if hasOwn(self.toBeAdded, typename) then
			table.insert(self.toBeAdded[typename], incoming)
		else
			self.toBeAdded[typename] = { incoming }
		end
	end)
end

function Policies:updateTypePolicy(typename: string, incoming: TypePolicy): ()
	local existing = self:getTypePolicy(typename)
	local keyFields, fields = incoming.keyFields, incoming.fields

	local function setMerge(
		existing: { merge: (FieldMergeFunction<any, any> | boolean)? },
		merge: (FieldMergeFunction<any, any> | boolean)?
	)
		if typeof(merge) == "function" then
			existing.merge = merge
		else
			-- Pass merge:true as a shorthand for a merge implementation
			-- that returns options.mergeObjects(existing, incoming).
			if merge == true then
				existing.merge = mergeTrueFn
			else
				-- Pass merge:false to make incoming always replace existing
				-- without any warnings about data clobbering.
				if merge == false then
					existing.merge = mergeFalseFn
				else
					existing.merge = existing.merge
				end
			end
		end
	end

	-- Type policies can define merge functions, as an alternative to
	-- using field policies to merge child objects.
	setMerge(existing, incoming.merge)

	-- Pass false to disable normalization for this typename.
	if keyFields == false then
		(existing :: any).keyFn = nullKeyFieldsFn
	else
		-- Pass an array of strings to use those fields to compute a
		-- composite ID for objects of this typename.
		if Boolean.toJSBoolean(Array.isArray(keyFields)) then
			(existing :: any).keyFn = keyFieldsFnFromSpecifier(keyFields :: any)
		else
			-- Pass a function to take full control over identification.
			if typeof(keyFields) == "function" then
				(existing :: any).keyFn = keyFields
			else
				-- Leave existing.keyFn unchanged if above cases fail.
				(existing :: any).keyFn = (existing :: any).keyFn
			end
		end
	end

	if Boolean.toJSBoolean(fields) then
		-- ROBLOX deviation: using Array.map instead of forEach
		Array.map(Object.keys(fields :: Record<string, any>), function(fieldName)
			local existing = self:getFieldPolicy(typename, fieldName, true)
			local incoming = (fields :: any)[fieldName]

			if typeof(incoming) == "function" then
				existing.read = incoming
			else
				local keyArgs, read, merge = incoming.keyArgs, incoming.read, incoming.merge

				-- Pass false to disable argument-based differentiation of
				-- field identities.
				if keyArgs == false then
					existing.keyFn = simpleKeyArgsFn
				else
					-- Pass an array of strings to use named arguments to
					-- compute a composite identity for the field.
					if Boolean.toJSBoolean(Array.isArray(keyArgs)) then
						existing.keyFn = keyArgsFnFromSpecifier(keyArgs) :: any
					else
						-- Pass a function to take full control over field identity.
						if typeof(keyArgs) == "function" then
							existing.keyFn = keyArgs
						else
							-- Leave existing.keyFn unchanged if above cases fail.
							existing.keyFn = existing.keyFn
						end
					end
				end

				if typeof(read) == "function" then
					existing.read = read
				end

				setMerge(existing :: any, merge)
			end

			if Boolean.toJSBoolean(existing.read) and Boolean.toJSBoolean(existing.merge) then
				-- If we have both a read and a merge function, assume
				-- keyArgs:false, because read and merge together can take
				-- responsibility for interpreting arguments in and out. This
				-- default assumption can always be overridden by specifying
				-- keyArgs explicitly in the FieldPolicy.
				existing.keyFn = Boolean.toJSBoolean(existing.keyFn) and existing.keyFn or simpleKeyArgsFn
			end
		end)
	end
end

function Policies:setRootTypename(
	which: string --[[ ROBLOX deviation: "Query" | "Mutation" | "Subscription" ]],
	typename_: string?
): ()
	local typename: string = typename_ :: any
	if typename == nil then
		typename = which
	end
	local rootId = "ROOT_" .. string.upper(which)
	local old = self.rootTypenamesById[rootId]
	if typename ~= old then
		invariant(
			not Boolean.toJSBoolean(old) or old == which,
			("Cannot change root %s __typename more than once"):format(which)
		)
		-- First, delete any old __typename associated with this rootId from
		-- rootIdsByTypename.
		if Boolean.toJSBoolean(old) then
			self.rootIdsByTypename[old] = nil
		end
		-- Now make this the only __typename that maps to this rootId.
		self.rootIdsByTypename[typename] = rootId
		-- Finally, update the __typename associated with this rootId.
		self.rootTypenamesById[rootId] = typename
	end
end

function Policies:addPossibleTypes(possibleTypes: PossibleTypesMap): ()
	self.usingPossibleTypes = true
	-- ROBLOX deviation: using Array.map instead of forEach
	Array.map(Object.keys(possibleTypes), function(supertype)
		-- Make sure all types have an entry in this.supertypeMap, even if
		-- their supertype set is empty, so we can return false immediately
		-- from policies.fragmentMatches for unknown supertypes.
		self:getSupertypeSet(supertype, true)

		-- ROBLOX deviation: using Array.map instead of forEach
		Array.map(possibleTypes[supertype], function(subtype)
			self:getSupertypeSet(subtype, true):add(supertype)
			-- ROBLOX deviation: string.match doesn't work with RegExps. Using RegExp:exec instead
			local match = TypeOrFieldNameRegExp:exec(subtype)
			if not match or match[1] ~= subtype then
				-- TODO Don't interpret just any invalid typename as a RegExp.
				self.fuzzySubtypes:set(subtype, RegExp.new(subtype))
			end
		end)
	end)
end

function Policies:getTypePolicy(typename: string): any --[[ ROBLOX TODO: Policies["typePolicies"][string] ]]
	if not hasOwn(self.typePolicies, typename) then
		self.typePolicies[typename] = {}
		local policy: any --[[ ROBLOX TODO: Policies["typePolicies"][string] ]] = self.typePolicies[typename]
		policy.fields = {}

		-- When the TypePolicy for typename is first accessed, instead of
		-- starting with an empty policy object, inherit any properties or
		-- fields from the type policies of the supertypes of typename.
		--
		-- Any properties or fields defined explicitly within the TypePolicy
		-- for typename will take precedence, and if there are multiple
		-- supertypes, the properties of policies whose types were added
		-- later via addPossibleTypes will take precedence over those of
		-- earlier supertypes. TODO Perhaps we should warn about these
		-- conflicts in development, and recommend defining the property
		-- explicitly in the subtype policy?
		--
		-- Field policy inheritance is atomic/shallow: you can't inherit a
		-- field policy and then override just its read function, since read
		-- and merge functions often need to cooperate, so changing only one
		-- of them would be a recipe for inconsistency.
		--
		-- Once the TypePolicy for typename has been accessed, its
		-- properties can still be updated directly using addTypePolicies,
		-- but future changes to supertype policies will not be reflected in
		-- this policy, because this code runs at most once per typename.
		local supertypes = self.supertypeMap:get(typename)
		if Boolean.toJSBoolean(supertypes) and Boolean.toJSBoolean(supertypes.size) then
			-- ROBLOX deviation: using Array.map instead of forEach
			Array.map(supertypes, function(supertype)
				local ref = self:getTypePolicy(supertype)
				local fields, rest = ref.fields, Object.assign({}, ref, { fields = Object.None })
				Object.assign(policy, rest)
				Object.assign(policy.fields, fields)
			end)
		end
	end

	local inbox = self.toBeAdded[typename]
	if Boolean.toJSBoolean(inbox) and Boolean.toJSBoolean(#inbox) then
		-- Merge the pending policies into this.typePolicies, in the order they
		-- were originally passed to addTypePolicy.
		-- ROBLOX deviation: using Array.map instead of forEach
		Array.map(Array.splice(inbox, 1), function(policy)
			self:updateTypePolicy(typename, policy)
		end)
	end

	return self.typePolicies[typename]
end

function Policies:getFieldPolicy(
	typename: string | nil,
	fieldName: string,
	createIfMissing: boolean
): {
	keyFn: KeyArgsFunction?,
	read: FieldReadFunction<any, any>?,
	merge: FieldMergeFunction<any, any>?,
} | nil
	if Boolean.toJSBoolean(typename) then
		local fieldPolicies = self:getTypePolicy(typename).fields
		if Boolean.toJSBoolean(fieldPolicies[fieldName]) then
			return fieldPolicies[fieldName]
		else
			if Boolean.toJSBoolean(createIfMissing) then
				fieldPolicies[fieldName] = {}
				return fieldPolicies[fieldName]
			else
				return nil
			end
		end
	end
	return nil
end

function Policies:getSupertypeSet(subtype: string, createIfMissing: boolean): Set<string> | nil
	local supertypeSet = self.supertypeMap:get(subtype)
	if not Boolean.toJSBoolean(supertypeSet) and createIfMissing then
		supertypeSet = Set.new()
		self.supertypeMap:set(subtype, supertypeSet)
	end
	return supertypeSet
end

function Policies:fragmentMatches(
	fragment: InlineFragmentNode | FragmentDefinitionNode,
	typename: string | nil,
	result: Record<string, any>,
	variables: Record<string, any>
): boolean
	if not Boolean.toJSBoolean(fragment.typeCondition) then
		return true
	end

	-- If the fragment has a type condition but the object we're matching
	-- against does not have a __typename, the fragment cannot match.
	if not Boolean.toJSBoolean(typename) then
		return false
	end

	local supertype = (fragment.typeCondition :: any).name.value
	-- Common case: fragment type condition and __typename are the same.
	if typename == supertype then
		return true
	end

	if Boolean.toJSBoolean(self.usingPossibleTypes) and self.supertypeMap:has(supertype) then
		local typenameSupertypeSet = self:getSupertypeSet(typename, true)
		local workQueue = { typenameSupertypeSet }
		local function maybeEnqueue(subtype: string)
			local supertypeSet = self:getSupertypeSet(subtype, false)
			if
				Boolean.toJSBoolean(supertypeSet)
				and Boolean.toJSBoolean(supertypeSet.size)
				and Array.indexOf(workQueue, supertypeSet) < 1
			then
				table.insert(workQueue:push(supertypeSet))
			end
		end

		-- We need to check fuzzy subtypes only if we encountered fuzzy
		-- subtype strings in addPossibleTypes, and only while writing to
		-- the cache, since that's when selectionSetMatchesResult gives a
		-- strong signal of fragment matching. The StoreReader class calls
		-- policies.fragmentMatches without passing a result object, so
		-- needToCheckFuzzySubtypes is always false while reading.
		local needToCheckFuzzySubtypes = not not Boolean.toJSBoolean(
			Boolean.toJSBoolean(result) and self.fuzzySubtypes.size
		)
		local checkingFuzzySubtypes = false

		-- It's important to keep evaluating workQueue.length each time through
		-- the loop, because the queue can grow while we're iterating over it.
		for i = 1, #workQueue do
			local supertypeSet = workQueue[i]

			if supertypeSet:has(supertype) then
				if not typenameSupertypeSet:has(supertype) then
					if checkingFuzzySubtypes then
						-- ROBLOX FIXME: no invariant.warn available
						-- invariant.warn(("Inferring subtype %s of supertype %s"):format(typename, supertype))
					end
					-- Record positive results for faster future lookup.
					-- Unfortunately, we cannot safely cache negative results,
					-- because new possibleTypes data could always be added to the
					-- Policies class.
					typenameSupertypeSet:add(supertype)
				end
				return true
			end

			-- ROBLOX deviation: using Array.map instead of forEach
			Array.map(supertypeSet, maybeEnqueue)

			if
				needToCheckFuzzySubtypes
				-- Start checking fuzzy subtypes only after exhausting all
				-- non-fuzzy subtypes (after the final iteration of the loop).
				and i == #workQueue
				-- We could wait to compare fragment.selectionSet to result
				-- after we verify the supertype, but this check is often less
				-- expensive than that search, and we will have to do the
				-- comparison anyway whenever we find a potential match.
				and Boolean.toJSBoolean(selectionSetMatchesResult(fragment.selectionSet, result, variables))
			then
				-- We don't always need to check fuzzy subtypes (if no result
				-- was provided, or !this.fuzzySubtypes.size), but, when we do,
				-- we only want to check them once.
				needToCheckFuzzySubtypes = false
				checkingFuzzySubtypes = true

				-- If we find any fuzzy subtypes that match typename, extend the
				-- workQueue to search through the supertypes of those fuzzy
				-- subtypes. Otherwise the for-loop will terminate and we'll
				-- return false below.
				-- ROBLOX deviation: using Array.map instead of forEach
				-- ROBLOX deviation: using Map:entries() as Array.map can't be used on a Map directly
				Array.map(self.fuzzySubtypes:entries(), function(entry)
					local regExp, fuzzyString = entry[2], entry[1] :: string
					-- ROBLOX deviation: string.match doesn't work with RegExps. Using RegExp:exec instead
					local match = regExp:exec(typename :: string)
					if Boolean.toJSBoolean(match) and match[1] == typename then
						maybeEnqueue(fuzzyString)
					end
					return 1
				end)
			end
		end
	end

	return false
end

function Policies:hasKeyArgs(typename: string | nil, fieldName: string): boolean
	local policy = (self :: PoliciesPrivate):getFieldPolicy(typename, fieldName, false)
	return not not (Boolean.toJSBoolean(policy) and Boolean.toJSBoolean((policy :: any).keyfn))
end

function Policies:getStoreFieldName(fieldSpec: FieldSpecifier): string
	local typename, fieldName = fieldSpec.typename, fieldSpec.fieldName
	local policy = (self :: PoliciesPrivate):getFieldPolicy(typename, fieldName, false)
	local storeFieldName: KeyArgsResult

	local keyFn
	if Boolean.toJSBoolean(policy) then
		keyFn = (policy :: any).keyFn
	else
		keyFn = nil
	end
	if Boolean.toJSBoolean(keyFn) and Boolean.toJSBoolean(typename) then
		local context: any --[[ ROBLOX TODO: Parameters<KeyArgsFunction>[1] ]] = {
			typename = typename,
			fieldName = fieldName,
			field = Boolean.toJSBoolean(fieldSpec.field) and fieldSpec.field or nil,
			variables = fieldSpec.variables,
		}
		local args = argsFromFieldSpecifier(fieldSpec)
		while Boolean.toJSBoolean(keyFn) do
			local specifierOrString = keyFn(args, context)
			if Array.isArray(specifierOrString) then
				keyFn = keyArgsFnFromSpecifier(specifierOrString)
			else
				-- If the custom keyFn returns a falsy value, fall back to
				-- fieldName instead.
				storeFieldName = Boolean.toJSBoolean(specifierOrString) and specifierOrString or fieldName
				break
			end
		end
	end

	if storeFieldName == nil then
		if Boolean.toJSBoolean(fieldSpec.field) then
			storeFieldName = storeKeyNameFromField(fieldSpec.field, fieldSpec.variables)
		else
			storeFieldName = getStoreKeyName(fieldName, argsFromFieldSpecifier(fieldSpec))
		end
	end

	-- Returning false from a keyArgs function is like configuring
	-- keyArgs: false, but more dynamic.
	if storeFieldName == false then
		return fieldName
	end

	-- Make sure custom field names start with the actual field.name.value
	-- of the field, so we can always figure out which properties of a
	-- StoreObject correspond to which original field names.
	if fieldName == fieldNameFromStoreName(storeFieldName) then
		return storeFieldName
	else
		return (fieldName .. ":") + storeFieldName
	end
end

type V = any
function Policies:readField--[[<V = StoreValue>]](options: ReadFieldOptions, context: ReadMergeModifyContext): SafeReadonly<V> | nil
	local objectOrReference = options.from
	if not Boolean.toJSBoolean(objectOrReference) then
		return
	end

	local nameOrField = Boolean.toJSBoolean(options.field) and options.field or options.fieldName
	if not Boolean.toJSBoolean(nameOrField) then
		return
	end

	if options.typename == nil then
		local typename = context.store:getFieldValue(objectOrReference, "__typename")
		if Boolean.toJSBoolean(typename) then
			options.typename = typename
		end
	end

	local storeFieldName = self:getStoreFieldName(options)
	local fieldName = fieldNameFromStoreName(storeFieldName)
	local existing = context.store:getFieldValue(objectOrReference, storeFieldName)
	local policy = (self :: PoliciesPrivate):getFieldPolicy(options.typename, fieldName, false)
	local read
	if Boolean.toJSBoolean(policy) then
		read = (policy :: any).read
	else
		read = nil
	end

	if Boolean.toJSBoolean(read) then
		local readOptions = makeFieldFunctionOptions(
			self,
			objectOrReference,
			options,
			context,
			context.store:getStorage(
				(function()
					if Boolean.toJSBoolean(isReference(objectOrReference)) then
						return objectOrReference.__ref
					else
						return objectOrReference
					end
				end)(),
				storeFieldName
			)
		)

		-- Call read(existing, readOptions) with cacheSlot holding this.cache.
		return cacheSlot:withValue(self.cache, read, { existing, readOptions }) :: SafeReadonly<V>
	end

	return existing
end

function Policies:getMergeFunction(
	parentTypename: string | nil,
	fieldName: string,
	childTypename: string | nil
): FieldMergeFunction<any, any> | nil
	local policy: any --[[ ROBLOX TODO: Policies["typePolicies"][string] | Policies["typePolicies"][string]["fields"][string] | undefined ]] =
		(
			self :: PoliciesPrivate
		):getFieldPolicy(parentTypename, fieldName, false)
	local merge
	if Boolean.toJSBoolean(policy) then
		merge = policy.merge
	else
		merge = policy
	end
	if not Boolean.toJSBoolean(merge) and Boolean.toJSBoolean(childTypename) then
		policy = self:getTypePolicy(childTypename)
		if Boolean.toJSBoolean(policy) then
			merge = policy.merge
		else
			merge = policy
		end
	end
	return merge
end

function Policies:runMergeFunction(
	existing: StoreValue,
	incoming: StoreValue,
	ref: MergeInfo,
	context: WriteContext,
	storage: StorageType
): any
	local field, typename, merge = ref.field, ref.typename, ref.merge

	if merge == mergeTrueFn then
		-- Instead of going to the trouble of creating a full
		-- FieldFunctionOptions object and calling mergeTrueFn, we can
		-- simply call mergeObjects, as mergeTrueFn would.
		return makeMergeObjectsFunction(context.store)(existing :: StoreObject, incoming :: StoreObject)
	end

	if merge == mergeFalseFn then
		-- Likewise for mergeFalseFn, whose implementation is even simpler.
		return incoming
	end

	-- If cache.writeQuery or cache.writeFragment was called with
	-- options.overwrite set to true, we still call merge functions, but
	-- the existing data is always undefined, so the merge function will
	-- not attempt to combine the incoming data with the existing data.
	if Boolean.toJSBoolean(context.overwrite) then
		existing = nil
	end

	return merge(
		existing,
		incoming,
		makeFieldFunctionOptions(
			self,
			-- Unlike options.readField for read functions, we do not fall
			-- back to the current object if no foreignObjOrRef is provided,
			-- because it's not clear what the current object should be for
			-- merge functions: the (possibly undefined) existing object, or
			-- the incoming object? If you think your merge function needs
			-- to read sibling fields in order to produce a new value for
			-- the current field, you might want to rethink your strategy,
			-- because that's a recipe for making merge behavior sensitive
			-- to the order in which fields are written into the cache.
			-- However, readField(name, ref) is useful for merge functions
			-- that need to deduplicate child objects and references.
			nil,
			{ typename = typename, fieldName = field.name.value, field = field, variables = context.variables },
			context,
			Boolean.toJSBoolean(storage) and storage or {}
		)
	)
end

exports.Policies = Policies

function makeFieldFunctionOptions(
	policies: Policies,
	objectOrReference: StoreObject | Reference | nil,
	fieldSpec: FieldSpecifier,
	context: ReadMergeModifyContext,
	storage: StorageType
): FieldFunctionOptions<Record<string, any>, Record<string, any>>
	local storeFieldName = policies:getStoreFieldName(fieldSpec)
	local fieldName = fieldNameFromStoreName(storeFieldName)
	local variables = Boolean.toJSBoolean(fieldSpec.variables) and fieldSpec.variables or context.variables
	local toReference, canRead
	do
		local ref = context.store
		toReference, canRead = ref.toReference, ref.canRead
	end
	return {
		args = argsFromFieldSpecifier(fieldSpec),
		field = Boolean.toJSBoolean(fieldSpec.field) and fieldSpec.field or nil,
		fieldName = fieldName,
		storeFieldName = storeFieldName,
		variables = variables,
		isReference = isReference,
		toReference = toReference,
		storage = storage,
		cache = policies.cache,
		canRead = canRead,
		readField = function(self, fieldNameOrOptions: string | ReadFieldOptions, from: StoreObject | Reference)
			local options: ReadFieldOptions = typeof(fieldNameOrOptions) == "string"
					and { fieldName = fieldNameOrOptions, from = from }
				or Object.assign({}, fieldNameOrOptions)
			if nil == options.from then
				options.from = objectOrReference
			end
			if nil == options.variables then
				options.variables = variables
			end
			return policies:readField(options, context)
		end,
		mergeObjects = makeMergeObjectsFunction(context.store),
	}
end
function makeMergeObjectsFunction(store: NormalizedCache): MergeObjectsFunction
	return function(existing, incoming)
		if
			Boolean.toJSBoolean(
				Boolean.toJSBoolean(Array.isArray(existing)) and Array.isArray(existing) or Array.isArray(incoming)
			)
		then
			error(InvariantError.new("Cannot automatically merge arrays"))
		end
		if
			Boolean.toJSBoolean((function()
				if Boolean.toJSBoolean(isNonNullObject(existing)) then
					return isNonNullObject(incoming)
				else
					return isNonNullObject(existing)
				end
			end)())
		then
			local eType = store:getFieldValue(existing, "__typename")
			local iType = store:getFieldValue(incoming, "__typename")
			local typesDiffer = (function()
				if
					Boolean.toJSBoolean((function()
						if Boolean.toJSBoolean(eType) then
							return iType
						else
							return eType
						end
					end)())
				then
					return eType ~= iType
				else
					return (function()
						if Boolean.toJSBoolean(eType) then
							return iType
						else
							return eType
						end
					end)()
				end
			end)()
			if Boolean.toJSBoolean(typesDiffer) then
				return incoming
			end
			if
				Boolean.toJSBoolean((function()
					if Boolean.toJSBoolean(isReference(existing)) then
						return storeValueIsStoreObject(incoming)
					else
						return isReference(existing)
					end
				end)())
			then
				store:merge(existing.__ref, incoming)
				return existing
			end
			if
				Boolean.toJSBoolean((function()
					if Boolean.toJSBoolean(storeValueIsStoreObject(existing)) then
						return isReference(incoming)
					else
						return storeValueIsStoreObject(existing)
					end
				end)())
			then
				store:merge(existing, incoming.__ref)
				return incoming
			end
			if
				Boolean.toJSBoolean((function()
					if Boolean.toJSBoolean(storeValueIsStoreObject(existing)) then
						return storeValueIsStoreObject(incoming)
					else
						return storeValueIsStoreObject(existing)
					end
				end)())
			then
				return Object.assign({}, existing, incoming)
			end
		end
		return incoming
	end
end
function keyArgsFnFromSpecifier(specifier: KeySpecifier): KeyArgsFunction
	return (
			function(args, context)
				if Boolean.toJSBoolean(args) then
					return ("%s:%s"):format(
						context.fieldName,
						HttpService:JSONEncode(computeKeyObject(args, specifier, false))
					)
				else
					return context.fieldName
				end
			end :: any
		) :: KeyArgsFunction
end
function keyFieldsFnFromSpecifier(specifier: KeySpecifier): KeyFieldsFunction
	local trie = Trie.new(canUseWeakMap)
	return (
			function(object, context)
				local aliasMap: AliasMap | nil
				if Boolean.toJSBoolean(context.selectionSet) and Boolean.toJSBoolean(context.fragmentMap) then
					local info = trie:lookupArray({ context.selectionSet, context.fragmentMap })
					if Boolean.toJSBoolean(info.aliasMap) then
						aliasMap = info.aliasMap
					else
						info.aliasMap = makeAliasMap(context.selectionSet, context.fragmentMap)
						aliasMap = info.aliasMap
					end
				end
				context.keyObject = computeKeyObject(object, specifier, true, aliasMap)
				local keyObject = context.keyObject
				return ("%s:%s"):format(context.typename, HttpService:JSONEncode(keyObject))
			end :: any
		) :: KeyFieldsFunction
end
type AliasMap = {
	-- Map from store key to corresponding response key. Undefined when there are
	-- no aliased fields in this selection set.
	aliases: Record<string, string>?,
	-- Map from store key to AliasMap correponding to a child selection set.
	-- Undefined when there are no child selection sets.
	subsets: Record<string, AliasMap>?,
}
function makeAliasMap(selectionSet: SelectionSetNode, fragmentMap: FragmentMap): AliasMap
	local map: AliasMap = {}
	local workQueue = Set.new({ selectionSet })
	workQueue:forEach(function(selectionSet)
		selectionSet.selections:forEach(function(selection)
			if Boolean.toJSBoolean(isField(selection)) then
				if Boolean.toJSBoolean(selection.alias) then
					local responseKey = selection.alias.value
					local storeKey = selection.name.value
					if storeKey ~= responseKey then
						local aliases
						if Boolean.toJSBoolean(map.aliases) then
							aliases = map.aliases
						else
							map.aliases = {}
							aliases = map.aliases
						end
						(aliases :: any)[storeKey] = responseKey
					end
				end
				if Boolean.toJSBoolean(selection.selectionSet) then
					local subsets
					if Boolean.toJSBoolean(map.subsets) then
						subsets = map.subsets
					else
						map.subsets = {}
						subsets = map.subsets
					end
					(subsets :: any)[selection.name.value] = makeAliasMap(selection.selectionSet, fragmentMap)
				end
			else
				local fragment = getFragmentFromSelection(selection, fragmentMap)
				if Boolean.toJSBoolean(fragment) then
					workQueue:add(fragment.selectionSet)
				end
			end
		end)
	end)
	return map
end
function computeKeyObject(
	response: Record<string, any>,
	specifier: KeySpecifier,
	strict: boolean,
	aliasMap: AliasMap?
): Record<string, any>
	local keyObj = {}
	local prevKey: string | nil
	-- ROBLOX deviation: using Array.map instead of forEach
	Array.map(specifier, function(s)
		if Boolean.toJSBoolean(Array.isArray(s)) then
			if typeof(prevKey) == "string" then
				local subsets
				if Boolean.toJSBoolean(aliasMap) then
					subsets = (aliasMap :: any).subsets
				else
					subsets = aliasMap
				end
				local subset
				if Boolean.toJSBoolean(subsets) then
					subset = subsets[prevKey]
				else
					subset = subsets
				end
				keyObj[prevKey] = computeKeyObject(response[prevKey], s, strict, subset)
			end
		else
			local aliases
			if Boolean.toJSBoolean(aliasMap) then
				aliases = (aliasMap :: any).aliases
			else
				aliases = aliasMap
			end
			local responseName
			if Boolean.toJSBoolean(aliases) and Boolean.toJSBoolean(aliases[s]) then
				responseName = aliases[s]
			else
				responseName = s
			end
			if Boolean.toJSBoolean(hasOwn(response, responseName)) then
				prevKey = s
				keyObj[(prevKey :: any) :: string] = response[responseName]
			else
				invariant(
					not Boolean.toJSBoolean(strict),
					("Missing field '%s' while computing key fields"):format(responseName)
				)
				prevKey = nil
			end
		end
		return nil
	end)
	return keyObj
end
return exports
