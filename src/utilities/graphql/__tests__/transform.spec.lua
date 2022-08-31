-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/3161e31538c33f3aafb18f955fbee0e6e7a0b0c0/src/utilities/graphql/__tests__/transform.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
type Array<T> = LuauPolyfill.Array<T>

local graphQLModule = require(rootWorkspace.GraphQL)
local print_ = graphQLModule.print
type DocumentNode = graphQLModule.DocumentNode
local gql = require(rootWorkspace.GraphQLTag).default
local disableFragmentWarnings = require(rootWorkspace.GraphQLTag).disableFragmentWarnings

-- Turn off warnings for repeated fragment names
disableFragmentWarnings()

local transformModule = require(script.Parent.Parent.transform)
local addTypenameToDocument = transformModule.addTypenameToDocument
local removeDirectivesFromDocument = transformModule.removeDirectivesFromDocument
local removeConnectionDirectiveFromDocument = transformModule.removeConnectionDirectiveFromDocument
local removeArgumentsFromDocument = transformModule.removeArgumentsFromDocument
local removeFragmentSpreadFromDocument = transformModule.removeFragmentSpreadFromDocument
local removeClientSetsFromDocument = transformModule.removeClientSetsFromDocument
local getQueryDefinition = require(script.Parent.Parent.getFromAST).getQueryDefinition

