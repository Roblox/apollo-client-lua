-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/__tests__/ApolloClient.ts

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
local instanceOf = LuauPolyfill.instanceof
local Object = LuauPolyfill.Object
local setTimeout = LuauPolyfill.setTimeout

type Array<T> = LuauPolyfill.Array<T>
type Map<T, U> = LuauPolyfill.Map<T, U>
type Object = LuauPolyfill.Object
type Promise<T> = LuauPolyfill.Promise<T>

type Record<T, U> = { [T]: U }

type Partial<T> = Object

local Promise = require(rootWorkspace.Promise)

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local jestExpect = JestGlobals.expect

local gql = require(rootWorkspace.GraphQLTag).default

local coreModule = require(script.Parent.Parent.core)
local ApolloClient = coreModule.ApolloClient
type ApolloClientOptions<TCacheShape> = coreModule.ApolloClientOptions<TCacheShape>
type DefaultOptions = coreModule.DefaultOptions
type FetchPolicy = coreModule.FetchPolicy
type QueryOptions<TVariables, TData> = coreModule.QueryOptions<TVariables, TData>
local makeReference = coreModule.makeReference

local Observable = require(script.Parent.Parent.utilities).Observable
local ApolloLink = require(script.Parent.Parent.link.core).ApolloLink
local httpLinkModule = require(script.Parent.Parent.link.http)
local HttpLink = httpLinkModule.HttpLink
type HttpLink = httpLinkModule.HttpLink

local inMemoryCacheModule = require(script.Parent.Parent.cache.inmemory.inMemoryCache)
local InMemoryCache = inMemoryCacheModule.InMemoryCache
type InMemoryCache = inMemoryCacheModule.InMemoryCache

local apolloCacheModule = require(script.Parent.Parent.cache.core.cache)
type ApolloCache<TCacheShape> = apolloCacheModule.ApolloCache<TCacheShape>

local testingModule = require(script.Parent.Parent.testing)
local stripSymbols = testingModule.stripSymbols
local withErrorSpy = testingModule.withErrorSpy
local typedDocumentNodeModule = require(srcWorkspace.jsutils.typedDocumentNode)
type TypedDocumentNode<Result, Variables> = typedDocumentNodeModule.TypedDocumentNode<Result, Variables>

