--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/graphql/__tests__/fragments.ts
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local print_ = require(rootWorkspace.GraphQL).print
local gql = require(rootWorkspace.GraphQLTag).default
local disableFragmentWarnings = require(rootWorkspace.GraphQLTag).disableFragmentWarnings
-- Turn off warnings for repeated fragment names
disableFragmentWarnings()
local fragmentsModule = require(script.Parent.Parent.fragments)
local getFragmentQueryDocument = fragmentsModule.getFragmentQueryDocument
local createFragmentMap = fragmentsModule.createFragmentMap
type FragmentMap = fragmentsModule.FragmentMap
local getFragmentDefinitions = require(script.Parent.Parent.getFromAST).getFragmentDefinitions

describe("getFragmentQueryDocument", function()
	it("will throw an error if there is an operation", function()
		expect(function()
			return getFragmentQueryDocument(gql([[

          {
            a
            b
            c
          }
        ]]))
		end).toThrowError(
			"Found a query operation. No operations are allowed when using a fragment as a query. Only fragments are allowed."
		)
		expect(function()
			return getFragmentQueryDocument(gql([[

          query {
            a
            b
            c
          }
        ]]))
		end).toThrowError(
			"Found a query operation. No operations are allowed when using a fragment as a query. Only fragments are allowed."
		)
		expect(function()
			return getFragmentQueryDocument(gql([[

          query Named {
            a
            b
            c
          }
        ]]))
		end).toThrowError(
			"Found a query operation named 'Named'. No operations are allowed when using a fragment as a query. Only fragments are allowed."
		)
		expect(function()
			return getFragmentQueryDocument(gql([[

          mutation Named {
            a
            b
            c
          }
        ]]))
		end).toThrowError(
			"Found a mutation operation named 'Named'. No operations are allowed when using a fragment as a query. "
				.. "Only fragments are allowed."
		)
		expect(function()
			return getFragmentQueryDocument(gql([[

          subscription Named {
            a
            b
            c
          }
        ]]))
		end).toThrowError(
			"Found a subscription operation named 'Named'. No operations are allowed when using a fragment as a query. "
				.. "Only fragments are allowed."
		)
	end)

	it("will throw an error if there is not exactly one fragment but no `fragmentName`", function()
		expect(function()
			getFragmentQueryDocument(gql([[

        fragment foo on Foo {
          a
          b
          c
        }

        fragment bar on Bar {
          d
          e
          f
        }
      ]]))
		end).toThrowError("Found 2 fragments. `fragmentName` must be provided when there is not exactly 1 fragment.")
		expect(function()
			getFragmentQueryDocument(gql([[

        fragment foo on Foo {
          a
          b
          c
        }

        fragment bar on Bar {
          d
          e
          f
        }

        fragment baz on Baz {
          g
          h
          i
        }
      ]]))
		end).toThrowError("Found 3 fragments. `fragmentName` must be provided when there is not exactly 1 fragment.")
		expect(function()
			getFragmentQueryDocument(gql([[

        scalar Foo
      ]]))
		end).toThrowError("Found 0 fragments. `fragmentName` must be provided when there is not exactly 1 fragment.")
	end)

	it("will create a query document where the single fragment is spread in the root query", function()
		expect(print_(getFragmentQueryDocument(gql([[

          fragment foo on Foo {
            a
            b
            c
          }
        ]])))).toEqual(print_(gql([[

        {
          ...foo
        }

        fragment foo on Foo {
          a
          b
          c
        }
      ]])))
	end)

	it("will create a query document where the named fragment is spread in the root query", function()
		expect(print_(getFragmentQueryDocument(
			gql([[

            fragment foo on Foo {
              a
              b
              c
            }

            fragment bar on Bar {
              d
              e
              f
              ...foo
            }

            fragment baz on Baz {
              g
              h
              i
              ...foo
              ...bar
            }
          ]]),
			"foo"
		))).toEqual(print_(gql([[

        {
          ...foo
        }

        fragment foo on Foo {
          a
          b
          c
        }

        fragment bar on Bar {
          d
          e
          f
          ...foo
        }

        fragment baz on Baz {
          g
          h
          i
          ...foo
          ...bar
        }
      ]])))
		expect(print_(getFragmentQueryDocument(
			gql([[

            fragment foo on Foo {
              a
              b
              c
            }

            fragment bar on Bar {
              d
              e
              f
              ...foo
            }

            fragment baz on Baz {
              g
              h
              i
              ...foo
              ...bar
            }
          ]]),
			"bar"
		))).toEqual(print_(gql([[

        {
          ...bar
        }

        fragment foo on Foo {
          a
          b
          c
        }

        fragment bar on Bar {
          d
          e
          f
          ...foo
        }

        fragment baz on Baz {
          g
          h
          i
          ...foo
          ...bar
        }
      ]])))
		expect(print_(getFragmentQueryDocument(
			gql([[

            fragment foo on Foo {
              a
              b
              c
            }

            fragment bar on Bar {
              d
              e
              f
              ...foo
            }

            fragment baz on Baz {
              g
              h
              i
              ...foo
              ...bar
            }
          ]]),
			"baz"
		))).toEqual(print_(gql([[

        {
          ...baz
        }

        fragment foo on Foo {
          a
          b
          c
        }

        fragment bar on Bar {
          d
          e
          f
          ...foo
        }

        fragment baz on Baz {
          g
          h
          i
          ...foo
          ...bar
        }
      ]])))
	end)
end)

it("should create the fragment map correctly", function()
	local fragments = getFragmentDefinitions(gql([[

    fragment authorDetails on Author {
      firstName
      lastName
    }

    fragment moreAuthorDetails on Author {
      address
    }
  ]]))
	local fragmentMap = createFragmentMap(fragments)
	local expectedTable: FragmentMap = {
		authorDetails = fragments[1],
		moreAuthorDetails = fragments[2],
	}
	expect(fragmentMap).toEqual(expectedTable)
end)

it("should return an empty fragment map if passed undefined argument", function()
	expect(createFragmentMap(nil)).toEqual({})
end)

return {}
