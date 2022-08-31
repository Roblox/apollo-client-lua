-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/testing/withConsoleSpy.ts
local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local Promise = require(rootWorkspace.Promise)
local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect
local jest = JestGlobals.jest

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local console = LuauPolyfill.console

local function wrapTestFunction(fn: (...any) -> any, consoleMethodName: string)
	return function(...)
		local args_ = table.pack(...)
		-- ROBLOX deviation: using jest.fn instead of spyOn(not available)
		local originalFn = console[consoleMethodName]
		local spy = jest.fn(function() end)
		console[consoleMethodName] = spy

		return Promise.new(function(resolve)
			resolve(if fn then fn(table.unpack(args_)) else nil)
		end):finally(function()
			expect(spy).toMatchSnapshot()
			spy:mockClear()
			console[consoleMethodName] = originalFn
		end)
	end
end

local function withErrorSpy<TArgs, TResult>(it: (...any) -> ...TResult, ...: any)
	local args = { ... } -- TArgs
	args[2] = wrapTestFunction(args[2], "error")
	return it(table.unpack(args))
end
exports.withErrorSpy = withErrorSpy

local function withWarningSpy<TArgs, TResult>(it: (...any) -> ...TResult, ...: any)
	local args = { ... } -- TArgs
	args[2] = wrapTestFunction(args[2], "warn")
	return it(table.unpack(args))
end
exports.withWarningSpy = withWarningSpy

local function withLogSpy<TArgs, TResult>(it: (...any) -> ...TResult, ...: any)
	local args = { ... } -- TArgs
	args[2] = wrapTestFunction(args[2], "log")
	return it(table.unpack(args))
end
exports.withLogSpy = withLogSpy

return exports
