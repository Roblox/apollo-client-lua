-- upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.6/src/core/index.ts

--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  ApolloClientOptions,
  DefaultOptions,
  mergeOptions,
} from './ApolloClient'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  ObservableQuery,
  FetchMoreOptions,
  UpdateQueryOptions,
  applyNextFetchPolicy,
} from './ObservableQuery'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  QueryOptions,
  WatchQueryOptions,
  MutationOptions,
  SubscriptionOptions,
  FetchPolicy,
  WatchQueryFetchPolicy,
  ErrorPolicy,
  FetchMoreQueryOptions,
  SubscribeToMoreOptions,
} from './watchQueryOptions'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export { NetworkStatus } from './networkStatus'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportAllDeclaration ]]
--[[ export * from './types'; ]]
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
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  Observable,
  Observer,
  ObservableSubscription,
  Reference,
  isReference,
  makeReference,
  StoreObject,
} from '../utilities'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import { setVerbosity } from "ts-invariant"; ]]
--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export { setVerbosity as setLogVerbosity } ]]

-- setVerbosity("log")

--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export {
  gql,
  resetCaches,
  disableFragmentWarnings,
  enableExperimentalFragmentVariables,
  disableExperimentalFragmentVariables,
} from 'graphql-tag'; ]]

local ApolloClient = require(script.ApolloClient).ApolloClient

return { ApolloClient = ApolloClient }
