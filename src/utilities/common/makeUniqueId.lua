-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/common/makeUniqueId.ts
local exports = {}
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Map = LuauPolyfill.Map

local prefixCounts = Map.new(nil)
local alphabet = {
	"0",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
}
local function makeUniqueId(prefix: string)
	--ROBLOX deviation: suffix replaces Math.random().toString(36).slice(2) that returns a string with eleven chars from "alphabet"
	math.randomseed(os.time())
	local suffix = ""
	for i = 1, 11, 1 do
		suffix ..= alphabet[math.random(1, 36)]
	end
	local count = Boolean.toJSBoolean(prefixCounts:get(prefix)) and prefixCounts:get(prefix) or 1
	prefixCounts:set(prefix, count + 1)
	return ("%s:%s:%s"):format(prefix, count, suffix)
end
exports.makeUniqueId = makeUniqueId
return exports
