-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/index.ts
local exports = {}

local _srcWorkspace = script.Parent.Parent.Parent.Parent
-- local invariant = require(rootWorkspace["ts-invariant"]).invariant
-- local DEV = require(script.Parent.utilities).DEV
-- invariant("boolean" == typeof(DEV), DEV)
-- local cacheModule = require(script.core.cache)
-- exports.Transaction = cacheModule.Transaction
-- exports.ApolloCache = cacheModule.ApolloCache
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
-- local commonModule = require(script.core.types.common)
-- exports.MissingFieldError = commonModule.MissingFieldError
-- exports.ReadFieldOptions = commonModule.ReadFieldOptions
-- local utilitiesModule = require(script.Parent.utilities)
-- exports.Reference = utilitiesModule.Reference
-- exports.isReference = utilitiesModule.isReference
-- exports.makeReference = utilitiesModule.makeReference
-- exports.EntityStore = require(script.inmemory.entityStore).EntityStore
-- exports.fieldNameFromStoreName = require(script.inmemory.helpers).fieldNameFromStoreName
-- local inMemoryCacheModule = require(script.inmemory.inMemoryCache)
-- exports.InMemoryCache = inMemoryCacheModule.InMemoryCache
-- exports.InMemoryCacheConfig = inMemoryCacheModule.InMemoryCacheConfig
-- local reactiveVarsModule = require(script.inmemory.reactiveVars)
-- exports.ReactiveVar = reactiveVarsModule.ReactiveVar
-- exports.makeVar = reactiveVarsModule.makeVar
-- exports.cacheSlot = reactiveVarsModule.cacheSlot
-- local policiesModule = require(script.inmemory.policies)
-- exports.defaultDataIdFromObject = policiesModule.defaultDataIdFromObject
-- exports.TypePolicies = policiesModule.TypePolicies
-- exports.TypePolicy = policiesModule.TypePolicy
-- exports.FieldPolicy = policiesModule.FieldPolicy
-- exports.FieldReadFunction = policiesModule.FieldReadFunction
-- exports.FieldMergeFunction = policiesModule.FieldMergeFunction
-- exports.FieldFunctionOptions = policiesModule.FieldFunctionOptions
-- exports.PossibleTypesMap = policiesModule.PossibleTypesMap
-- exports.Policies = policiesModule.Policies
-- exports.canonicalStringify = require(script.inmemory["object-canon"]).canonicalStringify
-- Object.assign(exports, require(script.inmemory.types))
return exports
