-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/context.ts

local srcWorkspace = script.Parent.Parent
local exports = {}
local entryTypesModule = require(script.Parent.entryTypes)
type AnyEntry = entryTypesModule.AnyEntry
local Slot = require(srcWorkspace.wry.context).Slot
local parentEntrySlot = Slot.new()
exports.parentEntrySlot = parentEntrySlot
local contextModule = require(srcWorkspace.wry.context)
exports.bindContext = contextModule.bind
exports.noContext = contextModule.noContext
exports.setTimeout = contextModule.setTimeout
-- exports.asyncFromGen = contextModule.asyncFromGen
return exports
