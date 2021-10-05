-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/policies/__tests__/relayStylePagination.test.ts
return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Boolean = LuauPolyfill.Boolean
	local Error = LuauPolyfill.Error
	local _Array = LuauPolyfill.Array
	local _Object = LuauPolyfill.Object
	type Object = LuauPolyfill.Object

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local cacheModule = require(script.Parent.Parent.Parent.Parent.cache)
	type FieldFunctionOptions<TArgs, TVars> = cacheModule.FieldFunctionOptions<TArgs, TVars>

	-- ROBLOX TODO: uncomment/remove underscore when available/used
	-- local InMemoryCache = cacheModule.InMemoryCache
	local _isReference = cacheModule.isReference
	local _makeReference = cacheModule.makeReference
	type StoreObject = cacheModule.StoreObject
	local paginationModule = require(script.Parent.Parent.pagination)
	local relayStylePagination = paginationModule.relayStylePagination
	type TRelayPageInfo = paginationModule.TRelayPageInfo

	describe("relayStylePagination", function()
		local policy = relayStylePagination()

		describe("read", function()
			local fakeEdges = {
				{ node = { __ref = "A" }, cursor = "cursorA" },
				{ node = { __ref = "B" }, cursor = "cursorB" },
				{ node = { __ref = "C" }, cursor = "cursorC" },
			}

			local fakeReadOptions = (
					{
						canRead = function(_self)
							return true
						end,
						readField = function(_self, key: string, obj: StoreObject)
							if Boolean.toJSBoolean(obj) then
								return obj[key]
							else
								return obj
							end
						end,
					} :: any
				) :: FieldFunctionOptions<any, any>

			it("should prefer existing.pageInfo.startCursor", function()
				local resultWithStartCursor = (policy :: any):read({
					edges = fakeEdges,
					pageInfo = ({
						startCursor = "preferredStartCursor",
						hasPreviousPage = false,
						hasNextPage = true,
					} :: any) :: TRelayPageInfo,
				}, fakeReadOptions)

				jestExpect(resultWithStartCursor and resultWithStartCursor.pageInfo).toEqual({
					startCursor = "preferredStartCursor",
					endCursor = "cursorC",
					hasPreviousPage = false,
					hasNextPage = true,
				})
			end)

			it("should prefer existing.pageInfo.endCursor", function()
				local resultWithEndCursor = (policy :: any):read({
					edges = fakeEdges,
					pageInfo = ({ endCursor = "preferredEndCursor", hasPreviousPage = false, hasNextPage = true } :: any) :: TRelayPageInfo,
				}, fakeReadOptions)

				jestExpect(resultWithEndCursor and resultWithEndCursor.pageInfo).toEqual({
					startCursor = "cursorA",
					endCursor = "preferredEndCursor",
					hasPreviousPage = false,
					hasNextPage = true,
				})
			end)

			it("should prefer existing.pageInfo.{start,end}Cursor", function()
				local resultWithEndCursor = (policy :: any):read({
					edges = fakeEdges,
					pageInfo = {
						startCursor = "preferredStartCursor",
						endCursor = "preferredEndCursor",
						hasPreviousPage = false,
						hasNextPage = true,
					},
				}, fakeReadOptions)

				jestExpect(resultWithEndCursor and resultWithEndCursor.pageInfo).toEqual({
					startCursor = "preferredStartCursor",
					endCursor = "preferredEndCursor",
					hasPreviousPage = false,
					hasNextPage = true,
				})
			end)

			it("should override pageInfo.{start,end}Cursor if empty strings", function()
				local resultWithEndCursor = (policy :: any):read({
					edges = {
						{ node = { __ref = "A" }, cursor = "" },
						{ node = { __ref = "B" }, cursor = "cursorB" },
						{ node = { __ref = "C" }, cursor = "" },
						{ node = { __ref = "D" }, cursor = "cursorD" },
						{ node = { __ref = "E" } } :: any,
					},
					pageInfo = { startCursor = "", endCursor = "", hasPreviousPage = false, hasNextPage = true },
				}, fakeReadOptions)

				jestExpect(resultWithEndCursor and resultWithEndCursor.pageInfo).toEqual({
					startCursor = "cursorB",
					endCursor = "cursorD",
					hasPreviousPage = false,
					hasNextPage = true,
				})
			end)
		end)

		describe("merge", function()
			local merge = policy.merge
			-- The merge function should exist, make TS aware
			if typeof(merge) ~= "function" then
				error(Error.new("Expecting merge function"))
			end

			-- ROBLOX TODO: needs InMemoryCache
			-- local options: FieldFunctionOptions = {
			-- 	args = nil,
			-- 	fieldName = "fake",
			-- 	storeFieldName = "fake",
			-- 	field = nil,
			-- 	isReference = isReference,
			-- 	toReference = function()
			-- 		return nil
			-- 	end,
			-- 	storage = {},
			-- 	cache = InMemoryCache.new(),
			-- 	readField = function(_self)
			-- 		return nil
			-- 	end,
			-- 	canRead = function(_self)
			-- 		return false
			-- 	end,
			-- 	mergeObjects = function(_self, existing, _incoming)
			-- 		return existing
			-- 	end,
			-- }

			-- ROBLOX TODO:needs inMemoryCache
			-- it("should maintain endCursor and startCursor with empty edges", function()
			-- 	local incoming: Object --[[ Parameters<typeof merge>[1] ]] = {
			-- 		pageInfo = { hasPreviousPage = false, hasNextPage = true, startCursor = "abc", endCursor = "xyz" },
			-- 	}

			-- 	local result = merge(nil, incoming, options)

			-- 	jestExpect(result).toEqual({
			-- 		edges = {},
			-- 		pageInfo = { hasPreviousPage = false, hasNextPage = true, startCursor = "abc", endCursor = "xyz" },
			-- 	})
			-- end)

			-- ROBLOX TODO:needs inMemoryCache
			-- it("should maintain existing PageInfo when adding a page", function()
			-- 	local existingEdges = { { cursor = "alpha", node = makeReference("fakeAlpha") } }

			-- 	local incomingEdges = { { cursor = "omega", node = makeReference("fakeOmega") } }

			-- 	local result = merge({
			-- 		edges = existingEdges,
			-- 		pageInfo = {
			-- 			hasPreviousPage = false,
			-- 			hasNextPage = true,
			-- 			startCursor = "alpha",
			-- 			endCursor = "alpha",
			-- 		},
			-- 	}, {
			-- 		edges = incomingEdges,
			-- 		pageInfo = {
			-- 			hasPreviousPage = true,
			-- 			hasNextPage = true,
			-- 			startCursor = incomingEdges[1].cursor,
			-- 			endCursor = incomingEdges[#incomingEdges --[[ ROBLOX deviation: added 1 to index]]].cursor,
			-- 		},
			-- 	}, Object.assign(
			-- 		{},
			-- 		options,
			-- 		{ args = { after = "alpha" } }
			-- 	))

			-- 	jestExpect(result).toEqual({
			-- 		edges = Array.concat({}, table.unpack(existingEdges), table.unpack(incomingEdges)),
			-- 		pageInfo = {
			-- 			hasPreviousPage = false,
			-- 			hasNextPage = true,
			-- 			startCursor = "alpha",
			-- 			endCursor = "omega",
			-- 		},
			-- 	})
			-- end)

			-- ROBLOX TODO:needs inMemoryCache
			-- it("should maintain extra PageInfo properties", function()
			-- 	local existingEdges = { { cursor = "alpha", node = makeReference("fakeAlpha") } }

			-- 	local incomingEdges = { { cursor = "omega", node = makeReference("fakeOmega") } }

			-- 	local result = merge({
			-- 		edges = existingEdges,
			-- 		pageInfo = {
			-- 			hasPreviousPage = false,
			-- 			hasNextPage = true,
			-- 			startCursor = "alpha",
			-- 			endCursor = "alpha",
			-- 			extra = "existing.pageInfo.extra",
			-- 		} :: TRelayPageInfo,
			-- 	}, {
			-- 		edges = incomingEdges,
			-- 		pageInfo = {
			-- 			hasPreviousPage = true,
			-- 			hasNextPage = true,
			-- 			startCursor = incomingEdges[1].cursor,
			-- 			endCursor = incomingEdges[#incomingEdges.length --[[ROBLOX deviation: added 1 to index]]].cursor,
			-- 			extra = "incoming.pageInfo.extra",
			-- 		} :: TRelayPageInfo,
			-- 	}, Object.assign(
			-- 		{},
			-- 		options,
			-- 		{ args = { after = "alpha" } }
			-- 	))

			-- 	jestExpect(result).toEqual({
			-- 		edges = Array.concat({}, table.unpack(existingEdges), table.unpack(incomingEdges)),
			-- 		pageInfo = {
			-- 			hasPreviousPage = false,
			-- 			hasNextPage = true,
			-- 			startCursor = "alpha",
			-- 			endCursor = "omega",
			-- -- This is the most important line in this test, since it proves
			-- -- incoming.pageInfo.extra was not lost.
			-- 			extra = "incoming.pageInfo.extra",
			-- 		},
			-- 	})
			-- end)
		end)
	end)
end
