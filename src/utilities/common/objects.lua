-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/common/objects.ts

local function isNonNullObject(obj: any): boolean
	return obj ~= nil and typeof(obj) == "table"
end

return {
	isNonNullObject = isNonNullObject,
}
