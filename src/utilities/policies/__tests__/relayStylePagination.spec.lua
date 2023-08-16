--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/policies/__tests__/relayStylePagination.test.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object

type Object = LuauPolyfill.Object
type Record<T, U> = { [T]: U }
type Function = (...any) -> ...any

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local cacheModule = require(script.Parent.Parent.Parent.Parent.cache)
type FieldFunctionOptions<TArgs, TVars> = cacheModule.FieldFunctionOptions<TArgs, TVars>

local InMemoryCache = cacheModule.InMemoryCache
local isReference = cacheModule.isReference
local makeReference = cacheModule.makeReference
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

			expect(resultWithStartCursor and resultWithStartCursor.pageInfo).toEqual({
				startCursor = "preferredStartCursor",
				endCursor = "cursorC",
				hasPreviousPage = false,
				hasNextPage = true,
			})
		end)

		it("should prefer existing.pageInfo.endCursor", function()
			local resultWithEndCursor = (policy :: any):read({
				edges = fakeEdges,
				pageInfo = (
						{ endCursor = "preferredEndCursor", hasPreviousPage = false, hasNextPage = true } :: any
					) :: TRelayPageInfo,
			}, fakeReadOptions)

			expect(resultWithEndCursor and resultWithEndCursor.pageInfo).toEqual({
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

			expect(resultWithEndCursor and resultWithEndCursor.pageInfo).toEqual({
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

			expect(resultWithEndCursor and resultWithEndCursor.pageInfo).toEqual({
				startCursor = "cursorB",
				endCursor = "cursorD",
				hasPreviousPage = false,
				hasNextPage = true,
			})
		end)
	end)

	describe("merge", function()
		local merge_ = policy.merge
		-- The merge function should exist, make TS aware
		if typeof(merge_) ~= "function" then
			error(Error.new("Expecting merge function"))
		end

		-- ROBLOX deviation: casting as function to help analyze
		local merge = merge_ :: Function

		local options: FieldFunctionOptions<Record<string, any>, Record<string, any>> = {
			args = nil,
			fieldName = "fake",
			storeFieldName = "fake",
			field = nil,
			isReference = function(_self, ...)
				return isReference(...)
			end,
			toReference = function()
				return nil
			end,
			storage = {},
			cache = InMemoryCache.new(),
			readField = function(_self)
				return nil
			end,
			canRead = function(_self)
				return false
			end,
			mergeObjects = function(_self, existing: any, _incoming: any)
				return existing
			end,
		}

		it("should maintain endCursor and startCursor with empty edges", function()
			local incoming --[[ Parameters<typeof merge>[1] ]] = {
				pageInfo = {
					hasPreviousPage = false,
					hasNextPage = true,
					startCursor = "abc",
					endCursor = "xyz",
				},
			}
			local result = merge(policy, nil, incoming, options)
			expect(result).toEqual({
				edges = {},
				pageInfo = {
					hasPreviousPage = false,
					hasNextPage = true,
					startCursor = "abc",
					endCursor = "xyz",
				},
			})
		end)

		it("should maintain existing PageInfo when adding a page", function()
			local existingEdges = {
				{ cursor = "alpha", node = makeReference("fakeAlpha") },
			}

			local incomingEdges = {
				{ cursor = "omega", node = makeReference("fakeOmega") },
			}

			local result = merge(
				policy,
				{
					edges = existingEdges,
					pageInfo = {
						hasPreviousPage = false,
						hasNextPage = true,
						startCursor = "alpha",
						endCursor = "alpha",
					},
				},
				{
					edges = incomingEdges,
					pageInfo = {
						hasPreviousPage = true,
						hasNextPage = true,
						startCursor = incomingEdges[1].cursor,
						endCursor = incomingEdges[#incomingEdges].cursor,
					},
				},
				Object.assign({}, options, {
					args = {
						after = "alpha",
					},
				})
			)

			expect(result).toEqual({
				edges = Array.concat({}, existingEdges, incomingEdges),
				pageInfo = {
					hasPreviousPage = false,
					hasNextPage = true,
					startCursor = "alpha",
					endCursor = "omega",
				},
			})
		end)

		it("should maintain extra PageInfo properties", function()
			local existingEdges = {
				{ cursor = "alpha", node = makeReference("fakeAlpha") },
			}

			local incomingEdges = {
				{ cursor = "omega", node = makeReference("fakeOmega") },
			}

			local result = merge(
				policy,
				{
					edges = existingEdges,
					pageInfo = ({
						hasPreviousPage = false,
						hasNextPage = true,
						startCursor = "alpha",
						endCursor = "alpha",
						extra = "existing.pageInfo.extra",
					} :: any) :: TRelayPageInfo,
				},
				{
					edges = incomingEdges,
					pageInfo = ({
						hasPreviousPage = true,
						hasNextPage = true,
						startCursor = incomingEdges[1].cursor,
						endCursor = incomingEdges[#incomingEdges].cursor,
						extra = "incoming.pageInfo.extra",
					} :: any) :: TRelayPageInfo,
				},
				Object.assign({}, options, {
					args = {
						after = "alpha",
					},
				})
			)

			expect(result).toEqual({
				edges = Array.concat({}, existingEdges, incomingEdges),
				pageInfo = {
					hasPreviousPage = false,
					hasNextPage = true,
					startCursor = "alpha",
					endCursor = "omega",
					-- This is the most important line in this test, since it proves
					-- incoming.pageInfo.extra was not lost.
					extra = "incoming.pageInfo.extra",
				},
			})
		end)
	end)
end)

return {}
