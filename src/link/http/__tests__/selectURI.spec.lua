--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/http/__tests__/selectURI.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local gql = require(rootWorkspace.GraphQLTag).default

local createOperation = require(script.Parent.Parent.Parent.utils.createOperation).createOperation
local selectURI = require(script.Parent.Parent.selectURI).selectURI

local query = gql([[

		query SampleQuery {
			stub {
				id
			}
		}
	]])

describe("selectURI", function()
	it("returns a passed in string", function()
		local uri = "/somewhere"
		local operation = createOperation({ uri = uri }, { query = query })
		expect(selectURI(operation)).toEqual(uri)
	end)

	it("returns a fallback of /graphql", function()
		local uri = "/graphql"
		local operation = createOperation({}, { query = query })
		expect(selectURI(operation)).toEqual(uri)
	end)

	it("returns the result of a UriFunction", function()
		local uri = "/somewhere"
		local operation = createOperation({}, { query = query })
		expect(selectURI(operation, function()
			return uri
		end)).toEqual(uri)
	end)
end)

return {}
