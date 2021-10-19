-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/stripSymbols.ts

type T_ = any

local exports = {}

local function stripSymbols(data: T_): T_
	--[[
		ROBLOX FIXME: stripping symbols is not supported yet
		original code:
		return JSON.parse(JSON.stringify(data));
	]]
	return data
end
exports.stripSymbols = stripSymbols
return exports
