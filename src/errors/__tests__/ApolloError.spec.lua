-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/errors/__tests__/ApolloError.ts
return function()
	local srcWorkspace = script.Parent.Parent.Parent
	local Packages = srcWorkspace.Parent

	local JestGlobals = require(Packages.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local ApolloError = require(srcWorkspace.errors).ApolloError

	local GraphQLError = require(Packages.GraphQL).GraphQLError

	local String = require(Packages.LuauPolyfill).String

	-- ROBLOX deviation: add polyfills for JS Primitives
	local LuauPolyfill = require(Packages.LuauPolyfill)
	local Error = LuauPolyfill.Error

	describe("ApolloError", function()
		it("should construct itself correctly", function()
			local graphQLErrors = {
				GraphQLError.new("Something went wrong with GraphQL"),
				GraphQLError.new("Something else went wrong with GraphQL"),
			}
			local networkError = Error.new("Network error")
			local errorMessage = "this is an error message"
			local apolloError = ApolloError.new({
				graphQLErrors = graphQLErrors,
				networkError = networkError,
				errorMessage = errorMessage,
			})
			jestExpect(apolloError.graphQLErrors).toEqual(graphQLErrors)
			jestExpect(apolloError.networkError).toEqual(networkError)
			jestExpect(apolloError.message).toBe(errorMessage)
		end)
		it("should add a network error to the message", function()
			local networkError = Error.new("this is an error message")
			local apolloError = ApolloError.new({ networkError = networkError })
			jestExpect(apolloError.message).toMatch("this is an error message")
			jestExpect(#String.split(apolloError.message, "\n")).toBe(1)
		end)
		it("should add a graphql error to the message", function()
			local graphQLErrors = { GraphQLError.new("this is an error message") }
			local apolloError = ApolloError.new({ graphQLErrors = graphQLErrors })
			jestExpect(apolloError.message).toMatch("this is an error message")
			jestExpect(#String.split(apolloError.message, "\n")).toBe(1)
		end)
		it("should add multiple graphql errors to the message", function()
			local graphQLErrors = { GraphQLError.new("this is new"), GraphQLError.new("this is old") }
			local apolloError = ApolloError.new({ graphQLErrors = graphQLErrors })
			local messages = String.split(apolloError.message, "\n")
			jestExpect(#messages).toBe(2)
			jestExpect(messages[1 --[[ ROBLOX adaptation: added 1 to array index ]]]).toMatch("this is new")
			jestExpect(messages[2 --[[ ROBLOX adaptation: added 1 to array index ]]]).toMatch("this is old")
		end)
		it("should add both network and graphql errors to the message", function()
			local graphQLErrors = { GraphQLError.new("graphql error message") }
			local networkError = Error.new("network error message")
			local apolloError = ApolloError.new({
				graphQLErrors = graphQLErrors,
				networkError = networkError,
			})
			local messages = String.split(apolloError.message, "\n")
			jestExpect(#messages).toBe(2)
			jestExpect(messages[1 --[[ ROBLOX adaptation: added 1 to array index ]]]).toMatch("graphql error message")
			jestExpect(messages[2 --[[ ROBLOX adaptation: added 1 to array index ]]]).toMatch("network error message")
		end)
		it("should contain a stack trace", function()
			local graphQLErrors = { GraphQLError.new("graphql error message") }
			local networkError = Error.new("network error message")
			local apolloError = ApolloError.new({
				graphQLErrors = graphQLErrors,
				networkError = networkError,
			})
			jestExpect(apolloError.stack).toBeDefined()
		end)
	end)
end
