-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/graphql/__tests__/getFromAST.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect
	-- local print = require(Packages.graphql).print
	local gql = require(rootWorkspace.Dev.GraphQLTag).default
	-- local graphqlModule = require(Packages.graphql)
	-- local FragmentDefinitionNode = graphqlModule.FragmentDefinitionNode
	-- local OperationDefinitionNode = graphqlModule.OperationDefinitionNode
	local getFromASTModule = require(script.Parent.Parent.getFromAST)
	-- local checkDocument = getFromASTModule.checkDocument
	-- local getFragmentDefinitions = getFromASTModule.getFragmentDefinitions
	-- local getQueryDefinition = getFromASTModule.getQueryDefinition
	-- local getDefaultValues = getFromASTModule.getDefaultValues
	local getOperationName = getFromASTModule.getOperationName
	-- describe("AST utility functions", function()
	-- 	it("should correctly check a document for correctness", function()
	-- 		local multipleQueries = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 		--[[ gql`
	--       query {
	--         author {
	--           firstName
	--           lastName
	--         }
	--       }

	--       query {
	--         author {
	--           address
	--         }
	--       }
	--     ` ]]
	-- 		expect(function()
	-- 			checkDocument(multipleQueries)
	-- 		end).toThrow()
	-- 		local namedFragment = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 		--[[ gql`
	--       query {
	--         author {
	--           ...authorDetails
	--         }
	--       }

	--       fragment authorDetails on Author {
	--         firstName
	--         lastName
	--       }
	--     ` ]]
	-- 		expect(function()
	-- 			checkDocument(namedFragment)
	-- 		end).not_.toThrow()
	-- 	end)
	-- 	it("should get fragment definitions from a document containing a single fragment", function()
	-- 		local singleFragmentDefinition = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 		--[[ gql`
	--       query {
	--         author {
	--           ...authorDetails
	--         }
	--       }

	--       fragment authorDetails on Author {
	--         firstName
	--         lastName
	--       }
	--     ` ]]
	-- 		local expectedDoc = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 		--[[ gql`
	--       fragment authorDetails on Author {
	--         firstName
	--         lastName
	--       }
	--     ` ]]
	-- 		local expectedResult: any --[[ ROBLOX TODO: Unhandled node for type: TSArrayType ]]		--[[ FragmentDefinitionNode[] ]]
	--  =
	-- 			{
	-- 				expectedDoc.definitions[1 --[[ ROBLOX adaptation: added 1 to array index ]]] :: FragmentDefinitionNode,
	-- 			}
	-- 		local actualResult = getFragmentDefinitions(singleFragmentDefinition)
	-- 		expect(actualResult.length).toEqual(expectedResult.length)
	-- 		expect(print(actualResult[1 --[[ ROBLOX adaptation: added 1 to array index ]]])).toBe(
	-- 			print(expectedResult[1 --[[ ROBLOX adaptation: added 1 to array index ]]])
	-- 		)
	-- 	end)
	-- 	it("should get fragment definitions from a document containing a multiple fragments", function()
	-- 		local multipleFragmentDefinitions = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 		--[[ gql`
	--       query {
	--         author {
	--           ...authorDetails
	--           ...moreAuthorDetails
	--         }
	--       }

	--       fragment authorDetails on Author {
	--         firstName
	--         lastName
	--       }

	--       fragment moreAuthorDetails on Author {
	--         address
	--       }
	--     ` ]]
	-- 		local expectedDoc = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 		--[[ gql`
	--       fragment authorDetails on Author {
	--         firstName
	--         lastName
	--       }

	--       fragment moreAuthorDetails on Author {
	--         address
	--       }
	--     ` ]]
	-- 		local expectedResult: any --[[ ROBLOX TODO: Unhandled node for type: TSArrayType ]]		--[[ FragmentDefinitionNode[] ]]
	--  =
	-- 			{
	-- 				expectedDoc.definitions[1 --[[ ROBLOX adaptation: added 1 to array index ]]] :: FragmentDefinitionNode,
	-- 				expectedDoc.definitions[2 --[[ ROBLOX adaptation: added 1 to array index ]]] :: FragmentDefinitionNode,
	-- 			}
	-- 		local actualResult = getFragmentDefinitions(multipleFragmentDefinitions)
	-- 		expect(actualResult:map(print)).toEqual(expectedResult:map(print))
	-- 	end)
	-- 	it(
	-- 		"should get the correct query definition out of a query containing multiple fragments",
	-- 		function()
	-- 			local queryWithFragments = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 			--[[ gql`
	--       fragment authorDetails on Author {
	--         firstName
	--         lastName
	--       }

	--       fragment moreAuthorDetails on Author {
	--         address
	--       }

	--       query {
	--         author {
	--           ...authorDetails
	--           ...moreAuthorDetails
	--         }
	--       }
	--     ` ]]
	-- 			local expectedDoc = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 			--[[ gql`
	--       query {
	--         author {
	--           ...authorDetails
	--           ...moreAuthorDetails
	--         }
	--       }
	--     ` ]]
	-- 			local expectedResult: OperationDefinitionNode =
	-- 				expectedDoc.definitions[1 --[[ ROBLOX adaptation: added 1 to array index ]]] :: OperationDefinitionNode
	-- 			local actualResult = getQueryDefinition(queryWithFragments)
	-- 			expect(print(actualResult)).toEqual(print(expectedResult))
	-- 		end
	-- 	)
	-- 	it("should throw if we try to get the query definition of a document with no query", function()
	-- 		local mutationWithFragments = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 		--[[ gql`
	--       fragment authorDetails on Author {
	--         firstName
	--         lastName
	--       }

	--       mutation {
	--         createAuthor(firstName: "John", lastName: "Smith") {
	--           ...authorDetails
	--         }
	--       }
	--     ` ]]
	-- 		expect(function()
	-- 			getQueryDefinition(mutationWithFragments)
	-- 		end).toThrow()
	-- 	end)
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
	-- 	it("should throw if type definitions found in document", function()
	-- 		local queryWithTypeDefination = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 		--[[ gql`
	--       fragment authorDetails on Author {
	--         firstName
	--         lastName
	--       }

	--       query($search: AuthorSearchInputType) {
	--         author(search: $search) {
	--           ...authorDetails
	--         }
	--       }

	--       input AuthorSearchInputType {
	--         firstName: String
	--       }
	--     ` ]]
	-- 		expect(function()
	-- 			getQueryDefinition(queryWithTypeDefination)
	-- 		end).toThrowError(
	-- 			'Schema type definitions not allowed in queries. Found: "InputObjectTypeDefinition"'
	-- 		)
	-- 	end)
	-- 	describe("getDefaultValues", function()
	-- 		it("will create an empty variable object if no default values are provided", function()
	-- 			local basicQuery = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 			--[[ gql`
	--         query people($first: Int, $second: String) {
	--           allPeople(first: $first) {
	--             people {
	--               name
	--             }
	--           }
	--         }
	--       ` ]]
	-- 			expect(getDefaultValues(getQueryDefinition(basicQuery))).toEqual({})
	-- 		end)
	-- 		it(
	-- 			"will create a variable object based on the definition node with default values",
	-- 			function()
	-- 				local basicQuery = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: TaggedTemplateExpression ]]
	-- 				--[[ gql`
	--         query people($first: Int = 1, $second: String!) {
	--           allPeople(first: $first) {
	--             people {
	--               name
	--             }
	--           }
	--         }
	--       ` ]]
	-- 				expect(getDefaultValues(getQueryDefinition(basicQuery))).toEqual({ first = 1 })
	-- 			end
	-- 		)
	-- 	end)
	-- end)
end
