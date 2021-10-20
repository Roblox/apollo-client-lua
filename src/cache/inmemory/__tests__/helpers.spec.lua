-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/__tests__/helpers.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local entityStoreModule = require(script.Parent.Parent.entityStore)
	local EntityStore = entityStoreModule.EntityStore
	local EntityStore_Root = entityStoreModule.EntityStore_Root

	local defaultNormalizedCacheFactory = require(script.Parent.helpers).defaultNormalizedCacheFactory

	describe("defaultNormalizedCacheFactory", function()
		it("should return an EntityStore", function()
			local store = defaultNormalizedCacheFactory()
			jestExpect(store).toBeInstanceOf(EntityStore)
			jestExpect(store).toBeInstanceOf(EntityStore_Root)
		end)
	end)
end
