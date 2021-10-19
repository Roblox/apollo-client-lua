-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/http/__tests__/serializeFetchParameter.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local serializeFetchParameter = require(script.Parent.Parent.serializeFetchParameter).serializeFetchParameter

	describe("serializeFetchParameter", function()
		it("throws a parse error on an unparsable body", function()
			local b = {}
			local a = { b = b };
			(b :: any).a = a

			jestExpect(function()
				return serializeFetchParameter(b, "Label")
			end).toThrow("Label")
		end)

		it("returns a correctly parsed body", function()
			local body = { no = "thing" }

			jestExpect(serializeFetchParameter(body, "Label")).toEqual('{"no":"thing"}')
		end)
	end)
end
