-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/parser/__tests__/parser.test.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local gql = require(rootWorkspace.GraphQLTag).default
local RegExp = require(rootWorkspace.LuauRegExp)
local ParentModule = require(script.Parent.Parent)
local parser = ParentModule.parser
local DocumentType = ParentModule.DocumentType
type OperationDefinition = any

describe("parser", function()
	it("should error if both a query and a mutation is present", function()
		local query = gql([[

      query {
        user {
          name
        }
      }

      mutation($t: String) {
        addT(t: $t) {
          user {
            name
          }
        }
      }
    ]])
		expect(function()
			parser(query)
		end).toThrowError(RegExp("react-apollo only supports"))
	end)
	it("should error if multiple operations are present", function()
		local query = gql([[

      query One {
        user {
          name
        }
      }

      query Two {
        user {
          name
        }
      }
    ]])
		expect(function()
			parser(query)
		end).toThrowError(RegExp("react-apollo only supports"))
	end)
	it("should error if not a DocumentNode", function()
		local query = [[

      query One { user { name } }
    ]]
		expect(function()
			parser(query :: any)
		end).toThrowError(RegExp("not a valid GraphQL DocumentNode"))
	end)
	it("should return the name of the operation", function()
		local query = gql([[

      query One {
        user {
          name
        }
      }
    ]])
		expect(parser(query).name).toBe("One")
		local mutation = gql([[

      mutation One {
        user {
          name
        }
      }
    ]])
		expect(parser(mutation).name).toBe("One")
		local subscription = gql([[

      subscription One {
        user {
          name
        }
      }
    ]])
		expect(parser(subscription).name).toBe("One")
	end)
	it("should return data as the name of the operation if not named", function()
		local query = gql([[

      query {
        user {
          name
        }
      }
    ]])
		expect(parser(query).name).toBe("data")
		local unnamedQuery = gql([[

      {
        user {
          name
        }
      }
    ]])
		expect(parser(unnamedQuery).name).toBe("data")
		local mutation = gql([[

      mutation {
        user {
          name
        }
      }
    ]])
		expect(parser(mutation).name).toBe("data")
		local subscription = gql([[

      subscription {
        user {
          name
        }
      }
    ]])
		expect(parser(subscription).name).toBe("data")
	end)
	it("should return the type of operation", function()
		local query = gql([[

      query One {
        user {
          name
        }
      }
    ]])
		expect(parser(query).type).toBe(DocumentType.Query)
		local unnamedQuery = gql([[

      {
        user {
          name
        }
      }
    ]])
		expect(parser(unnamedQuery).type).toBe(DocumentType.Query)
		local mutation = gql([[

      mutation One {
        user {
          name
        }
      }
    ]])
		expect(parser(mutation).type).toBe(DocumentType.Mutation)
		local subscription = gql([[

      subscription One {
        user {
          name
        }
      }
    ]])
		expect(parser(subscription).type).toBe(DocumentType.Subscription)
	end)
	it("should return the variable definitions of the operation", function()
		local query = gql([[

      query One($t: String!) {
        user(t: $t) {
          name
        }
      }
    ]])
		local definition = query.definitions[1] :: OperationDefinition
		expect(parser(query).variables).toEqual(definition.variableDefinitions)
		local mutation = gql([[

      mutation One($t: String!) {
        user(t: $t) {
          name
        }
      }
    ]])
		definition = mutation.definitions[1] :: OperationDefinition
		expect(parser(mutation).variables).toEqual(definition.variableDefinitions)
		local subscription = gql([[

      subscription One($t: String!) {
        user(t: $t) {
          name
        }
      }
    ]])
		definition = subscription.definitions[1] :: OperationDefinition
		expect(parser(subscription).variables).toEqual(definition.variableDefinitions)
	end)

	it("should not error if the operation has no variables", function()
		local query = gql([[

      query {
        user(t: $t) {
          name
        }
      }
    ]])
		local definition = query.definitions[1] :: OperationDefinition
		expect(parser(query).variables).toEqual(definition.variableDefinitions)
		local mutation = gql([[

      mutation {
        user(t: $t) {
          name
        }
      }
    ]])
		definition = mutation.definitions[1] :: OperationDefinition
		expect(parser(mutation).variables).toEqual(definition.variableDefinitions)
		local subscription = gql([[

      subscription {
        user(t: $t) {
          name
        }
      }
    ]])
		definition = subscription.definitions[1] :: OperationDefinition
		expect(parser(subscription).variables).toEqual(definition.variableDefinitions)
	end)
end)

return {}
