-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/readFromStore.ts

-- ROBLOX FIXME: remove when analyze is fixed
type InvalidAnalyzeErrorFix = any

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object
local Boolean = LuauPolyfill.Boolean
local Set = LuauPolyfill.Set
local WeakMap = LuauPolyfill.WeakMap
type Array<T> = LuauPolyfill.Array<T>
type Object = LuauPolyfill.Object
type WeakMap<T, U> = LuauPolyfill.WeakMap<T, U>
type Record<T, U> = { [T]: U }

local HttpService = game:GetService("HttpService")
local NULL = require(srcWorkspace.utilities).NULL
--[[
	ROBLOX deviation: no generic params for functions are supported.
	T_, TCacheKey_ is placeholder for generic T, TCacheKey param
]]
type T_ = any
type TCacheKey_ = any

--ROBLOX deviation: predefined variable
local assertSelectionSetForIdValue

local exports = {}

local graphqlModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphqlModule.DocumentNode
type FieldNode = graphqlModule.FieldNode
type SelectionSetNode = graphqlModule.SelectionSetNode
local optimismModule = require(srcWorkspace.optimism)
local wrap = optimismModule.wrap
type OptimisticWrapperFunction<TArgs, TResult, TKeyArgs, TCacheKey> =
	optimismModule.OptimisticWrapperFunction<TArgs, TResult, TKeyArgs, TCacheKey>
local invariantModule = require(srcWorkspace.jsutils.invariant)
local invariant = invariantModule.invariant
local InvariantError = invariantModule.InvariantError
type InvariantError = invariantModule.InvariantError

local utilitiesModule = require(script.Parent.Parent.Parent.utilities)
local isField = utilitiesModule.isField
local resultKeyNameFromField = utilitiesModule.resultKeyNameFromField
type Reference = utilitiesModule.Reference
local isReference = utilitiesModule.isReference
local makeReference = utilitiesModule.makeReference
type StoreObject = utilitiesModule.StoreObject
local createFragmentMap = utilitiesModule.createFragmentMap
type FragmentMap = utilitiesModule.FragmentMap
local shouldInclude = utilitiesModule.shouldInclude
local addTypenameToDocument = utilitiesModule.addTypenameToDocument
local getDefaultValues = utilitiesModule.getDefaultValues
local getFragmentDefinitions = utilitiesModule.getFragmentDefinitions
local getMainDefinition = utilitiesModule.getMainDefinition
local getQueryDefinition = utilitiesModule.getQueryDefinition
local mergeDeepArray = utilitiesModule.mergeDeepArray
local getFragmentFromSelection = utilitiesModule.getFragmentFromSelection
local maybeDeepFreeze = utilitiesModule.maybeDeepFreeze
local isNonNullObject = utilitiesModule.isNonNullObject
local _canUseWeakMap = utilitiesModule.canUseWeakMap
local Cache = require(script.Parent.Parent.core.types.Cache)
type Cache_DiffResult<T> = Cache.Cache_DiffResult<T>
local typesModule = require(script.Parent.types)
type DiffQueryAgainstStoreOptions = typesModule.DiffQueryAgainstStoreOptions
type NormalizedCache = typesModule.NormalizedCache
type ReadMergeModifyContext = typesModule.ReadMergeModifyContext
local entityStoreModule = require(script.Parent.entityStore)
local maybeDependOnExistenceOfEntity = entityStoreModule.maybeDependOnExistenceOfEntity
local supportsResultCaching = entityStoreModule.supportsResultCaching
type EntityStore = entityStoreModule.EntityStore
local getTypenameFromStoreObject = require(script.Parent.helpers).getTypenameFromStoreObject
local policiesModule = require(script.Parent.policies)
type Policies = policiesModule.Policies
-- ROBLOX TODO: use real type when implemented
-- local inMemoryCacheModule = require(script.Parent.inMemoryCache)
-- type InMemoryCache = inMemoryCacheModule.InMemoryCache
type InMemoryCache = Object
local coreTypesCommonModule = require(script.Parent.Parent.core.types.common)
local MissingFieldError = coreTypesCommonModule.MissingFieldError
type MissingFieldError = coreTypesCommonModule.MissingFieldError
local objectCanonModule = require(script.Parent["object-canon"])
local canonicalStringify = objectCanonModule.canonicalStringify
local ObjectCanon = objectCanonModule.ObjectCanon
type ObjectCanon = objectCanonModule.ObjectCanon

