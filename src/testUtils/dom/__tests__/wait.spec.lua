-- ROBLOX upstream: https://github.com/testing-library/dom-testing-library/blob/v6.11.0/src/__tests__/wait.js

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
local jestExpect = JestRoblox.Globals.expect
local jest = JestRoblox.Globals.jest

local wait = require(script.Parent.Parent).wait

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local setTimeout = LuauPolyfill.setTimeout

local Promise = require(rootWorkspace.Promise)

return function()
	describe("wait", function()
		it("it waits for the data to be loaded", function()
			local spy = jest:fn()
			-- we are using random timeout here to simulate a real-time example
			-- of an async operation calling a callback at a non-deterministic time
			local randomTimeout = math.random(0, 60)
			setTimeout(spy, randomTimeout)

			-- ROBLOX todo: ask about properly handling await
			wait(function()
				return jestExpect(spy).toHaveBeenCalledTimes(1)
			end):expect()
			jestExpect(spy).toHaveBeenCalledWith()
		end)

		it("wait defaults to a noop callback", function()
			local handler = jest:fn()
			-- ROBLOX deviation: handler is a callable "table", type(handler) == "table"
			-- this is throwing an error in the Promise library expecting the type to be "function"
			-- Wrapping in a function to make it work
			local handlerFunction = function()
				handler()
			end
			Promise.resolve():andThen(handlerFunction)
			wait():expect()
			jestExpect(handler).toHaveBeenCalledTimes(1)
		end)
	end)
end
