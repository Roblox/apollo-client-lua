return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local validateOperation = require(script.Parent.Parent.validateOperation).validateOperation
	local gql = require(rootWorkspace.Dev.GraphQLTag).default
	describe("validateOperation", function()
		it("should throw when invalid field in operation", function()
			jestExpect(function()
				return validateOperation({ qwerty = "" } :: any)
			end).toThrow()
		end)
		it("should not throw when valid fields in operation", function()
			jestExpect(function()
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
end
