-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/types.ts

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
type Array<T> = LuauPolyfill.Array<T>

local GraphQL = require(rootWorkspace.GraphQL)
type DocumentNode = GraphQL.DocumentNode
type GraphQLError = GraphQL.GraphQLError

-- ROBLOX deviation: need to define Promise type for use below
local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
type Promise<T> = PromiseTypeModule.Promise<T>

-- ROBLOX deviation: need to define Map type for use below
type Map<T, U> = { [any]: any }

-- ROBLOX deviation: only used during upstreams generic type restriction for RefetchQueriesOptions
-- local ApolloCache = require(script.Parent.Parent.cache).ApolloCache

-- ROBLOX TODO: use import when FetchResult is implemented
-- local FetchResult = require(script.Parent.Parent.link.core).FetchResult
type FetchResult<TData> = any
-- ROBLOX TODO: should be equivalent to:
-- type FetchResultWithoutContext = Omit<FetchResult<TData>, 'context'>
type FetchResultWithoutContext<TData> = FetchResult<TData>

-- ROBLOX TODO: use import when ApolloError is implemented
-- local ApolloError = require(script.Parent.Parent.errors).ApolloError
type ApolloError = any

-- ROBLOX TODO: use import when QueryInfo is implemented
-- local QueryInfo = require(script.Parent.QueryInfo).QueryInfo
type QueryInfo = any

-- ROBLOX TODO: use import when NetworkStatus is implemented
-- local NetworkStatus = require(script.Parent.networkStatus).NetworkStatus
type NetworkStatus = any

-- ROBLOX TODO: use import when Resolver is implemented
-- local Resolver = require(script.Parent.LocalState).Resolver
type Resolver = any

-- ROBLOX TODO: use import when ObservableQuery is implemented
-- local ObservableQuery = require(script.Parent.ObservableQuery).ObservableQuery
type ObservableQuery<T> = any

-- ROBLOX comment: moved to different file to solve circular dependency issue
local watchQueryOptionsModule = require(script.Parent.watchQueryOptions_types)
type QueryOptions<TVariables, TData> = watchQueryOptionsModule.QueryOptions<TVariables, TData>

-- ROBLOX TODO: use import when Cache namespace is implemented
-- ROBLOX deviation: Luau doesn't support namespaces
-- local Cache = require(script.Parent.Parent.cache).Cache
type Cache_DiffResult<any> = any

-- ROBLOX TODO: This type is used in tandem with the RefetchQueriesPromiseResults
-- typedef. It will need to be defined if we fully conform to upstreams implementation
-- of RefetchQueriesPromiseResults.
-- local IsStrictlyAny = require(script.Parent.Parent.utilities).IsStrictlyAny

-- ROBLOX deviation: creating typescripts Record<T, U> type
export type Record<T, U> = { [T]: U }

local typedDocumentNodeModule = require(srcWorkspace.jsutils.typedDocumentNode)
export type TypedDocumentNode<Result, Variables> = typedDocumentNodeModule.TypedDocumentNode<Result, Variables>

export type DefaultContext = Record<string, any>

export type QueryListener = (QueryInfo) -> nil

export type OnQueryUpdated<TResult> = (
	ObservableQuery<any>,
	Cache_DiffResult<any>,
	Cache_DiffResult<any> | nil
) -> boolean | TResult

export type RefetchQueryDescriptor = string | DocumentNode
export type InternalRefetchQueryDescriptor = RefetchQueryDescriptor | QueryOptions<any, any>

-- ROBLOX deviation: type RefetchQueriesIncludeShorthand = "all" | "active"
type RefetchQueriesIncludeShorthand = string

export type RefetchQueriesInclude = Array<RefetchQueryDescriptor> | RefetchQueriesIncludeShorthand

export type InternalRefetchQueriesInclude = Array<InternalRefetchQueryDescriptor> | RefetchQueriesIncludeShorthand

-- ROBLOX deviation: can't restrict generic params
-- export interface RefetchQueriesOptions<
--   TCache extends ApolloCache<any>,
--   TResult,
-- >
-- Used by ApolloClient["refetchQueries"]
-- TODO Improve documentation comments for this public type.
export type RefetchQueriesOptions<TCache, TResult> = {
	updateCache: ((TCache) -> nil)?,
	-- The client.refetchQueries method discourages passing QueryOptions, by
	-- restricting the public type of options.include to exclude QueryOptions as
	-- an available array element type (see InternalRefetchQueriesInclude for a
	-- version of RefetchQueriesInclude that allows legacy QueryOptions objects).
	include: RefetchQueriesInclude?,
	optimistic: boolean?,
	-- If no onQueryUpdated function is provided, any queries affected by the
	-- updateCache function or included in the options.include array will be
	-- refetched by default. Passing null instead of undefined disables this
	-- default refetching behavior for affected queries, though included queries
	-- will still be refetched.
	onQueryUpdated: (OnQueryUpdated<TResult> | nil)?,
}

