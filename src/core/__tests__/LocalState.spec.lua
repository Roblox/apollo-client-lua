-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/core/__tests__/LocalState.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest

local coreModule = require(script.Parent.Parent.Parent.core)
local ApolloClient = coreModule.ApolloClient
local InMemoryCache = coreModule.InMemoryCache
local gql = coreModule.gql

--[[*
	 * Creates an apollo-client instance with a local query resolver named 'localQuery'.
	 * @param localQueryResolver resolver function to run for "localQuery" query.
	]]
local function setupClientWithLocalQueryResolver(localQueryResolver: any)
	local cache = InMemoryCache.new()

	local resolvers = {
		Query = { localQuery = localQueryResolver },
	}

	local client = ApolloClient.new({
		cache = cache,
		resolvers = resolvers,
	})

	return client
end

describe("LocalState", function()
	it("resolver info field provides information about named fragments", function()
		-- Create client with local resolver
		local localQueryResolver = jest.fn().mockReturnValue({
			__typename = "LocalQueryResponse",
			namedFragmentField = "namedFragmentFieldValue",
		})
		local client = setupClientWithLocalQueryResolver(localQueryResolver)

		-- Query local resolver using named fragment
		local query = gql([[

      fragment NamedFragment on LocalQueryResponse {
        namedFragmentField
      }
      query {
        localQuery @client {
          ...NamedFragment
        }
      }
    ]])
		client
			:query({
				query = query,
			})
			:expect()

		-- Verify "fragmentMap" passed through via resolver's "info" parameter
		-- ROBLOX deviation START: thisArg is first argument, access 5 instead
		local localResolverInfoParam = localQueryResolver.mock.calls[1][5]
		expect(localResolverInfoParam.fragmentMap).toBeDefined()
		-- ROBLOX deviation END

		-- Verify local resolver can see "namedFragmentField" selected from named fragment
		-- ROBLOX deviation START: expect.objectContaining does not match correctly
		expect(localResolverInfoParam.fragmentMap.NamedFragment.selectionSet.selections[1]).toEqual({
			arguments = {},
			directives = {},
			kind = "Field",
			loc = expect.anything(),
			name = {
				kind = "Name",
				loc = expect.anything(),
				value = "namedFragmentField",
			},
		})
		-- ROBLOX deviation END
	end)
end)

return {}
