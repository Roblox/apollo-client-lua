-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/http/__tests__/helpers.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local window = _G

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean

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
		expect(window.fetch).toBe(nil)
		-- ROBLOX deviation: this expect doesn't seem to make sense in Lua
		-- expect(function()
		-- 	return fetch
		-- end).toThrowError(ReferenceError)
	end)

	it("globalThis === window", function()
		-- ROBLOX deviation: using _G instead of globalThis
		expect(_G).toBe(window)
	end)
end)

return exports