export type VariableMap = { [string]: any }

type ReadContext = ReadMergeModifyContext & {
	query: DocumentNode,
	policies: Policies,
	canonizeResults: boolean,
	fragmentMap: FragmentMap,
	path: Array<string | number>,
}

export type ExecResult<R> = { result: R, missing: Array<MissingFieldError>? }

local function missingFromInvariant(err: InvariantError, context: ReadContext)
	return MissingFieldError.new(err.message, Array.slice(context.path), context.query, context.variables)
end

type ExecSelectionSetOptions = {
	selectionSet: SelectionSetNode,
	objectOrReference: StoreObject | Reference,
	enclosingRef: Reference,
	context: ReadContext,
}

type ExecSubSelectedArrayOptions = { field: FieldNode, array: Array<any>, enclosingRef: Reference, context: ReadContext }

export type StoreReaderConfig = {
	cache: InMemoryCache,
	addTypename: boolean?,
	resultCacheMaxSize: number?,
	canon: ObjectCanon?,
}

--[[
  ROBLOX deviation: no way to handle tuple like types in Luau
  original type:
  type ExecSelectionSetKeyArgs = [
    SelectionSetNode,
    StoreObject | Reference,
    ReadMergeModifyContext,
    boolean,
  ];
]]
-- Arguments type after keyArgs translation.
type ExecSelectionSetKeyArgs = Array<SelectionSetNode | StoreObject | Reference | ReadMergeModifyContext | boolean>

local function execSelectionSetKeyArgs(options: ExecSelectionSetOptions): ExecSelectionSetKeyArgs
	return {
		options.selectionSet,
		options.objectOrReference,
		options.context,
		-- We split out this property so we can pass different values
		-- independently without modifying options.context itself.
		options.context.canonizeResults,
	}
end

export type StoreReader = {
	canon: ObjectCanon,
	resetCanon: (self: StoreReader) -> (),
	diffQueryAgainstStore: (self: StoreReader, ref: DiffQueryAgainstStoreOptions) -> Cache_DiffResult<T_>,
	isFresh: (
		self: StoreReader,
		result: Record<string, any>,
		parent: StoreObject | Reference,
		selectionSet: SelectionSetNode,
		context: ReadMergeModifyContext
	) -> boolean,
}

type StoreReaderPrivate = StoreReader & {
	-- cached version of executeSelectionset
	executeSelectionSet: OptimisticWrapperFunction<Array<ExecSelectionSetOptions>, -- Actual arguments tuple type.
	ExecResult<any>, -- Actual return type.
	ExecSelectionSetKeyArgs,
	TCacheKey_>,
	-- cached version of executeSubSelectedArray
	executeSubSelectedArray: OptimisticWrapperFunction<Array<ExecSubSelectedArrayOptions>, ExecResult<any>, Array<ExecSubSelectedArrayOptions>, TCacheKey_>,
	config: { cache: InMemoryCache, addTypename: boolean, resultCacheMaxSize: number? },
	knownResults: WeakMap<Record<string, any>, SelectionSetNode>,
	execSelectionSetImpl: (self: StoreReaderPrivate, ref: ExecSelectionSetOptions) -> ExecResult<any>,
	execSubSelectedArrayImpl: (self: StoreReaderPrivate, ref: ExecSubSelectedArrayOptions) -> ExecResult<any>,
}

local StoreReader = {}
StoreReader.__index = StoreReader

function StoreReader:resetCanon(): ()
	self.canon = ObjectCanon.new()
end

