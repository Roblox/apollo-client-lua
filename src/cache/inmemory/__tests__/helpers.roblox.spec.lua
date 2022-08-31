-- ROBLOX upstream: no upstream
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local helpersModule = require(script.Parent.Parent.helpers)
local getTypenameFromStoreObject = helpersModule.getTypenameFromStoreObject
local TypeOrFieldNameRegExp = helpersModule.TypeOrFieldNameRegExp
local fieldNameFromStoreName = helpersModule.fieldNameFromStoreName
local selectionSetMatchesResult = helpersModule.selectionSetMatchesResult
local storeValueIsStoreObject = helpersModule.storeValueIsStoreObject
local makeProcessedFieldsMerger = helpersModule.makeProcessedFieldsMerger

describe("inmemory helpers", function()
	it("ensure helper functions import correctly", function()
		expect(typeof(getTypenameFromStoreObject)).toBe("function")
		expect(typeof(TypeOrFieldNameRegExp)).toBe("table")
		expect(typeof(fieldNameFromStoreName)).toBe("function")
		expect(typeof(selectionSetMatchesResult)).toBe("function")
		expect(typeof(storeValueIsStoreObject)).toBe("function")
		expect(typeof(makeProcessedFieldsMerger)).toBe("function")
	end)
end)

return {}
