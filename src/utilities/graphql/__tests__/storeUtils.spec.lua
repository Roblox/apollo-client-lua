-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/graphql/__tests__/storeUtils.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local getStoreKeyName = require(script.Parent.Parent.storeUtils).getStoreKeyName

describe("getStoreKeyName", function()
	it(
		"should return a deterministic version of the store key name no matter "
			.. "which order the args object properties are in",
		function()
			local validStoreKeyName = 'someField({"prop1":"value1","prop2":"value2"})'
			local generatedStoreKeyName = getStoreKeyName("someField", { prop1 = "value1", prop2 = "value2" }, nil)
			expect(generatedStoreKeyName).toEqual(validStoreKeyName)

			generatedStoreKeyName = getStoreKeyName("someField", { prop2 = "value2", prop1 = "value1" }, nil)
			expect(generatedStoreKeyName).toEqual(validStoreKeyName)
		end
	)
end)

return {}
