-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/graphql/__tests__/getFromAST.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	type Array<T> = LuauPolyfill.Array<T>

	local print = require(rootWorkspace.GraphQL).print
	local gql = require(rootWorkspace.GraphQLTag).default
	local graphqlModule = require(rootWorkspace.GraphQL)
	type FragmentDefinitionNode = graphqlModule.FragmentDefinitionNode
	type OperationDefinitionNode = graphqlModule.OperationDefinitionNode

	local getFromASTModule = require(script.Parent.Parent.getFromAST)
	local checkDocument = getFromASTModule.checkDocument
	local getFragmentDefinitions = getFromASTModule.getFragmentDefinitions
	local getQueryDefinition = getFromASTModule.getQueryDefinition
	local getDefaultValues = getFromASTModule.getDefaultValues
	local getOperationName = getFromASTModule.getOperationName

	describe("AST utility functions", function()
		it("should correctly check a document for correctness", function()
			local multipleQueries = gql([[

					query {
						author {
						  firstName
						  lastName
						}
					}
		
					query {
						author {
						  address
						}
					}
				]])
			jestExpect(function()
				checkDocument(multipleQueries)
			end).toThrow()

			local namedFragment = gql([[

					query {
						author {
						  ...authorDetails
						}
					}
		
					fragment authorDetails on Author {
						firstName
						lastName
					}
				]])
			jestExpect(function()
				checkDocument(namedFragment)
			end).never.toThrow()
		end)

		it("should get fragment definitions from a document containing a single fragment", function()
			local singleFragmentDefinition = gql([[

					query {
						author {
							...authorDetails
						}
					}

					fragment authorDetails on Author {
						firstName
						lastName
					}
				]])
			local expectedDoc = gql([[

					fragment authorDetails on Author {
						firstName
						lastName
					}
				]])
			local expectedResult: Array<FragmentDefinitionNode> = {
				expectedDoc.definitions[1] :: FragmentDefinitionNode,
			}
			local actualResult = getFragmentDefinitions(singleFragmentDefinition)
			jestExpect(#actualResult).toEqual(#expectedResult)
			jestExpect(print(actualResult[1])).toBe(print(expectedResult[1]))
		end)

		it("should get fragment definitions from a document containing a multiple fragments", function()
			local multipleFragmentDefinitions = gql([[

				query {
					author {
						...authorDetails
						...moreAuthorDetails
					}
				  }
	
				fragment authorDetails on Author {
					firstName
					lastName
				}
	
				fragment moreAuthorDetails on Author {
					address
				}
			]])
			local expectedDoc = gql([[

				fragment authorDetails on Author {
					firstName
					lastName
				}
	
				fragment moreAuthorDetails on Author {
					address
				}
			]])
			local expectedResult: Array<FragmentDefinitionNode> = {
				expectedDoc.definitions[1] :: FragmentDefinitionNode,
				expectedDoc.definitions[2] :: FragmentDefinitionNode,
			}
			local actualResult = getFragmentDefinitions(multipleFragmentDefinitions)
			jestExpect(Array.map(actualResult, print)).toEqual(Array.map(expectedResult, print))
		end)

		it("should get the correct query definition out of a query containing multiple fragments", function()
			local queryWithFragments = gql([[

				fragment authorDetails on Author {
					firstName
					lastName
				}
	
				fragment moreAuthorDetails on Author {
					address
				}
	
				query {
					author {
						...authorDetails
						...moreAuthorDetails
					}
				}
			]])
			local expectedDoc = gql([[

				query {
					author {
						...authorDetails
						...moreAuthorDetails
					}
				}
			]])
			local expectedResult: OperationDefinitionNode = expectedDoc.definitions[1] :: OperationDefinitionNode
			local actualResult = getQueryDefinition(queryWithFragments)

			jestExpect(print(actualResult)).toEqual(print(expectedResult))
		end)

		it("should throw if we try to get the query definition of a document with no query", function()
			local mutationWithFragments = gql([[

				fragment authorDetails on Author {
					firstName
					lastName
				}
	
				mutation {
					createAuthor(firstName: "John", lastName: "Smith") {
						...authorDetails
					}
				}
			]])
			jestExpect(function()
				getQueryDefinition(mutationWithFragments)
			end).toThrow()
		end)

		it("should get the operation name out of a query", function()
			local query = gql([[

				query nameOfQuery {
					fortuneCookie
				}
			]])
			local operationName = getOperationName(query)
			jestExpect(operationName).toEqual("nameOfQuery")
		end)

		it("should get the operation name out of a mutation", function()
			local query = gql([[

				mutation nameOfMutation {
					fortuneCookie
				}
			]])
			local operationName = getOperationName(query)
			jestExpect(operationName).toEqual("nameOfMutation")
		end)

		it("should return null if the query does not have an operation name", function()
			local query = gql([[

				{
					fortuneCookie
				}
			]])
			local operationName = getOperationName(query)
			jestExpect(operationName).toEqual(nil)
		end)

		it("should throw if type definitions found in document", function()
			local queryWithTypeDefination = gql([[

				fragment authorDetails on Author {
					firstName
					lastName
					}
		
					query($search: AuthorSearchInputType) {
					author(search: $search) {
						...authorDetails
					}
					}
		
					input AuthorSearchInputType {
					firstName: String
					}
			]])
			jestExpect(function()
				getQueryDefinition(queryWithTypeDefination)
			end).toThrowError('Schema type definitions not allowed in queries. Found: "InputObjectTypeDefinition"')
		end)

		describe("getDefaultValues", function()
			it("will create an empty variable object if no default values are provided", function()
				local basicQuery = gql([[

					query people($first: Int, $second: String) {
						allPeople(first: $first) {
						people {
							name
						}
						}
					}
				]])
				jestExpect(getDefaultValues(getQueryDefinition(basicQuery))).toEqual({})
			end)

			it("will create a variable object based on the definition node with default values", function()
				local basicQuery = gql([[

					query people($first: Int = 1, $second: String!) {
						allPeople(first: $first) {
						  people {
							name
						  }
						}
					  }
				]])
				jestExpect(getDefaultValues(getQueryDefinition(basicQuery))).toEqual({ first = 1 })
			end)
		end)
	end)
end
