-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/http/serializeFetchParameter.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Error = LuauPolyfill.Error
type Error = LuauPolyfill.Error

local HttpService = game:GetService("HttpService")

local exports = {}

local invariantModule = require(srcWorkspace.jsutils.invariant)
local InvariantError = invariantModule.InvariantError
type InvariantError = invariantModule.InvariantError

export type ClientParseError = InvariantError & { parseError: Error }

local function serializeFetchParameter(p: any, label: string)
	local serialized
	local ok, result = pcall(function()
		-- ROBLOX deviation: using HttpService:JSONEncode instead of JSON.stringify
		serialized = HttpService:JSONEncode(p)
	end)
	if not ok then
		local e = result
		local parseError = InvariantError.new(
			-- ROBLOX deviation: using 'e' directly as JSONEncode throws bare string
			("Network request failed. %s is not serializable: %s"):format(label, e)
		) :: ClientParseError
		-- -- ROBLOX deviation: creating new Error as JSONEncode throws bare string
		parseError.parseError = Error.new(e)
		error(parseError)
	end
	return serialized
end
exports.serializeFetchParameter = serializeFetchParameter

return exports
