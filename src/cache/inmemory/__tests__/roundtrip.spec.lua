-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/__tests__/roundtrip.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Boolean = LuauPolyfill.Boolean
	local Error = LuauPolyfill.Error
	local Object = LuauPolyfill.Object
	-- ROBLOX TODO: remove when available in LuauPolyfill
	Object.isFrozen = (table :: any).isfrozen

	type Array<T> = LuauPolyfill.Array<T>
	type Object = LuauPolyfill.Object

	local RegExp = require(rootWorkspace.LuauRegExp)

	local NULL = require(srcWorkspace.utilities).NULL

	local graphQLModule = require(rootWorkspace.GraphQL)
	type DocumentNode = graphQLModule.DocumentNode

	local gql = require(rootWorkspace.GraphQLTag).default

	local EntityStore = require(script.Parent.Parent.entityStore).EntityStore
	local StoreReader = require(script.Parent.Parent.readFromStore).StoreReader
	local StoreWriter = require(script.Parent.Parent.writeToStore).StoreWriter
	local InMemoryCache = require(script.Parent.Parent.inMemoryCache).InMemoryCache

	local helpersModule = require(script.Parent.helpers)
	local writeQueryToStore = helpersModule.writeQueryToStore
	local readQueryFromStore = helpersModule.readQueryFromStore
	local withError = helpersModule.withError

	local withErrorSpy = require(srcWorkspace.testing).withErrorSpy

	local function assertDeeplyFrozen(value: any, stack_: Array<any>?)
		local stack = stack_ :: Array<any>
		if stack_ == nil then
			stack = {}
		end

		if value ~= nil and typeof(value) == "table" and Array.indexOf(stack, value) < 0 then
			-- ROBLOX FIXME: can't check isExtensible
			-- jestExpect(Object.isExtensible(value)).toBe(false)
			jestExpect(Object.isFrozen(value)).toBe(true)
			table.insert(stack, value)
			Array.forEach(Object.keys(value), function(key)
				assertDeeplyFrozen(value[key], stack)
			end)
			jestExpect(table.remove(stack)).toBe(value)
		end
	end

	local function storeRoundtrip(query: DocumentNode, result: any, variables: Object?)
		if variables == nil then
			variables = {}
		end
		local cache = InMemoryCache.new({ possibleTypes = { Character = { "Jedi", "Droid" } } })

		local reader = StoreReader.new({ cache = cache })
		local writer = StoreWriter.new(cache)

		local store = writeQueryToStore({
			writer = writer,
			result = result,
			query = query,
			variables = variables,
		})

		local readOptions = { store = store, query = query, variables = variables }

		local reconstructedResult = readQueryFromStore(reader, readOptions)

		-- Make sure the result is identical if we haven't written anything new
		-- to the store. https://github.com/apollographql/apollo-client/pull/3394
		jestExpect(reconstructedResult).toEqual(result)
		jestExpect(store).toBeInstanceOf(EntityStore)
		jestExpect(readQueryFromStore(reader, readOptions)).toBe(reconstructedResult)

		local immutableResult = readQueryFromStore(reader, readOptions)
		jestExpect(immutableResult).toEqual(reconstructedResult)
		jestExpect(readQueryFromStore(reader, readOptions)).toBe(immutableResult)

		if Boolean.toJSBoolean(_G.__DEV__) then
			local ok, res = pcall(function()
				(immutableResult :: any).illegal = "this should not work"
				error(Error.new("unreached"))
			end)

			if not ok then
				-- ROBLOX deviation: freeze error is not of type Error, we need to check before assertion
				jestExpect(typeof(res) == "table" and res.message or res).never.toMatch(RegExp("unreached"))

				-- ROBLOX deviation: freeze error is not an instance of Error, adding a test to verify expected message
				-- jestExpect(res).toBeInstanceOf(Error)
				jestExpect(res).toMatch("Attempt to modify a readonly table")
			end

			assertDeeplyFrozen(immutableResult)
		end

		-- Now make sure subtrees of the result are identical even after we write
		-- an additional bogus field to the store.
		writeQueryToStore({
			writer = writer,
			store = store,
			result = { oyez = 1234 },
			query = gql([[

      {
        oyez
      }
    ]]),
		})

		local deletedRootResult = readQueryFromStore(reader, readOptions)
		jestExpect(deletedRootResult).toEqual(result)

		if deletedRootResult == reconstructedResult then
			-- We don't expect the new result to be identical to the previous result,
			-- but there are some rare cases where that can happen, and it's a good
			-- thing, because it means the caching system is working slightly better
			-- than expected... and we don't need to continue with the rest of the
			-- comparison logic below.
			return
		end

		Array.forEach(Object.keys(result), function(key)
			jestExpect(deletedRootResult[key]).toBe(reconstructedResult[key])
		end)
	end

	describe("roundtrip", function()
		it("real graphql result", function()
			storeRoundtrip(
				gql([[

        {
          people_one(id: "1") {
            name
          }
        }
      ]]),
				{ people_one = { name = "Luke Skywalker" } }
			)
		end)

		it("multidimensional array (#776)", function()
			storeRoundtrip(
				gql([[

        {
          rows {
            value
          }
        }
      ]]),
				{ rows = { { { value = 1 }, { value = 2 } }, { { value = 3 }, { value = 4 } } } }
			)
		end)

		it("array with null values (#1551)", function()
			storeRoundtrip(
				gql([[

        {
          list {
            value
          }
        }
      ]]),
				{ list = { NULL, { value = 1 } } }
			)
		end)

		it("enum arguments", function()
			storeRoundtrip(
				gql([[

        {
          hero(episode: JEDI) {
            name
          }
        }
      ]]),
				{ hero = { name = "Luke Skywalker" } }
			)
		end)

		it("with an alias", function()
			storeRoundtrip(
				gql([[

        {
          luke: people_one(id: "1") {
            name
          }
          vader: people_one(id: "4") {
            name
          }
        }
      ]]),
				{ luke = { name = "Luke Skywalker" }, vader = { name = "Darth Vader" } }
			)
		end)

		it("with variables", function()
			storeRoundtrip(
				gql([[

        {
          luke: people_one(id: $lukeId) {
            name
          }
          vader: people_one(id: $vaderId) {
            name
          }
        }
      ]]),
				{ luke = { name = "Luke Skywalker" }, vader = { name = "Darth Vader" } },
				{ lukeId = "1", vaderId = "4" }
			)
		end)

		it("with GraphQLJSON scalar type", function()
			local updateClub = {
				uid = "1d7f836018fc11e68d809dfee940f657",
				name = "Eple",
				settings = {
					name = "eple",
					currency = "AFN",
					calendarStretch = 2,
					defaultPreAllocationPeriod = 1,
					confirmationEmailCopy = NULL,
					emailDomains = NULL,
				},
			} :: any

			storeRoundtrip(
				gql([[

        {
          updateClub {
            uid
            name
            settings
          }
        }
      ]]),
				{ updateClub = updateClub }
			)

			-- Reading immutable results from the store does not mean the original
			-- data should get frozen.
			-- ROBLOX FIXME: can't check isExtensible
			-- jestExpect(Object.isExtensible(updateClub)).toBe(true)
			jestExpect(Object.isFrozen(updateClub)).toBe(false)
		end)

		describe("directives", function()
			it("should be able to query with skip directive true", function()
				storeRoundtrip(
					gql([[

          query {
            fortuneCookie @skip(if: true)
          }
        ]]),
					{}
				)
			end)

			it("should be able to query with skip directive false", function()
				storeRoundtrip(
					gql([[

          query {
            fortuneCookie @skip(if: false)
          }
        ]]),
					{ fortuneCookie = "live long and prosper" }
				)
			end)
		end)

		describe("fragments", function()
			-- ROBLOX TODO: fragments are not supported yet
			itSKIP("should work on null fields", function()
				storeRoundtrip(
					gql([[

          query {
            field {
              ... on Obj {
                stuff
              }
            }
          }
        ]]),
					{ field = NULL }
				)
			end)

			-- ROBLOX TODO: fragments are not supported yet
			itSKIP("should work on basic inline fragments", function()
				storeRoundtrip(
					gql([[

          query {
            field {
              __typename
              ... on Obj {
                stuff
              }
            }
          }
        ]]),
					{ field = { __typename = "Obj", stuff = "Result" } }
				)
			end)

			-- XXX this test is weird because it assumes the server returned an incorrect result
			-- However, the user may have written this result with client.writeQuery.
			-- ROBLOX TODO: fragments are not supported yet
			withErrorSpy(itSKIP, "should throw an error on two of the same inline fragment types", function()
				jestExpect(function()
					storeRoundtrip(
						gql([[

            query {
              all_people {
                __typename
                name
                ... on Jedi {
                  side
                }
                ... on Jedi {
                  rank
                }
              }
            }
          ]]),
						{
							all_people = {
								{ __typename = "Jedi", name = "Luke Skywalker", side = "bright" },
							},
						}
					)
				end).toThrowError(RegExp("Can't find field 'rank'"))
			end)

			-- ROBLOX TODO: fragments are not supported yet
			itSKIP("should resolve fields it can on interface with non matching inline fragments", function()
				return withError(function()
					storeRoundtrip(
						gql([[

            query {
              dark_forces {
                __typename
                name
                ... on Droid {
                  model
                }
              }
            }
          ]]),
						{
							dark_forces = {
								{ __typename = "Droid", name = "8t88", model = "88" },
								{ __typename = "Darth", name = "Anakin Skywalker" },
							},
						}
					)
				end)
			end)

			-- ROBLOX TODO: fragments are not supported yet
			itSKIP("should resolve on union types with spread fragments", function()
				return withError(function()
					storeRoundtrip(
						gql([[

            fragment jediFragment on Jedi {
              side
            }

            fragment droidFragment on Droid {
              model
            }

            query {
              all_people {
                __typename
                name
                ...jediFragment
                ...droidFragment
              }
            }
          ]]),
						{
							all_people = {
								{ __typename = "Jedi", name = "Luke Skywalker", side = "bright" },
								{ __typename = "Droid", name = "R2D2", model = "astromech" },
							},
						}
					)
				end)
			end)

			-- ROBLOX TODO: fragments are not supported yet
			itSKIP("should work with a fragment on the actual interface or union", function()
				return withError(function()
					storeRoundtrip(
						gql([[

            fragment jediFragment on Character {
              side
            }

            fragment droidFragment on Droid {
              model
            }

            query {
              all_people {
                name
                __typename
                ...jediFragment
                ...droidFragment
              }
            }
          ]]),
						{
							all_people = {
								{ __typename = "Jedi", name = "Luke Skywalker", side = "bright" },
								{
									__typename = "Droid",
									name = "R2D2",
									model = "astromech",
									side = "bright",
								},
							},
						}
					)
				end)
			end)

			-- ROBLOX TODO: fragments are not supported yet
			withErrorSpy(itSKIP, "should throw on error on two of the same spread fragment types", function()
				jestExpect(function()
					storeRoundtrip(
						gql([[

            fragment jediSide on Jedi {
              side
            }

            fragment jediRank on Jedi {
              rank
            }

            query {
              all_people {
                __typename
                name
                ...jediSide
                ...jediRank
              }
            }
          ]]),
						{
							all_people = {
								{ __typename = "Jedi", name = "Luke Skywalker", side = "bright" },
							},
						}
					)
				end).toThrowError(RegExp("Can't find field 'rank'"))
			end)

			-- ROBLOX TODO: fragments are not supported yet
			itSKIP("should resolve on @include and @skip with inline fragments", function()
				storeRoundtrip(
					gql([[

          query {
            person {
              name
              __typename
              ... on Jedi @include(if: true) {
                side
              }
              ... on Droid @skip(if: true) {
                model
              }
            }
          }
        ]]),
					{ person = { __typename = "Jedi", name = "Luke Skywalker", side = "bright" } }
				)
			end)

			-- ROBLOX TODO: fragments are not supported yet
			itSKIP("should resolve on @include and @skip with spread fragments", function()
				storeRoundtrip(
					gql([[

          fragment jediFragment on Jedi {
            side
          }

          fragment droidFragment on Droid {
            model
          }

          query {
            person {
              name
              __typename
              ...jediFragment @include(if: true)
              ...droidFragment @skip(if: true)
            }
          }
        ]]),
					{ person = { __typename = "Jedi", name = "Luke Skywalker", side = "bright" } }
				)
			end)
		end)
	end)
end