function StoreReader.new(config: StoreReaderConfig): StoreReader
	local self = (setmetatable({}, StoreReader) :: any) :: StoreReaderPrivate

	-- ROBLOX section: inline properties
	self.knownResults = WeakMap.new()
	-- ROBLOX section end: inline properties

	self.config = Object.assign({}, config, { addTypename = config.addTypename ~= false })

	self.canon = Boolean.toJSBoolean(config.canon) and config.canon :: ObjectCanon or ObjectCanon.new()

	self.executeSelectionSet = wrap(function(_self, options)
		local canonizeResults = options.context.canonizeResults

		local peekArgs = execSelectionSetKeyArgs(options)

		-- Negate this boolean option so we can find out if we've already read
		-- this result using the other boolean value.
		peekArgs[4] = not canonizeResults

		local other = self.executeSelectionSet:peek(table.unpack(peekArgs))

		if Boolean.toJSBoolean(other) and other ~= nil then
			if canonizeResults then
				return Object.assign({}, other, {
					-- If we previously read this result without canonizing it, we can
					-- reuse that result simply by canonizing it now.
					result = self.canon:admit(other.result),
				})
			end
			-- If we previously read this result with canonization enabled, we can
			-- return that canonized result as-is.
			return other
		end

		maybeDependOnExistenceOfEntity(options.context.store, options.enclosingRef.__ref)

		-- Finally, if we didn't find any useful previous results, run the real
		-- execSelectionSetImpl method with the given options.
		return self:execSelectionSetImpl(options)
	end, {
		max = self.config.resultCacheMaxSize,
		keyArgs = function(_self, ...)
			return execSelectionSetKeyArgs(...)
		end,
		-- Note that the parameters of makeCacheKey are determined by the
		-- array returned by keyArgs.
		makeCacheKey = function(_self, selectionSet, parent, context, canonizeResults): Object | nil
			if supportsResultCaching(context.store) then
				return ((context.store :: any) :: EntityStore):makeCacheKey(
					selectionSet,
					isReference(parent) and parent.__ref or parent,
					context.varString,
					canonizeResults
				)
			end
			return nil
		end,
	}, self)

	self.executeSubSelectedArray = wrap(function(_self, options: ExecSubSelectedArrayOptions)
		maybeDependOnExistenceOfEntity(options.context.store, options.enclosingRef.__ref)
		return self:execSubSelectedArrayImpl(options)
	end, {
		max = self.config.resultCacheMaxSize,
		makeCacheKey = function(_self, ref): Object | nil
			local field, array, context = ref.field, ref.array, ref.context
			if supportsResultCaching(context.store) then
				return ((context.store :: any) :: EntityStore):makeCacheKey(field, array, context.varString)
			end
			return nil
		end,
	}, self)

	return (self :: any) :: StoreReader
end

--[[*
 * Given a store and a query, return as much of the result as possible and
 * identify if any data was missing from the store.
 * @param  {DocumentNode} query A parsed GraphQL query document
 * @param  {Store} store The Apollo Client store object
 * @return {result: Object, complete: [boolean]}
]]
function StoreReader:diffQueryAgainstStore(ref: DiffQueryAgainstStoreOptions): Cache_DiffResult<T_>
	local store, query, rootId, variables, returnPartialData, canonizeResults =
		ref.store,
		ref.query,
		(ref.rootId :: any) :: string,
		ref.variables,
		(ref.returnPartialData :: any) :: boolean,
		(ref.canonizeResults :: any) :: boolean
	if rootId == nil then
		rootId = "ROOT_QUERY"
	end
	if returnPartialData == nil then
		returnPartialData = true
	end
	if canonizeResults == nil then
		canonizeResults = true
	end

	local policies = self.config.cache.policies

	variables = Object.assign({}, getDefaultValues(getQueryDefinition(query)), variables)

	local rootRef = makeReference(rootId)
	local execResult = self:executeSelectionSet({
		selectionSet = getMainDefinition(query).selectionSet,
		objectOrReference = rootRef,
		enclosingRef = rootRef,
		context = {
			store = store,
			query = query,
			policies = policies,
			variables = variables,
			varString = canonicalStringify(variables),
			canonizeResults = canonizeResults,
			fragmentMap = createFragmentMap(getFragmentDefinitions(query)),
			path = {},
		},
	})

	local hasMissingFields = Boolean.toJSBoolean(execResult.missing) and #execResult.missing > 0
	if hasMissingFields and not returnPartialData then
		error(execResult.missing[1])
	end

	return {
		result = execResult.result,
		missing = execResult.missing,
		complete = not hasMissingFields,
	}
end

function StoreReader:isFresh(
	result: Record<string, any>,
	parent: StoreObject | Reference,
	selectionSet: SelectionSetNode,
	context: ReadMergeModifyContext
): boolean
	if supportsResultCaching(context.store) and self.knownResults:get(result) == selectionSet then
		local latest = self.executeSelectionSet:peek(
			selectionSet,
			parent,
			context,
			-- If result is canonical, then it could only have been previously
			-- cached by the canonizing version of executeSelectionSet, so we can
			-- avoid checking both possibilities here.
			self.canon:isKnown(result)
		)
		if Boolean.toJSBoolean(latest) and result == latest.result then
			return true
		end
	end
	return false
