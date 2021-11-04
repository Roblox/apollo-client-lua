-- ROBLOX comment: created to solve a circular dependency issue
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
type Error = LuauPolyfill.Error
type Object = LuauPolyfill.Object
type Record<T, U> = { [T]: U }

local graphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphQLModule.DocumentNode

local typedDocumentNodeModule = require(srcWorkspace.jsutils.typedDocumentNode)
type TypedDocumentNode<Result, Variables> = typedDocumentNodeModule.TypedDocumentNode<Result, Variables>

--[[
  /**
 * fetchPolicy determines where the client may return a result from. The options are:
 * - cache-first (default): return result from cache. Only fetch from network if cached result is not available.
 * - cache-and-network: return result from cache first (if it exists), then return network result once it's available.
 * - cache-only: return result from cache if available, fail otherwise.
 * - no-cache: return result from network, fail if network call doesn't succeed, don't save to cache
 * - network-only: return result from network, fail if network call doesn't succeed, save to cache
 * - standby: only for queries that aren't actively watched, but should be available for refetch and updateQueries.
 */
]]
-- ROBLOX deviation :
-- export type FetchPolicy =| 'cache-first'| 'network-only'| 'cache-only'| 'no-cache'| 'standby'
export type FetchPolicy = string

-- ROBLOX deviation :
-- export type ErrorPolicy = 'none' | 'ignore' | 'all';
export type ErrorPolicy = string

export type QueryOptions<TVariables, TData> = {
	--[[
    /**
     * A GraphQL document that consists of a single query to be sent down to the
     * server.
     */
    // TODO REFACTOR: rename this to document. Didn't do it yet because it's in a
    // lot of tests.
  ]]
	query: DocumentNode | TypedDocumentNode<TData, TVariables>,
	--[[
  /**
   * A map going from variable name to variable value, where the variables are used
   * within the GraphQL query.
   */

]]
	variables: TVariables?,
	--[[
  /**
   * Specifies the {@link ErrorPolicy} to be used for this query
   */
]]
	errorPolicy: ErrorPolicy?,
	--[[
  /**
   * Context to be passed to link execution chain
   */
]]
	context: any?,
	--[[
  /**
   * Specifies the {@link FetchPolicy} to be used for this query
   */
]]
	fetchPolicy: FetchPolicy?,
	--[[
  /**
   * The time interval (in milliseconds) on which this query should be
   * refetched from the server.
   */
]]
	pollInterval: number?,
	--[[
  /**
   * Whether or not updates to the network status should trigger next on the observer of this query
   */
]]
	notifyOnNetworkStatusChange: boolean?,
	--[[
  /**
   * Allow returning incomplete data from the cache when a larger query cannot
   * be fully satisfied by the cache, instead of returning nothing.
   */
]]
	returnPartialData: boolean?,
	--[[
    /**
     * If `true`, perform a query `refetch` if the query result is marked as
     * being partial, and the returned data is reset to an empty Object by the
     * Apollo Client `QueryManager` (due to a cache miss).
     */
  ]]
	partialRefetch: boolean?,
	--[[
  /**
   * Whether to canonize cache results before returning them. Canonization
   * takes some extra time, but it speeds up future deep equality comparisons.
   * Defaults to true.
   */
]]
	canonizeResults: boolean?,
}

export type QueryOptions_omit_fetchPolicy<TVariables, TData> = {
	query: typeof((({} :: any) :: QueryOptions<TVariables, TData>).query),
	variables: typeof((({} :: any) :: QueryOptions<TVariables, TData>).variables),
	errorPolicy: typeof((({} :: any) :: QueryOptions<TVariables, TData>).errorPolicy),
	context: typeof((({} :: any) :: QueryOptions<TVariables, TData>).context),
	pollInterval: typeof((({} :: any) :: QueryOptions<TVariables, TData>).pollInterval),
	notifyOnNetworkStatusChange: typeof((({} :: any) :: QueryOptions<TVariables, TData>).notifyOnNetworkStatusChange),
	returnPartialData: typeof((({} :: any) :: QueryOptions<TVariables, TData>).returnPartialData),
	partialRefetch: typeof((({} :: any) :: QueryOptions<TVariables, TData>).partialRefetch),
	canonizeResults: typeof((({} :: any) :: QueryOptions<TVariables, TData>).canonizeResults),
}

export type WatchQueryOptions<TVariables, TData> = QueryOptions_omit_fetchPolicy<TVariables, TData> & {
	--[[
    /**
     * Specifies the {@link FetchPolicy} to be used for this query.
     */
     ]]
	fetchPolicy: WatchQueryFetchPolicy?,
	--[[
    /**
     * Specifies the {@link FetchPolicy} to be used after this query has completed.
     */
  ]]
	nextFetchPolicy: any?, -- ROBLOX todo:  WatchQueryFetchPolicy | ((this: WatchQueryOptions<TVariables, TData>,lastFetchPolicy: WatchQueryFetchPolicy,) => WatchQueryFetchPolicy)
	--[[
    /**
     * Specifies whether a {@link NetworkStatus.refetch} operation should merge
     * incoming field data with existing data, or overwrite the existing data.
     * Overwriting is probably preferable, but merging is currently the default
     * behavior, for backwards compatibility with Apollo Client 3.x.
     */
  ]]
	refetchWritePolicy: RefetchWritePolicy?,
}

-- ROBLOX deviation
-- export type WatchQueryFetchPolicy = FetchPolicy | 'cache-and-network';
export type WatchQueryFetchPolicy = string
-- ROBLOX deviation
-- export type RefetchWritePolicy = "merge" | "overwrite";
export type RefetchWritePolicy = string

export type FetchMoreQueryOptions<TVariables, TData> = {
	query: (DocumentNode | TypedDocumentNode<TData, TVariables>)?,
	variables: any?, --ROBLOX deviation: Partial<TVariables>
	context: any?,
}

export type UpdateQueryFn<TData, TSubscriptionVariables, TSubscriptionData> = (
	previousQueryResult: TData,
	options: { subscriptionData: { data: TSubscriptionData }, variables: TSubscriptionVariables? }
) -> TData

-- ROBLOX deviation: this is the imported type that causes the circular dep, inline trivial
type DefaultContext = Record<string, any>
export type SubscribeToMoreOptions<TData, TSubscriptionVariables, TSubscriptionData> = {
	self: SubscribeToMoreOptions<TData, TSubscriptionVariables, TSubscriptionData>,
	document: DocumentNode | TypedDocumentNode<TSubscriptionData, TSubscriptionVariables>,
	variables: TSubscriptionVariables?,
	updateQuery: UpdateQueryFn<TData, TSubscriptionVariables, TSubscriptionData>?,
	onError: ((error: Error) -> ())?,
	context: DefaultContext?,
}

return {}
