-- ROBLOX upstream: https://github.com/testing-library/react-testing-library/blob/v9.4.1/src/index.js

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

-- ROBLOX deviation: we may not need flush functionality. need to verify.
-- local flush = require(script["flush-microtasks"]).default

-- ROBLOX deviation: this is not needed, already importing cleanup from pure below
-- local cleanup = require(script.pure).cleanup

local exports: { [string]: any } = {}

-- ROBLOX deviation: we may not need to auto insert cleanup, we're already inserting them in our jest tests. need to verify.
--[[
if we're running in a test runner that supports afterEach
then we'll automatically run cleanup afterEach test
this ensures that tests run in isolation from each other
if you don't like this then either import the `pure` module
or set the RTL_SKIP_AUTO_CLEANUP env variable to 'true'.
]]

-- if
-- 	Boolean.toJSBoolean((function()
-- 		if Boolean.toJSBoolean(typeof(afterEach) == "function") then
-- 			return not Boolean.toJSBoolean(process.env.RTL_SKIP_AUTO_CLEANUP)
-- 		else
-- 			return typeof(afterEach) == "function"
-- 		end
-- 	end)())
-- then
-- 	afterEach(function()
-- 		error("not implemented") --[[ await flush() ]]
-- 		--[[ ROBLOX TODO: Unhandled node for type: AwaitExpression ]]
-- 		cleanup()
-- 	end)
-- end

Object.assign(exports, require(script.pure))

return exports
