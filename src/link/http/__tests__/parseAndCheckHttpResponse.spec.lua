-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/http/__tests__/parseAndCheckHttpResponse.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Error = LuauPolyfill.Error
	type Object = LuauPolyfill.Object

	local Promise = require(rootWorkspace.Promise)

	local HttpService = game:GetService("HttpService")

	-- ROBLOX deviation: method not available
	local function fail(...)
		jestExpect(false).toBe(true)
	end

	local gql = require(rootWorkspace.Dev.GraphQLTag).default
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

		it("throws a parse error with a status code on unparsable response", function()
			local status = 400
			-- ROBLOX deviation: using custom fetchResponse mock function
			fetchResponse(status)
				:andThen(parseAndCheckHttpResponse(operations))
				:andThen(fail)
				:catch(function(e)
					jestExpect(e.statusCode).toBe(status)
					jestExpect(e.name).toBe("ServerParseError")
					jestExpect(e).toHaveProperty("response")
					jestExpect(e).toHaveProperty("bodyText")
				end)
				:catch(fail)
				:expect()
		end)

		it("throws a network error with a status code and result", function()
			local status = 403
			local body = { data = "fail" }
			-- ROBLOX deviation: using custom fetchResponse mock function
			fetchResponse({ body = body, status = status })
				:andThen(parseAndCheckHttpResponse(operations))
				:andThen(fail)
				:catch(function(e)
					jestExpect(e.statusCode).toBe(status)
					jestExpect(e.name).toBe("ServerError")
					jestExpect(e).toHaveProperty("response")
					jestExpect(e).toHaveProperty("result")
				end)
				:catch(fail)
				:expect()
		end)

		it("throws a server error on incorrect data", function()
			local data = { hello = "world" }
			-- ROBLOX deviation: using custom fetchResponse mock function
			fetchResponse(data)
				:andThen(parseAndCheckHttpResponse(operations))
				:andThen(fail)
				:catch(function(e)
					jestExpect(e.statusCode).toBe(200)
					jestExpect(e.name).toBe("ServerError")
					jestExpect(e).toHaveProperty("response")
					jestExpect(e.result).toEqual(data)
				end)
				:catch(fail)
				:expect()
		end)

		it("is able to return a correct GraphQL result", function()
			local errors = { "", "" .. tostring(Error.new("hi")) }
			local data = { data = { hello = "world" }, errors = errors }
			-- ROBLOX deviation: using custom fetchResponse mock function
			fetchResponse({ body = data })
				:andThen(parseAndCheckHttpResponse(operations))
				:andThen(function(ref)
					local data, e = ref.data, ref.errors
					jestExpect(data).toEqual({ hello = "world" })
					jestExpect(#e).toEqual(#errors)
					jestExpect(e).toEqual(errors)
				end)
				:catch(fail)
				:expect()
		end)
	end)
end
