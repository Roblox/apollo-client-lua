--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/http/__tests__/selectHttpOptionsAndBody.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local itFIXME = function(description: string, ...: any)
	it.todo(description)
end

local gql = require(rootWorkspace.GraphQLTag).default

local createOperation = require(script.Parent.Parent.Parent.utils.createOperation).createOperation
local selectHttpOptionsAndBodyModule = require(script.Parent.Parent.selectHttpOptionsAndBody)
local selectHttpOptionsAndBody = selectHttpOptionsAndBodyModule.selectHttpOptionsAndBody
local fallbackHttpConfig = selectHttpOptionsAndBodyModule.fallbackHttpConfig
local query = gql([[

		query SampleQuery {
			stub {
				id
			}
		}
	]])

describe("selectHttpOptionsAndBody", function()
	it("includeQuery allows the query to be ignored", function()
		local body =
			selectHttpOptionsAndBody(createOperation({}, { query = query }), { http = { includeQuery = false } }).body
		expect(body).never.toHaveProperty("query")
	end)

	it("includeExtensions allows the extensions to be added", function()
		local extensions = { yo = "what up" }
		local body = selectHttpOptionsAndBody(
			createOperation({}, { query = query, extensions = extensions }),
			{ http = { includeExtensions = true } }
		).body
		expect(body).toHaveProperty("extensions")
		expect((body :: any).extensions).toEqual(extensions)
	end)

	it("the fallbackConfig is used if no other configs are specified", function()
		local defaultHeaders = { accept = "*/*", ["content-type"] = "application/json" }

		local defaultOptions = { method = "POST" }

		local extensions = { yo = "what up" }
		local ref = selectHttpOptionsAndBody(
			createOperation({}, { query = query, extensions = extensions }),
			fallbackHttpConfig
		)
		local options, body = ref.options, ref.body

		expect(body).toHaveProperty("query")
		expect(body).never.toHaveProperty("extensions")

		expect(options.headers).toEqual(defaultHeaders)
		expect(options.method).toEqual(defaultOptions.method)
	end)

	it("allows headers, credentials, and setting of method to function correctly", function()
		local headers = { accept = "application/json", ["content-type"] = "application/graphql" }

		local credentials = { ["X-Secret"] = "djmashko" }

		local opts = { opt = "hi" }

		local config = { headers = headers, credentials = credentials, options = opts }

		local extensions = { yo = "what up" }

		local ref = selectHttpOptionsAndBody(
			createOperation({}, { query = query, extensions = extensions }),
			fallbackHttpConfig,
			config
		)
		local options, body = ref.options, ref.body

		expect(body).toHaveProperty("query")
		expect(body).never.toHaveProperty("extensions")

		expect(options.headers).toEqual(headers)
		expect(options.credentials).toEqual(credentials)
		expect(options.opt).toEqual("hi")
		expect(options.method).toEqual("POST") -- from default
	end)

	-- ROBLOX FIXME: order of props definition doesn't correspond to order of execution
	itFIXME("normalizes HTTP header names to lower case", function()
		local headers = {
			accept = "application/json",
			Accept = "application/octet-stream",
			["content-type"] = "application/graphql",
			["Content-Type"] = "application/javascript",
			["CONTENT-type"] = "application/json",
		}

		local config = { headers = headers }

		local ref = selectHttpOptionsAndBody(createOperation({}, { query = query }), fallbackHttpConfig, config)
		local options, body = ref.options, ref.body

		expect(body).toHaveProperty("query")
		expect(body).never.toHaveProperty("extensions")

		expect(options.headers).toEqual({
			accept = "application/octet-stream",
			["content-type"] = "application/json",
		})
	end)
end)

return {}
