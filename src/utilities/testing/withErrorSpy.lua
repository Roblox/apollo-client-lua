-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/withErrorSpy.ts

local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local Promise = require(rootWorkspace.Promise)
local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local jestExpect = JestGlobals.expect
local jest = JestGlobals.jest

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local console = LuauPolyfill.console

local function withErrorSpy(it, ...)
	local args = { ... }
	local fn = args[2]
	args[2] = function(...)
		local args_ = ...
		-- ROBLOX deviation: using jest.fn instead of spyOn(not available)
		local originalFn = console.error
		local errorSpy = jest.fn(function() end)
		console.error = errorSpy

		return Promise.new(function(resolve)
			resolve((function()
				if fn then
					return fn(args_)
				else
					return nil
				end
			end)())
		end)
			:andThen(function()
				jestExpect(errorSpy).toMatchSnapshot()
				console.error = originalFn
			end)
			:catch(function(err)
				console.error = originalFn
				error(err)
			end)
			:expect()
	end
	return it(table.unpack(args))
end
exports.withErrorSpy = withErrorSpy
return exports
