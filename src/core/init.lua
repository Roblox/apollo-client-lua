-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/index.ts

local exports = {}
local srcWorkspace = script.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

-- local DEV = require(srcWorkspace.utilities).DEV

--[[ export {
  ApolloClientOptions,
} from './ApolloClient'; ]]
local ApolloClientModule = require(script.ApolloClient)
export type ApolloClient<TCacheShape> = ApolloClientModule.ApolloClient<TCacheShape>
exports.ApolloClient = ApolloClientModule.ApolloClient
export type DefaultOptions = ApolloClientModule.DefaultOptions
exports.mergeOptions = ApolloClientModule.mergeOptions

local ObservableQueryModule = require(script.ObservableQuery)
-- exports.ObservableQuery = ObservableQueryModule.ObservableQuery
export type ObservableQuery<TData, TVariables> = ObservableQueryModule.ObservableQuery<TData, TVariables>
-- exports.FetchMoreOptions = ObservableQueryModule.FetchMoreOptions
-- exports.UpdateQueryOptions = ObservableQueryModule.UpdateQueryOptions
exports.applyNextFetchPolicy = ObservableQueryModule.applyNextFetchPolicy

local watchQueryOptionsModule = require(script.watchQueryOptions)
export type QueryOptions<TVariables, TData> = watchQueryOptionsModule.QueryOptions<TVariables, TData>
export type WatchQueryOptions<TVariables, TData> = watchQueryOptionsModule.WatchQueryOptions<TVariables, TData>
export type FetchPolicy = watchQueryOptionsModule.FetchPolicy
export type WatchQueryFetchPolicy = watchQueryOptionsModule.WatchQueryFetchPolicy
export type ErrorPolicy = watchQueryOptionsModule.ErrorPolicy
export type FetchMoreQueryOptions<TVariables, TData> = watchQueryOptionsModule.FetchMoreQueryOptions<TVariables, TData>
--[[ export {
  MutationOptions,
  SubscriptionOptions,
  SubscribeToMoreOptions,
} from './watchQueryOptions'; ]]
local networkStatusModule = require(script.networkStatus)
exports.NetworkStatus = networkStatusModule.NetworkStatus
export type NetworkStatus = networkStatusModule.NetworkStatus
local typesModule = require(script.types)
Object.assign(exports, typesModule)
export type TypedDocumentNode<Result, Variables> = typesModule.TypedDocumentNode<Result, Variables>
export type DefaultContext = typesModule.DefaultContext
export type QueryListener = typesModule.QueryListener
export type OnQueryUpdated<TResult> = typesModule.OnQueryUpdated<TResult>
export type RefetchQueryDescriptor = typesModule.RefetchQueryDescriptor
export type InternalRefetchQueryDescriptor = typesModule.InternalRefetchQueryDescriptor
export type RefetchQueriesInclude = typesModule.RefetchQueriesInclude
export type InternalRefetchQueriesInclude = typesModule.InternalRefetchQueriesInclude
export type RefetchQueriesOptions<TCache, TResult> = typesModule.RefetchQueriesOptions<TCache, TResult>
export type RefetchQueriesPromiseResults<TResult> = typesModule.RefetchQueriesPromiseResults<TResult>
export type RefetchQueriesResult<TResult> = typesModule.RefetchQueriesResult<TResult>
export type InternalRefetchQueriesOptions<TCache, TResult> = typesModule.InternalRefetchQueriesOptions<TCache, TResult>
export type InternalRefetchQueriesResult<TResult> = typesModule.InternalRefetchQueriesResult<TResult>
export type InternalRefetchQueriesMap<TResult> = typesModule.InternalRefetchQueriesMap<TResult>
export type PureQueryOptions = typesModule.PureQueryOptions
export type OperationVariables = typesModule.OperationVariables
export type ApolloQueryResult<T> = typesModule.ApolloQueryResult<T>
export type MutationQueryReducer<T> = typesModule.MutationQueryReducer<T>
export type MutationQueryReducersMap<T> = typesModule.MutationQueryReducersMap<T>
export type MutationUpdaterFunction<TData, TVariables, TContext, TCache> =
	typesModule.MutationUpdaterFunction<TData, TVariables, TContext, TCache>
export type Resolvers = typesModule.Resolvers
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  Resolver,
  FragmentMatcher,
} from './LocalState'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export { isApolloError, ApolloError } from '../errors'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  // All the exports (types and values) from ../cache, minus cacheSlot,
  // which we want to keep semi-private.
  Cache,
  ApolloCache,
  Transaction,
  DataProxy,
  InMemoryCache,
  InMemoryCacheConfig,
  MissingFieldError,
  defaultDataIdFromObject,
  ReactiveVar,
  makeVar,
  TypePolicies,
  TypePolicy,
  FieldPolicy,
  FieldReadFunction,
  FieldMergeFunction,
  FieldFunctionOptions,
  PossibleTypesMap,
} from '../cache'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportAllDeclaration ]]
--[[ export * from '../cache/inmemory/types'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportAllDeclaration ]]
--[[ export * from '../link/core'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportAllDeclaration ]]
--[[ export * from '../link/http'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  fromError,
  toPromise,
  fromPromise,
  ServerError,
  throwServerError,
} from '../link/utils'; ]]
local utilitiesModule = require(script.Parent.utilities)
export type Observable<T> = utilitiesModule.Observable<T>
export type Observer<T> = utilitiesModule.Observer<T>
export type ObservableSubscription<T> = utilitiesModule.ObservableSubscription<T>
export type Reference = utilitiesModule.Reference
exports.isReference = utilitiesModule.isReference
exports.makeReference = utilitiesModule.makeReference
export type StoreObject = utilitiesModule.StoreObject
--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import { setVerbosity } from "ts-invariant"; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export { setVerbosity as setLogVerbosity } ]]

-- setVerbosity(DEV ? "log" : "silent")

--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  gql,
  resetCaches,
  disableFragmentWarnings,
  enableExperimentalFragmentVariables,
  disableExperimentalFragmentVariables,
} from 'graphql-tag'; ]]

return exports
