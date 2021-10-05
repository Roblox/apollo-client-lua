-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/index.ts
local exports = {}

local srcWorkspace = script.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

local invariantModule = require(srcWorkspace.jsutils.invariant)
local invariant = invariantModule.invariant
local DEV = require(script.Parent.utilities).DEV
invariant("boolean" == typeof(DEV), DEV)
local cacheModule = require(script.core.cache)
export type Transaction<T> = cacheModule.Transaction<T>
export type ApolloCache<TSerialized> = cacheModule.ApolloCache<TSerialized>

local cacheTypesModule = require(script.core.types.Cache)
export type Cache_DiffResult<T> = cacheTypesModule.Cache_DiffResult<T>
export type Cache_WatchCallback = cacheTypesModule.Cache_WatchCallback
export type Cache_ReadOptions<TVariables, TData> = cacheTypesModule.Cache_ReadOptions<TVariables, TData>
export type Cache_WriteOptions<TResult, TVariables> = cacheTypesModule.Cache_WriteOptions<TResult, TVariables>
export type Cache_DiffOptions<TVariables, TData> = cacheTypesModule.Cache_DiffOptions<TVariables, TData>
export type Cache_WatchOptions<Watcher> = cacheTypesModule.Cache_WatchOptions<Watcher>
export type Cache_EvictOptions = cacheTypesModule.Cache_EvictOptions
export type Cache_ModifyOptions = cacheTypesModule.Cache_ModifyOptions
export type Cache_BatchOptions<C> = cacheTypesModule.Cache_BatchOptions<C>
export type Cache_ReadQueryOptions<TData, TVariables> = cacheTypesModule.Cache_ReadQueryOptions<TData, TVariables>
export type Cache_ReadFragmentOptions<TData, TVariables> = cacheTypesModule.Cache_ReadFragmentOptions<TData, TVariables>
export type Cache_WriteQueryOptions<TData, TVariables> = cacheTypesModule.Cache_WriteQueryOptions<TData, TVariables>
export type Cache_WriteFragmentOptions<TData, TVariables> = cacheTypesModule.Cache_WriteFragmentOptions<TData, TVariables>
export type Cache_Fragment<TData, TVariables> = cacheTypesModule.Cache_Fragment<TData, TVariables>

-- exports.DataProxy = require(script.core.types.DataProxy).DataProxy
local commonModule = require(script.core.types.common)
exports.MissingFieldError = commonModule.MissingFieldError
export type MissingFieldError = commonModule.MissingFieldError
export type ReadFieldOptions = commonModule.ReadFieldOptions

local utilitiesModule = require(script.Parent.utilities)
export type Reference = utilitiesModule.Reference
exports.isReference = utilitiesModule.isReference
exports.makeReference = utilitiesModule.makeReference
-- exports.EntityStore = require(script.inmemory.entityStore).EntityStore
exports.fieldNameFromStoreName = require(script.inmemory.helpers).fieldNameFromStoreName
-- local inMemoryCacheModule = require(script.inmemory.inMemoryCache)
-- exports.InMemoryCache = inMemoryCacheModule.InMemoryCache
-- exports.InMemoryCacheConfig = inMemoryCacheModule.InMemoryCacheConfig
local reactiveVarsModule = require(script.inmemory.reactiveVars)
export type ReactiveVar<T> = reactiveVarsModule.ReactiveVar<T>
exports.makeVar = reactiveVarsModule.makeVar
exports.cacheSlot = reactiveVarsModule.cacheSlot
local policiesModule = require(script.inmemory.policies)
exports.defaultDataIdFromObject = policiesModule.defaultDataIdFromObject
export type TypePolicies = policiesModule.TypePolicies
export type TypePolicy = policiesModule.TypePolicy
export type FieldPolicy<TExisting, TIncoming, TReadResult> = policiesModule.FieldPolicy<TExisting, TIncoming, TReadResult>
export type FieldReadFunction<T, V> = policiesModule.FieldReadFunction<T, V>
export type FieldMergeFunction<T, V> = policiesModule.FieldMergeFunction<T, V>
export type FieldFunctionOptions<TArgs, TVars> = policiesModule.FieldFunctionOptions<TArgs, TVars>
export type PossibleTypesMap = policiesModule.PossibleTypesMap
exports.Policies = policiesModule.Policies
exports.canonicalStringify = require(script.inmemory["object-canon"]).canonicalStringify

local inMemoryTypesModule = require(script.inmemory.types)
Object.assign(exports, inMemoryTypesModule)
export type StoreObject = inMemoryTypesModule.StoreObject
export type StoreValue = inMemoryTypesModule.StoreValue
-- ROBLOX comment: already exported from utilities module
-- export type Reference = inMemoryTypesModule.Reference
export type IdGetterObj = inMemoryTypesModule.IdGetterObj
export type IdGetter = inMemoryTypesModule.IdGetter
export type NormalizedCache = inMemoryTypesModule.NormalizedCache
export type NormalizedCacheObject = inMemoryTypesModule.NormalizedCacheObject
export type OptimisticStoreItem = inMemoryTypesModule.OptimisticStoreItem
export type ReadQueryOptions = inMemoryTypesModule.ReadQueryOptions
export type DiffQueryAgainstStoreOptions = inMemoryTypesModule.DiffQueryAgainstStoreOptions
export type ApolloReducerConfig = inMemoryTypesModule.ApolloReducerConfig
export type MergeInfo = inMemoryTypesModule.MergeInfo
export type MergeTree = inMemoryTypesModule.MergeTree
export type ReadMergeModifyContext = inMemoryTypesModule.ReadMergeModifyContext

return exports
