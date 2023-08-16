--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/graphql/__tests__/directives.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array

local gql = require(rootWorkspace.GraphQLTag).default

local cloneDeep = require(script.Parent.Parent.Parent.common.cloneDeep).cloneDeep

local directivesModule = require(script.Parent.Parent.directives)
local shouldInclude = directivesModule.shouldInclude
local hasDirectives = directivesModule.hasDirectives
local getQueryDefinition = require(script.Parent.Parent.getFromAST).getQueryDefinition

describe("hasDirective", function()
	it("should allow searching the ast for a directive", function()
		local query = gql([[

      query Simple {
        field @live
      }
    ]])

		expect(hasDirectives({ "live" }, query)).toBe(true)
		expect(hasDirectives({ "defer" }, query)).toBe(false)
	end)

	it("works for all operation types", function()
		local query = gql([[

      {
        field @live {
          subField {
            hello @live
          }
        }
      }
    ]])

		local mutation = gql([[

      mutation Directive {
        mutate {
          field {
            subField {
              hello @live
            }
          }
        }
      }
    ]])

		local subscription = gql([[

      subscription LiveDirective {
        sub {
          field {
            subField {
              hello @live
            }
          }
        }
      }
    ]])

		Array.forEach({ query, mutation, subscription }, function(x)
			expect(hasDirectives({ "live" }, x)).toBe(true)
			expect(hasDirectives({ "defer" }, x)).toBe(false)
		end)
	end)

	it("works for simple fragments", function()
		local query = gql([[

      query Simple {
        ...fieldFragment
      }

      fragment fieldFragment on Field {
        foo @live
      }
    ]])
		expect(hasDirectives({ "live" }, query)).toBe(true)
		expect(hasDirectives({ "defer" }, query)).toBe(false)
	end)

	it("works for nested fragments", function()
		local query = gql([[

      query Simple {
        ...fieldFragment1
      }

      fragment fieldFragment1 on Field {
        bar {
          baz {
            ...nestedFragment
          }
        }
      }

      fragment nestedFragment on Field {
        foo @live
      }
    ]])
		expect(hasDirectives({ "live" }, query)).toBe(true)
		expect(hasDirectives({ "defer" }, query)).toBe(false)
	end)
end)

describe("shouldInclude", function()
	it("should should not include a skipped field", function()
		local query = gql([[

      query {
        fortuneCookie @skip(if: true)
      }
    ]])
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(not shouldInclude(field, {})).toBe(true)
	end)

	it("should include an included field", function()
		local query = gql([[

      query {
        fortuneCookie @include(if: true)
      }
    ]])

		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(shouldInclude(field, {})).toBe(true)
	end)

	it("should not include a not include: false field", function()
		local query = gql([[

      query {
        fortuneCookie @include(if: false)
      }
    ]])

		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(not shouldInclude(field, {})).toBe(true)
	end)

	it("should include a skip: false field", function()
		local query = gql([[

      query {
        fortuneCookie @skip(if: false)
      }
    ]])

		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(shouldInclude(field, {})).toBe(true)
	end)

	it("should not include a field if skip: true and include: true", function()
		local query = gql([[

      query {
        fortuneCookie @skip(if: true) @include(if: true)
      }
    ]])

		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(not shouldInclude(field, {})).toBe(true)
	end)

	it("should not include a field if skip: true and include: false", function()
		local query = gql([[

      query {
        fortuneCookie @skip(if: true) @include(if: false)
      }
    ]])
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(not shouldInclude(field, {})).toBe(true)
	end)

	it("should include a field if skip: false and include: true", function()
		local query = gql([[

      query {
        fortuneCookie @skip(if: false) @include(if: true)
      }
    ]])

		local field = getQueryDefinition(query).selectionSet.selections[1]

		expect(shouldInclude(field, {})).toBe(true)
	end)

	it("should not include a field if skip: false and include: false", function()
		local query = gql([[

      query {
        fortuneCookie @skip(if: false) @include(if: false)
      }
    ]])
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(not shouldInclude(field, {})).toBe(true)
	end)

	it("should leave the original query unmodified", function()
		local query = gql([[

      query {
        fortuneCookie @skip(if: false) @include(if: false)
      }
    ]])
		local queryClone = cloneDeep(query)
		local field = getQueryDefinition(query).selectionSet.selections[1]
		shouldInclude(field, {})
		expect(query).toEqual(queryClone)
	end)

	it("does not throw an error on an unsupported directive", function()
		local query = gql([[

      query {
        fortuneCookie @dosomething(if: true)
      }
    ]])
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(function()
			shouldInclude(field, {})
		end).never.toThrow()
	end)

	it("throws an error on an invalid argument for the skip directive", function()
		local query = gql([[

      query {
        fortuneCookie @skip(nothing: true)
      }
    ]])
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(function()
			shouldInclude(field, {})
		end).toThrow()
	end)

	it("throws an error on an invalid argument for the include directive", function()
		local query = gql([[

      query {
        fortuneCookie @include(nothing: true)
      }
    ]])
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(function()
			shouldInclude(field, {})
		end).toThrow()
	end)

	it("throws an error on an invalid variable name within a directive argument", function()
		local query = gql([[

      query {
        fortuneCookie @include(if: $neverDefined)
      }
    ]])
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(function()
			shouldInclude(field, {})
		end).toThrow()
	end)

	it("evaluates variables on skip fields", function()
		local query = gql([[

      query($shouldSkip: Boolean) {
        fortuneCookie @skip(if: $shouldSkip)
      }
    ]])
		local variables = { shouldSkip = true }
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(not shouldInclude(field, variables)).toBe(true)
	end)

	it("evaluates variables on include fields", function()
		local query = gql([[

      query($shouldSkip: Boolean) {
        fortuneCookie @include(if: $shouldInclude)
      }
    ]])
		local variables = { shouldInclude = false }
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(not shouldInclude(field, variables)).toBe(true)
	end)

	it("throws an error if the value of the argument is not a variable or boolean", function()
		local query = gql([[

      query {
        fortuneCookie @include(if: "string")
      }
    ]])
		local field = getQueryDefinition(query).selectionSet.selections[1]
		expect(function()
			shouldInclude(field, {})
		end).toThrow()
	end)
end)

return {}
