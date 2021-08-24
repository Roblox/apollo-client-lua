-- ROBLOX upstream: https://github.com/apollographql/invariant-packages/blob/be3bfe/packages/ts-invariant/src/invariant.ts
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Error = LuauPolyfill.Error
type Error = { name: string, message: string, stack: string? }

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
	if not condition then
		error(message or "Unexpected invariant triggered.")
	end
end

return {
	invariant = invariant,
	InvariantError = InvariantError,
}
