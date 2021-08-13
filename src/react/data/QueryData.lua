-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/data/QueryData.ts
local exports = {}
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local Promise = require(rootWorkspace.Promise)
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean, Object = LuauPolyfill.Boolean, LuauPolyfill.Object
local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
type Promise<T> = PromiseTypeModule.Promise<T>
local hasOwnProperty = require(srcWorkspace.luaUtils.hasOwnProperty)
type Function = () -> ()

local equal = require(srcWorkspace.jsutils.equal)

local apolloErrorModule = require(srcWorkspace.errors)
local ApolloError = apolloErrorModule.ApolloError
type ApolloError = apolloErrorModule.ApolloError
local coreModule = require(script.Parent.Parent.Parent.core)
type ApolloClient<TCacheShape> = coreModule.ApolloClient<TCacheShape>
local NetworkStatus = coreModule.NetworkStatus

type FetchMoreQueryOptions<TVariables, TData> = coreModule.FetchMoreQueryOptions<TVariables, TData>

type ObservableQuery<TData, TVariables> = coreModule.ObservableQuery<TData, TVariables>

local applyNextFetchPolicy = coreModule.applyNextFetchPolicy

-- local SubscribeToMoreOptions = coreModule.SubscribeToMoreOptions

-- ROBLOX TODO use import when FetchMoreOptions is imported
-- local FetchMoreOptions = coreModule.FetchMoreOptions
type FetchMoreOptions<TData, TVariables> = any

-- ROBLOX TODO use import when UpdateQueryOptions is imported
-- local UpdateQueryOptions = coreModule.UpdateQueryOptions
type UpdateQueryOptions = any

-- ROBLOX TODO import from coreModule when available
local GraphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = GraphQLModule.DocumentNode

-- ROBLOX TODO import from coreModule when available
type TypedDocumentNode<Result, Variables> = coreModule.TypedDocumentNode<Result, Variables>

-- ROBLOX TODO use import when ObservableSubscription is imported
-- local ObservableSubscription = require(srcWorkspace.utilities).ObservableSubscription
type ObservableSubscription = any

local DocumentType = require(script.Parent.Parent.parser).DocumentType
local typesModule = require(script.Parent.Parent.types.types)
type QueryResult<TData, TVariables> = typesModule.QueryResult<TData, TVariables>
type QueryDataOptions<TData, TVariables> = typesModule.QueryDataOptions<TData, TVariables>
type QueryTupleAsReturnType<TData, TVariables> = typesModule.QueryTupleAsReturnType<TData, TVariables>
type QueryLazyOptions<TVariables> = typesModule.QueryLazyOptions<TVariables>
type ObservableQueryFields<TData, TVariables> = typesModule.ObservableQueryFields<TData, TVariables>
local operationDataModule = require(script.Parent.OperationData)
local OperationData = operationDataModule.OperationData
type OperationData<TOptions> = operationDataModule.OperationData<TOptions>

type QueryData<TData, TVariables> = OperationData<QueryDataOptions<TData, TVariables>> & {
	onNewData: ((self: QueryData<TData, TVariables>) -> ()),
	execute: ((self: QueryData<TData, TVariables>) -> QueryResult<TData, TVariables>),
	executeLazy: ((self: QueryData<TData, TVariables>) -> QueryTupleAsReturnType<TData, TVariables>),
	fetchData: ((self: QueryData<TData, TVariables>) -> Promise<nil> | boolean),
	afterExecute: ((self: QueryData<TData, TVariables>, ref: { lazy: boolean? }) -> any),
	cleanup: ((self: QueryData<TData, TVariables>) -> ()),
	getOptions: ((self: QueryData<TData, TVariables>) -> QueryDataOptions<TData, TVariables>),
	ssrInitiated: ((self: QueryData<TData, TVariables>) -> any),
}

local QueryData = setmetatable({}, { __index = OperationData })
QueryData.__index = QueryData

