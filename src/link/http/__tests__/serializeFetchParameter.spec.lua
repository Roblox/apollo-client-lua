-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/http/__tests__/serializeFetchParameter.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local serializeFetchParameter = require(script.Parent.Parent.serializeFetchParameter).serializeFetchParameter

describe("serializeFetchParameter", function()
	it("throws a parse error on an unparsable body", function()
		local b = {}
		local a = { b = b };
		(b :: any).a = a

		expect(function()
			return serializeFetchParameter(b, "Label")
		end).toThrow("Label")
	end)

	it("returns a correctly parsed body", function()
		local body = { no = "thing" }

		expect(serializeFetchParameter(body, "Label")).toEqual('{"no":"thing"}')
	end)
end)

return {}
