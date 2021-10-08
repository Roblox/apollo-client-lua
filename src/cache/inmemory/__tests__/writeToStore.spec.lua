-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/__tests__/writeToStore.ts

-- ROBLOX TODO: implement upstream tests

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local writeToStoreModule = require(script.Parent.Parent.writeToStore)
	local StoreWriter = writeToStoreModule.StoreWriter

	describe("writeToStore", function()
		it("should ensure StoreWriter is a class", function()
			jestExpect(typeof(StoreWriter)).toBe("table")
		end)

		it("should create StoreWriter instance", function()
			jestExpect(function()
				StoreWriter.new({} :: any)
			end).never.toThrow()

			jestExpect(StoreWriter.new({} :: any)).toBeInstanceOf(StoreWriter)
		end)
	end)
end
