--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/__tests__/exports.ts
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local describe = JestGlobals.describe

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object
type Array<T> = LuauPolyfill.Array<T>
type Object = { [string]: any }
type Record<T, U> = { [T]: U }

local cache = require(srcWorkspace.cache)
local client = require(srcWorkspace)
local core = require(srcWorkspace.core)
local errors = require(srcWorkspace.errors)
-- ROBLOX comment: Packages that are not ported are defined as nil
-- to run the check function and emit a warning
local linkBatch = nil --require(srcWorkspace.link.batch)
local linkBatchHTTP = nil -- require(srcWorkspace.link["batch-http"])
local linkContext = nil -- require(srcWorkspace.link.context)
local linkCore = require(srcWorkspace.link.core)
local linkError = nil -- require(srcWorkspace.link.error)
local linkHTTP = require(srcWorkspace.link.http)
local linkPersistedQueries = nil -- require(srcWorkspace.link["persisted-queries"])
local linkRetry = nil -- require(srcWorkspace.link.retry)
local linkSchema = nil -- require(srcWorkspace.link.schema)
local linkUtils = require(srcWorkspace.link.utils)
local linkWS = nil -- require(srcWorkspace.link.ws)
local react = require(srcWorkspace.react)
local reactComponents = require(srcWorkspace.react.components)
local reactContext = require(srcWorkspace.react.context)
local reactData = require(srcWorkspace.react.data)
local reactHOC = nil -- require(srcWorkspace.react.hoc)
local reactHooks = require(srcWorkspace.react.hooks)
local reactParser = require(srcWorkspace.react.parser)
local reactSSR = nil -- require(srcWorkspace.react.ssr)
local testing = require(srcWorkspace.testing)
local utilities = require(srcWorkspace.utilities)
local entryPoints = require(rootWorkspace.Config.entryPoints)

type Namespace = Object | nil

describe("exports of public entry points", function()
	-- ROBLOX deviation: using array instead of Set (doesn't work with expect.toContain)
	-- and to preserve duplicates and error when there are duplicate keys in the exported keys
	-- and the expected keys to be missing
	local testedIds = {}

	-- ROBLOX deviation: add missing exports
	local function check(id: string, ns: Namespace, missingExports: Array<string>?)
		if ns == nil then
			-- ROBLOX comment: test did not run, but we want to mark it as checked
			table.insert(testedIds, id)
			warn(id .. " not ported")
			return
		end
		if missingExports ~= nil and #missingExports > 0 then
			warn(id .. " has some missing exports:\n" .. Array.join(missingExports, ",\n"))
		end
		it(id, function()
			table.insert(testedIds, id)
			expect(Array.sort(Array.concat(Object.keys(ns :: Object), missingExports or {}))).toMatchSnapshot()
		end)
	end

	check("@apollo/client", client, {
		-- ROBLOX TODO: subscriptions is not implemented yet
		"useSubscription",
	})
	check("@apollo/client/cache", cache)
	check("@apollo/client/core", core)
	check("@apollo/client/errors", errors)
	check("@apollo/client/link/batch", linkBatch)
	check("@apollo/client/link/batch-http", linkBatchHTTP)
	check("@apollo/client/link/context", linkContext)
	check("@apollo/client/link/core", linkCore)
	check("@apollo/client/link/error", linkError)
	check("@apollo/client/link/http", linkHTTP)
	check("@apollo/client/link/persisted-queries", linkPersistedQueries)
	check("@apollo/client/link/retry", linkRetry)
	check("@apollo/client/link/schema", linkSchema)
	check("@apollo/client/link/utils", linkUtils)
	check("@apollo/client/link/ws", linkWS)
	check("@apollo/client/react", react, {
		-- ROBLOX TODO: subscriptions is not implemented yet
		"useSubscription",
	})
	check("@apollo/client/react/components", reactComponents, {
		-- ROBLOX TODO: subscriptions is not implemented yet
		"Subscription",
	})
	check("@apollo/client/react/context", reactContext)
	check("@apollo/client/react/data", reactData, {
		-- ROBLOX TODO: subscriptions is not implemented yet
		"SubscriptionData",
	})
	check("@apollo/client/react/hoc", reactHOC)
	check("@apollo/client/react/hooks", reactHooks, {
		-- ROBLOX TODO: subscriptions is not implemented yet
		"useSubscription",
	})
	check("@apollo/client/react/parser", reactParser)
	check("@apollo/client/react/ssr", reactSSR)
	check("@apollo/client/testing", testing, {
		-- ROBLOX TODO: createMockClient is not implemented yet
		"createMockClient",
	})
	check("@apollo/client/utilities", utilities)

	it("completeness", function()
		-- ROBLOX deviation: using custom function
		local join = function(...)
			local arr = { ... }
			return Array.join(arr, "/")
		end

		entryPoints.forEach(function(info: Record<string, any>)
			local id = join(table.unpack(Array.concat({ "@apollo/client" }, info.dirs)))
			expect(testedIds).toContain(id)
		end)
	end)
end)

return {}
