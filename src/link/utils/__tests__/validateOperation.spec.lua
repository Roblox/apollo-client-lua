-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/utils/__tests__/validateOperation.ts
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local validateOperation = require(script.Parent.Parent.validateOperation).validateOperation
local gql = require(rootWorkspace.GraphQLTag).default
describe("validateOperation", function()
	it("should throw when invalid field in operation", function()
		expect(function()
			return validateOperation({ qwerty = "" } :: any)
		end).toThrow()
	end)
	it("should not throw when valid fields in operation", function()
		expect(function()
			return validateOperation({
				query = gql([[

					query SampleQuery {
							stub {
									id
							}
					}
				]]),
				context = {},
				variables = {},
			})
		end).never.toThrow()
	end)
end)

return {}