end

-- Uncached version of executeSelectionSet.
function StoreReader:execSelectionSetImpl(ref: ExecSelectionSetOptions): ExecResult<any>
	local selectionSet, objectOrReference, enclosingRef, context =
		ref.selectionSet, ref.objectOrReference, ref.enclosingRef, ref.context
	if
		isReference(objectOrReference)
		and not Boolean.toJSBoolean(context.policies.rootTypenamesById[(objectOrReference :: Reference).__ref])
		and not context.store:has((objectOrReference :: Reference).__ref)
	then
		return {
			result = self.canon.empty,
			missing = {
				missingFromInvariant(
					InvariantError.new(
						("Dangling reference to missing %s object"):format((objectOrReference :: Reference).__ref)
					),
					context
				),
			},
		}
	end

	local variables, policies, store = context.variables, context.policies, context.store
	local objectsToMerge: Array<{ [string]: any }> = {}
	local finalResult: ExecResult<any> = { result = NULL }
	local typename = store:getFieldValue(objectOrReference, "__typename")

	if
		self.config.addTypename
		and typeof(typename) == "string"
		and not Boolean.toJSBoolean(policies.rootIdsByTypename[typename])
	then
		-- Ensure we always include a default value for the __typename
		-- field, if we have one, and this.config.addTypename is true. Note
		-- that this field can be overridden by other merged objects.
		table.insert(objectsToMerge, { __typename = typename })
	end

	local function getMissing(): Array<MissingFieldError>
		if not Boolean.toJSBoolean(finalResult.missing) then
			finalResult.missing = {}
		end
		return finalResult.missing :: Array<MissingFieldError>
	end

	local function handleMissing(result: ExecResult<T_>): T_
		if Boolean.toJSBoolean(result.missing) then
			local missing = getMissing()
			local resultMissing = result.missing :: Array<any>
			for i = 1, #resultMissing do
				table.insert(missing, resultMissing[i])
			end
		end
		return result.result
	end

	local workSet = Set.new(selectionSet.selections)

	-- ROBLOX deviation: can't use Array.map on a Set in Lua
	for _, selection in workSet:ipairs() do
		-- Omit fields with directives @skip(if: <truthy value>) or
		-- @include(if: <falsy value>).
		if not shouldInclude(selection, variables) then
			-- ROBLOX deviation: using continue instead of return to finish current loop cycle, but not return from the whole function
			continue
		end

		if isField(selection) then
			local fieldValue = policies:readField({
				fieldName = (selection :: FieldNode).name.value,
				field = selection :: FieldNode,
				variables = context.variables,
				from = objectOrReference,
			} :: InvalidAnalyzeErrorFix, context)

			local resultName = resultKeyNameFromField(selection)
			table.insert(context.path, resultName)

			if fieldValue == nil then
				if not Boolean.toJSBoolean(addTypenameToDocument:added(selection)) then
					table.insert(
						getMissing(),
						missingFromInvariant(
							InvariantError.new(
								("Can't find field '%s' on %s"):format(
									selection.name.value,
									isReference(objectOrReference)
											and (objectOrReference :: Reference).__ref .. " object"
										--[[
										  ROBLOX CHECK:
										  HttpService:JSONEncode won't format the JSON same as JSON.stringify
										  original code:
										  JSON.stringify(objectOrReference, nil, 2)
										]]
										or "object " .. HttpService:JSONEncode(objectOrReference)
								)
							),
							context
						)
					)
				end
			elseif Array.isArray(fieldValue) then
				fieldValue = handleMissing(self:executeSubSelectedArray({
					field = selection,
					array = fieldValue,
					enclosingRef = enclosingRef,
					context = context,
				}))
			elseif not Boolean.toJSBoolean(selection.selectionSet) then
				-- If the field does not have a selection set, then we handle it
				-- as a scalar value. To keep this.canon from canonicalizing
				-- this value, we use this.canon.pass to wrap fieldValue in a
				-- Pass object that this.canon.admit will later unwrap as-is.
				if context.canonizeResults then
					fieldValue = self.canon:pass(fieldValue)
				end
			elseif fieldValue ~= NULL then
				-- In this case, because we know the field has a selection set,
				-- it must be trying to query a GraphQLObjectType, which is why
				-- fieldValue must be != null.
				fieldValue = handleMissing(self:executeSelectionSet({
					selectionSet = selection.selectionSet,
					objectOrReference = fieldValue :: StoreObject | Reference,
					enclosingRef = isReference(fieldValue) and fieldValue or enclosingRef,
					context = context,
				}))
			end

			if fieldValue ~= nil then
				table.insert(objectsToMerge, { [resultName] = fieldValue })
			end

			invariant(table.remove(context.path) == resultName)
		else
			local fragment = getFragmentFromSelection(selection, context.fragmentMap)

			if Boolean.toJSBoolean(fragment) and Boolean.toJSBoolean(policies:fragmentMatches(fragment, typename)) then
				Array.forEach(fragment.selectionSet.selections, workSet.add, workSet)
			end
		end
	end

	-- Perform a single merge at the end so that we can avoid making more
	-- defensive shallow copies than necessary.
	local merged = mergeDeepArray(objectsToMerge)
	if context.canonizeResults then
		finalResult.result = self.canon:admit(merged)
	else
		-- Since this.canon is normally responsible for freezing results (only in
		-- development), freeze them manually if canonization is disabled.
		finalResult.result = maybeDeepFreeze(merged)
	end

	-- Store this result with its selection set so that we can quickly
	-- recognize it again in the StoreReader#isFresh method.
	self.knownResults:set(finalResult.result, selectionSet)

	return finalResult
