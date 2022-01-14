-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/core/__tests__/ObservableQuery.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local jest = JestGlobals.jest

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

-- ROBLOX TODO: replace when function generics are available
type T_ = any

local exports = {}

local queryManagerModule = require(script.Parent.Parent.QueryManager)
type QueryManager<TStore> = queryManagerModule.QueryManager<TStore>
-- ROBLOX deviation START: inline QueryManager_fetchQueryByPolicy as `fetchQueryByPolicy` is a private method
local queryInfoModule = require(script.Parent.Parent.QueryInfo)
type QueryInfo = queryInfoModule.QueryInfo
local watchQueryOptionsModule = require(script.Parent.Parent.watchQueryOptions_types)
type WatchQueryOptions__ = watchQueryOptionsModule.WatchQueryOptions__
local networkStatusModule = require(script.Parent.Parent.networkStatus)
type NetworkStatus = networkStatusModule.NetworkStatus
local coreTypesModule = require(script.Parent.Parent.types)
type ApolloQueryResult<T> = coreTypesModule.ApolloQueryResult<T>
local utilitiesObservablesModule = require(script.Parent.Parent.Parent.utilities.observables.Concast)
type ConcastSourcesIterable<T> = utilitiesObservablesModule.ConcastSourcesIterable<T>
type QueryManager_fetchQueryByPolicy = (
	self: QueryManager<any>,
	queryInfo: QueryInfo,
	ref: WatchQueryOptions__,
	networkStatus: NetworkStatus
) -> ConcastSourcesIterable<ApolloQueryResult<any>>
-- ROBLOX deviation END

local function mockFetchQuery(queryManager: QueryManager<any>)
	local fetchQueryObservable = queryManager.fetchQueryObservable
	local fetchQueryByPolicy: QueryManager_fetchQueryByPolicy = (queryManager :: any).fetchQueryByPolicy

	local function mock(original: T_)
		return jest.fn(function(_self, ...)
			return original(queryManager, ...)
		end)
	end

	local mocks = {
		fetchQueryObservable = mock(fetchQueryObservable),
		fetchQueryByPolicy = mock(fetchQueryByPolicy),
	}

	Object.assign(queryManager, mocks)

	return mocks
end
exports.mockFetchQuery = mockFetchQuery

return exports