describe("removeArgumentsFromDocument", function()
	it("should remove a single variable", function()
		local query = gql([[

				query Simple($variable: String!) {
					field(usingVariable: $variable) {
						child
						foo
					}
					network
				}
			]])
		local expected = gql([[

				query Simple {
					field {
						child
						foo
					}
					network
				}
			]])
		local doc = removeArgumentsFromDocument({ {
			name = "variable",
		} }, query) :: DocumentNode
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove a single variable and the field from the query", function()
		local query = gql([[

				query Simple($variable: String!) {
					field(usingVariable: $variable) {
						child
						foo
					}
					network
				}
			]])
		local expected = gql([[

				query Simple {
					network
				}
			]])
		local doc = removeArgumentsFromDocument({ {
			name = "variable",
			remove = true,
		} }, query) :: DocumentNode
		expect(print_(doc)).toBe(print_(expected))
	end)
end)
describe("removeFragmentSpreadFromDocument", function()
	it("should remove a named fragment spread", function()
		local query = gql([[

				query Simple {
					...FragmentSpread
					property
					...ValidSpread
				}

				fragment FragmentSpread on Thing {
					foo
					bar
					baz
				}

				fragment ValidSpread on Thing {
					oof
					rab
					zab
				}
			]])
		local expected = gql([[

			query Simple {
				property
				...ValidSpread
			}

			fragment ValidSpread on Thing {
				oof
				rab
				zab
			}
			]])
		local doc = removeFragmentSpreadFromDocument({ {
			name = "FragmentSpread",
			remove = true,
		} }, query) :: DocumentNode
		expect(print_(doc)).toBe(print_(expected))
	end)
end)
describe("removeDirectivesFromDocument", function()
	it("should not remove unused variable definitions unless the field is removed", function()
		local query = gql([[

			query Simple($variable: String!) {
				field(usingVariable: $variable) @client
				networkField
			}
			]])

		local expected = gql([[

			query Simple($variable: String!) {
				field(usingVariable: $variable)
				networkField
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "client",
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove unused variable definitions associated with the removed directive", function()
		local query = gql([[

			query Simple($variable: String!) {
				field(usingVariable: $variable) @client
				networkField
			}
			]])

		local expected = gql([[

			query Simple {
				networkField
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "client",
			remove = true,
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should not remove used variable definitions", function()
		local query = gql([[

			query Simple($variable: String!) {
				field(usingVariable: $variable) @client
				networkField(usingVariable: $variable)
			}
			]])

		local expected = gql([[

			query Simple($variable: String!) {
				networkField(usingVariable: $variable)
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "client",
			remove = true,
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove fragment spreads and definitions associated with the removed directive", function()
		local query = gql([[

			query Simple {
				networkField
				field @client {
					...ClientFragment
				}
			}

			fragment ClientFragment on Thing {
				otherField
				bar
			}
			]])

		local expected = gql([[

			query Simple {
				networkField
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "client",
			remove = true,
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should not remove fragment spreads and definitions used without the removed directive", function()
		local query = gql([[

			query Simple {
				networkField {
					...ClientFragment
				}
				field @client {
					...ClientFragment
				}
			}

			fragment ClientFragment on Thing {
				otherField
				bar
			}
			]])

		local expected = gql([[

			query Simple {
				networkField {
					...ClientFragment
				}
			}

			fragment ClientFragment on Thing {
				otherField
				bar
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "client",
			remove = true,
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove a simple directive", function()
		local query = gql([[

			query Simple {
				field @storage(if: true)
			}
			]])

		local expected = gql([[

			query Simple {
				field
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "storage",
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove a simple directive [test function]", function()
		local query = gql([[

			query Simple {
				field @storage(if: true)
			}
			]])

		local expected = gql([[

			query Simple {
				field
			}
			]])

		local function test(_self: any, ref: any)
			local value = ref.name.value
			return value == "storage"
		end
		local doc = removeDirectivesFromDocument({ {
			test = test,
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove only the wanted directive", function()
		local query = gql([[

			query Simple {
				maybe @skip(if: false)
				field @storage(if: true)
			}
			]])

		local expected = gql([[

			query Simple {
				maybe @skip(if: false)
				field
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "storage",
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove only the wanted directive [test function]", function()
		local query = gql([[

			query Simple {
				maybe @skip(if: false)
				field @storage(if: true)
			}
			]])

		local expected = gql([[

			query Simple {
				maybe @skip(if: false)
				field
			}
			]])

		local function test(_self: any, ref: any)
			local value = ref.name.value
			return value == "storage"
		end
		local doc = removeDirectivesFromDocument({ {
			test = test,
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove multiple directives in the query", function()
		local query = gql([[

			query Simple {
				field @storage(if: true)
				other: field @storage
			}
			]])

		local expected = gql([[

			query Simple {
				field
				other: field
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "storage",
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove multiple directives of different kinds in the query", function()
		local query = gql([[

			query Simple {
				maybe @skip(if: false)
				field @storage(if: true)
				other: field @client
			}
			]])

		local expected = gql([[

			query Simple {
				maybe @skip(if: false)
				field
				other: field
			}
			]])

		-- ROBLOX FIXME Luau: cannot have arrays with different elements
		local removed = {
			{ name = "storage" } :: any,
			{
				test = function(_self: any, directive: any)
					return directive.name.value == "client"
				end,
			},
		}
		local doc = removeDirectivesFromDocument(removed, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove a simple directive and its field if needed", function()
		local query = gql([[

			query Simple {
				field @storage(if: true)
				keep
			}
			]])

		local expected = gql([[

			query Simple {
				keep
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "storage",
			remove = true,
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove a simple directive [test function]_", function()
		local query = gql([[

			query Simple {
				field @storage(if: true)
				keep
			}
			]])

		local expected = gql([[

			query Simple {
				keep
			}
			]])

		local function test(_self: any, ref: any)
			local value = ref.name.value
			return value == "storage"
		end
		local doc = removeDirectivesFromDocument({ {
			test = test,
			remove = true,
		} }, query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should return null if the query is no longer valid", function()
		local query = gql([[

			query Simple {
				field @storage(if: true)
			}
			]])

		local doc = removeDirectivesFromDocument({ { name = "storage", remove = true } }, query)
		expect(doc).toBe(nil)
	end)

	it("should return null if the query is no longer valid [test function]", function()
		local query = gql([[

			query Simple {
				field @storage(if: true)
			}
			]])

		local function test(_self: any, ref: any)
			local value = ref.name.value
			return value == "storage"
		end
		local doc = removeDirectivesFromDocument({ { test = test, remove = true } }, query)
		expect(doc).toBe(nil)
	end)

	it("should return null only if the query is not valid", function()
		local query = gql([[

			query Simple {
				...fragmentSpread
			}

			fragment fragmentSpread on Thing {
				field
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "storage",
			remove = true,
		} }, query)
		expect(print_(doc)).toBe(print_(query))
	end)

	it("should return null only if the query is not valid through nested fragments", function()
		local query = gql([[

			query Simple {
				...fragmentSpread
			}

			fragment fragmentSpread on Thing {
				...inDirection
			}

			fragment inDirection on Thing {
				field @storage
			}
			]])

		local doc = removeDirectivesFromDocument({ { name = "storage", remove = true } }, query)
		expect(doc).toBe(nil)
	end)

	it("should only remove values asked through nested fragments", function()
		local query = gql([[

			query Simple {
				...fragmentSpread
			}

			fragment fragmentSpread on Thing {
				...inDirection
			}

			fragment inDirection on Thing {
				field @storage
				bar
			}
			]])

		local expectedQuery = gql([[

			query Simple {
				...fragmentSpread
			}

			fragment fragmentSpread on Thing {
				...inDirection
			}

			fragment inDirection on Thing {
				bar
			}
			]])

		local doc = removeDirectivesFromDocument({ {
			name = "storage",
			remove = true,
		} }, query)
		expect(print_(doc)).toBe(print_(expectedQuery))
	end)

	it("should return null even through fragments if needed", function()
		local query = gql([[

			query Simple {
				...fragmentSpread
			}

			fragment fragmentSpread on Thing {
				field @storage
			}
			]])

		local doc = removeDirectivesFromDocument({ { name = "storage", remove = true } }, query)
		expect(doc).toBe(nil)
	end)

	it("should not throw in combination with addTypenameToDocument", function()
		local query = gql([[

			query Simple {
				...fragmentSpread
			}

			fragment fragmentSpread on Thing {
				...inDirection
			}

			fragment inDirection on Thing {
				field @storage
			}
			]])

		expect(function()
			removeDirectivesFromDocument({ { name = "storage", remove = true } }, addTypenameToDocument(query))
		end).never.toThrow()
	end)
end)
describe("query transforms", function()
	it("should correctly add typenames", function()
		local testQuery = gql([[

			query {
				author {
					name {
						firstName
						lastName
					}
				}
			}
			]])

		local newQueryDoc = addTypenameToDocument(testQuery)
		local expectedQuery = gql([[

			query {
				author {
					name {
						firstName
						lastName
						__typename
					}
					__typename
				}
			}
			]])

		local expectedQueryStr = print_(expectedQuery)
		expect(print_(newQueryDoc)).toBe(expectedQueryStr)
	end)

	it("should not add duplicates", function()
		local testQuery = gql([[

			query {
				author {
					name {
						firstName
						lastName
						__typename
					}
				}
			}
			]])

		local newQueryDoc = addTypenameToDocument(testQuery)
		local expectedQuery = gql([[

			query {
				author {
					name {
						firstName
						lastName
						__typename
					}
					__typename
				}
			}
			]])

		local expectedQueryStr = print_(expectedQuery)
		expect(print_(newQueryDoc)).toBe(expectedQueryStr)
	end)

	it("should not screw up on a FragmentSpread within the query AST", function()
		local testQuery = gql([[

			query withFragments {
				user(id: 4) {
					friends(first: 10) {
						...friendFields
					}
				}
			}
			]])

		local expectedQuery = getQueryDefinition(gql([[

			query withFragments {
				user(id: 4) {
					friends(first: 10) {
						...friendFields
						__typename
					}
					__typename
				}
			}
			]]))
		local modifiedQuery = addTypenameToDocument(testQuery)
		expect(print_(expectedQuery)).toBe(print_(getQueryDefinition(modifiedQuery)))
	end)

	it("should modify all definitions in a document", function()
		local testQuery = gql([[

			query withFragments {
				user(id: 4) {
					friends(first: 10) {
						...friendFields
					}
				}
			}

			fragment friendFields on User {
				firstName
				lastName
			}
			]])

		local newQueryDoc = addTypenameToDocument(testQuery)
		local expectedQuery = gql([[

			query withFragments {
				user(id: 4) {
					friends(first: 10) {
						...friendFields
						__typename
					}
					__typename
				}
			}

			fragment friendFields on User {
				firstName
				lastName
				__typename
			}
			]])

		expect(print_(expectedQuery)).toBe(print_(newQueryDoc))
	end)

	it("should be able to apply a QueryTransformer correctly", function()
		local testQuery = gql([[

			query {
				author {
					firstName
					lastName
				}
			}
			]])

		local expectedQuery = getQueryDefinition(gql([[

			query {
				author {
					firstName
					lastName
					__typename
				}
			}
			]]))
		local modifiedQuery = addTypenameToDocument(testQuery)
		expect(print_(expectedQuery)).toBe(print_(getQueryDefinition(modifiedQuery)))
	end)

	it("should be able to apply a MutationTransformer correctly", function()
		local testQuery = gql([[

			mutation {
				createAuthor(firstName: "John", lastName: "Smith") {
					firstName
					lastName
				}
			}
			]])

		local expectedQuery = gql([[

			mutation {
				createAuthor(firstName: "John", lastName: "Smith") {
					firstName
					lastName
					__typename
				}
			}
			]])

		local modifiedQuery = addTypenameToDocument(testQuery)
		expect(print_(expectedQuery)).toBe(print_(modifiedQuery))
	end)

	it("should add typename fields correctly on this one query", function()
		local testQuery = gql([[

			query Feed($type: FeedType!) {
				# Eventually move this into a no fetch query right on the entry
				# since we literally just need this info to determine whether to
				# show upvote/downvote buttons
				currentUser {
					login
				}
				feed(type: $type) {
					createdAt
					score
					commentCount
					id
					postedBy {
						login
						html_url
					}
					repository {
						name
						full_name
						description
						html_url
						stargazers_count
						open_issues_count
						created_at
						owner {
							avatar_url
						}
					}
				}
			}
			]])

		local expectedQuery = getQueryDefinition(gql([[

			query Feed($type: FeedType!) {
				currentUser {
					login
					__typename
				}
				feed(type: $type) {
					createdAt
					score
					commentCount
					id
					postedBy {
						login
						html_url
						__typename
					}
					repository {
						name
						full_name
						description
						html_url
						stargazers_count
						open_issues_count
						created_at
						owner {
							avatar_url
							__typename
						}
						__typename
					}
					__typename
				}
			}
			]]))
		local modifiedQuery = addTypenameToDocument(testQuery)
		expect(print_(expectedQuery)).toBe(print_(getQueryDefinition(modifiedQuery)))
	end)

	it("should correctly remove connections", function()
		local testQuery = gql([[

			query {
				author {
					name @connection(key: "foo") {
						firstName
						lastName
					}
				}
			}
			]])

		local newQueryDoc = removeConnectionDirectiveFromDocument(testQuery)
		local expectedQuery = gql([[

			query {
				author {
					name {
						firstName
						lastName
					}
				}
			}
			]])

		local expectedQueryStr = print_(expectedQuery)
		expect(expectedQueryStr).toBe(print_(newQueryDoc))
	end)
end)
describe("removeClientSetsFromDocument", function()
	it("should remove @client fields from document", function()
		local query = gql([[

			query Author {
				name
				isLoggedIn @client
			}
			]])

		local expected = gql([[

			query Author {
				name
			}
			]])

		local doc = removeClientSetsFromDocument(query)
		expect(print_(doc)).toBe(print_(expected))
	end)

	it("should remove @client fields from fragments", function()
		local query = gql([[

			fragment authorInfo on Author {
				name
				isLoggedIn @client
			}
			]])

		local expected = gql([[

			fragment authorInfo on Author {
				name
			}
			]])

		local doc = removeClientSetsFromDocument(query)
		expect(print_(doc)).toBe(print_(expected))
	end)
end)

return {}
