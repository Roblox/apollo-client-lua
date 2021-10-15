-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/ApolloClient.ts

local exports = {}
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean, Object, setTimeout = LuauPolyfill.Boolean, LuauPolyfill.Object, LuauPolyfill.setTimeout

type Array<T> = LuauPolyfill.Array<T>
type Object = LuauPolyfill.Object

local GraphQL = require(rootWorkspace.GraphQL)
type ExecutionResult = GraphQL.ExecutionResult
type DocumentNode = GraphQL.DocumentNode

-- ROBLOX TODO: need to remove _ when we use invariant
local _invariant = require(srcWorkspace.jsutils.invariant).invariant

--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import { ApolloLink, FetchResult, GraphQLRequest, execute } from '../link/core'; ]]
type ApolloLink = { [string]: any }

--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import { ApolloCache, DataProxy } from '../cache'; ]]
type ApolloCache<TCacheShape> = { [string]: any }

--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import { Observable, compact } from '../utilities'; ]]
local compact = require(srcWorkspace.utilities).compact
local version_ = require(srcWorkspace.version)

--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import { HttpLink, UriFunction } from '../link/http'; ]]
type UriFunction = ({ [string]: any }) -> string

--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import { QueryManager } from './QueryManager'; ]]
--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import { ObservableQuery } from './ObservableQuery'; ]]

local coreTypesModule = require(srcWorkspace.core.types)
type ApolloQueryResult<T> = coreTypesModule.ApolloQueryResult<T>
type DefaultContext = coreTypesModule.DefaultContext
type OperationVariables = coreTypesModule.OperationVariables
type Resolvers = coreTypesModule.Resolvers
type RefetchQueriesOptions<TCache, TResult> = coreTypesModule.RefetchQueriesOptions<TCache, TResult>
type RefetchQueriesResult<TResult> = coreTypesModule.RefetchQueriesResult<TResult>
type InternalRefetchQueriesResult<TResult> = coreTypesModule.InternalRefetchQueriesResult<TResult>
type RefetchQueriesInclude = coreTypesModule.RefetchQueriesInclude

--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import {
  QueryOptions,
  WatchQueryOptions,
  MutationOptions,
  SubscriptionOptions,
  WatchQueryFetchPolicy,
} from './watchQueryOptions'; ]]

--[[ ROBLOX TODO: Unhandled node for type: ImportDeclaration ]]
--[[ import {
  LocalState,
  FragmentMatcher,
} from './LocalState'; ]]
-- ROBLOX todo: import fragment matcher when we convert ./LocalState
type FragmentMatcher = (rootValue: any, typeCondition: string, context: any) -> boolean

-- ROBLOX TODO: convert DefaultOptions when we implement these types
-- export type DefaultOptions = {
--   watchQuery: Partial<WatchQueryOptions<any, any>>,
--   query: Partial<QueryOptions<any, any>>,
--   mutate: Partial<MutationOptions<any, any, any>>,
-- }
export type DefaultOptions = { [string]: any }

local _hasSuggestedDevtools = false
export type ApolloClientOptions<TCacheShape> = {
	uri: string? | UriFunction?,
	credentials: string?,
	-- headers: Record<string, string>?,
	headers: { [string]: string }?,
	link: ApolloLink?,
	-- ROBLOX deviation: TEMPORARILY setting cache to potentially nil until we convert InMemoryCache
	cache: ApolloCache<TCacheShape>?,
	ssrForceFetchDelay: number?,
	ssrMode: boolean?,
	connectToDevTools: boolean?,
	queryDeduplication: boolean?,
	defaultOptions: DefaultOptions?,
	assumeImmutableResults: boolean?,
	resolvers: Resolvers? | Array<Resolvers>?,
	typeDefs: string? | Array<string>? | DocumentNode? | Array<DocumentNode>?,
	fragmentMatcher: FragmentMatcher?,
	name: string?,
	version: string?,
}
type OptionsUnion = Object

local function mergeOptions(defaults: any, options: any): any
	return compact(
		defaults,
		options,
		Boolean.toJSBoolean(options.variables)
				and { variables = Object.assign({}, defaults.variables, options.variables) }
			or options.variables
	)