function QueryData.new(
	ref: { options: QueryDataOptions<any, any>, context: any, onNewData: Function }
): QueryData<any, any>
	local options, context, onNewData = ref.options, ref.context, ref.onNewData
	local self: any = OperationData.new(options, context)
	self.onNewData = onNewData

	self.runLazyQuery = function(options: QueryLazyOptions<any>?)
		self:cleanup()
		self.runLazy = true
		self.lazyOptions = options
		self:onNewData()
	end

	self.obsRefetch = function(variables: any?)
		if Boolean.toJSBoolean(self.currentObservable) then
			return self.currentObservable:refetch(variables)
		end
	end

	self.obsFetchmore = function(fetchMoreOptions: FetchMoreQueryOptions<any, any> & FetchMoreOptions<any, any>)
		return self.currentObservable:fetchMore(fetchMoreOptions)
	end

	-- ROBLOX deviation: there are no default generic params in Luau:
	-- <TVars = TVariables>(
	--     mapFn: (
	--       previousQueryResult: TData,
	--       options: UpdateQueryOptions<TVars>
	--     ) => TData
	--   )
	self.obsUpdateQuery = function(mapFn: any)
		return self.currentObservable:updateQuery(mapFn)
	end

	self.obsStartPolling = function(pollInterval: number)
		if Boolean.toJSBoolean(self.currentObservable) then
			return self.currentObservable:startPolling(pollInterval)
		end
	end

	self.obsStopPolling = function()
		if Boolean.toJSBoolean(self.currentObservable) then
			return self.currentObservable:stopPolling()
		end
	end

	-- ROBLOX deviation: there are no default generic params in Luau:
	-- <
	-- TSubscriptionData = TData,
	-- TSubscriptionVariables = TVariables
	-- >(
	-- options: SubscribeToMoreOptions<
	--   TData,
	--   TSubscriptionVariables,
	--   TSubscriptionData
	-- >
	-- )
	self.obsSubscribeToMore = function(options: any)
		return self.currentObservable:subscribeToMore(options)
	end

	return setmetatable(self, QueryData)
end

function QueryData:execute()
	self:refreshClient()
	local ref = self:getOptions()
	local skip, query: any = ref.skip, ref.query
	if skip or query ~= self.previous.query then
		self:removeQuerySubscription()
		self:removeObservable(not Boolean.toJSBoolean(skip))
		self.previous.query = query
	end
	self:updateObservableQuery()
	return self:getExecuteSsrResult() or self:getExecuteResult()
end

function QueryData:executeLazy(): any
	if not Boolean.toJSBoolean(self.runLazy) then
		return table.pack(
			self.runLazyQuery,
			{ loading = false, networkStatus = NetworkStatus.ready, called = false, data = nil }
		)
	else
		return table.pack(self.runLazyQuery, self:execute())
	end
end

-- // For server-side rendering
function QueryData:fetchData()
	local options = self:getOptions()
	if Boolean.toJSBoolean(Boolean.toJSBoolean(options.skip) and options.skip or options.ssr == false) then
		return false
	end
	return Promise.new(function(resolve)
		return self:startQuerySubscription(resolve)
	end)
end

function QueryData:afterExecute(ref: { lazy: boolean? })
	local lazy = ref.lazy or false
	self.isMounted = true
	local options = self:getOptions()
	local ssrDisabled = options.ssr == false

	if
		Boolean.toJSBoolean(self.currentObservable)
		and not Boolean.toJSBoolean(ssrDisabled)
		and not Boolean.toJSBoolean(self:ssrInitiated())
	then
		self:startQuerySubscription()
	end
	if not Boolean.toJSBoolean(lazy) or Boolean.toJSBoolean(self.runLazy) then
		self:handleErrorOrCompleted()
	end
	self.previousOptions = options
	return function(...)
		return self:unmount(...)
	end
end

function QueryData:cleanup()
	self:removeQuerySubscription()
	self:removeObservable(true)
	self.previous.result = nil
end

function QueryData:getOptions(): any
	local super = getmetatable(getmetatable(self)).__index
	local options = super.options(self)

	if Boolean.toJSBoolean(self.lazyOptions) then
		Object.assign({}, options.variables, self.lazyOptions.variables)
		Object.assign({}, options.context, self.lazyOptions.context)
	end

	--   // skip is not supported when using lazy query execution.
	if Boolean.toJSBoolean(self.runLazy) then
		self.options = nil
	end
	return options
end

function QueryData:ssrInitiated()
	if Boolean.toJSBoolean(self.context) then
		return self.context.renderPromises
	else
		return self.context
	end
end

