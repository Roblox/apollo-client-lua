-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/withErrorSpy.ts

local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local _Promise = require(rootWorkspace.Promise)
local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local _jestExpect = JestGlobals.expect
local _jest = JestGlobals.jest

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local _console = LuauPolyfill.console

local function withErrorSpy(it, ...)
	local args = { ... }
	warn("spyOn not implemented, skipping snapshot test")
	-- local fn = args[2]
	-- args[2] = function()
	-- 	local args = { it, table.unpack(args) }
	-- local errorSpy = jest.spyOn(console, "error")
	-- errorSpy:mockImplementation(function() end)
	-- return Promise.new(function(resolve)
	-- 	resolve((function()
	-- 		if fn then
	-- 			return fn(args)
	-- 		else
	-- 			return nil
	-- 		end
	-- 	end)())
	-- end):finally(function()
	-- 	jestExpect(errorSpy).toMatchSnapshot()
	-- 	errorSpy:mockReset()
	-- end)
	-- end
	return it(table.unpack(args))
end
exports.withErrorSpy = withErrorSpy
return exports
