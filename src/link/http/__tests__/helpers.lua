-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/http/__tests__/helpers.ts

type Function = (...any) -> ...any

-- ROBLOX deviation: need to provide beforeEach, afterEach, describe, it from the test spec file itself
return function(test: { beforeEach: Function, afterEach: Function, describe: Function, it: Function })
	local beforeEach = test.beforeEach
	local afterEach = test.afterEach
	local describe = test.describe
	local it = test.it
	local window = _G

	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Boolean = LuauPolyfill.Boolean

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local exports = {}

	local function voidFetchDuringEachTest()
		--[[
			ROBLOX deviation: no Object.getOwnPropertyDescriptor
			local fetchDesc = Object:getOwnPropertyDescriptor(window, "fetch")
		]]
		local fetchDesc = window.fetch

		beforeEach(function()
			--[[
				ROBLOX deviation: no Object.getOwnPropertyDescriptor
				fetchDesc = fetchDesc || Object.getOwnPropertyDescriptor(window, "fetch");
			]]
			fetchDesc = Boolean.toJSBoolean(fetchDesc) and fetchDesc or window.fetch
			--[[
				ROBLOX deviation: not property descriptor in Lua
				if (fetchDesc?.configurable)
			]]
			if true then
				(window :: any).fetch = nil
			end
		end)

		afterEach(function()
			--[[
				ROBLOX deviation: not property descriptor in Lua
				if (fetchDesc?.configurable)
			]]
			if true then
				--[[
					ROBLOX deviation: no Object.defineProperty
					Object.defineProperty(window, "fetch", fetchDesc);
				]]
				window.fetch = fetchDesc
			end
		end)
	end
	exports.voidFetchDuringEachTest = voidFetchDuringEachTest

	describe("voidFetchDuringEachTest", function()
		voidFetchDuringEachTest()

		it("hides the global.fetch function", function()
			jestExpect(window.fetch).toBe(nil)
			-- ROBLOX deviation: this expect doesn't seem to make sense in Lua
			-- jestExpect(function()
			-- 	return fetch
			-- end).toThrowError(ReferenceError)
		end)

		it("globalThis === window", function()
			-- ROBLOX deviation: using _G instead of globalThis
			jestExpect(_G).toBe(window)
		end)
	end)

	return exports
end
