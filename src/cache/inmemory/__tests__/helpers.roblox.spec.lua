--[[
 * Copyright (c) Roblox Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
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

	describe("fieldNameFromStoreName", function()
		it("should not match for field names starting with a number", function()
			expect(fieldNameFromStoreName("3abc")).toEqual("3abc")
		end)

		it("should match for fields starting with _", function()
			expect(fieldNameFromStoreName("_h3llo")).toEqual("_h3llo")
			expect(fieldNameFromStoreName("_H3Llo")).toEqual("_H3Llo")
			expect(fieldNameFromStoreName("_HELLO")).toEqual("_HELLO")
		end)

		it("should not match non-alphanumeric starting characters", function()
			expect(fieldNameFromStoreName("$_hello")).toEqual("$_hello")
		end)

		it("should not match unicode starting characters", function()
			expect(fieldNameFromStoreName("â_hello")).toEqual("â_hello")
		end)

		it("should match for alphabetic starting characters", function()
			expect(fieldNameFromStoreName("hel2lo_")).toEqual("hel2lo_")
			expect(fieldNameFromStoreName("H_eLlo")).toEqual("H_eLlo")
			expect(fieldNameFromStoreName("HELLO")).toEqual("HELLO")
		end)

		it("should stop matching at non-alphanumberic character", function()
			expect(fieldNameFromStoreName("hello$goodbye")).toEqual("hello")
			expect(fieldNameFromStoreName("_hello$goodbye")).toEqual("_hello")
			expect(fieldNameFromStoreName("h_e_3_l_o$goodbye")).toEqual("h_e_3_l_o")
		end)
	end)
end)

return {}
