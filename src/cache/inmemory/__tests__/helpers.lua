-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/helpers.ts
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Object = LuauPolyfill.Object
local console = LuauPolyfill.console

local RegExp = require(rootWorkspace.LuauRegExp)
type RegExp = RegExp.RegExp

type Function = (...any) -> ...any

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect

local exports = {}
local typesModule = require(script.Parent.Parent.types)
type NormalizedCache = typesModule.NormalizedCache
type NormalizedCacheObject = typesModule.NormalizedCacheObject
type DiffQueryAgainstStoreOptions = typesModule.DiffQueryAgainstStoreOptions
local entityStoreModule = require(script.Parent.Parent.entityStore)
local EntityStore_Root = entityStoreModule.EntityStore_Root
local InMemoryCache = require(script.Parent.Parent.inMemoryCache).InMemoryCache
local readFromStoreModule = require(script.Parent.Parent.readFromStore)
type StoreReader = readFromStoreModule.StoreReader
local writeToStoreModule = require(script.Parent.Parent.writeToStore)
type StoreWriter = writeToStoreModule.StoreWriter
local cacheCoreModule = require(script.Parent.Parent.Parent.Parent.cache)
type Cache_WriteOptions<TResult, TVariables> = cacheCoreModule.Cache_WriteOptions<TResult, TVariables>

local function defaultNormalizedCacheFactory(seed: NormalizedCacheObject?): NormalizedCache
	local cache = InMemoryCache.new()
	return EntityStore_Root.new({
		policies = cache.policies,
		resultCaching = true,
		seed = seed,
	})
end
exports.defaultNormalizedCacheFactory = defaultNormalizedCacheFactory

type WriteQueryToStoreOptions = Cache_WriteOptions<any, any> & {
	writer: StoreWriter,
	store: NormalizedCache?,
}

local function readQueryFromStore(reader: StoreReader, options: DiffQueryAgainstStoreOptions)
	return reader:diffQueryAgainstStore(Object.assign({}, options, {
		returnPartialData = false,
	})).result
end
exports.readQueryFromStore = readQueryFromStore

local function writeQueryToStore(options: WriteQueryToStoreOptions): NormalizedCache
	local dataId, store, writeOptions =
		options.dataId, options.store, Object.assign({}, options, { dataId = Object.None, store = Object.None })
	if options.dataId == nil then
		dataId = "ROOT_QUERY"
	end
	if options.store == nil then
		store = EntityStore_Root.new({
			policies = options.writer.cache.policies,
		})
	end
	options.writer:writeToStore(
		store,
		Object.assign({}, writeOptions, {
			dataId = dataId,
		})
	)
	return store
end
exports.writeQueryToStore = writeQueryToStore

local function withError(func: Function, regex: RegExp?)
	local message: string = nil :: any
	local error_ = console.error
	console.error = function(m: any)
		message = m
	end

	local ok, result = pcall(function()
		local result = func()
		if Boolean.toJSBoolean(regex) then
			expect(message).toMatch(regex)
		end
		return result
	end)
	console.error = error_
	if not ok then
		error(result)
	end
	return result
end
exports.withError = withError

return exports
