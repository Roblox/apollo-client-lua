-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/http/__tests__/selectHttpOptionsAndBody.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

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
			local body = selectHttpOptionsAndBody(
				createOperation({}, { query = query }),
				{ http = { includeQuery = false } }
			).body
			jestExpect(body).never.toHaveProperty("query")
		end)

		it("includeExtensions allows the extensions to be added", function()
			local extensions = { yo = "what up" }
			local body = selectHttpOptionsAndBody(
				createOperation({}, { query = query, extensions = extensions }),
				{ http = { includeExtensions = true } }
			).body
			jestExpect(body).toHaveProperty("extensions")
			jestExpect((body :: any).extensions).toEqual(extensions)
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

			jestExpect(body).toHaveProperty("query")
			jestExpect(body).never.toHaveProperty("extensions")

			jestExpect(options.headers).toEqual(defaultHeaders)
			jestExpect(options.method).toEqual(defaultOptions.method)
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

			jestExpect(body).toHaveProperty("query")
			jestExpect(body).never.toHaveProperty("extensions")

			jestExpect(options.headers).toEqual(headers)
			jestExpect(options.credentials).toEqual(credentials)
			jestExpect(options.opt).toEqual("hi")
			jestExpect(options.method).toEqual("POST") -- from default
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

			jestExpect(body).toHaveProperty("query")
			jestExpect(body).never.toHaveProperty("extensions")

			jestExpect(options.headers).toEqual({
				accept = "application/octet-stream",
				["content-type"] = "application/json",
			})
		end)
	end)
end