function QueryData:getExecuteSsrResult(): any
	local ref = self:getOptions()
	local ssr, skip = ref.ssr, ref.skip
	local ssrDisabled = ssr == false
	local fetchDisabled = self:refreshClient().client.disableNetworkFetches
	local ssrLoading = Object.assign({}, {
		loading = true,
		networkStatus = NetworkStatus.loading,
		called = true,
		data = nil,
		stale = false,
		client = self.client,
		self:observableQueryFields(),
	}) :: QueryResult<any, any>

	-- // If SSR has been explicitly disabled, and this function has been called
	-- // on the server side, return the default loading state.
	if
		Boolean.toJSBoolean(ssrDisabled)
		and (Boolean.toJSBoolean(self:ssrInitiated()) or Boolean.toJSBoolean(fetchDisabled))
	then
		self.previous.result = ssrLoading
		return ssrLoading
	end
	if Boolean.toJSBoolean(self:ssrInitiated()) then
		local result = Boolean.toJSBoolean(self:getExecuteResult()) and self:getExecuteResult() or ssrLoading
		if Boolean.toJSBoolean(result.loading) and not Boolean.toJSBoolean(skip) then
			self.context.renderPromises:addQueryPromise(self, function()
				return nil
			end)
		end
		return result
	end

	return nil
end

function QueryData:prepareObservableQueryOptions()
	local options = self:getOptions()
	self:verifyDocumentType(options.query, DocumentType.Query)
	local displayName = Boolean.toJSBoolean(options.displayName) and options.displayName or "Query"

	-- // Set the fetchPolicy to cache-first for network-only and cache-and-network
	-- // fetches for server side renders.
	if
		Boolean.toJSBoolean(self:ssrInitiated())
		and (options.fetchPolicy == "network-only" or options.fetchPolicy == "cache-and-network")
	then
		options.fetchPolicy = "cache-first"
	elseif Boolean.toJSBoolean(options.nextFetchPolicy) and Boolean.toJSBoolean(self.currentObservable) then
		applyNextFetchPolicy(options)
	end
	return Object.assign({}, options, { displayName = displayName, context = options.context })
end

function QueryData:initializeObservableQuery()
	-- // See if there is an existing observable that was used to fetch the same
	-- // data and if so, use it instead since it will contain the proper queryId
	-- // to fetch the result set. This is used during SSR.
	if Boolean.toJSBoolean(self:ssrInitiated()) then
		self.currentObservable = self.context.renderPromises:getSSRObservable(self:getOptions())
	end
	if not Boolean.toJSBoolean(self.currentObservable) then
		local observableQueryOptions = self:prepareObservableQueryOptions()
		self.previous.observableQueryOptions = Object.assign({}, observableQueryOptions, { children = Object.None })
		self.currentObservable = self:refreshClient().client:watchQuery(Object.assign({}, observableQueryOptions))
		if Boolean.toJSBoolean(self:ssrInitiated()) then
			self.context.renderPromises:registerSSRObservable(self.currentObservable, observableQueryOptions)
		end
	end
end

function QueryData:updateObservableQuery()
	-- // If we skipped initially, we may not have yet created the observable
	if not Boolean.toJSBoolean(self.currentObservable) then
		self:initializeObservableQuery()
		return
	end
	local newObservableQueryOptions = Object.assign(
		{},
		self:prepareObservableQueryOptions(),
		{ children = Object.None }
	)
	if Boolean.toJSBoolean(self:getOptions().skip) then
		self.previous.observableQueryOptions = newObservableQueryOptions
		return
	end
	if not equal(newObservableQueryOptions, self.previous.observableQueryOptions) then
		self.previous.observableQueryOptions = newObservableQueryOptions
		self.currentObservable
			:setOptions(newObservableQueryOptions) -- // The error will be passed to the child container, so we don't			-- // need to log it here. We could conceivably log something if			-- // an option was set. OTOH we don't log errors w/ the original			-- // query. See https://github.com/apollostack/react-apollo/issues/404

			:catch(function() end)
	end
end

