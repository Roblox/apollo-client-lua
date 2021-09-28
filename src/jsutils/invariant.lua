-- ROBLOX upstream: https://github.com/apollographql/invariant-packages/blob/be3bfe/packages/ts-invariant/src/invariant.ts
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array, Boolean, console, Error =
	LuauPolyfill.Array, LuauPolyfill.Boolean, LuauPolyfill.console, LuauPolyfill.Error
type Error = LuauPolyfill.Error

local genericMessage = "Invariant Violation"
local InvariantError = setmetatable({}, { __index = Error })
InvariantError.__index = InvariantError

type InvariantError = Error & { framesToPop: number, name: string }
function InvariantError.new(message_: (string | number)?)
	local message = message_ :: string | number
	if message_ == nil then
		message = genericMessage
	end

	local error_
	if typeof(message) == "number" then
		error_ = ("%s: %s (see https://github.com/apollographql/invariant-packages)"):format(
			genericMessage,
			tostring(message)
		)
	else
		error_ = (message :: string)
	end

	local self = Error.new(error_)
	self.framesToPop = 1
	self.name = genericMessage

	return setmetatable(self, InvariantError)
end

local function invariant(condition: any, message: string | nil)
	if not Boolean.toJSBoolean(condition) then
		error(InvariantError.new(message))
	end
end

local verbosityLevels = { "debug", "log", "warn", "error", "silent" }
local verbosityLevel = Array.indexOf(verbosityLevels, "log")

local function wrapConsoleMethod(name: string)
	return function(...)
		if Array.indexOf(verbosityLevels, name) >= verbosityLevel then
			-- Default to console.log if this host environment happens not to provide
			-- all the console.* methods we need.
			local method = Boolean.toJSBoolean(console[name]) and console[name] or console.log
			return method(...)
		end
	end
end

return {
	invariant = setmetatable({
		debug = wrapConsoleMethod("debug"),
		log = wrapConsoleMethod("log"),
		warn = wrapConsoleMethod("warn"),
		error = wrapConsoleMethod("error"),
	}, {
		__call = function(_self, condition, message)
			invariant(condition, message)
		end,
	}),
	InvariantError = InvariantError,
}
