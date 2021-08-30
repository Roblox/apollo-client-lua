-- ROBLOX upstream: https://github.com/facebook/react/blob/v16.9.0/packages/shared/warningWithoutStack.js

--[[
  Copyright (c) Facebook, Inc. and its affiliates.

  This source code is licensed under the MIT license found in the
  LICENSE file in the root directory of this source tree.
]]

--[[
  Similar to invariant but only logs a warning if the condition is not met.
  This can be used to log issues in development environments in critical
  paths. Removing the logging code for production environments will keep the
  same logic and follow the same code paths.
]]

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local console = LuauPolyfill.console
local Error = LuauPolyfill.Error
local Array = LuauPolyfill.Array

-- ROBLOX TODO: implement the fully featured version it in LuauPolyfill
function Array.unshift(arr, v)
	table.insert(arr, 1, v)
	return #arr
end

local exports = {}

local function warningWithoutStack(condition: boolean?, format: string?, ...: any): () end

if Boolean.toJSBoolean(_G.__DEV__) then
	warningWithoutStack = function(condition: boolean?, format: string?, ...)
		local args = table.pack(...)
		if format == nil then
			error(
				Error.new("`warningWithoutStack(condition, format, ...args)` requires a warning " .. "message argument")
			)
		end
		if #args > 8 then
			-- Check before the condition to catch violations early.
			error(Error.new("warningWithoutStack() currently supports at most 8 arguments."))
		end
		if Boolean.toJSBoolean(condition) then
			return
		end
		if typeof(console) ~= "nil" then
			local argsWithFormat = Array.map(args, function(item)
				return "" .. tostring(item)
			end, nil)
			Array.unshift(argsWithFormat, "Warning: " .. tostring(format))
			-- We intentionally don't use spread (or .apply) directly because it
			-- breaks IE9: https://github.com/facebook/react/issues/13610
			console.error(table.unpack(argsWithFormat))
		end

		-- --- Welcome to debugging React ---
		-- This error was thrown as a convenience so that you can use this stack
		-- to find the callsite that caused this warning to fire.
		xpcall(function()
			-- ROBLOX deviation: Lua string.format uses the same interpolation character as javascript
			local message = (format :: string):format(table.unpack(args))
			error(Error.new(message))
		end, function(x) end)
	end
end

exports.default = warningWithoutStack

return exports