-- // Setup a subscription to watch for Apollo Client `ObservableQuery` changes.
-- // When new data is received, and it doesn't match the data that was used
-- // during the last `QueryData.execute` call (and ultimately the last query
-- // component render), trigger the `onNewData` callback. If not specified,
-- // `onNewData` will fallback to the default `QueryData.onNewData` function
-- // (which usually leads to a query component re-render).
function QueryData:startQuerySubscription(onNewData: Function?)
	if onNewData == nil then
		onNewData = self.onNewData
	end
	if Boolean.toJSBoolean(self.currentSubscription) or Boolean.toJSBoolean(self:getOptions().skip) then
		return
	end
	self.currentSubscription = self.currentObservable:subscribe({
		next = function(ref)
			local loading, networkStatus, data = ref.loading, ref.networkStatus, ref.data
			local previousResult = self.previous.result

			-- // Make sure we're not attempting to re-render similar results
			if
				Boolean.toJSBoolean(previousResult)
				and previousResult.loading == loading
				and previousResult.networkStatus == networkStatus
				and equal(previousResult.data, data)
			then
				return
			end

			(onNewData :: Function)()
		end,
		["error"] = function(error_)
			self:resubscribeToQuery()
			if not hasOwnProperty(error_, "graphQLErrors") then
				error(error_)
			end
			local previousResult = self.previous.result
			if
				(Boolean.toJSBoolean(previousResult) and Boolean.toJSBoolean(previousResult.loading))
				or not equal(error_, self.previous.error)
			then
				self.previous.error = error_;
				(onNewData :: Function)()
			end
		end,
	})
end

function QueryData:resubscribeToQuery()
	self:removeQuerySubscription()

	-- // Unfortunately, if `lastError` is set in the current
	-- // `observableQuery` when the subscription is re-created,
	-- // the subscription will immediately receive the error, which will
	-- // cause it to terminate again. To avoid this, we first clear
	-- // the last error/result from the `observableQuery` before re-starting
	-- // the subscription, and restore it afterwards (so the subscription
	-- // has a chance to stay open).
	local currentObservable = self.currentObservable
	if Boolean.toJSBoolean(currentObservable) then
		local lastError = currentObservable:getLastError()
		local lastResult = currentObservable:getLastResult()
		currentObservable:resetLastResults()
		self:startQuerySubscription()
		Object.assign(currentObservable, { lastError = lastError, lastResult = lastResult })
	end
end