-- ROBLOX deviation: setting type as any
--
-- The client.refetchQueries method returns a thenable (PromiseLike) object
-- whose result is an array of Promise.resolve'd TResult values, where TResult
-- is whatever type the (optional) onQueryUpdated function returns. When no
-- onQueryUpdated function is given, TResult defaults to ApolloQueryResult<any>
-- (thanks to default type parameters for client.refetchQueries).
--
-- export type RefetchQueriesPromiseResults<TResult> =
--
-- If onQueryUpdated returns any, all bets are off, so the results array must
-- be a generic any[] array, which is much less confusing than the union type
-- we get if we don't check for any. I hoped `any extends TResult` would do
-- the trick here, instead of IsStrictlyAny, but you can see for yourself what
-- fails in the refetchQueries tests if you try making that simplification.
--
--   IsStrictlyAny<TResult> extends true
--     ? any[]
--
-- If the onQueryUpdated function passed to client.refetchQueries returns true
-- or false, that means either to refetch the query (true) or to skip the
-- query (false). Since refetching produces an ApolloQueryResult<any>, and
-- skipping produces nothing, the fully-resolved array of all results produced
-- will be an ApolloQueryResult<any>[], when TResult extends boolean.
--
--     : TResult extends boolean
--     ? ApolloQueryResult<any>[]
--
-- If onQueryUpdated returns a PromiseLike<U>, that thenable will be passed as
-- an array element to Promise.all, so we infer/unwrap the array type U here.
--
--     : TResult extends PromiseLike<infer U>
--     ? U[]
--
-- All other onQueryUpdated results end up in the final Promise.all array as
-- themselves, with their original TResult type. Note that TResult will
-- default to ApolloQueryResult<any> if no onQueryUpdated function is passed
-- to client.refetchQueries.
--
--     : TResult[];

export type RefetchQueriesPromiseResults<TResult> = Array<TResult>

-- The result of client.refetchQueries is thenable/awaitable, if you just want
-- an array of fully resolved results, but you can also access the raw results
-- immediately by examining the additional { queries, results } properties of
-- the RefetchQueriesResult<TResult> object.
export type RefetchQueriesResult<TResult> = Promise<RefetchQueriesPromiseResults<TResult>> & {
	-- An array of ObservableQuery objects corresponding 1:1 to TResult values
	-- in the results arrays (both the TResult[] array below, and the results
	-- array resolved by the Promise above).
	queries: Array<ObservableQuery<any>>,
	-- These are the raw TResult values returned by any onQueryUpdated functions
	-- that were invoked by client.refetchQueries.
	results: Array<InternalRefetchQueriesResult<TResult>>,
}

-- ROBLOX deviation: Luau doesn't have Omit type util so we need to be more verbose
-- Omit<RefetchQueriesOptions<TCache, TResult>, "include">
type RefetchQueriesOptionsWithoutInclude<TCache, TResult> = {
	updateCache: ((TCache) -> nil)?,
	optimistic: boolean?,
	onQueryUpdated: (OnQueryUpdated<TResult> | nil)?,
}
export type InternalRefetchQueriesOptions<TCache, TResult> = RefetchQueriesOptionsWithoutInclude<TCache, TResult> & {
	-- Just like the refetchQueries option for a mutation, an array of strings,
	-- DocumentNode objects, and/or QueryOptions objects, or one of the shorthand
	-- strings "all" or "active", to select every (active) query.
	include: InternalRefetchQueriesInclude?,
	-- This part of the API is a (useful) implementation detail, but need not be
	-- exposed in the public client.refetchQueries API (above).
	removeOptimistic: string?,
}

export type InternalRefetchQueriesResult<TResult> = TResult | Promise<ApolloQueryResult<any>>

export type InternalRefetchQueriesMap<TResult> = Map<ObservableQuery<any>, InternalRefetchQueriesResult<TResult>>

-- TODO Remove this unnecessary type in Apollo Client 4.
export type PureQueryOptions = QueryOptions<any, any>

export type OperationVariables = Record<string, any>

export type ApolloQueryResult<T> = {
	data: T,
	errors: Array<GraphQLError>?,
	error: ApolloError?,
	loading: boolean,
	networkStatus: NetworkStatus,
	-- If result.data was read from the cache with missing fields,
	-- result.partial will be true. Otherwise, result.partial will be falsy
	-- (usually because the property is absent from the result object).
	partial: boolean?,
}

-- This is part of the public API, people write these functions in `updateQueries`.
export type MutationQueryReducer<T> = (
	Record<string, any>,
	{ mutationResult: FetchResult<T>, queryName: string | nil, queryVariables: Record<string, any> }
) -> Record<string, any>

export type MutationQueryReducersMap<T> = { [string]: MutationQueryReducer<T> }

-- ROBLOX deviation: Luau doesn't have Omit type util so we need to be more verbose
-- Omit<FetchResult<TData>, 'context'>
export type MutationUpdaterFunction<TData, TVariables, TContext, TCache> = (
	TCache,
	FetchResultWithoutContext<TData>,
	{ context: TContext?, variables: TVariables? }
) -> nil

export type Resolvers = { [string]: { [string]: Resolver } }

return {}
