-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/__tests__/diffAgainstStore.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Boolean = LuauPolyfill.Boolean
	local Error = LuauPolyfill.Error

	local RegExp = require(rootWorkspace.LuauRegExp)

	local HttpService = game:GetService("HttpService")

	local graphQLTagModule = require(rootWorkspace.Dev.GraphQLTag)
	local gql = graphQLTagModule.default
	local disableFragmentWarnings = graphQLTagModule.disableFragmentWarnings

	local StoreReader = require(script.Parent.Parent.readFromStore).StoreReader

	local StoreWriter = require(script.Parent.Parent.writeToStore).StoreWriter

	local defaultDataIdFromObject = require(script.Parent.Parent.policies).defaultDataIdFromObject

	local typesModule = require(script.Parent.Parent.types)
	type NormalizedCache = typesModule.NormalizedCache
	type Reference = typesModule.Reference

	local InMemoryCache = require(script.Parent.Parent.inMemoryCache).InMemoryCache

	local helpersModule = require(script.Parent.helpers)
	local defaultNormalizedCacheFactory = helpersModule.defaultNormalizedCacheFactory
	local writeQueryToStore = helpersModule.writeQueryToStore
	local withError = helpersModule.withError

	disableFragmentWarnings()

	describe("diffing queries against the store", function()
		local cache = InMemoryCache.new({ dataIdFromObject = defaultDataIdFromObject })
		local reader = StoreReader.new({ cache = cache })
		local writer = StoreWriter.new(cache)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("expects named fragments to return complete as true when diffd against " .. "the store", function()
			local store = defaultNormalizedCacheFactory({})

			local queryResult = reader:diffQueryAgainstStore({
				store = store,
				query = gql([[

          query foo {
            ...root
          }

          fragment root on Query {
            nestedObj {
              innerArray {
                id
                someField
              }
            }
          }
        ]]),
			})
			jestExpect(queryResult.complete).toEqual(false)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("expects inline fragments to return complete as true when diffd against " .. "the store", function()
			local store = defaultNormalizedCacheFactory()

			local queryResult = reader:diffQueryAgainstStore({
				store = store,
				query = gql([[

          {
            ... on DummyQuery {
              nestedObj {
                innerArray {
                  id
                  otherField
                }
              }
            }
            ... on Query {
              nestedObj {
                innerArray {
                  id
                  someField
                }
              }
            }
            ... on DummyQuery2 {
              nestedObj {
                innerArray {
                  id
                  otherField2
                }
              }
            }
          }
        ]]),
			})
			jestExpect(queryResult.complete).toEqual(false)
		end)

		it("returns nothing when the store is enough", function()
			local query = gql([[

      {
        people_one(id: "1") {
          name
        }
      }
    ]])

			local result = { people_one = { name = "Luke Skywalker" } }

			local store = writeQueryToStore({ writer = writer, result = result, query = query })
			jestExpect(reader:diffQueryAgainstStore({ store = store, query = query }).complete).toBeTruthy()
		end)

		it("caches root queries both under the ID of the node and the query name", function()
			local writer = StoreWriter.new(InMemoryCache.new({ typePolicies = { Person = { keyFields = { "id" } } } }))

			local store = writeQueryToStore({
				writer = writer,
				query = gql([[

        {
          people_one(id: "1") {
            __typename
            idAlias: id
            name
          }
        }
      ]]),
				result = {
					people_one = { __typename = "Person", idAlias = "1", name = "Luke Skywalker" },
				},
			})

			local secondQuery = gql([[

      {
        people_one(id: "1") {
          __typename
          id
          name
        }
      }
    ]])

			local complete = reader:diffQueryAgainstStore({ store = store, query = secondQuery }).complete

			jestExpect(complete).toBeTruthy()
			jestExpect((store :: any):lookup('Person:{"id":"1"}')).toEqual({
				__typename = "Person",
				id = "1",
				name = "Luke Skywalker",
			})
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("does not swallow errors other than field errors", function()
			local firstQuery = gql([[

      query {
        person {
          powers
        }
      }
    ]])

			local firstResult = { person = { powers = "the force" } }

			local store = writeQueryToStore({
				writer = writer,
				result = firstResult,
				query = firstQuery,
			})

			local unionQuery = gql([[

      query {
        ...notARealFragment
      }
    ]])
			return jestExpect(function()
				reader:diffQueryAgainstStore({ store = store, query = unionQuery })
			end).toThrowError(RegExp("No fragment"))
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("does not error on a correct query with union typed fragments", function()
			return withError(function()
				local firstQuery = gql([[

        query {
          person {
            __typename
            firstName
            lastName
          }
        }
      ]])

				local firstResult = {
					person = { __typename = "Author", firstName = "John", lastName = "Smith" },
				}

				local store = writeQueryToStore({
					writer = writer,
					result = firstResult,
					query = firstQuery,
				})

				local unionQuery = gql([[

        query {
          person {
            __typename
            ... on Author {
              firstName
              lastName
            }
            ... on Jedi {
              powers
            }
          }
        }
      ]])

				local complete = reader:diffQueryAgainstStore({
					store = store,
					query = unionQuery,
					returnPartialData = false,
				}).complete

				jestExpect(complete).toBe(true)
			end)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("does not error on a query with fields missing from all but one named fragment", function()
			local firstQuery = gql([[

      query {
        person {
          __typename
          firstName
          lastName
        }
      }
    ]])

			local firstResult = {
				person = { __typename = "Author", firstName = "John", lastName = "Smith" },
			}

			local store = writeQueryToStore({
				writer = writer,
				result = firstResult,
				query = firstQuery,
			})

			local unionQuery = gql([[

      query {
        person {
          __typename
          ...authorInfo
          ...jediInfo
        }
      }

      fragment authorInfo on Author {
        firstName
      }

      fragment jediInfo on Jedi {
        powers
      }
    ]])

			local complete = reader:diffQueryAgainstStore({ store = store, query = unionQuery }).complete

			jestExpect(complete).toBe(true)
		end)

		-- ROBLOX TODO: fragments are not supported yet. Tests pass but for the wrong reasons
		itSKIP("throws an error on a query with fields missing from matching named fragments", function()
			local firstQuery = gql([[

      query {
        person {
          __typename
          firstName
          lastName
        }
      }
    ]])

			local firstResult = {
				person = { __typename = "Author", firstName = "John", lastName = "Smith" },
			}

			local store = writeQueryToStore({
				writer = writer,
				result = firstResult,
				query = firstQuery,
			})

			local unionQuery = gql([[

      query {
        person {
          __typename
          ...authorInfo2
          ...jediInfo2
        }
      }

      fragment authorInfo2 on Author {
        firstName
        address
      }

      fragment jediInfo2 on Jedi {
        jedi
      }
    ]])

			jestExpect(function()
				reader:diffQueryAgainstStore({
					store = store,
					query = unionQuery,
					returnPartialData = false,
				})
			end).toThrow()
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("returns available fields if returnPartialData is true", function()
			local firstQuery = gql([[

      {
        people_one(id: "1") {
          __typename
          id
          name
        }
      }
    ]])

			local firstResult = {
				people_one = { __typename = "Person", id = "lukeId", name = "Luke Skywalker" },
			}

			local store = writeQueryToStore({
				writer = writer,
				result = firstResult,
				query = firstQuery,
			})

			-- Variants on a simple query with a missing field.

			local simpleQuery = gql([[

      {
        people_one(id: "1") {
          name
          age
        }
      }
    ]])

			local inlineFragmentQuery = gql([[

      {
        people_one(id: "1") {
          ... on Person {
            name
            age
          }
        }
      }
    ]])

			local namedFragmentQuery = gql([[

      query {
        people_one(id: "1") {
          ...personInfo
        }
      }

      fragment personInfo on Person {
        name
        age
      }
    ]])

			local simpleDiff = reader:diffQueryAgainstStore({ store = store, query = simpleQuery })

			jestExpect(simpleDiff.result).toEqual({
				people_one = { __typename = "Person", name = "Luke Skywalker" },
			})

			local inlineDiff = reader:diffQueryAgainstStore({
				store = store,
				query = inlineFragmentQuery,
			})

			jestExpect(inlineDiff.result).toEqual({
				people_one = { __typename = "Person", name = "Luke Skywalker" },
			})

			local namedDiff = reader:diffQueryAgainstStore({
				store = store,
				query = namedFragmentQuery,
			})

			jestExpect(namedDiff.result).toEqual({
				people_one = { __typename = "Person", name = "Luke Skywalker" },
			})

			jestExpect(function()
				reader:diffQueryAgainstStore({
					store = store,
					query = simpleQuery,
					returnPartialData = false,
				})
			end).toThrow()
		end)

		it("will add a private id property", function()
			local query = gql([[

      query {
        a {
          id
          b
        }
        c {
          d
          e {
            id
            f
          }
          g {
            h
          }
        }
      }
    ]])

			local queryResult = {
				a = { { id = "a:1", b = 1.1 }, { id = "a:2", b = 1.2 }, { id = "a:3", b = 1.3 } },
				c = {
					d = 2,
					e = {
						{ id = "e:1", f = 3.1 },
						{ id = "e:2", f = 3.2 },
						{ id = "e:3", f = 3.3 },
						{ id = "e:4", f = 3.4 },
						{ id = "e:5", f = 3.5 },
					},
					g = { h = 4 },
				},
			}

			local cache = InMemoryCache.new({
				dataIdFromObject = function(_self, ref)
					local id = ref.id
					return id
				end,
			})

			local writer = StoreWriter.new(cache)

			local store = writeQueryToStore({ writer = writer, query = query, result = queryResult })

			local result = reader:diffQueryAgainstStore({ store = store, query = query }).result

			jestExpect(result).toEqual(queryResult)

			jestExpect(cache:identify(result.a[1])).toEqual("a:1")

			jestExpect(cache:identify(result.a[2])).toEqual("a:2")

			jestExpect(cache:identify(result.a[3])).toEqual("a:3")

			jestExpect(cache:identify(result.c.e[1])).toEqual("e:1")

			jestExpect(cache:identify(result.c.e[2])).toEqual("e:2")

			jestExpect(cache:identify(result.c.e[3])).toEqual("e:3")

			jestExpect(cache:identify(result.c.e[4])).toEqual("e:4")

			jestExpect(cache:identify(result.c.e[5])).toEqual("e:5")
		end)

		describe("referential equality preservation", function()
			it("will return the previous result if there are no changes", function()
				local query = gql([[

        query {
          a {
            b
          }
          c {
            d
            e {
              f
            }
          }
        }
      ]])

				local queryResult = { a = { b = 1 }, c = { d = 2, e = { f = 3 } } }

				local store = writeQueryToStore({
					writer = writer,
					query = query,
					result = queryResult,
				})

				local previousResult = { a = { b = 1 }, c = { d = 2, e = { f = 3 } } }

				local result = reader:diffQueryAgainstStore({
					store = store,
					query = query,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(queryResult)
				jestExpect(result).toEqual(previousResult)
			end)

			it("will return parts of the previous result that changed", function()
				local query = gql([[

        query {
          a {
            b
          }
          c {
            d
            e {
              f
            }
          }
        }
      ]])

				local queryResult = { a = { b = 1 }, c = { d = 2, e = { f = 3 } } }

				local store = writeQueryToStore({
					writer = writer,
					query = query,
					result = queryResult,
				})

				local previousResult = { a = { b = 1 }, c = { d = 20, e = { f = 3 } } }

				local result = reader:diffQueryAgainstStore({
					store = store,
					query = query,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(queryResult)
				jestExpect(result).never.toEqual(previousResult)
				jestExpect(result.a).toEqual(previousResult.a)
				jestExpect(result.c).never.toEqual(previousResult.c)
				jestExpect(result.c.e).toEqual(previousResult.c.e)
			end)

			it("will return the previous result if there are no changes in child arrays", function()
				local query = gql([[

        query {
          a {
            b
          }
          c {
            d
            e {
              f
            }
          }
        }
      ]])

				local queryResult = {
					a = { { b = 1.1 }, { b = 1.2 }, { b = 1.3 } },
					c = { d = 2, e = { { f = 3.1 }, { f = 3.2 }, { f = 3.3 }, { f = 3.4 }, { f = 3.5 } } },
				}

				local store = writeQueryToStore({
					writer = writer,
					query = query,
					result = queryResult,
				})

				local previousResult = {
					a = { { b = 1.1 }, { b = 1.2 }, { b = 1.3 } },
					c = { d = 2, e = { { f = 3.1 }, { f = 3.2 }, { f = 3.3 }, { f = 3.4 }, { f = 3.5 } } },
				}
				local result = reader:diffQueryAgainstStore({
					store = store,
					query = query,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(queryResult)
				jestExpect(result).toEqual(previousResult)
			end)

			it("will not add zombie items when previousResult starts with the same items", function()
				local query = gql([[

        query {
          a {
            b
          }
        }
      ]])

				local queryResult = { a = { { b = 1.1 }, { b = 1.2 } } }

				local store = writeQueryToStore({
					writer = writer,
					query = query,
					result = queryResult,
				})

				local previousResult = { a = { { b = 1.1 }, { b = 1.2 }, { b = 1.3 } } }

				local result = reader:diffQueryAgainstStore({
					store = store,
					query = query,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(queryResult)
				jestExpect(result.a[1]).toEqual(previousResult.a[1])
				jestExpect(result.a[2]).toEqual(previousResult.a[2])
			end)

			it("will return the previous result if there are no changes in nested child arrays", function()
				local query = gql([[

        query {
          a {
            b
          }
          c {
            d
            e {
              f
            }
          }
        }
      ]])

				local queryResult = {
					a = { { { { { { b = 1.1 }, { b = 1.2 }, { b = 1.3 } } } } } },
					c = {
						d = 2,
						e = {
							{ { f = 3.1 }, { f = 3.2 }, { f = 3.3 } },
							{
								{ f = 3.4 },
								{ f = 3.5 },
							},
						},
					},
				}

				local store = writeQueryToStore({
					writer = writer,
					query = query,
					result = queryResult,
				})

				local previousResult = {
					a = { { { { { { b = 1.1 }, { b = 1.2 }, { b = 1.3 } } } } } },
					c = {
						d = 2,
						e = {
							{ { f = 3.1 }, { f = 3.2 }, { f = 3.3 } },
							{
								{ f = 3.4 },
								{ f = 3.5 },
							},
						},
					},
				}

				local result = reader:diffQueryAgainstStore({
					store = store,
					query = query,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(queryResult)
				jestExpect(result).toEqual(previousResult)
			end)

			it("will return parts of the previous result if there are changes in child arrays", function()
				local query = gql([[

        query {
          a {
            b
          }
          c {
            d
            e {
              f
            }
          }
        }
      ]])

				local queryResult = {
					a = { { b = 1.1 }, { b = 1.2 }, { b = 1.3 } },
					c = { d = 2, e = { { f = 3.1 }, { f = 3.2 }, { f = 3.3 }, { f = 3.4 }, {
						f = 3.5,
					} } },
				}

				local store = writeQueryToStore({
					writer = writer,
					query = query,
					result = queryResult,
				})

				local previousResult = {
					a = { { b = 1.1 }, { b = -1.2 }, { b = 1.3 } },
					c = {
						d = 20,
						e = { { f = 3.1 }, { f = 3.2 }, { f = 3.3 }, { f = 3.4 }, {
							f = 3.5,
						} },
					},
				}

				local result = reader:diffQueryAgainstStore({
					store = store,
					query = query,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(queryResult)
				jestExpect(result).never.toEqual(previousResult)
				jestExpect(result.a).never.toEqual(previousResult.a)
				jestExpect(result.a[1]).toEqual(previousResult.a[1])
				jestExpect(result.a[2]).never.toEqual(previousResult.a[2])
				jestExpect(result.a[3]).toEqual(previousResult.a[3])
				jestExpect(result.c).never.toEqual(previousResult.c)
				jestExpect(result.c.e).toEqual(previousResult.c.e)
				jestExpect(result.c.e[1]).toEqual(previousResult.c.e[1])
				jestExpect(result.c.e[2]).toEqual(previousResult.c.e[2])
				jestExpect(result.c.e[3]).toEqual(previousResult.c.e[3])
				jestExpect(result.c.e[4]).toEqual(previousResult.c.e[4])
				jestExpect(result.c.e[5]).toEqual(previousResult.c.e[5])
			end)

			it("will return the same items in a different order with `dataIdFromObject`", function()
				local query = gql([[

        query {
          a {
            id
            b
          }
          c {
            d
            e {
              id
              f
            }
            g {
              h
            }
          }
        }
      ]])

				local queryResult = {
					a = { { id = "a:1", b = 1.1 }, { id = "a:2", b = 1.2 }, { id = "a:3", b = 1.3 } },
					c = {
						d = 2,
						e = {
							{ id = "e:1", f = 3.1 },
							{ id = "e:2", f = 3.2 },
							{ id = "e:3", f = 3.3 },
							{ id = "e:4", f = 3.4 },
							{ id = "e:5", f = 3.5 },
						},
						g = { h = 4 },
					},
				}

				local writer = StoreWriter.new(InMemoryCache.new({
					dataIdFromObject = function(_self, ref)
						local id = ref.id
						return id
					end,
				}))

				local store = writeQueryToStore({
					writer = writer,
					query = query,
					result = queryResult,
				})

				local previousResult = {
					a = { { id = "a:3", b = 1.3 }, { id = "a:2", b = 1.2 }, { id = "a:1", b = 1.1 } },
					c = {
						d = 2,
						e = {
							{ id = "e:4", f = 3.4 },
							{ id = "e:2", f = 3.2 },
							{ id = "e:5", f = 3.5 },
							{ id = "e:3", f = 3.3 },
							{ id = "e:1", f = 3.1 },
						},
						g = { h = 4 },
					},
				}

				local result = reader:diffQueryAgainstStore({
					store = store,
					query = query,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(queryResult)
				jestExpect(result).never.toEqual(previousResult)
				jestExpect(result.a).never.toEqual(previousResult.a)
				jestExpect(result.a[1]).toEqual(previousResult.a[3])
				jestExpect(result.a[2]).toEqual(previousResult.a[2])
				jestExpect(result.a[3]).toEqual(previousResult.a[1])
				jestExpect(result.c).never.toEqual(previousResult.c)
				jestExpect(result.c.e).never.toEqual(previousResult.c.e)
				jestExpect(result.c.e[1]).toEqual(previousResult.c.e[5])
				jestExpect(result.c.e[2]).toEqual(previousResult.c.e[2])
				jestExpect(result.c.e[3]).toEqual(previousResult.c.e[4])
				jestExpect(result.c.e[4]).toEqual(previousResult.c.e[1])
				jestExpect(result.c.e[5]).toEqual(previousResult.c.e[3])
				jestExpect(result.c.g).toEqual(previousResult.c.g)
			end)

			it("will return the same JSON scalar field object", function()
				local query = gql([[

        {
          a {
            b
            c
          }
          d {
            e
            f
          }
        }
      ]])

				local queryResult = {
					a = { b = 1, c = { x = 2, y = 3, z = 4 } },
					d = { e = 5, f = { x = 6, y = 7, z = 8 } },
				}

				local store = writeQueryToStore({
					writer = writer,
					query = query,
					result = queryResult,
				})

				local previousResult = {
					a = { b = 1, c = { x = 2, y = 3, z = 4 } },
					d = { e = 50, f = { x = 6, y = 7, z = 8 } },
				}

				local result = reader:diffQueryAgainstStore({
					store = store,
					query = query,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(queryResult)
				jestExpect(result).never.toEqual(previousResult)
				jestExpect(result.a).toEqual(previousResult.a)
				jestExpect(result.d).never.toEqual(previousResult.d)
				jestExpect(result.d.f).toEqual(previousResult.d.f)
			end)

			it("will preserve equality with custom resolvers", function()
				local listQuery = gql([[

        {
          people {
            id
            name
            __typename
          }
        }
      ]])

				local listResult = {
					people = { { id = 4, name = "Luke Skywalker", __typename = "Person" } },
				}

				local itemQuery = gql([[

        {
          person(id: 4) {
            id
            name
            __typename
          }
        }
      ]])

				local cache = InMemoryCache.new({
					typePolicies = {
						Query = {
							fields = {
								person = function(_self, _, ref)
									local args = ref.args

									jestExpect(typeof((args :: any).id)).toBe("number")

									local ref_ = ref:toReference({
										__typename = "Person",
										id = (args :: any).id,
									})

									jestExpect(ref:isReference(ref_)).toBe(true)

									jestExpect(ref_).toEqual({
										__ref = ("Person:%s"):format(HttpService:JSONEncode({ id = (args :: any).id })),
									})

									local found = Array.find(ref:readField("people") :: any, function(person)
										if Boolean.toJSBoolean(ref_) then
											return person.__ref == ref_.__ref
										else
											return ref
										end
									end)

									jestExpect(found).toBeTruthy()

									return found
								end,
							},
						},
						Person = { keyFields = { "id" } },
					},
				})

				local reader = StoreReader.new({ cache = cache })

				local writer = StoreWriter.new(cache, reader)

				local store = writeQueryToStore({
					writer = writer,
					query = listQuery,
					result = listResult,
				})

				local previousResult = {
					person = listResult.people[1],
				}

				local result = reader:diffQueryAgainstStore({
					store = store,
					query = itemQuery,
					previousResult = previousResult,
				}).result

				jestExpect(result).toEqual(previousResult)
			end)
		end)

		describe("malformed queries", function()
			it("throws for non-scalar query fields without selection sets", function()
				-- Issue #4025, fixed by PR #4038.

				local validQuery = gql([[

        query getMessageList {
          messageList {
            id
            __typename
            message
          }
        }
      ]])

				local invalidQuery = gql([[

        query getMessageList {
          # This field needs a selection set because its value is an array
          # of non-scalar objects.
          messageList
        }
      ]])

				local store = writeQueryToStore({
					writer = writer,
					query = validQuery,
					result = {
						messageList = {
							{ id = 1, __typename = "Message", message = "hi" },
							{ id = 2, __typename = "Message", message = "hello" },
							{ id = 3, __typename = "Message", message = "hey" },
						},
					},
				})

				local ok, res = pcall(function()
					reader:diffQueryAgainstStore({ store = store, query = invalidQuery })
					error(Error.new("should have thrown"))
				end)

				if not ok then
					jestExpect(res.message).toEqual(
						"Missing selection set for object of type Message returned for query field messageList"
					)
				end
			end)
		end)

		describe("issue #4081", function()
			--ROBLOX TODO: fragments are not supported yet
			itSKIP("should not return results containing cycles", function()
				local company = { __typename = "Company", id = 1, name = "Apollo", users = {} } :: any

				table.insert(company.users, { __typename = "User", id = 1, name = "Ben", company = company })

				table.insert(company.users, { __typename = "User", id = 2, name = "James", company = company })

				local query = gql([[

        query Query {
          user {
            ...UserFragment
            company {
              users {
                ...UserFragment
              }
            }
          }
        }

        fragment UserFragment on User {
          id
          name
          company {
            id
            name
          }
        }
      ]])

				local function check(store: NormalizedCache)
					local result = reader:diffQueryAgainstStore({ store = store, query = query }).result

					-- This JSON.stringify call has the side benefit of verifying that the
					-- result does not have any cycles.
					local json = HttpService:JSONEncode(result)

					Array.forEach(company.users, function(user: any)
						jestExpect(json).toContain(HttpService:JSONEncode(user.name))
					end)

					jestExpect(result).toEqual({
						user = {
							__typename = "User",
							id = 1,
							name = "Ben",
							company = {
								__typename = "Company",
								id = 1,
								name = "Apollo",
								users = {
									{
										__typename = "User",
										id = 1,
										name = "Ben",
										company = { __typename = "Company", id = 1, name = "Apollo" },
									},
									{
										__typename = "User",
										id = 2,
										name = "James",
										company = { __typename = "Company", id = 1, name = "Apollo" },
									},
								},
							},
						},
					})
				end

				check(writeQueryToStore({
					writer = StoreWriter.new(InMemoryCache.new({ dataIdFromObject = 0 and nil or nil })),
					query = query,
					result = {
						user = company.users[1],
					},
				}))

				check(writeQueryToStore({
					writer = StoreWriter.new(InMemoryCache.new({ dataIdFromObject = defaultDataIdFromObject })),
					query = query,
					result = {
						user = company.users[1],
					},
				}))
			end)
		end)
	end)
end