function QueryData:getExecuteResult()
	local result = self:observableQueryFields()
	local options = self:getOptions()

	-- // When skipping a query (ie. we're not querying for data but still want
	-- // to render children), make sure the `data` is cleared out and
	-- // `loading` is set to `false` (since we aren't loading anything).
	-- //
	-- // NOTE: We no longer think this is the correct behavior. Skipping should
	-- // not automatically set `data` to `undefined`, but instead leave the
	-- // previous data in place. In other words, skipping should not mandate
	-- // that previously received data is all of a sudden removed. Unfortunately,
	-- // changing this is breaking, so we'll have to wait until Apollo Client
	-- // 4.0 to address this.
	if Boolean.toJSBoolean(options.skip) then
		result = Object.assign({}, result, {
			data = Object.None,
			["error"] = Object.None,
			loading = false,
			networkStatus = NetworkStatus.ready,
			called = true,
		})
	elseif Boolean.toJSBoolean(self.currentObservable) then
		-- // Fetch the current result (if any) from the store.
		local currentResult = self.currentObservable:getCurrentResult()
		local data, loading, partial, networkStatus, errors =
			currentResult.data,
			currentResult.loading,
			currentResult.partial,
			currentResult.networkStatus,
			currentResult.errors
		local error_ = currentResult.error

		-- // Until a set naming convention for networkError and graphQLErrors is
		-- // decided upon, we map errors (graphQLErrors) to the error options.
		if Boolean.toJSBoolean(errors) and #errors > 0 then
			error_ = ApolloError.new({ graphQLErrors = errors })
		end
		result = Object.assign(
			{},
			result,
			{ data = data, loading = loading, networkStatus = networkStatus, ["error"] = error_, called = true }
		)
		if Boolean.toJSBoolean(loading) then
			-- // Fall through without modifying result...
		elseif Boolean.toJSBoolean(error_) then
			Object.assign(result, {
				data = (self.currentObservable:getLastResult() or {} :: any).data,
			})
		else
			local ref = self.currentObservable.options
			local fetchPolicy = ref.fetchPolicy
			local partialRefetch = options.partialRefetch
			if
				Boolean.toJSBoolean(partialRefetch)
				and Boolean.toJSBoolean(partial)
				and (not Boolean.toJSBoolean(data) or #Object.keys(data) == 0)
				and fetchPolicy ~= "cache-only"
			then
				-- // When a `Query` component is mounted, and a mutation is executed
				-- // that returns the same ID as the mounted `Query`, but has less
				-- // fields in its result, Apollo Client's `QueryManager` returns the
				-- // data as `undefined` since a hit can't be found in the cache.
				-- // This can lead to application errors when the UI elements rendered by
				-- // the original `Query` component are expecting certain data values to
				-- // exist, and they're all of a sudden stripped away. To help avoid
				-- // this we'll attempt to refetch the `Query` data.
				Object.assign(result, { loading = true, networkStatus = NetworkStatus.loading })
				result:refetch()
				return result
			end
		end
	end
	result.client = self.client
	-- // Store options as this.previousOptions.
	self:setOptions(options, true)
	local previousResult = self.previous.result
	if Boolean.toJSBoolean(previousResult) and Boolean.toJSBoolean(previousResult.loading) then
		self.previous.loading = previousResult.loading
	else
		self.previous.loading = false
	end
	-- // Ensure the returned result contains previousData as a separate
	-- // property, to give developers the flexibility of leveraging outdated
	-- // data while new data is loading from the network. Falling back to
	-- // previousResult.previousData when previousResult.data is falsy here
	-- // allows result.previousData to persist across multiple results.
	if Boolean.toJSBoolean(previousResult) then
		result.previousData = Boolean.toJSBoolean(previousResult.data) and previousResult.data
			or previousResult.previousData
	else
		result.previousData = previousResult
	end
	self.previous.result = result

	-- // Any query errors that exist are now available in `result`, so we'll
	-- // remove the original errors from the `ObservableQuery` query store to
	-- // make sure they aren't re-displayed on subsequent (potentially error
	-- // free) requests/responses.
	if Boolean.toJSBoolean(self.currentObservable) then
		self.currentObservable:resetQueryStoreErrors()
	end
	return result
end

function QueryData:handleErrorOrCompleted()
	if not self.currentObservable or not self.previous.result then
		return
	end

	local ref = self.previous.result
	local data, loading, error_ = ref.data, ref.loading, ref.error
	if not Boolean.toJSBoolean(loading) then
		local refOptions = self:getOptions()
		local query, variables, onCompleted, onError, skip =
			refOptions.query, refOptions.variables, refOptions.onCompleted, refOptions.onError, refOptions.skip

		-- // No changes, so we won't call onError/onCompleted.
		if
			Boolean.toJSBoolean(self.previousOptions)
			and not Boolean.toJSBoolean(self.previous.loading)
			and equal(self.previousOptions.query, query)
			and equal(self.previousOptions.variables, variables)
		then
			return
		end
		if Boolean.toJSBoolean(onCompleted) and not Boolean.toJSBoolean(error_) and not Boolean.toJSBoolean(skip) then
			onCompleted(data)
		elseif Boolean.toJSBoolean(onError) and Boolean.toJSBoolean(error_) then
			onError(error_)
		end
	end
end

function QueryData:removeQuerySubscription()
	if Boolean.toJSBoolean(self.currentSubscription) then
		self.currentSubscription:unsubscribe()
		self.currentSubscription = nil
	end
end

function QueryData:removeObservable(andDelete: boolean)
	if Boolean.toJSBoolean(self.currentObservable) then
		self.currentObservable["tearDownQuery"]()
		if Boolean.toJSBoolean(andDelete) then
			self.currentObservable = nil
		end
	end
end

function QueryData:observableQueryFields()
	local variables
	if Boolean.toJSBoolean(self.currentObservable) then
		variables = self.currentObservable.variables
	else
		variables = nil
	end
	return {
		variables = variables,
		refetch = self.obsRefetch,
		fetchMore = self.obsFetchMore,
		updateQuery = self.obsUpdateQuery,
		startPolling = self.obsStartPolling,
		stopPolling = self.obsStopPolling,
		subscribeToMore = self.obsSubscribeToMore,
	}
end

exports.QueryData = QueryData
return exports