end
exports.mergeOptions = mergeOptions

--[[ ROBLOX TODO: Unhandled node for type: ExportNamedDeclaration ]]
--[[ export class ApolloClient<TCacheShape> implements DataProxy {
  public link: ApolloLink;
  public cache: ApolloCache<TCacheShape>;
  public disableNetworkFetches: boolean;
  public version: string;
  public queryDeduplication: boolean;
  public defaultOptions: DefaultOptions = {};
  public readonly typeDefs: ApolloClientOptions<TCacheShape>['typeDefs'];

  private queryManager: QueryManager<TCacheShape>;
  private devToolsHookCb: Function;
  private resetStoreCallbacks: Array<() => Promise<any>> = [];
  private clearStoreCallbacks: Array<() => Promise<any>> = [];
  private localState: LocalState<TCacheShape>;
]]

export type ApolloClient<TCacheShape> = {
	link: ApolloLink,
	cache: ApolloCache<TCacheShape>,
	disableNetworkFetches: boolean,
	version: string,
	queryDeduplication: boolean,
	defaultOptions: DefaultOptions,
	typeDefs: string? | Array<string>? | DocumentNode? | Array<DocumentNode>?,
}

local ApolloClient = {}
ApolloClient.__index = ApolloClient

--[[
/**
   * Constructs an instance of {@link ApolloClient}.
   *
   * @param uri The GraphQL endpoint that Apollo Client will connect to. If
   *            `link` is configured, this option is ignored.
   * @param link The {@link ApolloLink} over which GraphQL documents will be resolved into a response.
   *
   * @param cache The initial cache to use in the data store.
   *
   * @param ssrMode Determines whether this is being run in Server Side Rendering (SSR) mode.
   *
   * @param ssrForceFetchDelay Determines the time interval before we force fetch queries for a
   * server side render.
   *
   * @param queryDeduplication If set to false, a query will still be sent to the server even if a query
   * with identical parameters (query, variables, operationName) is already in flight.
   *
   * @param defaultOptions Used to set application wide defaults for the
   *                       options supplied to `watchQuery`, `query`, or
   *                       `mutate`.
   *
   * @param assumeImmutableResults When this option is true, the client will assume results
   *                               read from the cache are never mutated by application code,
   *                               which enables substantial performance optimizations. Passing
   *                               `{ freezeResults: true }` to the `InMemoryCache` constructor
   *                               can help enforce this immutability.
   *
   * @param name A custom name that can be used to identify this client, when
   *             using Apollo client awareness features. E.g. "iOS".
   *
   * @param version A custom version that can be used to identify this client,
   *                when using Apollo client awareness features. This is the
   *                version of your client, which you may want to increment on
   *                new builds. This is NOT the version of Apollo Client that
   *                you are using.
   */
]]
function ApolloClient.new(options: ApolloClientOptions<{ [string]: any }>): ApolloClient<{ [string]: any }>
	local self = setmetatable({}, ApolloClient)

	-- ROBLOX TODO: remove _ from these variables when we use them
	local _uri = options.uri
	local _credentials = options.credentials
	local _headers = options.headers
	local cache = options.cache
	local ssrMode = options.ssrMode or false
	local ssrForceFetchDelay = options.ssrForceFetchDelay or 0
	-- ROBLOX deviation: there is no window object, this defaults to false
	local _connectToDevTools = options.connectToDevTools or false
	local queryDeduplication = options.queryDeduplication or true
	local defaultOptions = options.defaultOptions
	local _assumeImmutableResults = options.assumeImmutableResults or false
	local _resolvers = options.resolvers
	local typeDefs = options.typeDefs
	local _fragmentMatcher = options.fragmentMatcher
	local _clientAwarenessName = options.name
	local _clientAwarenessVersion = options.version

	local link = options.link

	-- ROBLOX TODO: will convert this when we convert ApolloLink and HttpLink
	--[[
  if (!link) {
    link = uri
    ? new HttpLink({ uri, credentials, headers })
    : ApolloLink.empty();
  }
  ]]

	-- ROBLOX todo: when we convert and use ApolloCache, we can uncomment this
	-- invariant(
	-- 	cache,
	-- 	"To initialize Apollo Client, you must specify a 'cache' property "
	-- 		.. "in the options object. \n"
	-- 		.. "For more information, please visit: https://go.apollo.dev/c/docs"
	-- )

	self.link = link
	self.cache = cache
	self.disableNetworkFetches = ssrMode or (ssrForceFetchDelay > 0)
	self.queryDeduplication = queryDeduplication
	self.defaultOptions = defaultOptions or {}
	self.typeDefs = typeDefs

	if ssrForceFetchDelay then
		setTimeout(function()
			self.disableNetworkFetches = false
		end, ssrForceFetchDelay)
	end

	-- ROBLOX deviation: the functions dont need to be bound to lua tables
	--[[
  this.watchQuery = this.watchQuery.bind(this);
  this.query = this.query.bind(this);
  this.mutate = this.mutate.bind(this);
  this.resetStore = this.resetStore.bind(this);
  this.reFetchObservableQueries = this.reFetchObservableQueries.bind(this);
  ]]

	-- ROBLOX deviation: no window in Roblox environment
	--[[
  if (connectToDevTools && typeof window === 'object') {
    (window as any).__APOLLO_CLIENT__ = this;
  }
  ]]

	-- ROBLOX deviation: no devtools
	--[[
  /**
    * Suggest installing the devtools for developers who don't have them
    */
  if (!hasSuggestedDevtools && __DEV__) {
    hasSuggestedDevtools = true;
    if (
      typeof window !== 'undefined' &&
      window.document &&
      window.top === window.self &&
      !(window as any).__APOLLO_DEVTOOLS_GLOBAL_HOOK__
    ) {
      const nav = window.navigator;
      const ua = nav && nav.userAgent;
      let url: string | undefined;
      if (typeof ua === "string") {
        if (ua.indexOf("Chrome/") > -1) {
          url = "https://chrome.google.com/webstore/detail/" +
            "apollo-client-developer-t/jdkknkkbebbapilgoeccciglkfbmbnfm";
        } else if (ua.indexOf("Firefox/") > -1) {
          url = "https://addons.mozilla.org/en-US/firefox/addon/apollo-developer-tools/";
        }
      }
      if (url) {
        invariant.log(
          "Download the Apollo DevTools for a better development " +
            "experience: " + url
        );
      }
    }
  }
  ]]

	self.version = version_

	-- ROBLOX TODO: will convert this when we convert LocalState
	--[[
  this.localState = new LocalState({
    cache,
    client: this,
    resolvers,
    fragmentMatcher,
  });
  ]]

	-- ROBLOX TODO: will convert this when we convert QueryManager
	--[[
  this.queryManager = new QueryManager({
    cache: this.cache,
    link: this.link,
    queryDeduplication,
    ssrMode,
    clientAwareness: {
      name: clientAwarenessName!,
      version: clientAwarenessVersion!,
    },
    localState: this.localState,
    assumeImmutableResults,
    onBroadcast: connectToDevTools ? () => {
      if (this.devToolsHookCb) {
        this.devToolsHookCb({
          action: {},
          state: {
            queries: this.queryManager.getQueryStore(),
            mutations: this.queryManager.mutationStore || {},
          },
          dataWithOptimisticResults: this.cache.extract(true),
        });
      }
    } : void 0,
  });
  ]]

	return (self :: any) :: ApolloClient<{ [string]: any }>
end

--[[
  /**
   * Call this method to terminate any active client processes, making it safe
   * to dispose of this `ApolloClient` instance.
   */
  public stop() {
    this.queryManager.stop();
  }

  /**
   * This watches the cache store of the query according to the options specified and
   * returns an {@link ObservableQuery}. We can subscribe to this {@link ObservableQuery} and
   * receive updated results through a GraphQL observer when the cache store changes.
   * <p /><p />
   * Note that this method is not an implementation of GraphQL subscriptions. Rather,
   * it uses Apollo's store in order to reactively deliver updates to your query results.
   * <p /><p />
   * For example, suppose you call watchQuery on a GraphQL query that fetches a person's
   * first and last name and this person has a particular object identifer, provided by
   * dataIdFromObject. Later, a different query fetches that same person's
   * first and last name and the first name has now changed. Then, any observers associated
   * with the results of the first query will be updated with a new result object.
   * <p /><p />
   * Note that if the cache does not change, the subscriber will *not* be notified.
   * <p /><p />
   * See [here](https://medium.com/apollo-stack/the-concepts-of-graphql-bc68bd819be3#.3mb0cbcmc) for
   * a description of store reactivity.
   */
  public watchQuery<T = any, TVariables = OperationVariables>(
    options: WatchQueryOptions<TVariables, T>,
  ): ObservableQuery<T, TVariables> {
    if (this.defaultOptions.watchQuery) {
      options = mergeOptions(this.defaultOptions.watchQuery, options);
    }

    // XXX Overwriting options is probably not the best way to do this long term...
    if (
      this.disableNetworkFetches &&
      (options.fetchPolicy === 'network-only' ||
        options.fetchPolicy === 'cache-and-network')
    ) {
      options = { ...options, fetchPolicy: 'cache-first' };
    }

    return this.queryManager.watchQuery<T, TVariables>(options);
  }

  /**
   * This resolves a single query according to the options specified and
   * returns a {@link Promise} which is either resolved with the resulting data
   * or rejected with an error.
   *
   * @param options An object of type {@link QueryOptions} that allows us to
   * describe how this query should be treated e.g. whether it should hit the
   * server at all or just resolve from the cache, etc.
   */
  public query<T = any, TVariables = OperationVariables>(
    options: QueryOptions<TVariables, T>,
  ): Promise<ApolloQueryResult<T>> {
    if (this.defaultOptions.query) {
      options = mergeOptions(this.defaultOptions.query, options);
    }

    invariant(
      (options.fetchPolicy as WatchQueryFetchPolicy) !== 'cache-and-network',
      'The cache-and-network fetchPolicy does not work with client.query, because ' +
      'client.query can only return a single result. Please use client.watchQuery ' +
      'to receive multiple results from the cache and the network, or consider ' +
      'using a different fetchPolicy, such as cache-first or network-only.'
    );

    if (this.disableNetworkFetches && options.fetchPolicy === 'network-only') {
      options = { ...options, fetchPolicy: 'cache-first' };
    }

    return this.queryManager.query<T, TVariables>(options);
  }

  /**
   * This resolves a single mutation according to the options specified and returns a
   * {@link Promise} which is either resolved with the resulting data or rejected with an
   * error.
   *
   * It takes options as an object with the following keys and values:
   */
  public mutate<
    TData = any,
    TVariables = OperationVariables,
    TContext = DefaultContext,
    TCache extends ApolloCache<any> = ApolloCache<any>
  >(
    options: MutationOptions<TData, TVariables, TContext>,
  ): Promise<FetchResult<TData>> {
    if (this.defaultOptions.mutate) {
      options = mergeOptions(this.defaultOptions.mutate, options);
    }
    return this.queryManager.mutate<TData, TVariables, TContext, TCache>(options);
  }

  /**
   * This subscribes to a graphql subscription according to the options specified and returns an
   * {@link Observable} which either emits received data or an error.
   */
  public subscribe<T = any, TVariables = OperationVariables>(
    options: SubscriptionOptions<TVariables, T>,
  ): Observable<FetchResult<T>> {
    return this.queryManager.startGraphQLSubscription<T>(options);
  }

  /**
   * Tries to read some data from the store in the shape of the provided
   * GraphQL query without making a network request. This method will start at
   * the root query. To start at a specific id returned by `dataIdFromObject`
   * use `readFragment`.
   *
   * @param optimistic Set to `true` to allow `readQuery` to return
   * optimistic results. Is `false` by default.
   */
  public readQuery<T = any, TVariables = OperationVariables>(
    options: DataProxy.Query<TVariables, T>,
    optimistic: boolean = false,
  ): T | null {
    return this.cache.readQuery<T, TVariables>(options, optimistic);
  }

  /**
   * Tries to read some data from the store in the shape of the provided
   * GraphQL fragment without making a network request. This method will read a
   * GraphQL fragment from any arbitrary id that is currently cached, unlike
   * `readQuery` which will only read from the root query.
   *
   * You must pass in a GraphQL document with a single fragment or a document
   * with multiple fragments that represent what you are reading. If you pass
   * in a document with multiple fragments then you must also specify a
   * `fragmentName`.
   *
   * @param optimistic Set to `true` to allow `readFragment` to return
   * optimistic results. Is `false` by default.
   */
  public readFragment<T = any, TVariables = OperationVariables>(
    options: DataProxy.Fragment<TVariables, T>,
    optimistic: boolean = false,
  ): T | null {
    return this.cache.readFragment<T, TVariables>(options, optimistic);
  }

  /**
   * Writes some data in the shape of the provided GraphQL query directly to
   * the store. This method will start at the root query. To start at a
   * specific id returned by `dataIdFromObject` then use `writeFragment`.
   */
  public writeQuery<TData = any, TVariables = OperationVariables>(
    options: DataProxy.WriteQueryOptions<TData, TVariables>,
  ): void {
    this.cache.writeQuery<TData, TVariables>(options);
    this.queryManager.broadcastQueries();
  }

  /**
   * Writes some data in the shape of the provided GraphQL fragment directly to
   * the store. This method will write to a GraphQL fragment from any arbitrary
   * id that is currently cached, unlike `writeQuery` which will only write
   * from the root query.
   *
   * You must pass in a GraphQL document with a single fragment or a document
   * with multiple fragments that represent what you are writing. If you pass
   * in a document with multiple fragments then you must also specify a
   * `fragmentName`.
   */
  public writeFragment<TData = any, TVariables = OperationVariables>(
    options: DataProxy.WriteFragmentOptions<TData, TVariables>,
  ): void {
    this.cache.writeFragment<TData, TVariables>(options);
    this.queryManager.broadcastQueries();
  }

  public __actionHookForDevTools(cb: () => any) {
    this.devToolsHookCb = cb;
  }

  public __requestRaw(payload: GraphQLRequest): Observable<ExecutionResult> {
    return execute(this.link, payload);
  }

  /**
   * Resets your entire store by clearing out your cache and then re-executing
   * all of your active queries. This makes it so that you may guarantee that
   * there is no data left in your store from a time before you called this
   * method.
   *
   * `resetStore()` is useful when your user just logged out. You’ve removed the
   * user session, and you now want to make sure that any references to data you
   * might have fetched while the user session was active is gone.
   *
   * It is important to remember that `resetStore()` *will* refetch any active
   * queries. This means that any components that might be mounted will execute
   * their queries again using your network interface. If you do not want to
   * re-execute any queries then you should make sure to stop watching any
   * active queries.
   */
  public resetStore(): Promise<ApolloQueryResult<any>[] | null> {
    return Promise.resolve()
      .then(() => this.queryManager.clearStore())
      .then(() => Promise.all(this.resetStoreCallbacks.map(fn => fn())))
      .then(() => this.reFetchObservableQueries());
  }

  /**
   * Remove all data from the store. Unlike `resetStore`, `clearStore` will
   * not refetch any active queries.
   */
  public clearStore(): Promise<any[]> {
    return Promise.resolve()
      .then(() => this.queryManager.clearStore())
      .then(() => Promise.all(this.clearStoreCallbacks.map(fn => fn())));
  }

  /**
   * Allows callbacks to be registered that are executed when the store is
   * reset. `onResetStore` returns an unsubscribe function that can be used
   * to remove registered callbacks.
   */
  public onResetStore(cb: () => Promise<any>): () => void {
    this.resetStoreCallbacks.push(cb);
    return () => {
      this.resetStoreCallbacks = this.resetStoreCallbacks.filter(c => c !== cb);
    };
  }

  /**
   * Allows callbacks to be registered that are executed when the store is
   * cleared. `onClearStore` returns an unsubscribe function that can be used
   * to remove registered callbacks.
   */
  public onClearStore(cb: () => Promise<any>): () => void {
    this.clearStoreCallbacks.push(cb);
    return () => {
      this.clearStoreCallbacks = this.clearStoreCallbacks.filter(c => c !== cb);
    };
  }

  /**
   * Refetches all of your active queries.
   *
   * `reFetchObservableQueries()` is useful if you want to bring the client back to proper state in case of a network outage
   *
   * It is important to remember that `reFetchObservableQueries()` *will* refetch any active
   * queries. This means that any components that might be mounted will execute
   * their queries again using your network interface. If you do not want to
   * re-execute any queries then you should make sure to stop watching any
   * active queries.
   * Takes optional parameter `includeStandby` which will include queries in standby-mode when refetching.
   */
  public reFetchObservableQueries(
    includeStandby?: boolean,
  ): Promise<ApolloQueryResult<any>[]> {
    return this.queryManager.reFetchObservableQueries(includeStandby);
  }

  /**
   * Refetches specified active queries. Similar to "reFetchObservableQueries()" but with a specific list of queries.
   *
   * `refetchQueries()` is useful for use cases to imperatively refresh a selection of queries.
   *
   * It is important to remember that `refetchQueries()` *will* refetch specified active
   * queries. This means that any components that might be mounted will execute
   * their queries again using your network interface. If you do not want to
   * re-execute any queries then you should make sure to stop watching any
   * active queries.
   * Takes optional parameter `includeStandby` which will include queries in standby-mode when refetching.
   */
  public refetchQueries<
    TCache extends ApolloCache<any> = ApolloCache<TCacheShape>,
    TResult = Promise<ApolloQueryResult<any>>,
  >(
    options: RefetchQueriesOptions<TCache, TResult>,
  ): RefetchQueriesResult<TResult> {
    const map = this.queryManager.refetchQueries(options);
    const queries: ObservableQuery<any>[] = [];
    const results: InternalRefetchQueriesResult<TResult>[] = [];

    map.forEach((result, obsQuery) => {
      queries.push(obsQuery);
      results.push(result);
    });

    const result = Promise.all<TResult>(
      results as TResult[]
    ) as RefetchQueriesResult<TResult>;

    // In case you need the raw results immediately, without awaiting
    // Promise.all(results):
    result.queries = queries;
    result.results = results;

    return result;
  }

  /**
   * Get all currently active `ObservableQuery` objects, in a `Map` keyed by
   * query ID strings. An "active" query is one that has observers and a
   * `fetchPolicy` other than "standby" or "cache-only". You can include all
   * `ObservableQuery` objects (including the inactive ones) by passing "all"
   * instead of "active", or you can include just a subset of active queries by
   * passing an array of query names or DocumentNode objects.
   */
  public getObservableQueries(
    include: RefetchQueriesInclude = "active",
  ): Map<string, ObservableQuery<any>> {
    return this.queryManager.getObservableQueries(include);
  }

  /**
   * Exposes the cache's complete state, in a serializable format for later restoration.
   */
  public extract(optimistic?: boolean): TCacheShape {
    return this.cache.extract(optimistic);
  }

  /**
   * Replaces existing state in the cache (if any) with the values expressed by
   * `serializedState`.
   *
   * Called when hydrating a cache (server side rendering, or offline storage),
   * and also (potentially) during hot reloads.
   */
  public restore(serializedState: TCacheShape): ApolloCache<TCacheShape> {
    return this.cache.restore(serializedState);
  }

  /**
   * Add additional local resolvers.
   */
  public addResolvers(resolvers: Resolvers | Resolvers[]) {
    this.localState.addResolvers(resolvers);
  }

  /**
   * Set (override existing) local resolvers.
   */
  public setResolvers(resolvers: Resolvers | Resolvers[]) {
    this.localState.setResolvers(resolvers);
  }

  /**
   * Get all registered local resolvers.
   */
  public getResolvers() {
    return this.localState.getResolvers();
  }

  /**
   * Set a custom local state fragment matcher.
   */
  public setLocalStateFragmentMatcher(fragmentMatcher: FragmentMatcher) {
    this.localState.setFragmentMatcher(fragmentMatcher);
  }

  /**
   * Define a new ApolloLink (or link chain) that Apollo Client will use.
   */
  public setLink(newLink: ApolloLink) {
    this.link = this.queryManager.link = newLink;
  }
} ]]
exports.ApolloClient = ApolloClient

return exports
