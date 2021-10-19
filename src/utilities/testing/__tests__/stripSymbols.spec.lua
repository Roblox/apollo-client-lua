-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/__tests__/stripSymbols.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Symbol = LuauPolyfill.Symbol

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local stripSymbols = require(script.Parent.Parent.stripSymbols).stripSymbols
	describe("stripSymbols", function()
		-- ROBLOX FIXME: stripping symbols is not supported yet
		itFIXME("should strip symbols (only)", function()
			local sym = Symbol("id")
			local data = { foo = "bar", [sym] = "ROOT_QUERY" }
			jestExpect(stripSymbols(data)).toEqual({ foo = "bar", [sym] = "ROOT_QUERY" })
		end)
	end)
end
