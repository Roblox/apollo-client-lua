-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/common/global.ts
local exports = {}
local maybe = require(script.Parent.maybe).maybe
-- ROBLOX deviation: Roblox doesn't have a concept of window or process.env. _G is the replacement.
--[[
export default (
  maybe(() => globalThis) ||
  maybe(() => window) ||
  maybe(() => self) ||
  maybe(() => global) ||
  maybe(() => Function("return this")())
) as typeof globalThis & {
  __DEV__: typeof __DEV__;
};
]]

exports.default = maybe(function()
	return _G
end)

return exports
