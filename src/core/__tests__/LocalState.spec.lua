-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/core/__tests__/LocalState.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
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
		-- ROBLOX TODO: fragments are not supported
		xit("resolver info field provides information about named fragments", function()
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
			local localResolverInfoParam = localQueryResolver.mock.calls[1][4]
			jestExpect(localResolverInfoParam.fragmentMap).toBeDefined()

			-- Verify local resolver can see "namedFragmentField" selected from named fragment
			jestExpect(localResolverInfoParam.fragmentMap.NamedFragment.selectionSet.selections).toContainEqual(
				jestExpect.objectContaining({
					name = {
						kind = "Name",
						value = "namedFragmentField",
					},
				})
			)
		end)
	end)
end
