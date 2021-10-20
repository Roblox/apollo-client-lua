-- ROBLOX upstream: no upstream

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local helpersModule = require(script.Parent.Parent.helpers)
	local getTypenameFromStoreObject = helpersModule.getTypenameFromStoreObject
	local TypeOrFieldNameRegExp = helpersModule.TypeOrFieldNameRegExp
	local fieldNameFromStoreName = helpersModule.fieldNameFromStoreName
	local selectionSetMatchesResult = helpersModule.selectionSetMatchesResult
	local storeValueIsStoreObject = helpersModule.storeValueIsStoreObject
	local makeProcessedFieldsMerger = helpersModule.makeProcessedFieldsMerger

	describe("inmemory helpers", function()
		it("ensure helper functions import correctly", function()
			jestExpect(typeof(getTypenameFromStoreObject)).toBe("function")
			jestExpect(typeof(TypeOrFieldNameRegExp)).toBe("table")
			jestExpect(typeof(fieldNameFromStoreName)).toBe("function")
			jestExpect(typeof(selectionSetMatchesResult)).toBe("function")
			jestExpect(typeof(storeValueIsStoreObject)).toBe("function")
			jestExpect(typeof(makeProcessedFieldsMerger)).toBe("function")
		end)
	end)
end
