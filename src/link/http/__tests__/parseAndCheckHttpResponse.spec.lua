--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/http/__tests__/parseAndCheckHttpResponse.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Error = LuauPolyfill.Error
type Object = LuauPolyfill.Object

local Promise = require(rootWorkspace.Promise)

local HttpService = game:GetService("HttpService")

local gql = require(rootWorkspace.GraphQLTag).default
-- ROBLOX deviation: custom mock function instead of fetch-mock library
local function fetchResponse(response: number | { status: number?, body: any? } | Object)
	local status: number, res: any?

	if typeof(response) == "number" then
		status = response
		res = nil
	elseif typeof(response.status) == "number" or response.body ~= nil then
		status = response.status or 200
		res = response.body
	else
		status = 200
		res = response
	end
	return Promise.resolve({
		text = function(_self)
			return Promise.resolve(res and HttpService:JSONEncode(res) or "")
		end,
		status = status,
	})
end

local createOperation = require(script.Parent.Parent.Parent.utils.createOperation).createOperation
local parseAndCheckHttpResponse = require(script.Parent.Parent.parseAndCheckHttpResponse).parseAndCheckHttpResponse

local query = gql([[

		query SampleQuery {
			stub {
				id
			}
		}
	]])

describe("parseAndCheckResponse", function()
	-- ROBLOX deviation: with custom fetchResponse function beforeEach hook is unnnecessary

	local operations = { createOperation({}, { query = query }) }

	it("throws a parse error with a status code on unparsable response", function(_, done)
		local status = 400
		-- ROBLOX deviation: using custom fetchResponse mock function
		fetchResponse(status)
			:andThen(parseAndCheckHttpResponse(operations))
			:andThen(
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done
				-- ROBLOX deviation END
			)
			:catch(function(e)
				expect(e.statusCode).toBe(status)
				expect(e.name).toBe("ServerParseError")
				expect(e).toHaveProperty("response")
				expect(e).toHaveProperty("bodyText")
				done()
			end)
			:catch(
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done
				-- ROBLOX deviation END
			)
	end)

	it("throws a network error with a status code and result", function(_, done)
		local status = 403
		local body = { data = "fail" }
		-- ROBLOX deviation: using custom fetchResponse mock function
		fetchResponse({ body = body, status = status })
			:andThen(parseAndCheckHttpResponse(operations))
			:andThen(
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done
				-- ROBLOX deviation END
			)
			:catch(function(e)
				expect(e.statusCode).toBe(status)
				expect(e.name).toBe("ServerError")
				expect(e).toHaveProperty("response")
				expect(e).toHaveProperty("result")
				done()
			end)
			:catch(
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done
				-- ROBLOX deviation END
			)
	end)

	it("throws a server error on incorrect data", function(_, done)
		local data = { hello = "world" }
		-- ROBLOX deviation: using custom fetchResponse mock function
		fetchResponse(data)
			:andThen(parseAndCheckHttpResponse(operations))
			:andThen(
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done
				-- ROBLOX deviation END
			)
			:catch(function(e)
				expect(e.statusCode).toBe(200)
				expect(e.name).toBe("ServerError")
				expect(e).toHaveProperty("response")
				expect(e.result).toEqual(data)
				done()
			end)
			:catch(
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done
				-- ROBLOX deviation END
			)
	end)

	it("is able to return a correct GraphQL result", function(_, done)
		local errors = { "", "" .. tostring(Error.new("hi")) }
		local data = { data = { hello = "world" }, errors = errors }
		-- ROBLOX deviation: using custom fetchResponse mock function
		fetchResponse({ body = data })
			:andThen(parseAndCheckHttpResponse(operations))
			:andThen(function(ref)
				local data, e = ref.data, ref.errors
				expect(data).toEqual({ hello = "world" })
				expect(#e).toEqual(#errors)
				expect(e).toEqual(errors)
				done()
			end)
			:catch(
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done
				-- ROBLOX deviation END
			)
	end)
end)

return {}
