-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/helpers.ts
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local entityStoreModule = require(script.Parent.Parent.entityStore)
local EntityStore = entityStoreModule.EntityStore
local EntityStore_Root = entityStoreModule.EntityStore_Root

local defaultNormalizedCacheFactory = require(script.Parent.helpers).defaultNormalizedCacheFactory

describe("defaultNormalizedCacheFactory", function()
	it("should return an EntityStore", function()
		local store = defaultNormalizedCacheFactory()
		expect(store).toBeInstanceOf(EntityStore)
		expect(store).toBeInstanceOf(EntityStore_Root)
	end)
end)

return {}