return function()
	describe("ApolloClient", function()
		describe("constructor", function()
			local oldFetch: any

			beforeEach(function()
				oldFetch = _G.fetch
				_G.fetch = function()
					return nil :: any
				end
			end)

			afterEach(function()
				_G.fetch = oldFetch
			end)

			it("will throw an error if cache is not passed in", function()
				jestExpect(function()
					ApolloClient.new({ link = ApolloLink.empty() } :: any)
				end).toThrowErrorMatchingSnapshot()
			end)

			it("should create an `HttpLink` instance if `uri` is provided", function()
				local uri = "http://localhost:4000"
				local client = ApolloClient.new({ cache = InMemoryCache.new(), uri = uri })
				jestExpect(client.link).toBeDefined()
				jestExpect((client.link :: HttpLink).options.uri).toEqual(uri)
			end)

			it("should accept `link` over `uri` if both are provided", function()
				local uri1 = "http://localhost:3000"
				local uri2 = "http://localhost:4000"
				local client = ApolloClient.new({
					cache = InMemoryCache.new(),
					uri = uri1,
					link = HttpLink.new({ uri = uri2 }),
				})
				jestExpect((client.link :: HttpLink).options.uri).toEqual(uri2)
			end)

			it("should create an empty Link if `uri` and `link` are not provided", function()
				local client = ApolloClient.new({ cache = InMemoryCache.new() })
				jestExpect(client.link).toBeDefined()
				jestExpect(instanceOf(client.link, ApolloLink)).toBeTruthy()
			end)
		end)

		describe("readQuery", function()
			it("will read some data from the store", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new():restore({ ROOT_QUERY = { a = 1, b = 2, c = 3 } }),
				} :: any)

				jestExpect(stripSymbols(client:readQuery({
					query = gql([[

              {
                a
              }
            ]]),
				}))).toEqual({ a = 1 })

				jestExpect(stripSymbols(client:readQuery({
					query = gql([[

              {
                b
                c
              }
            ]]),
				}))).toEqual({ b = 2, c = 3 })

				jestExpect(stripSymbols(client:readQuery({
					query = gql([[

              {
                a
                b
                c
              }
            ]]),
				}))).toEqual({ a = 1, b = 2, c = 3 })
			end)

			it("will read some deeply nested data from the store", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new():restore({
						ROOT_QUERY = { a = 1, b = 2, c = 3, d = makeReference("foo") },
						foo = { __typename = "Foo", e = 4, f = 5, g = 6, h = makeReference("bar") },
						bar = { __typename = "Bar", i = 7, j = 8, k = 9 },
					}),
				} :: any)

				jestExpect(stripSymbols(client:readQuery({
					query = gql([[

              {
                a
                d {
                  e
                }
              }
            ]]),
				}))).toEqual({ a = 1, d = { e = 4, __typename = "Foo" } })

				jestExpect(stripSymbols(client:readQuery({
					query = gql([[

              {
                a
                d {
                  e
                  h {
                    i
                  }
                }
              }
            ]]),
				}))).toEqual({
					a = 1,
					d = { __typename = "Foo", e = 4, h = { i = 7, __typename = "Bar" } },
				})

				jestExpect(stripSymbols(client:readQuery({
					query = gql([[

              {
                a
                b
                c
                d {
                  e
                  f
                  g
                  h {
                    i
                    j
                    k
                  }
                }
              }
            ]]),
				}))).toEqual({
					a = 1,
					b = 2,
					c = 3,
					d = {
						__typename = "Foo",
						e = 4,
						f = 5,
						g = 6,
						h = { __typename = "Bar", i = 7, j = 8, k = 9 },
					},
				})
			end)

			it("will read some data from the store with variables", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new():restore({
						ROOT_QUERY = {
							['field({"literal":true,"value":42})'] = 1,
							['field({"literal":false,"value":42})'] = 2,
						},
					}),
				} :: any)

				jestExpect(stripSymbols(client:readQuery({
					query = gql([[

              query($literal: Boolean, $value: Int) {
                a: field(literal: true, value: 42)
                b: field(literal: $literal, value: $value)
              }
            ]]),
					variables = { literal = false, value = 42 },
				}))).toEqual({ a = 1, b = 2 })
			end)
		end)

		it("will read some data from the store with default values", function()
			local client = ApolloClient.new({
				link = ApolloLink.empty(),
				cache = InMemoryCache.new():restore({
					ROOT_QUERY = {
						['field({"literal":true,"value":-1})'] = 1,
						['field({"literal":false,"value":42})'] = 2,
					},
				}),
			} :: any)

			jestExpect(stripSymbols(client:readQuery({
				query = gql([[

            query($literal: Boolean, $value: Int = -1) {
              a: field(literal: $literal, value: $value)
            }
          ]]),
				variables = { literal = false, value = 42 },
			}))).toEqual({ a = 2 })

			jestExpect(stripSymbols(client:readQuery({
				query = gql([[

            query($literal: Boolean, $value: Int = -1) {
              a: field(literal: $literal, value: $value)
            }
          ]]),
				variables = { literal = true },
			}))).toEqual({ a = 1 })
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xdescribe("readFragment", function()
			it("will throw an error when there is no fragment", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				jestExpect(function()
					client:readFragment({
						id = "x",
						fragment = gql([[

            query {
              a
              b
              c
            }
          ]]),
					})
				end).toThrowError(
					"Found a query operation. No operations are allowed when using a fragment as a query. Only fragments are allowed."
				)

				jestExpect(function()
					client:readFragment({
						id = "x",
						fragment = gql([[

            schema {
              query: Query
            }
          ]]),
					})
				end).toThrowError(
					"Found 0 fragments. `fragmentName` must be provided when there is not exactly 1 fragment."
				)
			end)

			it("will throw an error when there is more than one fragment but no fragment name", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				jestExpect(function()
					client:readFragment({
						id = "x",
						fragment = gql([[

            fragment a on A {
              a
            }

            fragment b on B {
              b
            }
          ]]),
					})
				end).toThrowError(
					"Found 2 fragments. `fragmentName` must be provided when there is not exactly 1 fragment."
				)

				jestExpect(function()
					client:readFragment({
						id = "x",
						fragment = gql([[

            fragment a on A {
              a
            }

            fragment b on B {
              b
            }

            fragment c on C {
              c
            }
          ]]),
					})
				end).toThrowError(
					"Found 3 fragments. `fragmentName` must be provided when there is not exactly 1 fragment."
				)
			end)

			it("will read some deeply nested data from the store at any id", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new():restore({
						ROOT_QUERY = {
							__typename = "Foo",
							a = 1,
							b = 2,
							c = 3,
							d = makeReference("foo"),
						},
						foo = { __typename = "Foo", e = 4, f = 5, g = 6, h = makeReference("bar") },
						bar = { __typename = "Bar", i = 7, j = 8, k = 9 },
					}),
				} :: any)

				jestExpect(stripSymbols(client:readFragment({
					id = "foo",
					fragment = gql([[

              fragment fragmentFoo on Foo {
                e
                h {
                  i
                }
              }
            ]]),
				}))).toEqual({ __typename = "Foo", e = 4, h = { __typename = "Bar", i = 7 } })

				jestExpect(stripSymbols(client:readFragment({
					id = "foo",
					fragment = gql([[

              fragment fragmentFoo on Foo {
                e
                f
                g
                h {
                  i
                  j
                  k
                }
              }
            ]]),
				}))).toEqual({
					__typename = "Foo",
					e = 4,
					f = 5,
					g = 6,
					h = { __typename = "Bar", i = 7, j = 8, k = 9 },
				})

				jestExpect(stripSymbols(client:readFragment({
					id = "bar",
					fragment = gql([[

              fragment fragmentBar on Bar {
                i
              }
            ]]),
				}))).toEqual({ __typename = "Bar", i = 7 })

				jestExpect(stripSymbols(client:readFragment({
					id = "bar",
					fragment = gql([[

              fragment fragmentBar on Bar {
                i
                j
                k
              }
            ]]),
				}))).toEqual({ __typename = "Bar", i = 7, j = 8, k = 9 })

				jestExpect(stripSymbols(client:readFragment({
					id = "foo",
					fragment = gql([[

              fragment fragmentFoo on Foo {
                e
                f
                g
                h {
                  i
                  j
                  k
                }
              }

              fragment fragmentBar on Bar {
                i
                j
                k
              }
            ]]),
					fragmentName = "fragmentFoo",
				}))).toEqual({
					__typename = "Foo",
					e = 4,
					f = 5,
					g = 6,
					h = { __typename = "Bar", i = 7, j = 8, k = 9 },
				})

				jestExpect(stripSymbols(client:readFragment({
					id = "bar",
					fragment = gql([[

              fragment fragmentFoo on Foo {
                e
                f
                g
                h {
                  i
                  j
                  k
                }
              }

              fragment fragmentBar on Bar {
                i
                j
                k
              }
            ]]),
					fragmentName = "fragmentBar",
				}))).toEqual({ __typename = "Bar", i = 7, j = 8, k = 9 })
			end)

			it("will read some data from the store with variables", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new():restore({
						foo = {
							__typename = "Foo",
							['field({"literal":true,"value":42})'] = 1,
							['field({"literal":false,"value":42})'] = 2,
						},
					}),
				} :: any)

				jestExpect(stripSymbols(client:readFragment({
					id = "foo",
					fragment = gql([[

              fragment foo on Foo {
                a: field(literal: true, value: 42)
                b: field(literal: $literal, value: $value)
              }
            ]]),
					variables = { literal = false, value = 42 },
				}))).toEqual({ __typename = "Foo", a = 1, b = 2 })
			end)

			it("will return null when an id that can\u{2019}t be found is provided", function()
				local client1 = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				local client2 = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new():restore({
						bar = { __typename = "Foo", a = 1, b = 2, c = 3 },
					}),
				} :: any)

				local client3 = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new():restore({
						foo = { __typename = "Foo", a = 1, b = 2, c = 3 },
					}),
				} :: any)

				jestExpect(client1:readFragment({
					id = "foo",
					fragment = gql([[

            fragment fooFragment on Foo {
              a
              b
              c
            }
          ]]),
				})).toBe(nil)

				jestExpect(client2:readFragment({
					id = "foo",
					fragment = gql([[

            fragment fooFragment on Foo {
              a
              b
              c
            }
          ]]),
				})).toBe(nil)

				jestExpect(stripSymbols(client3:readFragment({
					id = "foo",
					fragment = gql([[

              fragment fooFragment on Foo {
                a
                b
                c
              }
            ]]),
				}))).toEqual({ __typename = "Foo", a = 1, b = 2, c = 3 })
			end)
		end)

		describe("writeQuery", function()
			it("will write some data to the store", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				client:writeQuery({
					data = { a = 1 },
					query = gql([[

          {
            a
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", a = 1 },
				})

				client:writeQuery({
					data = { b = 2, c = 3 },
					query = gql([[

          {
            b
            c
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", a = 1, b = 2, c = 3 },
				})

				client:writeQuery({
					data = { a = 4, b = 5, c = 6 },
					query = gql([[

          {
            a
            b
            c
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", a = 4, b = 5, c = 6 },
				})
			end)

			it("will write some deeply nested data to the store", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({
						typePolicies = { Query = { fields = { d = { merge = false } } } } :: any,
					}),
				})

				client:writeQuery({
					data = { a = 1, d = { __typename = "D", e = 4 } },
					query = gql([[

          {
            a
            d {
              e
            }
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()

				client:writeQuery({
					data = { a = 1, d = { __typename = "D", h = { __typename = "H", i = 7 } } },
					query = gql([[

          {
            a
            d {
              h {
                i
              }
            }
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()

				client:writeQuery({
					data = {
						a = 1,
						b = 2,
						c = 3,
						d = {
							__typename = "D",
							e = 4,
							f = 5,
							g = 6,
							h = { __typename = "H", i = 7, j = 8, k = 9 },
						},
					},
					query = gql([[

          {
            a
            b
            c
            d {
              e
              f
              g
              h {
                i
                j
                k
              }
            }
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
			end)

			it("will write some data to the store with variables", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				client:writeQuery({
					data = { a = 1, b = 2 },
					query = gql([[

          query($literal: Boolean, $value: Int) {
            a: field(literal: true, value: 42)
            b: field(literal: $literal, value: $value)
          }
        ]]),
					variables = { literal = false, value = 42 },
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						['field({"literal":true,"value":42})'] = 1,
						['field({"literal":false,"value":42})'] = 2,
					},
				})
			end)

			it("will write some data to the store with default values for variables", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				client:writeQuery({
					data = { a = 2 },
					query = gql([[

          query($literal: Boolean, $value: Int = -1) {
            a: field(literal: $literal, value: $value)
          }
        ]]),
					variables = { literal = true, value = 42 },
				})

				client:writeQuery({
					data = { a = 1 },
					query = gql([[

          query($literal: Boolean, $value: Int = -1) {
            a: field(literal: $literal, value: $value)
          }
        ]]),
					variables = { literal = false },
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						['field({"literal":true,"value":42})'] = 2,
						['field({"literal":false,"value":-1})'] = 1,
					},
				})
			end)

			withErrorSpy(it, "should warn when the data provided does not match the query shape", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({ possibleTypes = {} }),
				})
				client:writeQuery({
					data = { todos = { { id = "1", name = "Todo 1", __typename = "Todo" } } },
					query = gql([[

          query {
            todos {
              id
              name
              description
            }
          }
        ]]),
				})
			end)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xdescribe("writeFragment", function()
			it("will throw an error when there is no fragment", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				jestExpect(function()
					client:writeFragment({
						data = {},
						id = "x",
						fragment = gql([[

            query {
              a
              b
              c
            }
          ]]),
					})
				end).toThrowError(
					"Found a query operation. No operations are allowed when using a fragment as a query. Only fragments are allowed."
				)

				jestExpect(function()
					client:writeFragment({
						data = {},
						id = "x",
						fragment = gql([[

            schema {
              query: Query
            }
          ]]),
					})
				end).toThrowError(
					"Found 0 fragments. `fragmentName` must be provided when there is not exactly 1 fragment."
				)
			end)

			it("will throw an error when there is more than one fragment but no fragment name", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				jestExpect(function()
					client:writeFragment({
						data = {},
						id = "x",
						fragment = gql([[

            fragment a on A {
              a
            }

            fragment b on B {
              b
            }
          ]]),
					})
				end).toThrowError(
					"Found 2 fragments. `fragmentName` must be provided when there is not exactly 1 fragment."
				)

				jestExpect(function()
					client:writeFragment({
						data = {},
						id = "x",
						fragment = gql([[

            fragment a on A {
              a
            }

            fragment b on B {
              b
            }

            fragment c on C {
              c
            }
          ]]),
					})
				end).toThrowError(
					"Found 3 fragments. `fragmentName` must be provided when there is not exactly 1 fragment."
				)
			end)

			it("will write some deeply nested data into the store at any id", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({
						dataIdFromObject = function(_self, o: any)
							return o.id
						end,
					}),
				})

				client:writeFragment({
					data = { __typename = "Foo", e = 4, h = { __typename = "Bar", id = "bar", i = 7 } },
					id = "foo",
					fragment = gql([[

          fragment fragmentFoo on Foo {
            e
            h {
              i
            }
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()

				client:writeFragment({
					data = {
						__typename = "Foo",
						f = 5,
						g = 6,
						h = { __typename = "Bar", id = "bar", j = 8, k = 9 },
					},
					id = "foo",
					fragment = gql([[

          fragment fragmentFoo on Foo {
            f
            g
            h {
              j
              k
            }
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()

				client:writeFragment({
					data = { __typename = "Bar", i = 10 },
					id = "bar",
					fragment = gql([[

          fragment fragmentBar on Bar {
            i
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()

				client:writeFragment({
					data = { __typename = "Bar", j = 11, k = 12 },
					id = "bar",
					fragment = gql([[

          fragment fragmentBar on Bar {
            j
            k
          }
        ]]),
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()

				client:writeFragment({
					data = {
						__typename = "Foo",
						e = 4,
						f = 5,
						g = 6,
						h = { __typename = "Bar", id = "bar", i = 7, j = 8, k = 9 },
					},
					id = "foo",
					fragment = gql([[

          fragment fooFragment on Foo {
            e
            f
            g
            h {
              i
              j
              k
            }
          }

          fragment barFragment on Bar {
            i
            j
            k
          }
        ]]),
					fragmentName = "fooFragment",
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()

				client:writeFragment({
					data = { __typename = "Bar", i = 10, j = 11, k = 12 },
					id = "bar",
					fragment = gql([[

          fragment fooFragment on Foo {
            e
            f
            g
            h {
              i
              j
              k
            }
          }

          fragment barFragment on Bar {
            i
            j
            k
          }
        ]]),
					fragmentName = "barFragment",
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
			end)

			it("will write some data to the store with variables", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				client:writeFragment({
					data = { __typename = "Foo", a = 1, b = 2 },
					id = "foo",
					fragment = gql([[

          fragment foo on Foo {
            a: field(literal: true, value: 42)
            b: field(literal: $literal, value: $value)
          }
        ]]),
					variables = { literal = false, value = 42 },
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					__META = { extraRootIds = { "foo" } },
					foo = {
						__typename = "Foo",
						['field({"literal":true,"value":42})'] = 1,
						['field({"literal":false,"value":42})'] = 2,
					},
				})
			end)

			withErrorSpy(it, "should warn when the data provided does not match the fragment shape", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({ possibleTypes = {} }),
				})

				client:writeFragment({
					data = { __typename = "Bar", i = 10 },
					id = "bar",
					fragment = gql([[

          fragment fragmentBar on Bar {
            i
            e
          }
        ]]),
				})
			end)

			describe("change will call observable next", function()
				local query = gql([[

        query nestedData {
          people {
            id
            friends {
              id
              type
            }
          }
        }
      ]])

				type Friend = { id: number, type: string, __typename: string }

				type Data = { people: { id: number, __typename: string, friends: Array<Friend> } }

				local bestFriend = { id = 1, type = "best", __typename = "Friend" }

				local badFriend = { id = 2, type = "bad", __typename = "Friend" }

				local data = {
					people = { id = 1, __typename = "Person", friends = { bestFriend, badFriend } },
				}

				local link = ApolloLink.new(function()
					return Observable.of({ data = data })
				end)

				local function newClient()
					return ApolloClient.new({
						link = link,
						cache = InMemoryCache.new({
							typePolicies = { Person = { fields = { friends = { merge = false } } } },
							dataIdFromObject = function(_self, result)
								if
									Boolean.toJSBoolean((function()
										if Boolean.toJSBoolean(result.id) then
											return result.__typename
										else
											return result.id
										end
									end)())
								then
									return result.__typename .. tostring(result.id)
								end
								return nil
							end,
							addTypename = true,
						} :: any),
					})
				end

				describe("using writeQuery", function()
					it("with TypedDocumentNode", function()
						local client = newClient()

						-- This is defined manually for the purpose of the test, but
						-- eventually this could be generated with graphql-code-generator
						local typedQuery: TypedDocumentNode<Data, { testVar: string }> = query

						-- The result and variables are being typed automatically, based on the query object we pass,
						-- and type inference is done based on the TypeDocumentNode object.
						local result = client
							:query({
								query = typedQuery,
								variables = {
									testVar = "foo",
								},
							})
							:expect()
						-- Just try to access it, if something will break, TS will throw an error
						-- during the test
						local _check = result.data.people.friends[0].id
					end)

					it("with a replacement of nested array (wq)", function()
						-- ROBLOX deviation: wrap in promise to wait for done
						Promise.new(function(done, _fail)
							local count = 0

							local client = newClient()

							local observable = client:watchQuery({ query = query })

							local subscription
							subscription = observable:subscribe({
								next = function(_self, nextResult)
									(function()
										count += 1
										return count
									end)()
									if count == 1 then
										jestExpect(stripSymbols(nextResult.data)).toEqual(data)
										jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(data)
										local readData = stripSymbols(client:readQuery({ query = query }))
										jestExpect(stripSymbols(readData)).toEqual(data)
										local bestFriends = Array.filter((readData :: any).people.friends, function(x)
											return x.type == "best"
										end)
										client:writeQuery({
											query = query,
											data = {
												people = {
													id = 1,
													friends = bestFriends,
													__typename = "Person",
												},
											},
										})
									elseif count == 2 then
										local expectation = {
											people = {
												id = 1,
												friends = { bestFriend },
												__typename = "Person",
											},
										}
										jestExpect(stripSymbols(nextResult.data)).toEqual(expectation)
										jestExpect(stripSymbols(client:readQuery({ query = query }))).toEqual(
											expectation
										)
										subscription:unsubscribe()
										done()
									end
								end,
							})
						end):timeout(3):expect()
					end)

					it("with a value change inside a nested array (wq)", function()
						-- ROBLOX deviation: wrap in promise to wait for done
						Promise.new(function(done, fail)
							local count = 0

							local client = newClient()

							local observable = client:watchQuery({ query = query })
							observable:subscribe({
								next = function(_self, nextResult)
									(function()
										local result = count
										count += 1
										return result
									end)()
									if count == 1 then
										jestExpect(stripSymbols(nextResult.data)).toEqual(data)
										jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(data)
										local readData = stripSymbols(client:readQuery({ query = query }))
										jestExpect(stripSymbols(readData)).toEqual(data)
										local friends = (readData :: any).people.friends
										friends[
											1 --[[ ROBLOX adaptation: added 1 to array index ]]
										].type =
											"okayest"
										friends[
											2 --[[ ROBLOX adaptation: added 1 to array index ]]
										].type =
											"okayest"
										client:writeQuery({
											query = query,
											data = {
												people = {
													id = 1,
													friends = friends,
													__typename = "Person",
												},
											},
										})
										setTimeout(function()
											if count == 1 then
												fail(
													Error.new(
														"writeFragment did not re-call observable with next value"
													)
												)
											end
										end, 250)
									end
									if count == 2 then
										local expectation0 = Object.assign({}, bestFriend, { type = "okayest" })
										local expectation1 = Object.assign({}, badFriend, { type = "okayest" })
										local nextFriends = stripSymbols((nextResult.data :: any).people.friends)
										jestExpect(nextFriends[1]).toEqual(expectation0)
										jestExpect(nextFriends[2]).toEqual(expectation1)
										local readFriends = stripSymbols(
											(client:readQuery({ query = query }) :: any).people.friends
										)
										jestExpect(readFriends[1]).toEqual(expectation0)
										jestExpect(readFriends[2]).toEqual(expectation1)
										done()
									end
								end,
							})
						end):timeout(3):expect()
					end)
				end)

				-- ROBLOX TODO: fragments are not supported yet
				xdescribe("using writeFragment", function()
					it("with a replacement of nested array (wf)", function()
						-- ROBLOX deviation: wrap in promise to wait for done
						Promise.new(function(done, fail)
							local count = 0

							local client = newClient()

							local observable = client:watchQuery({ query = query })

							observable:subscribe({
								next = function(_self, result)
									(function()
										local result = count
										count += 1
										return result
									end)()
									if count == 1 then
										jestExpect(stripSymbols(result.data)).toEqual(data)
										jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(data)
										local bestFriends = Array.filter(
											(result.data :: any).people.friends,
											function(x)
												return x.type == "best"
											end
										)
										client:writeFragment({
											id = ("Person%s"):format((result.data :: any).people.id),
											fragment = gql([[

                    fragment bestFriends on Person {
                      friends {
                        id
                      }
                    }
                  ]]),
											data = { friends = bestFriends, __typename = "Person" },
										})
										setTimeout(function()
											if count == 1 then
												fail(
													Error.new(
														"writeFragment did not re-call observable with next value"
													)
												)
											end
										end, 50)
									end
									if count == 2 then
										jestExpect(stripSymbols((result.data :: any).people.friends)).toEqual({
											bestFriend,
										})
										done()
									end
								end,
							})
						end):timeout(3):expect()
					end)

					it("with a value change inside a nested array (wf)", function()
						-- ROBLOX deviation: wrap in promise to wait for done
						Promise.new(function(done, fail)
							local count = 0

							local client = newClient()

							local observable = client:watchQuery({ query = query })

							observable:subscribe({
								next = function(_self, result)
									(function()
										local result = count
										count += 1
										return result
									end)()
									if count == 1 then
										jestExpect(stripSymbols(result.data)).toEqual(data)
										jestExpect(stripSymbols(observable:getCurrentResult().data)).toEqual(data)
										local friends = (result.data :: any).people.friends
										client:writeFragment({
											id = ("Person%s"):format((result.data :: any).people.id),
											fragment = gql([[

                    fragment bestFriends on Person {
                      friends {
                        id
                        type
                      }
                    }
                  ]]),
											data = {
												friends = {
													Object.assign({}, friends[1], { type = "okayest" }),
													Object.assign({}, friends[2], { type = "okayest" }),
												},
												__typename = "Person",
											},
										})
										setTimeout(function()
											if count == 1 then
												fail(
													Error.new(
														"writeFragment did not re-call observable with next value"
													)
												)
											end
										end, 50)
									end
									if count == 2 then
										local nextFriends = stripSymbols((result.data :: any).people.friends)
										jestExpect(nextFriends[1]).toEqual(
											Object.assign({}, bestFriend, { type = "okayest" })
										)
										jestExpect(nextFriends[2]).toEqual(
											Object.assign({}, badFriend, { type = "okayest" })
										)
										done()
									end
								end,
							})
						end):timeout(3):expect()
					end)
				end)
			end)
		end)

		describe("write then read", function()
			-- ROBLOX TODO: fragments are not supported yet
			xit("will write data locally which will then be read back", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({
						dataIdFromObject = function(_self, object)
							if typeof(object.__typename) == "string" then
								return string.lower(object.__typename)
							end
							return nil :: any
						end,
					}):restore({
						foo = { __typename = "Foo", a = 1, b = 2, c = 3, bar = makeReference("bar") },
						bar = { __typename = "Bar", d = 4, e = 5, f = 6 },
					}),
				} :: any)

				jestExpect(stripSymbols(client:readFragment({
					id = "foo",
					fragment = gql([[

              fragment x on Foo {
                a
                b
                c
                bar {
                  d
                  e
                  f
                }
              }
            ]]),
				}))).toEqual({
					__typename = "Foo",
					a = 1,
					b = 2,
					c = 3,
					bar = { d = 4, e = 5, f = 6, __typename = "Bar" },
				})

				client:writeFragment({
					id = "foo",
					fragment = gql([[

          fragment x on Foo {
            a
          }
        ]]),
					data = { __typename = "Foo", a = 7 },
				})

				jestExpect(stripSymbols(client:readFragment({
					id = "foo",
					fragment = gql([[

              fragment x on Foo {
                a
                b
                c
                bar {
                  d
                  e
                  f
                }
              }
            ]]),
				}))).toEqual({
					__typename = "Foo",
					a = 7,
					b = 2,
					c = 3,
					bar = { __typename = "Bar", d = 4, e = 5, f = 6 },
				})

				client:writeFragment({
					id = "foo",
					fragment = gql([[

          fragment x on Foo {
            bar {
              d
            }
          }
        ]]),
					data = { __typename = "Foo", bar = { __typename = "Bar", d = 8 } },
				})

				jestExpect(stripSymbols(client:readFragment({
					id = "foo",
					fragment = gql([[

              fragment x on Foo {
                a
                b
                c
                bar {
                  d
                  e
                  f
                }
              }
            ]]),
				}))).toEqual({
					__typename = "Foo",
					a = 7,
					b = 2,
					c = 3,
					bar = { __typename = "Bar", d = 8, e = 5, f = 6 },
				})

				client:writeFragment({
					id = "bar",
					fragment = gql([[

          fragment y on Bar {
            e
          }
        ]]),
					data = { __typename = "Bar", e = 9 },
				})

				jestExpect(stripSymbols(client:readFragment({
					id = "foo",
					fragment = gql([[

              fragment x on Foo {
                a
                b
                c
                bar {
                  d
                  e
                  f
                }
              }
            ]]),
				}))).toEqual({
					__typename = "Foo",
					a = 7,
					b = 2,
					c = 3,
					bar = { __typename = "Bar", d = 8, e = 9, f = 6 },
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
			end)

			it("will write data to a specific id", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({
						dataIdFromObject = function(_self, o: any)
							return o.key
						end,
					}),
				})

				client:writeQuery({
					query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                key
                e
                f
              }
            }
          }
        ]]),
					data = {
						a = 1,
						b = 2,
						foo = {
							__typename = "foo",
							c = 3,
							d = 4,
							bar = { key = "foobar", __typename = "bar", e = 5, f = 6 },
						},
					},
				})

				jestExpect(stripSymbols(client:readQuery({
					query = gql([[

              {
                a
                b
                foo {
                  c
                  d
                  bar {
                    key
                    e
                    f
                  }
                }
              }
            ]]),
				}))).toEqual({
					a = 1,
					b = 2,
					foo = {
						__typename = "foo",
						c = 3,
						d = 4,
						bar = { __typename = "bar", key = "foobar", e = 5, f = 6 },
					},
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
			end)

			it("will not use a default id getter if __typename is not present", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({ addTypename = false }),
				})

				client:writeQuery({
					query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                id
                e
                f
              }
            }
          }
        ]]),
					data = { a = 1, b = 2, foo = { c = 3, d = 4, bar = { id = "foobar", e = 5, f = 6 } } },
				})

				client:writeQuery({
					query = gql([[

          {
            g
            h
            bar {
              i
              j
              foo {
                _id
                k
                l
              }
            }
          }
        ]]),
					data = {
						g = 8,
						h = 9,
						bar = { i = 10, j = 11, foo = { _id = "barfoo", k = 12, l = 13 } },
					},
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						a = 1,
						b = 2,
						g = 8,
						h = 9,
						bar = { i = 10, j = 11, foo = { _id = "barfoo", k = 12, l = 13 } },
						foo = { c = 3, d = 4, bar = { id = "foobar", e = 5, f = 6 } },
					},
				})
			end)

			it("will not use a default id getter if id and _id are not present", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				client:writeQuery({
					query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                e
                f
              }
            }
          }
        ]]),
					data = {
						a = 1,
						b = 2,
						foo = {
							__typename = "foo",
							c = 3,
							d = 4,
							bar = { __typename = "bar", e = 5, f = 6 },
						},
					},
				})

				client:writeQuery({
					query = gql([[

          {
            g
            h
            bar {
              i
              j
              foo {
                k
                l
              }
            }
          }
        ]]),
					data = {
						g = 8,
						h = 9,
						bar = {
							__typename = "bar",
							i = 10,
							j = 11,
							foo = { __typename = "foo", k = 12, l = 13 },
						},
					},
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
			end)

			it("will use a default id getter if __typename and id are present", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				client:writeQuery({
					query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                id
                e
                f
              }
            }
          }
        ]]),
					data = {
						a = 1,
						b = 2,
						foo = {
							__typename = "foo",
							c = 3,
							d = 4,
							bar = { __typename = "bar", id = "foobar", e = 5, f = 6 },
						},
					},
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
			end)

			it("will use a default id getter if __typename and _id are present", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				client:writeQuery({
					query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                _id
                e
                f
              }
            }
          }
        ]]),
					data = {
						a = 1,
						b = 2,
						foo = {
							__typename = "foo",
							c = 3,
							d = 4,
							bar = { __typename = "bar", _id = "foobar", e = 5, f = 6 },
						},
					},
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
			end)

			it("will not use a default id getter if id is present and __typename is not present", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({ addTypename = false }),
				})

				client:writeQuery({
					query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                id
                e
                f
              }
            }
          }
        ]]),
					data = {
						a = 1,
						b = 2,
						foo = { c = 3, d = 4, bar = { id = "foobar", e = 5, f = 6 } },
					},
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						a = 1,
						b = 2,
						foo = { c = 3, d = 4, bar = { id = "foobar", e = 5, f = 6 } },
					},
				})
			end)

			it("will not use a default id getter if _id is present but __typename is not present", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new({ addTypename = false }),
				})

				client:writeQuery({
					query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                _id
                e
                f
              }
            }
          }
        ]]),
					data = {
						a = 1,
						b = 2,
						foo = { c = 3, d = 4, bar = { _id = "foobar", e = 5, f = 6 } },
					},
				})

				jestExpect((client.cache :: InMemoryCache):extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						a = 1,
						b = 2,
						foo = { c = 3, d = 4, bar = { _id = "foobar", e = 5, f = 6 } },
					},
				})
			end)

			it(
				"will not use a default id getter if either _id or id is present when __typename is not also present",
				function()
					local client = ApolloClient.new({
						link = ApolloLink.empty(),
						cache = InMemoryCache.new({ addTypename = false }),
					})

					client:writeQuery({
						query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                id
                e
                f
              }
            }
          }
        ]]),
						data = {
							a = 1,
							b = 2,
							foo = {
								c = 3,
								d = 4,
								bar = { __typename = "bar", id = "foobar", e = 5, f = 6 },
							},
						},
					})

					client:writeQuery({
						query = gql([[

          {
            g
            h
            bar {
              i
              j
              foo {
                _id
                k
                l
              }
            }
          }
        ]]),
						data = {
							g = 8,
							h = 9,
							bar = { i = 10, j = 11, foo = { _id = "barfoo", k = 12, l = 13 } },
						},
					})

					jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
				end
			)

			it(
				"will use a default id getter if one is not specified and __typename is present along with either _id or id",
				function()
					local client = ApolloClient.new({
						link = ApolloLink.empty(),
						cache = InMemoryCache.new(),
					})

					client:writeQuery({
						query = gql([[

          {
            a
            b
            foo {
              c
              d
              bar {
                id
                e
                f
              }
            }
          }
        ]]),
						data = {
							a = 1,
							b = 2,
							foo = {
								__typename = "foo",
								c = 3,
								d = 4,
								bar = { __typename = "bar", id = "foobar", e = 5, f = 6 },
							},
						},
					})

					client:writeQuery({
						query = gql([[

          {
            g
            h
            bar {
              i
              j
              foo {
                _id
                k
                l
              }
            }
          }
        ]]),
						data = {
							g = 8,
							h = 9,
							bar = {
								__typename = "bar",
								i = 10,
								j = 11,
								foo = { __typename = "foo", _id = "barfoo", k = 12, l = 13 },
							},
						},
					})

					jestExpect((client.cache :: InMemoryCache):extract()).toMatchSnapshot()
				end
			)
		end)

		describe("watchQuery", function()
			it(
				"should change the `fetchPolicy` to `cache-first` if network fetching "
					.. "is disabled, and the incoming `fetchPolicy` is set to "
					.. "`network-only` or `cache-and-network`",
				function()
					local client = ApolloClient.new({
						link = ApolloLink.empty(),
						cache = InMemoryCache.new(),
					})

					client.disableNetworkFetches = true

					local query = gql([[

          query someData {
            foo {
              bar
            }
          }
        ]])
					Array.forEach({ "network-only", "cache-and-network" }, function(fetchPolicy: FetchPolicy)
						local observable = client:watchQuery({
							query = query,
							fetchPolicy = fetchPolicy,
						})

						jestExpect(observable.options.fetchPolicy).toEqual("cache-first")
					end)
				end
			)

			it("should not change the incoming `fetchPolicy` if network fetching " .. "is enabled", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				client.disableNetworkFetches = false

				local query = gql([[

          query someData {
            foo {
              bar
            }
          }
        ]])
				Array.forEach({
					"cache-first",
					"cache-and-network",
					"network-only",
					"cache-only",
					"no-cache",
				}, function(fetchPolicy: FetchPolicy)
					local observable = client:watchQuery({
						query = query,
						fetchPolicy = fetchPolicy,
					})

					jestExpect(observable.options.fetchPolicy).toEqual(fetchPolicy)
				end)
			end)
		end)

		describe("defaultOptions", function()
			it("should set `defaultOptions` to an empty object if not provided in " .. "the constructor", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				jestExpect(client.defaultOptions).toEqual({})
			end)

			it("should set `defaultOptions` using options passed into the constructor", function()
				local defaultOptions: DefaultOptions = { query = { fetchPolicy = "no-cache" } } :: any

				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
					defaultOptions = defaultOptions,
				})

				jestExpect(client.defaultOptions).toEqual(defaultOptions)
			end)

			it("should use default options (unless overridden) when querying", function()
				local defaultOptions: DefaultOptions = { query = { fetchPolicy = "no-cache" } } :: any

				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
					defaultOptions = defaultOptions,
				})

				local queryOptions: QueryOptions<any, any> = {
					query = gql([[

          {
            a
          }
        ]]),
				}

				local queryManager = (client :: any).queryManager

				local _query = queryManager.query
				queryManager.query = function(_self, options)
					queryOptions = options
					return _query(options)
				end
				xpcall(function()
					client
						:query({
							query = gql([[

			  {
				a
			  }
		  ]]),
						})
						:expect()
				end, function(error_)
					-- Swallow errors caused by mocking; not part of this test
				end)

				jestExpect(queryOptions.fetchPolicy).toEqual((defaultOptions.query :: any).fetchPolicy)

				client:stop()
			end)

			it("should be able to set all default query options", function()
				ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
					defaultOptions = {
						query = {
							query = { kind = "Document", definitions = {} },
							variables = { foo = "bar" },
							errorPolicy = "none",
							context = nil,
							fetchPolicy = "cache-first",
							pollInterval = 100,
							notifyOnNetworkStatusChange = true,
							returnPartialData = true,
							partialRefetch = true,
						},
					} :: any,
				})
			end)
		end)

		describe("clearStore", function()
			it("should remove all data from the store", function()
				local client = ApolloClient.new({
					link = ApolloLink.empty(),
					cache = InMemoryCache.new(),
				})

				type Data = { a: number }

				client:writeQuery({
					data = { a = 1 },
					query = gql([[

          {
            a
          }
        ]]),
				})

				jestExpect((client.cache :: any).data.data).toEqual({
					ROOT_QUERY = { __typename = "Query", a = 1 },
				})

				client:clearStore():expect()

				jestExpect((client.cache :: any).data.data).toEqual({})
			end)
		end)

		describe("setLink", function()
			it("should override default link with newly set link", function()
				local client = ApolloClient.new({ cache = InMemoryCache.new() })

				jestExpect(client.link).toBeDefined()

				local newLink = ApolloLink.new(function(_self, operation)
					return Observable.new(function(observer)
						observer:next({
							data = { widgets = { { name = "Widget 1" }, {
								name = "Widget 2",
							} } },
						})
						observer:complete()
					end)
				end)

				client:setLink(newLink)

				local data
				do
					local ref = client
						:query({
							query = gql([[{ widgets }]]),
						})
						:expect()

					data = ref.data
				end

				jestExpect(data.widgets).toBeDefined()

				jestExpect(#data.widgets).toBe(2)
			end)
		end)
	end)
end
