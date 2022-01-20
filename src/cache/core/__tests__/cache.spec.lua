-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/core/__tests__/cache.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)

	local Promise = require(rootWorkspace.Promise)
	type Record<T, U> = { [T]: U }

	type Promise<T> = LuauPolyfill.Promise<T>

	--[[
	  ROBLOX deviation: no generic params for functions are supported.
	  T_, TVariables_, TResult_, TSerialized_, QueryType_, FragmentType_ are placeholders for generic T, TVariables, TResult, TSerialized, QueryType, FragmentType_ param
	]]
	type T_ = any
	type TVariables_ = any
	type TResult_ = any

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest

	local gql = require(rootWorkspace.GraphQLTag).default
	local apolloCacheModule = require(script.Parent.Parent.cache)
	local ApolloCache = apolloCacheModule.ApolloCache
	type ApolloCache<TSerialized> = apolloCacheModule.ApolloCache<TSerialized>
	-- ROBLOX deviation: importing directly from relevant type files to avoid circular deps
	local cacheModule = require(script.Parent.Parent.types.Cache)
	type Cache_ReadOptions<TVariables, TData> = cacheModule.Cache_ReadOptions<TVariables, TData>
	type Cache_WriteOptions<TResult, TVariables> = cacheModule.Cache_WriteOptions<TResult, TVariables>
	type Cache_DiffOptions = cacheModule.Cache_DiffOptions
	type Cache_WatchOptions<Watcher> = cacheModule.Cache_WatchOptions<Watcher>
	type Cache_DiffResult<T> = cacheModule.Cache_DiffResult<T>
	type Cache_EvictOptions = cacheModule.Cache_EvictOptions
	type Cache_BatchOptions<C> = cacheModule.Cache_BatchOptions<C>
	type Cache_ModifyOptions = cacheModule.Cache_ModifyOptions
	type Cache_ReadQueryOptions<TData, TVariables> = cacheModule.Cache_ReadQueryOptions<TData, TVariables>
	type Cache_ReadFragmentOptions<TData, TVariables> = cacheModule.Cache_ReadFragmentOptions<TData, TVariables>
	type Cache_WriteQueryOptions<TData, TVariables> = cacheModule.Cache_WriteQueryOptions<TData, TVariables>
	type Cache_WriteFragmentOptions<TData, TVariables> = cacheModule.Cache_WriteFragmentOptions<TData, TVariables>
	local dataProxyModule = require(script.Parent.Parent.types.DataProxy)
	type DataProxy_DiffResult<T> = dataProxyModule.DataProxy_DiffResult<T>
	local storeUtilsModule = require(script.Parent.Parent.Parent.Parent.utilities.graphql.storeUtils)
	type Reference = storeUtilsModule.Reference

	type TestCache = ApolloCache<any> & {
		diff: (self: TestCache, query: Cache_DiffOptions) -> DataProxy_DiffResult<T_>,
		evict: (self: TestCache) -> boolean,
		extract: (self: TestCache, optimistic: boolean) -> any,
		performTransaction: (self: TestCache, transaction: (c: ApolloCache<any>) -> ()) -> (),
		read: (self: TestCache, query: Cache_ReadOptions<TVariables_, any>) -> T_ | nil,
		recordOptimisticTransaction: (self: TestCache, transaction: (c: ApolloCache<any>) -> (), id: string) -> (),
		removeOptimistic: (self: TestCache, id: string) -> (),
		reset: (self: TestCache) -> Promise<nil>,
		restore: (self: TestCache, serializedState: any) -> ApolloCache<any>,
		watch: (self: TestCache, watch: Cache_WatchOptions<Record<string, any>>) -> (() -> ()),
		write: (self: TestCache, _: Cache_WriteOptions<TResult_, TVariables_>) -> Reference | nil,
	}

	local TestCache = setmetatable({}, { __index = ApolloCache })
	TestCache.__index = TestCache

	function TestCache.new(): TestCache
		local self = setmetatable(ApolloCache.new(), TestCache)

		return (self :: any) :: TestCache
	end

	function TestCache:diff(query: Cache_DiffOptions): DataProxy_DiffResult<T_>
		return {}
	end

	function TestCache:evict(): boolean
		return false
	end

	function TestCache:extract(optimistic: boolean): any
		return nil
	end

	function TestCache:performTransaction(transaction: (c: ApolloCache<any>) -> ()): () end

	function TestCache:read(query: Cache_ReadOptions<TVariables_, any>): T_ | nil
		return nil
	end

	function TestCache:recordOptimisticTransaction(transaction: (c: ApolloCache<any>) -> (), id: string): () end

	function TestCache:removeOptimistic(id: string): () end

	function TestCache:reset(): Promise<nil>
		return Promise.new(function()
			return nil
		end)
	end

	function TestCache:restore(serializedState: any): ApolloCache<any>
		return self
	end

	function TestCache:watch(watch: Cache_WatchOptions<Record<string, any>>): () -> ()
		return function() end
	end

	function TestCache:write(_: Cache_WriteOptions<TResult_, TVariables_>): Reference | nil
		return
	end

	local query = gql([[{ a }]])
	describe("abstract cache", function()
		describe("transformDocument", function()
			it("returns the document", function()
				local test = TestCache.new()
				jestExpect(test:transformDocument(query)).toBe(query)
			end)
		end)

		describe("transformForLink", function()
			it("returns the document", function()
				local test = TestCache.new()
				jestExpect(test:transformForLink(query)).toBe(query)
			end)
		end)

		describe("readQuery", function()
			it("runs the read method", function()
				local test = TestCache.new()
				test.read = jest.fn()

				test:readQuery({ query = query })
				jestExpect(test.read).toBeCalled()
			end)

			it("defaults optimistic to false", function()
				local test = TestCache.new()
				test.read = function(_self: any, ref)
					local optimistic = ref.optimistic
					return optimistic :: any
				end

				jestExpect(test:readQuery({ query = query })).toBe(false)
				jestExpect(test:readQuery({ query = query }, true)).toBe(true)
			end)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xdescribe("readFragment", function()
			it("runs the read method", function()
				local test = TestCache.new()
				test.read = jest.fn()
				local fragment = {
					id = "frag",
					fragment = gql([[

						fragment a on b {
							name
						}
					]]),
				}

				test:readFragment(fragment)
				jestExpect(test.read).toBeCalled()
			end)

			it("defaults optimistic to false", function()
				local test = TestCache.new()
				test.read = function(_self: any, ref)
					local optimistic = ref.optimistic
					return optimistic :: any
				end
				local fragment = {
					id = "frag",
					fragment = gql([[

						fragment a on b {
							name
						}
					]]),
				}

				jestExpect(test:readFragment(fragment)).toBe(false)
				jestExpect(test:readFragment(fragment, true)).toBe(true)
			end)
		end)

		describe("writeQuery", function()
			it("runs the write method", function()
				local test = TestCache.new()
				test.write = jest.fn()

				test:writeQuery({ query = query, data = "foo" })
				jestExpect(test.write).toBeCalled()
			end)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xdescribe("writeFragment", function()
			it("runs the write method", function()
				local test = TestCache.new()
				test.write = jest.fn()
				local fragment = {
					id = "frag",
					fragment = gql([[

						fragment a on b {
							name
						}
					]]),
					data = "foo",
				}

				test:writeFragment(fragment)
				jestExpect(test.write).toBeCalled()
			end)
		end)
	end)
end
