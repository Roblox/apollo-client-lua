-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/common/canUse.ts
-- ROBLOX deviation: the upstream of this file would always return true in Roblox environment

return {
	canUseWeakMap = true,
	canUseWeakSet = false,
}