end

-- Uncached version of executeSubSelectedArray.
function StoreReader:execSubSelectedArrayImpl(ref: ExecSubSelectedArrayOptions): ExecResult<any>
	local field, array, enclosingRef, context = ref.field, ref.array, ref.enclosingRef, ref.context

	local missing: Array<MissingFieldError> | nil

	local function handleMissing(childResult: ExecResult<T_>, i: number): T_
		if Boolean.toJSBoolean(childResult.missing) then
			missing = Boolean.toJSBoolean(missing) and missing or {}
			local refArr = childResult.missing :: Array<any>
			for i_ = 1, #refArr do
				table.insert(missing :: Array<MissingFieldError>, refArr[i_])
			end
		end

		invariant(table.remove(context.path) == i)

		return childResult.result
	end

	if Boolean.toJSBoolean(field.selectionSet) then
		array = Array.filter(array, function(item)
			return context.store:canRead(item)
		end)
	end

	array = Array.map(array, function(item: any, i: number)
		-- null value in array
		if item == NULL then
			return NULL
		end

		table.insert(context.path, i)

		-- This is a nested array, recurse
		-- ROBLOX deviation: empty object shouldn't be treated as an array
		if Array.isArray(item) and #item > 0 then
			return handleMissing(
				self:executeSubSelectedArray({
					field = field,
					array = item,
					enclosingRef = enclosingRef,
					context = context,
				}),
				i
			)
		end

		-- This is an object, run the selection set on it
		if Boolean.toJSBoolean(field.selectionSet) then
			return handleMissing(
				self:executeSelectionSet({
					selectionSet = field.selectionSet,
					objectOrReference = item,
					enclosingRef = isReference(item) and item or enclosingRef,
					context = context,
				}),
				i
			)
		end

		if _G.__DEV__ then
			assertSelectionSetForIdValue(context.store, field, item)
		end

		invariant(table.remove(context.path) == i)

		return item
	end)

	return {
		result = (function()
			if context.canonizeResults then
				return self.canon:admit(array)
			else
				return array
			end
		end)(),
		missing = missing,
	}
end

exports.StoreReader = StoreReader

function assertSelectionSetForIdValue(store: NormalizedCache, field: FieldNode, fieldValue: any)
	if not Boolean.toJSBoolean(field.selectionSet) then
		local workSet = Set.new({ fieldValue })
		for _, value in workSet:ipairs() do
			if isNonNullObject(value) then
				invariant(
					not isReference(value),
					("Missing selection set for object of type %s returned for query field %s"):format(
						getTypenameFromStoreObject(store, value) or "nil" :: string,
						field.name.value
					)
				)
				Array.forEach(Object.values(value), workSet.add, workSet)
			end
		end
	end
end

return exports
