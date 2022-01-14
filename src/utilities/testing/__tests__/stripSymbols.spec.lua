-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/testing/__tests__/stripSymbols.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Symbol = LuauPolyfill.Symbol

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local stripSymbols = require(script.Parent.Parent.stripSymbols).stripSymbols
	describe("stripSymbols", function()
		it("should strip symbols (only)", function()
			local sym = Symbol("id")
			local data = { foo = "bar", [sym] = "ROOT_QUERY" }
			jestExpect(stripSymbols(data)).toEqual({ foo = "bar" })
		end)

		-- ROBLOX comment: no upstream equivalent
		it("should strip symbols (only) in nested objects", function()
			local sym = Symbol("id")
			local data = {
				foo = "bar",
				[sym] = "ROOT_QUERY",
				nested = {
					foo = "bar",
					[sym] = "ROOT_QUERY",
					deeplyNested = {
						foo = "bar",
						[sym] = "ROOT_QUERY",
					},
				},
			}
			jestExpect(stripSymbols(data)).toEqual({
				foo = "bar",
				nested = { foo = "bar", deeplyNested = { foo = "bar" } },
			})
		end)

		-- ROBLOX comment: no upstream equivalent
		it("original object is not modified", function()
			local sym = Symbol("id")
			local data = {
				foo = "bar",
				[sym] = "ROOT_QUERY",
			}
			local stripped = stripSymbols(data)
			jestExpect(stripped[sym]).toBeUndefined()
			jestExpect(data[sym]).toBe("ROOT_QUERY")
		end)
	end)
end
