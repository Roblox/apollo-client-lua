-- ROBLOX no upstream

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local utilitiesModule = require(script.Parent.Parent)

	describe("utilities/init", function()
		it("should export relevant functions from './graphql/getFromAST' module", function()
			jestExpect(typeof(utilitiesModule.checkDocument)).toBe("function")
			jestExpect(typeof(utilitiesModule.getOperationDefinition)).toBe("function")
			jestExpect(typeof(utilitiesModule.getOperationName)).toBe("function")
			jestExpect(typeof(utilitiesModule.getFragmentDefinitions)).toBe("function")
			jestExpect(typeof(utilitiesModule.getQueryDefinition)).toBe("function")
			jestExpect(typeof(utilitiesModule.getFragmentDefinition)).toBe("function")
			jestExpect(typeof(utilitiesModule.getMainDefinition)).toBe("function")
			jestExpect(typeof(utilitiesModule.getDefaultValues)).toBe("function")
		end)

		it("should export relevant functions from './graphql/storeUtils' module", function()
			jestExpect(typeof(utilitiesModule.makeReference)).toBe("function")
			jestExpect(typeof(utilitiesModule.isDocumentNode)).toBe("function")
			jestExpect(typeof(utilitiesModule.isReference)).toBe("function")
			jestExpect(typeof(utilitiesModule.isField)).toBe("function")
			jestExpect(typeof(utilitiesModule.isInlineFragment)).toBe("function")
			jestExpect(typeof(utilitiesModule.valueToObjectRepresentation)).toBe("function")
			jestExpect(typeof(utilitiesModule.storeKeyNameFromField)).toBe("function")
			jestExpect(typeof(utilitiesModule.argumentsObjectFromField)).toBe("function")
			jestExpect(typeof(utilitiesModule.resultKeyNameFromField)).toBe("function")
			jestExpect(typeof(utilitiesModule.getStoreKeyName)).toBe("table")
			jestExpect(typeof(getmetatable(utilitiesModule.getStoreKeyName).__call)).toBe("function")
		end)

		it("should export relevant functions from './graphql/transform' module", function()
			jestExpect(typeof(utilitiesModule.addTypenameToDocument)).toBe("table")
			jestExpect(typeof(getmetatable(utilitiesModule.addTypenameToDocument).__call)).toBe("function")
			jestExpect(typeof(utilitiesModule.buildQueryFromSelectionSet)).toBe("function")
			jestExpect(typeof(utilitiesModule.removeDirectivesFromDocument)).toBe("function")
			jestExpect(typeof(utilitiesModule.removeConnectionDirectiveFromDocument)).toBe("function")
			jestExpect(typeof(utilitiesModule.removeArgumentsFromDocument)).toBe("function")
			jestExpect(typeof(utilitiesModule.removeFragmentSpreadFromDocument)).toBe("function")
			jestExpect(typeof(utilitiesModule.removeClientSetsFromDocument)).toBe("function")
		end)
	end)
end
