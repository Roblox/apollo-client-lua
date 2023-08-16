--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX no upstream

local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local utilitiesModule = require(script.Parent.Parent)

describe("utilities/init", function()
	it("should export relevant functions from './graphql/getFromAST' module", function()
		expect(typeof(utilitiesModule.checkDocument)).toBe("function")
		expect(typeof(utilitiesModule.getOperationDefinition)).toBe("function")
		expect(typeof(utilitiesModule.getOperationName)).toBe("function")
		expect(typeof(utilitiesModule.getFragmentDefinitions)).toBe("function")
		expect(typeof(utilitiesModule.getQueryDefinition)).toBe("function")
		expect(typeof(utilitiesModule.getFragmentDefinition)).toBe("function")
		expect(typeof(utilitiesModule.getMainDefinition)).toBe("function")
		expect(typeof(utilitiesModule.getDefaultValues)).toBe("function")
	end)

	it("should export relevant functions from './graphql/storeUtils' module", function()
		expect(typeof(utilitiesModule.makeReference)).toBe("function")
		expect(typeof(utilitiesModule.isDocumentNode)).toBe("function")
		expect(typeof(utilitiesModule.isReference)).toBe("function")
		expect(typeof(utilitiesModule.isField)).toBe("function")
		expect(typeof(utilitiesModule.isInlineFragment)).toBe("function")
		expect(typeof(utilitiesModule.valueToObjectRepresentation)).toBe("function")
		expect(typeof(utilitiesModule.storeKeyNameFromField)).toBe("function")
		expect(typeof(utilitiesModule.argumentsObjectFromField)).toBe("function")
		expect(typeof(utilitiesModule.resultKeyNameFromField)).toBe("function")
		expect(typeof(utilitiesModule.getStoreKeyName)).toBe("table")
		expect(typeof(getmetatable(utilitiesModule.getStoreKeyName).__call)).toBe("function")
	end)

	it("should export relevant functions from './graphql/transform' module", function()
		expect(typeof(utilitiesModule.addTypenameToDocument)).toBe("table")
		expect(typeof(getmetatable(utilitiesModule.addTypenameToDocument).__call)).toBe("function")
		expect(typeof(utilitiesModule.buildQueryFromSelectionSet)).toBe("function")
		expect(typeof(utilitiesModule.removeDirectivesFromDocument)).toBe("function")
		expect(typeof(utilitiesModule.removeConnectionDirectiveFromDocument)).toBe("function")
		expect(typeof(utilitiesModule.removeArgumentsFromDocument)).toBe("function")
		expect(typeof(utilitiesModule.removeFragmentSpreadFromDocument)).toBe("function")
		expect(typeof(utilitiesModule.removeClientSetsFromDocument)).toBe("function")
	end)
end)

return {}
