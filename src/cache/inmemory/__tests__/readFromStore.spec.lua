-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/__tests__/readFromStore.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local _jest = JestGlobals.jest

	local NULL = require(srcWorkspace.utilities).NULL
	type JestMock = { mockClear: (self: any, ...any) -> (), mock: any } & typeof(setmetatable({}, {
		__call = function(self, ...: any): ...any
			return ...
		end,
	}))

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Object = LuauPolyfill.Object
	local Boolean = LuauPolyfill.Boolean

	type Array<T> = LuauPolyfill.Array<T>
	type Object = LuauPolyfill.Object

	local HttpService = game:GetService("HttpService")

	--[[
		ROBLOX deviation: no generic params for functions are supported.
		Data_, Vars_ are placeholders for generic Data, Vars param
	]]
	type Data_ = any
	type Vars_ = any

	-- local typedDocumentNodeModule = require(srcWorkspace.jsutils.typedDocumentNode)
	-- type TypedDocumentNode<Result, Variables> = typedDocumentNodeModule.TypedDocumentNode<Result, Variables>

	-- local lodashModule = require(Packages.lodash)
	local assign = Object.assign
	local function omit(obj, ...)
		local props = { ... }
		return assign(
			{},
			obj,
			Array.reduce(props, function(acc, prop)
				acc[prop] = Object.None
				return acc
			end, {})
		)
	end
	local gql = require(rootWorkspace.GraphQLTag).default

	local stripSymbols = require(script.Parent.Parent.Parent.Parent.utilities.testing.stripSymbols).stripSymbols

	local inMemoryCacheModule = require(script.Parent.Parent.inMemoryCache)
	local InMemoryCache = inMemoryCacheModule.InMemoryCache
	type InMemoryCache = inMemoryCacheModule.InMemoryCache

	local typesModule = require(script.Parent.Parent.types)
	type StoreObject = typesModule.StoreObject

	local StoreReader = require(script.Parent.Parent.readFromStore).StoreReader
	local cacheModule = require(script.Parent.Parent.Parent.core.types.Cache)
	type Cache_DiffResult<T> = cacheModule.Cache_DiffResult<T>
	local MissingFieldError = require(script.Parent.Parent.Parent.core.types.common).MissingFieldError

	local helpersModule = require(script.Parent.helpers)
	local defaultNormalizedCacheFactory = helpersModule.defaultNormalizedCacheFactory
	local readQueryFromStore = helpersModule.readQueryFromStore
	local withError = helpersModule.withError
	local coreModule = require(script.Parent.Parent.Parent.Parent.core)
	local makeReference = coreModule.makeReference
	type Reference = coreModule.Reference
	local isReference = coreModule.isReference
	type TypedDocumentNode<Result, Variables> = coreModule.TypedDocumentNode<Result, Variables>

	-- jest.mock("optimism")
	local wrap = require(srcWorkspace.optimism).wrap
	local withErrorSpy = require(srcWorkspace.testing).withErrorSpy

	-- ROBLOX TODO: these tests require jest.mock
	xdescribe("resultCacheMaxSize", function()
		local cache = InMemoryCache.new()
		local wrapSpy: JestMock = wrap :: any
		beforeEach(function()
			wrapSpy:mockClear()
		end)

		it("does not set max size on caches if resultCacheMaxSize is not configured", function()
			StoreReader.new({ cache = cache })
			jestExpect(wrapSpy).toHaveBeenCalled()

			Array.forEach(wrapSpy.mock.calls, function(ref)
				local max = ref[2].max
				jestExpect(max).toBeUndefined()
			end)
		end)

		it("configures max size on caches when resultCacheMaxSize is set", function()
			local resultCacheMaxSize = 12345
			StoreReader.new({ cache = cache, resultCacheMaxSize = resultCacheMaxSize })
			jestExpect(wrapSpy).toHaveBeenCalled()

			Array.forEach(wrapSpy.mock.calls, function(ref)
				local max = ref[2].max
				jestExpect(max).toBe(resultCacheMaxSize)
			end)
		end)
	end)

	describe("reading from the store", function()
		local reader = StoreReader.new({ cache = InMemoryCache.new() })
		-- ROBLOX TODO: fragments are not supported yet
		xit("runs a nested query with proper fragment fields in arrays", function()
			withError(function()
				local store = defaultNormalizedCacheFactory({
					ROOT_QUERY = ({ __typename = "Query", nestedObj = makeReference("abcde") } :: any) :: StoreObject,
					abcde = ({ id = "abcde", innerArray = { { id = "abcdef", someField = 3 } } } :: any) :: StoreObject,
				})
				local queryResult = readQueryFromStore(reader, {
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

				jestExpect(stripSymbols(queryResult)).toEqual({
					nestedObj = { innerArray = { { id = "abcdef", someField = 3 } } },
				})
			end)
		end)

		it("rejects malformed queries", function()
			jestExpect(function()
				readQueryFromStore(reader, {
					store = defaultNormalizedCacheFactory(),
					query = gql([[
          				query {
          				  name
          				}
					  
          				query {
          				  address
					}
          				]]),
				})
			end).toThrowError("2 operations")

			jestExpect(function()
				readQueryFromStore(reader, {
					store = defaultNormalizedCacheFactory(),
					query = gql([[
          fragment x on y {
            name
          }
          ]]),
				})
			end).toThrowError("contain a query")
		end)

		it("runs a basic query", function()
			local result = (
					{ id = "abcd", stringField = "This is a string!", numberField = 5, nullField = NULL } :: any
				) :: StoreObject
			local store = defaultNormalizedCacheFactory({ ROOT_QUERY = result })
			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        query {
          stringField
          numberField
        }
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = result["stringField"],
				numberField = result["numberField"],
			})
		end)

		it("runs a basic query with arguments", function()
			local query = gql([[
      query {
        id
        stringField(arg: $stringArg)
        numberField(intArg: $intArg, floatArg: $floatArg)
        nullField
      }
      ]])

			local variables = { intArg = 5, floatArg = 3.14, stringArg = "This is a string!" }

			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = {
					id = "abcd",
					nullField = NULL,
					-- ROBLOX deviation: HttpService:JSONEncode(3.14) output is different than JSON.stringify(3.14) (JSONEncode gives more precision)
					[('numberField({"floatArg":%s,"intArg":5})'):format(HttpService:JSONEncode(3.14))] = 5,
					['stringField({"arg":"This is a string!"})'] = "Heyo",
				},
			})

			local result = readQueryFromStore(reader, { store = store, query = query, variables = variables })

			jestExpect(stripSymbols(result)).toEqual({
				id = "abcd",
				nullField = NULL,
				numberField = 5,
				stringField = "Heyo",
			})
		end)

		it("runs a basic query with custom directives", function()
			local query = gql([[
      query {
        id
        firstName @include(if: true)
        lastName @upperCase
        birthDate @dateFormat(format: "DD-MM-YYYY")
      }
      ]])

			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = {
					id = "abcd",
					firstName = "James",
					["lastName@upperCase"] = "BOND",
					['birthDate@dateFormat({"format":"DD-MM-YYYY"})'] = "20-05-1940",
				},
			})

			local result = readQueryFromStore(reader, { store = store, query = query })

			jestExpect(stripSymbols(result)).toEqual({
				id = "abcd",
				firstName = "James",
				lastName = "BOND",
				birthDate = "20-05-1940",
			})
		end)

		it("runs a basic query with default values for arguments", function()
			local query = gql([[
      query someBigQuery(
        $stringArg: String = "This is a default string!"
        $intArg: Int = 0
        $floatArg: Float
      ) {
        id
        stringField(arg: $stringArg)
        numberField(intArg: $intArg, floatArg: $floatArg)
        nullField
      }
      ]])

			local variables = { floatArg = 3.14 }

			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = {
					id = "abcd",
					nullField = NULL,
					-- ROBLOX deviation: HttpService:JSONEncode(3.14) output is different than JSON.stringify(3.14) (JSONEncode gives more precision)
					[('numberField({"floatArg":%s,"intArg":0})'):format(HttpService:JSONEncode(3.14))] = 5,
					['stringField({"arg":"This is a default string!"})'] = "Heyo",
				},
			})

			local result = readQueryFromStore(reader, { store = store, query = query, variables = variables })

			jestExpect(stripSymbols(result)).toEqual({
				id = "abcd",
				nullField = NULL,
				numberField = 5,
				stringField = "Heyo",
			})
		end)

		it("runs a nested query", function()
			local result: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				nestedObj = ({
					id = "abcde",
					stringField = "This is a string too!",
					numberField = 6,
					nullField = NULL,
				} :: any) :: StoreObject,
			}

			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = assign(
					{},
					assign({}, omit(result, "nestedObj")),
					({ nestedObj = makeReference("abcde") } :: any) :: StoreObject
				),
				abcde = result.nestedObj,
			})

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          stringField
          numberField
          nestedObj {
            stringField
            numberField
          }
		}
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = "This is a string!",
				numberField = 5,
				nestedObj = { stringField = "This is a string too!", numberField = 6 },
			})
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xit("runs a nested query with multiple fragments", function()
			local result: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				nestedObj = ({
					id = "abcde",
					stringField = "This is a string too!",
					numberField = 6,
					nullField = NULL,
				} :: any) :: StoreObject,
				deepNestedObj = ({ stringField = "This is a deep string", numberField = 7, nullField = NULL } :: any) :: StoreObject,
				nullObject = NULL,
				__typename = "Item",
			}

			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = assign(
					{},
					assign({}, omit(result, "nestedObj", "deepNestedObj")),
					({ __typename = "Query", nestedObj = makeReference("abcde") } :: any) :: StoreObject
				),
				abcde = assign({}, result.nestedObj, { deepNestedObj = makeReference("abcdef") }) :: StoreObject,
				abcdef = result.deepNestedObj :: StoreObject,
			})

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          stringField
          numberField
          nullField
          ... on Query {
            nestedObj {
              stringField
              nullField
              deepNestedObj {
                stringField
                nullField
              }
            }
          }
          ... on Query {
            nestedObj {
              numberField
              nullField
              deepNestedObj {
                numberField
                nullField
              }
            }
          }
          ... on Query {
            nullObject
          }
		}
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				nestedObj = {
					stringField = "This is a string too!",
					numberField = 6,
					nullField = NULL,
					deepNestedObj = { stringField = "This is a deep string", numberField = 7, nullField = NULL },
				},
				nullObject = NULL,
			})
		end)

		it("runs a nested query with an array without IDs", function()
			local result: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				nestedArray = {
					{ stringField = "This is a string too!", numberField = 6, nullField = NULL },
					{ stringField = "This is a string also!", numberField = 7, nullField = NULL },
				} :: Array<StoreObject>,
			}

			local store = defaultNormalizedCacheFactory({ ROOT_QUERY = result })

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          stringField
          numberField
          nestedArray {
            stringField
            numberField
          }
		}
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = "This is a string!",
				numberField = 5,
				nestedArray = {
					{ stringField = "This is a string too!", numberField = 6 },
					{ stringField = "This is a string also!", numberField = 7 },
				},
			})
		end)

		it("runs a nested query with an array without IDs and a null", function()
			local result: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				nestedArray = { NULL, { stringField = "This is a string also!", numberField = 7, nullField = NULL } } :: Array<StoreObject>,
			}

			local store = defaultNormalizedCacheFactory({ ROOT_QUERY = result })

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          stringField
          numberField
          nestedArray {
            stringField
            numberField
          }
		}
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = "This is a string!",
				numberField = 5,
				nestedArray = { NULL :: any, { stringField = "This is a string also!", numberField = 7 } },
			})
		end)

		it("runs a nested query with an array with IDs and a null", function()
			local result: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				nestedArray = {
					NULL,
					{ id = "abcde", stringField = "This is a string also!", numberField = 7, nullField = NULL },
				} :: Array<StoreObject>,
			}

			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = assign(
					{},
					assign({}, omit(result, "nestedArray")),
					{ nestedArray = { NULL, makeReference("abcde") } }
				) :: StoreObject,
				abcde = result.nestedArray[2],
			})

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          stringField
          numberField
          nestedArray {
            id
            stringField
            numberField
          }
        }
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = "This is a string!",
				numberField = 5,
				nestedArray = {
					NULL :: any,
					{ id = "abcde", stringField = "This is a string also!", numberField = 7 },
				},
			})
		end)

		it("throws on a missing field", function()
			local result = (
					{ id = "abcd", stringField = "This is a string!", numberField = 5, nullField = NULL } :: any
				) :: StoreObject

			local store = defaultNormalizedCacheFactory({ ROOT_QUERY = result })

			jestExpect(function()
				readQueryFromStore(reader, {
					store = store,
					query = gql([[
          {
            stringField
            missingField
          }
          ]]),
				})
			end).toThrowError("Can't find field 'missingField' on ROOT_QUERY object")
		end)

		it("readQuery supports returnPartialData", function()
			local cache = InMemoryCache.new()
			local aQuery = gql([[query { a } ]])
			local bQuery = gql([[query { b } ]])
			local abQuery = gql([[query { a b } ]])

			cache:writeQuery({ query = aQuery, data = { a = 123 } })

			jestExpect(cache:readQuery({ query = bQuery })).toBe(NULL)
			jestExpect(cache:readQuery({ query = abQuery })).toBe(NULL)

			jestExpect(cache:readQuery({ query = bQuery, returnPartialData = true })).toEqual({})

			jestExpect(cache:readQuery({ query = abQuery, returnPartialData = true })).toEqual({ a = 123 })
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xit("readFragment supports returnPartialData", function()
			local cache = InMemoryCache.new()
			local id = cache:identify({ __typename = "ABObject", id = 321 })

			local aFragment = gql([[fragment AFragment on ABObject { a } ]])
			local bFragment = gql([[fragment BFragment on ABObject { b } ]])
			local abFragment = gql([[fragment ABFragment on ABObject { a b } ]])

			jestExpect(cache:readFragment({ id = id, fragment = aFragment })).toBe(NULL)
			jestExpect(cache:readFragment({ id = id, fragment = bFragment })).toBe(NULL)
			jestExpect(cache:readFragment({ id = id, fragment = abFragment })).toBe(NULL)

			local ref = cache:writeFragment({
				id = id,
				fragment = aFragment,
				data = { __typename = "ABObject", a = 123 },
			})

			jestExpect(isReference(ref)).toBe(true)
			jestExpect(ref.__ref).toBe(id)

			jestExpect(cache:readFragment({ id = id, fragment = bFragment })).toBe(NULL)

			jestExpect(cache:readFragment({ id = id, fragment = abFragment })).toBe(NULL)

			jestExpect(cache:readFragment({ id = id, fragment = bFragment, returnPartialData = true })).toEqual({
				__typename = "ABObject",
			})
			jestExpect(cache:readFragment({ id = id, fragment = abFragment, returnPartialData = true })).toEqual({
				__typename = "ABObject",
				a = 123,
			})
		end)

		it("distinguishes between missing @client and non-@client fields", function()
			local query = gql([[
      query {
        normal {
          present @client
          missing
        }
        clientOnly @client {
          present
          missing
        }
	}
      ]])

			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							normal = function(_self)
								return { present = "here" }
							end,
							clientOnly = function(_self)
								return { present = "also here" }
							end,
						},
					},
				},
			})

			local result, complete, missing
			do
				local ref = cache:diff({ query = query, optimistic = true, returnPartialData = true })
				result, complete, missing = ref.result, ref.complete, ref.missing
			end

			jestExpect(complete).toBe(false)

			jestExpect(result).toEqual({ normal = { present = "here" }, clientOnly = { present = "also here" } })

			jestExpect(missing).toEqual(Array.map({
				MissingFieldError.new(
					[[Can't find field 'missing' on object {"present":"here"}]],
					{ "normal", "missing" },
					query,
					{}
				),
				MissingFieldError.new(
					[[Can't find field 'missing' on object {"present":"also here"}]],
					{ "clientOnly", "missing" },
					query,
					{}
				),
			}, function(e)
				-- ROBLOX deviation: overwrite stack properties with jestExpect.anything() so that they don't cause failures
				e.stack = jestExpect.anything()
				return e
			end))
		end)

		it("runs a nested query where the reference is null", function()
			local result: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				nestedObj = NULL,
			}

			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = assign({}, assign({}, omit(result, "nestedObj")), { nestedObj = NULL }) :: StoreObject,
			})

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          stringField
          numberField
          nestedObj {
            stringField
            numberField
          }
		}
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = "This is a string!",
				numberField = 5,
				nestedObj = NULL,
			})
		end)

		it("runs an array of non-objects", function()
			local result: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				simpleArray = { "one", "two", "three" },
			}

			local store = defaultNormalizedCacheFactory({ ROOT_QUERY = result })

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          stringField
          numberField
          simpleArray
		}
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = "This is a string!",
				numberField = 5,
				simpleArray = { "one", "two", "three" },
			})
		end)

		it("runs an array of non-objects with null", function()
			local result: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				simpleArray = { NULL :: any, "two", "three" },
			}

			local store = defaultNormalizedCacheFactory({ ROOT_QUERY = result })

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          stringField
          numberField
          simpleArray
		}
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({
				stringField = "This is a string!",
				numberField = 5,
				simpleArray = { NULL :: any, "two", "three" },
			})
		end)

		it("will read from an arbitrary root id", function()
			local data: any = {
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
				nestedObj = ({
					id = "abcde",
					stringField = "This is a string too!",
					numberField = 6,
					nullField = NULL,
				} :: any) :: StoreObject,
				deepNestedObj = ({ stringField = "This is a deep string", numberField = 7, nullField = NULL } :: any) :: StoreObject,
				nullObject = NULL,
				__typename = "Item",
			}

			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = assign(
					{},
					assign({}, omit(data, "nestedObj", "deepNestedObj")),
					{ __typename = "Query", nestedObj = makeReference("abcde") }
				) :: StoreObject,
				abcde = assign({}, data.nestedObj, { deepNestedObj = makeReference("abcdef") }) :: StoreObject,
				abcdef = data.deepNestedObj :: StoreObject,
			})

			local queryResult1 = readQueryFromStore(reader, {
				store = store,
				rootId = "abcde",
				query = gql([[
        {
          stringField
          numberField
          nullField
          deepNestedObj {
            stringField
            numberField
            nullField
          }
        }
        ]]),
			})

			jestExpect(stripSymbols(queryResult1)).toEqual({
				stringField = "This is a string too!",
				numberField = 6,
				nullField = NULL,
				deepNestedObj = { stringField = "This is a deep string", numberField = 7, nullField = NULL },
			})

			local queryResult2 = readQueryFromStore(reader, {
				store = store,
				rootId = "abcdef",
				query = gql([[
        {
          stringField
          numberField
          nullField
        }
        ]]),
			})

			jestExpect(stripSymbols(queryResult2)).toEqual({
				stringField = "This is a deep string",
				numberField = 7,
				nullField = NULL,
			})
		end)

		it("properly handles the @connection directive", function()
			local store = defaultNormalizedCacheFactory({ ROOT_QUERY = { ["books:abc"] = { { name = "efgh" } } } })

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          books(skip: 0, limit: 2) @connection(key: "abc") {
            name
          }
        }
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({ books = { { name = "efgh" } } })
		end)

		it("can use keyArgs function instead of @connection directive", function()
			local reader = StoreReader.new({
				cache = InMemoryCache.new({
					typePolicies = {
						Query = {
							fields = {
								books = {
									keyArgs = function()
										return "abc"
									end,
								},
							},
						},
					},
				}),
			})

			local store = defaultNormalizedCacheFactory({ ROOT_QUERY = { ["books:abc"] = { { name = "efgh" } } } })

			local queryResult = readQueryFromStore(reader, {
				store = store,
				query = gql([[
        {
          books(skip: 0, limit: 2) {
            name
          }
        }
        ]]),
			})

			jestExpect(stripSymbols(queryResult)).toEqual({ books = { { name = "efgh" } } })
		end)

		it("refuses to return raw Reference objects", function()
			local store = defaultNormalizedCacheFactory({
				ROOT_QUERY = {
					author = {
						__typename = "Author",
						name = "Toni Morrison",
						books = {
							{ title = "The Bluest Eye", publisher = makeReference("Publisher1") },
							{ title = "Song of Solomon", publisher = makeReference("Publisher2") },
							{ title = "Beloved", publisher = makeReference("Publisher2") },
						},
					},
				},
				Publisher1 = { __typename = "Publisher", id = 1, name = "Holt, Rinehart and Winston" },
				Publisher2 = { __typename = "Publisher", id = 2, name = "Alfred A. Knopf, Inc." },
			})

			jestExpect(function()
				readQueryFromStore(reader, {
					store = store,
					query = gql([[
          {
            author {
              name
              books
            }
          }
          ]]),
				})
			end).toThrow("Missing selection set for object of type Publisher returned for query field books")

			jestExpect(readQueryFromStore(reader, {
				store = store,
				query = gql([[
          {
            author {
              name
              books {
                title
                publisher {
                  name
                }
              }
            }
          }
          ]]),
			})).toEqual({
				author = {
					__typename = "Author",
					name = "Toni Morrison",
					books = {
						{
							title = "The Bluest Eye",
							publisher = { __typename = "Publisher", name = "Holt, Rinehart and Winston" },
						},
						{
							title = "Song of Solomon",
							publisher = { __typename = "Publisher", name = "Alfred A. Knopf, Inc." },
						},
						{
							title = "Beloved",
							publisher = { __typename = "Publisher", name = "Alfred A. Knopf, Inc." },
						},
					},
				},
			})
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xit("read functions for root query fields work with empty cache", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							uuid = function(self)
								return "8d573b9c-cfcf-4e3e-98dd-14d255af577e"
							end,
							null = function(self)
								return NULL
							end,
						},
					},
				},
			})

			jestExpect(cache:readQuery({
				query = gql([[ query { uuid null } ]]),
			})).toEqual({ uuid = "8d573b9c-cfcf-4e3e-98dd-14d255af577e", null = NULL })

			jestExpect(cache:extract()).toEqual({})

			jestExpect(cache:readFragment({
				id = "ROOT_QUERY",
				fragment = gql([[
        fragment UUIDFragment on Query {
          null
          uuid
        }
        ]]),
			})).toEqual({ uuid = "8d573b9c-cfcf-4e3e-98dd-14d255af577e", null = NULL })

			jestExpect(cache:extract()).toEqual({})

			jestExpect(cache:readFragment({
				id = "does not exist",
				fragment = gql([[
        fragment F on Never {
          whatever
        }
        ]]),
			})).toBe(NULL)

			jestExpect(cache:extract()).toEqual({})
		end)

		it("custom read functions can map/filter dangling references", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							ducks = function(_self, existing: Array<Reference>?, ref)
								if existing == nil then
									existing = {}
								end
								return Array.map(existing, function(duck)
									if ref:canRead(duck) then
										return duck
									else
										return NULL
									end
								end)
							end,
							chickens = function(_self, existing: Array<Reference>?, ref)
								if existing == nil then
									existing = {}
								end
								return Array.map(existing, function(chicken)
									if ref:canRead(chicken) then
										return chicken
									else
										return {}
									end
								end)
							end,
							oxen = function(_self, existing: Array<Reference>?, ref)
								if existing == nil then
									existing = {}
								end
								return Array.filter(existing, function(val)
									return ref:canRead(val)
								end)
							end,
						},
					},
				},
			})

			cache:writeQuery({
				query = gql([[
        query {
          ducks { quacking }
          chickens { inCoop }
          oxen { gee haw }
        }
        ]]),
				data = {
					ducks = {
						{ __typename = "Duck", id = 1, quacking = true },
						{ __typename = "Duck", id = 2, quacking = false },
						{ __typename = "Duck", id = 3, quacking = false },
					},
					chickens = {
						{ __typename = "Chicken", id = 1, inCoop = true },
						{ __typename = "Chicken", id = 2, inCoop = true },
						{ __typename = "Chicken", id = 3, inCoop = false },
					},
					oxen = {
						{ __typename = "Ox", id = 1, gee = true, haw = false },
						{ __typename = "Ox", id = 2, gee = false, haw = true },
					},
				},
			})

			jestExpect(cache:extract()).toEqual({
				["Chicken:1"] = { __typename = "Chicken", id = 1, inCoop = true },
				["Chicken:2"] = { __typename = "Chicken", id = 2, inCoop = true },
				["Chicken:3"] = { __typename = "Chicken", id = 3, inCoop = false },
				["Duck:1"] = { __typename = "Duck", id = 1, quacking = true },
				["Duck:2"] = { __typename = "Duck", id = 2, quacking = false },
				["Duck:3"] = { __typename = "Duck", id = 3, quacking = false },
				["Ox:1"] = { __typename = "Ox", id = 1, gee = true, haw = false },
				["Ox:2"] = { __typename = "Ox", id = 2, gee = false, haw = true },
				ROOT_QUERY = {
					__typename = "Query",
					chickens = { { __ref = "Chicken:1" }, { __ref = "Chicken:2" }, { __ref = "Chicken:3" } },
					ducks = { { __ref = "Duck:1" }, { __ref = "Duck:2" }, { __ref = "Duck:3" } },
					oxen = { { __ref = "Ox:1" }, { __ref = "Ox:2" } },
				},
			})

			local function diffChickens()
				return cache:diff({
					query = gql([[query { chickens { id inCoop }}]]),
					optimistic = true,
				})
			end

			jestExpect(diffChickens()).toEqual({
				complete = true,
				result = {
					chickens = {
						{ __typename = "Chicken", id = 1, inCoop = true },
						{ __typename = "Chicken", id = 2, inCoop = true },
						{ __typename = "Chicken", id = 3, inCoop = false },
					},
				},
			})

			jestExpect(cache:evict({ id = cache:identify({ __typename = "Chicken", id = 2 }) })).toBe(true)

			jestExpect(diffChickens()).toEqual({
				complete = false,
				missing = { jestExpect.anything(), jestExpect.anything() },
				result = {
					chickens = {
						{ __typename = "Chicken", id = 1, inCoop = true },
						{} :: any,
						{ __typename = "Chicken", id = 3, inCoop = false },
					},
				},
			})

			local function diffDucks()
				return cache:diff({
					query = gql([[query { ducks { id quacking }}]]),
					optimistic = true,
				})
			end

			jestExpect(diffDucks()).toEqual({
				complete = true,
				result = {
					ducks = {
						{ __typename = "Duck", id = 1, quacking = true },
						{ __typename = "Duck", id = 2, quacking = false },
						{ __typename = "Duck", id = 3, quacking = false },
					},
				},
			})

			jestExpect(cache:evict({ id = cache:identify({ __typename = "Duck", id = 3 }) })).toBe(true)

			jestExpect(diffDucks()).toEqual({
				complete = true,
				result = {
					ducks = {
						{ __typename = "Duck", id = 1, quacking = true },
						{ __typename = "Duck", id = 2, quacking = false },
						NULL :: any,
					},
				},
			})

			local function diffOxen()
				return cache:diff({
					query = gql([[query { oxen { id gee haw }}]]),
					optimistic = true,
				})
			end

			jestExpect(diffOxen()).toEqual({
				complete = true,
				result = {
					oxen = {
						{ __typename = "Ox", id = 1, gee = true, haw = false },
						{ __typename = "Ox", id = 2, gee = false, haw = true },
					},
				},
			})

			jestExpect(cache:evict({ id = cache:identify({ __typename = "Ox", id = 1 }) })).toBe(true)

			jestExpect(diffOxen()).toEqual({
				complete = true,
				result = { oxen = { { __typename = "Ox", id = 2, gee = false, haw = true } } },
			})
		end)

		withErrorSpy(it, "propagates eviction signals to parent queries", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Deity = {
						keyFields = { "name" },
						fields = {
							children = function(_self, offspring: Array<Reference>, ref)
								if Boolean.toJSBoolean(offspring) then
									return Array.filter(offspring, function(val)
										return ref:canRead(val)
									end)
								else
									return {}
								end
							end,
						},
					},
					Query = {
						fields = {
							ruler = function(_self, ruler, ref)
								if ref:canRead(ruler) then
									return ruler
								else
									return ref:toReference({ __typename = "Deity", name = "Apollo" })
								end
							end,
						},
					},
				},
			})

			local rulerQuery = gql([[
      query {
        ruler {
          name
          children {
            name
            children {
              name
            }
          }
        }
	}
      ]])

			local children = Array.map(
				{ "Son #1", "Hera", "Son #2", "Zeus", "Demeter", "Hades", "Poseidon", "Hestia" },
				function(name)
					return { __typename = "Deity", name = name, children = {} }
				end
			)

			cache:writeQuery({
				query = rulerQuery,
				data = { ruler = { __typename = "Deity", name = "Cronus", children = children } },
			})

			local diffs: Array<Cache_DiffResult<any>> = {}

			local function watch(immediate: boolean?)
				if immediate == nil then
					immediate = true
				end
				return cache:watch({
					query = rulerQuery,
					immediate = immediate,
					optimistic = true,
					callback = function(_self, diff)
						table.insert(diffs, diff)
					end,
				})
			end

			local _cancel = watch()

			local function devour(name: string)
				return cache:evict({ id = cache:identify({ __typename = "Deity", name = name }) })
			end

			local initialDiff = {
				result = { ruler = { __typename = "Deity", name = "Cronus", children = children } },
				complete = true,
			}

			jestExpect(diffs).toEqual({ initialDiff })

			jestExpect(devour("Son #1")).toBe(true)

			local childrenWithoutSon1 = Array.filter(children, function(child)
				return child.name ~= "Son #1"
			end)

			jestExpect(#childrenWithoutSon1).toBe(#children - 1)

			local diffWithoutSon1 = {
				result = { ruler = { name = "Cronus", __typename = "Deity", children = childrenWithoutSon1 } },
				complete = true,
			}

			jestExpect(diffs).toEqual({ initialDiff, diffWithoutSon1 })

			jestExpect(devour("Son #1")).toBe(false)

			jestExpect(diffs).toEqual({ initialDiff, diffWithoutSon1 })

			jestExpect(devour("Son #2")).toBe(true)

			local diffWithoutDevouredSons = {
				result = {
					ruler = {
						name = "Cronus",
						__typename = "Deity",
						children = Array.filter(childrenWithoutSon1, function(child)
							return child.name ~= "Son #2"
						end),
					},
				},
				complete = true,
			}

			jestExpect(diffs).toEqual({ initialDiff, diffWithoutSon1, diffWithoutDevouredSons })

			-- ROBLOX TODO: from here on fragments are used (currently unsupported)
			-- local _childrenOfZeus = Array.map({ "Ares", "Artemis", "Apollo", "Athena" }, function(name)
			-- 	return { __typename = "Deity", name = name, children = {} }
			-- end)

			-- 		local zeusRef = cache:writeFragment({
			-- 			id = cache:identify({ __typename = "Deity", name = "Zeus" }),
			-- 			fragment = gql([[fragment Offspring on Deity {
			--     children {
			--       name
			--     }
			--   } ]]),
			-- 			data = { children = childrenOfZeus },
			-- 		})

			-- 		jestExpect(isReference(zeusRef)).toBe(true)

			-- 		jestExpect(zeusRef.__ref).toBe('Deity:{"name":"Zeus"}')

			-- 		local diffWithChildrenOfZeus = {
			-- 			complete = true,
			-- 			result = Object.assign({}, diffWithoutDevouredSons.result, {
			-- 				ruler = Object.assign({}, diffWithoutDevouredSons.result.ruler, {
			-- 					children = Array.map(diffWithoutDevouredSons.result.ruler.children, function(child)
			-- 						return child.name == "Zeus"
			-- 								and Object.assign({}, child, {
			-- 									children = Array.map(childrenOfZeus, function(ref)
			-- 										local _children, child =
			-- 											ref.children, Object.assign({}, ref, { children = Object.None })
			-- 										return child
			-- 									end),
			-- 								})
			-- 							or child
			-- 					end),
			-- 				}),
			-- 			}),
			-- 		}

			-- 		jestExpect(diffs).toEqual({
			-- 			initialDiff,
			-- 			diffWithoutSon1,
			-- 			diffWithoutDevouredSons,
			-- 			diffWithChildrenOfZeus,
			-- 		})

			-- 		cache:writeQuery({ query = rulerQuery, data = { ruler = { __typename = "Deity", name = "Zeus" } } })

			-- 		local diffWithZeusAsRuler = {
			-- 			complete = true,
			-- 			result = { ruler = { __typename = "Deity", name = "Zeus", children = childrenOfZeus } },
			-- 		}

			-- 		jestExpect(diffs).toEqual({
			-- 			initialDiff,
			-- 			diffWithoutSon1,
			-- 			diffWithoutDevouredSons,
			-- 			diffWithChildrenOfZeus,
			-- 			diffWithZeusAsRuler,
			-- 		})

			-- 		jestExpect(Array.sort(cache:gc())).toEqual({
			-- 			'Deity:{"name":"Cronus"}',
			-- 			'Deity:{"name":"Demeter"}',
			-- 			'Deity:{"name":"Hades"}',
			-- 			'Deity:{"name":"Hera"}',
			-- 			'Deity:{"name":"Hestia"}',
			-- 			'Deity:{"name":"Poseidon"}',
			-- 		})

			-- 		local snapshotAfterGC = {
			-- 			ROOT_QUERY = { __typename = "Query", ruler = { __ref = 'Deity:{"name":"Zeus"}' } },
			-- 			['Deity:{"name":"Zeus"}'] = {
			-- 				__typename = "Deity",
			-- 				name = "Zeus",
			-- 				children = {
			-- 					{ __ref = 'Deity:{"name":"Ares"}' },
			-- 					{ __ref = 'Deity:{"name":"Artemis"}' },
			-- 					{ __ref = 'Deity:{"name":"Apollo"}' },
			-- 					{ __ref = 'Deity:{"name":"Athena"}' },
			-- 				},
			-- 			},
			-- 			['Deity:{"name":"Apollo"}'] = { __typename = "Deity", name = "Apollo" },
			-- 			['Deity:{"name":"Artemis"}'] = { __typename = "Deity", name = "Artemis" },
			-- 			['Deity:{"name":"Ares"}'] = { __typename = "Deity", name = "Ares" },
			-- 			['Deity:{"name":"Athena"}'] = { __typename = "Deity", name = "Athena" },
			-- 		}

			-- 		local zeusMeta = { extraRootIds = { 'Deity:{"name":"Zeus"}' } }

			-- 		jestExpect(cache:extract()).toEqual(Object.assign({}, snapshotAfterGC, { __META = zeusMeta }))

			-- 		jestExpect(diffs).toEqual({
			-- 			initialDiff,
			-- 			diffWithoutSon1,
			-- 			diffWithoutDevouredSons,
			-- 			diffWithChildrenOfZeus,
			-- 			diffWithZeusAsRuler,
			-- 		})

			-- 		cancel()

			-- 		local lastDiff = diffs[#diffs]

			-- 		jestExpect(cache:readQuery({ query = rulerQuery })).toBe(lastDiff.result)

			-- 		jestExpect(cache:evict({ id = cache:identify({ __typename = "Deity", name = "Ares" }) })).toBe(true)

			-- 		jestExpect(diffs).toEqual({
			-- 			initialDiff,
			-- 			diffWithoutSon1,
			-- 			diffWithoutDevouredSons,
			-- 			diffWithChildrenOfZeus,
			-- 			diffWithZeusAsRuler,
			-- 		})

			-- 		local snapshotWithoutAres = Object.assign({}, snapshotAfterGC, { __META = zeusMeta });
			-- 		(snapshotWithoutAres :: any)['Deity:{"name":"Ares"}'] = nil

			-- 		jestExpect(cache:extract()).toEqual(snapshotWithoutAres)

			-- 		jestExpect(cache:gc()).toEqual({})

			-- 		local childrenOfZeusWithoutAres = Array.filter(childrenOfZeus, function(child)
			-- 			return child.name ~= "Ares"
			-- 		end)

			-- 		jestExpect(childrenOfZeusWithoutAres).toEqual({
			-- 			{ __typename = "Deity", name = "Artemis", children = {} },
			-- 			{ __typename = "Deity", name = "Apollo", children = {} },
			-- 			{ __typename = "Deity", name = "Athena", children = {} },
			-- 		})

			-- 		jestExpect(cache:readQuery({ query = rulerQuery })).toEqual({
			-- 			ruler = { __typename = "Deity", name = "Zeus", children = childrenOfZeusWithoutAres },
			-- 		})

			-- 		jestExpect(cache:evict({ id = cache:identify({ __typename = "Deity", name = "Zeus" }) })).toBe(true)

			-- 		cache:retain(cache:identify({
			-- 			__typename = "Deity",
			-- 			name = "Apollo",
			-- 		}))

			-- 		jestExpect(Array.sort(cache:gc())).toEqual({ 'Deity:{"name":"Artemis"}', 'Deity:{"name":"Athena"}' })

			-- 		jestExpect(cache:extract()).toEqual({
			-- 			__META = { extraRootIds = { 'Deity:{"name":"Apollo"}', 'Deity:{"name":"Zeus"}' } },
			-- 			ROOT_QUERY = { __typename = "Query", ruler = { __ref = 'Deity:{"name":"Zeus"}' } },
			-- 			['Deity:{"name":"Apollo"}'] = { __typename = "Deity", name = "Apollo" },
			-- 		})

			-- 		local apolloRulerResult = cache:readQuery({
			-- 			query = rulerQuery,
			-- 		})

			-- 		jestExpect(apolloRulerResult).toEqual({ ruler = { __typename = "Deity", name = "Apollo", children = {} } })

			-- 		jestExpect(diffs).toEqual({
			-- 			initialDiff,
			-- 			diffWithoutSon1,
			-- 			diffWithoutDevouredSons,
			-- 			diffWithChildrenOfZeus,
			-- 			diffWithZeusAsRuler,
			-- 		})

			-- 		local cancel2 = watch(false)

			-- 		jestExpect(diffs).toEqual({
			-- 			initialDiff,
			-- 			diffWithoutSon1,
			-- 			diffWithoutDevouredSons,
			-- 			diffWithChildrenOfZeus,
			-- 			diffWithZeusAsRuler,
			-- 		})

			-- 		cache:modify({
			-- 			fields = {
			-- 				ruler = function(self, value, ref)
			-- 					local toReference = ref.toReference
			-- 					jestExpect(isReference(value)).toBe(true)
			-- 					jestExpect(value.__ref).toBe(cache:identify(diffWithZeusAsRuler.result.ruler))
			-- 					jestExpect(value.__ref).toBe('Deity:{"name":"Zeus"}')
			-- 					return toReference(apolloRulerResult.ruler)
			-- 				end,
			-- 			},
			-- 		})

			-- 		cancel2()

			-- 		local diffWithApolloAsRuler = { complete = true, result = apolloRulerResult }

			-- 		jestExpect(diffs).toEqual({
			-- 			initialDiff,
			-- 			diffWithoutSon1,
			-- 			diffWithoutDevouredSons,
			-- 			diffWithChildrenOfZeus,
			-- 			diffWithZeusAsRuler,
			-- 			diffWithApolloAsRuler,
			-- 		})

			-- 		jestExpect(cache:release(cache:identify({
			-- 			__typename = "Deity",
			-- 			name = "Apollo",
			-- 		}))).toBe(0)

			-- 		jestExpect(cache:gc()).toEqual({})

			-- 		jestExpect(cache:extract()).toEqual({
			-- 			__META = zeusMeta,
			-- 			ROOT_QUERY = { __typename = "Query", ruler = { __ref = 'Deity:{"name":"Apollo"}' } },
			-- 			['Deity:{"name":"Apollo"}'] = { __typename = "Deity", name = "Apollo" },
			-- 		})
		end)

		it("returns === results for different queries", function()
			local cache = InMemoryCache.new()

			local aQuery: TypedDocumentNode<{ a: Array<string> }, { [string]: any }> = gql([[query { a } ]])

			local abQuery: TypedDocumentNode<{ a: Array<string>, b: { c: string, d: string } }, { [string]: any }> =
				gql(
					[[query { a b { c d } } ]]
				)

			local bQuery: TypedDocumentNode<{ b: { c: string, d: string } }, { [string]: any }> = gql(
				[[query { b { d c } } ]]
			)

			local abData1 = {
				a = { "a", "y" },
				b = {
					c = "see",
					d = "dee",
				},
			}

			cache:writeQuery({
				query = abQuery,
				data = abData1,
			})

			local function read(query: TypedDocumentNode<Data_, Vars_>)
				return cache:readQuery({
					query = query,
				})
			end

			local aResult1 = read(aQuery)
			local abResult1 = read(abQuery)
			local bResult1 = read(bQuery)

			jestExpect(aResult1.a).toBe(abResult1.a)
			jestExpect(abResult1).toEqual(abData1)
			jestExpect(aResult1).toEqual({ a = abData1.a })
			jestExpect(bResult1).toEqual({ b = abData1.b })
			jestExpect(abResult1.b).toBe(bResult1.b)

			local aData2 = {
				--[[
					ROBLOX deviation: creating an array explicitely as String.split doesn't work correctly for "" separator
					original code:
					a: "ayy".split(""),
				]]
				a = { "a", "y", "y" },
			}

			cache:writeQuery({
				query = aQuery,
				data = aData2,
			})

			local aResult2 = read(aQuery)
			local abResult2 = read(abQuery)
			local bResult2 = read(bQuery)

			jestExpect(aResult2).toEqual(aData2)
			jestExpect(abResult2).toEqual(Object.assign({}, abData1, aData2))
			jestExpect(aResult2.a).toBe(abResult2.a)
			jestExpect(bResult2).toBe(bResult1)
			jestExpect(abResult2.b).toBe(bResult2.b)
			jestExpect(abResult2.b).toBe(bResult1.b)

			local bData3 = {
				b = {
					d = "D",
					c = "C",
				},
			}

			cache:writeQuery({
				query = bQuery,
				data = bData3,
			})

			local aResult3 = read(aQuery)
			local abResult3 = read(abQuery)
			local bResult3 = read(bQuery)

			jestExpect(aResult3).toBe(aResult2)
			jestExpect(bResult3).toEqual(bData3)
			jestExpect(bResult3).never.toBe(bData3)
			jestExpect(abResult3).toEqual(Object.assign({}, abResult2, bData3))

			jestExpect(cache:extract()).toMatchSnapshot()
		end)

		it("does not canonicalize custom scalar objects", function()
			-- local now = Date.new()
			local now = DateTime.now()

			local abc = { a = 1, b = 2, c = 3 }

			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							now = function(self)
								return now
							end,
							abc = function(self)
								return abc
							end,
						},
					},
				},
			})

			local query: TypedDocumentNode<{ now: typeof(now), abc: typeof(abc) }, { [string]: any }> = gql(
				[[query { now abc } ]]
			)

			local result1 = cache:readQuery({
				query = query,
			})

			local result2 = cache:readQuery({
				query = query,
			})

			jestExpect(result1).toBe(result2)

			-- jestExpect(result1.now).toBeInstanceOf(Date)

			jestExpect(result1.now).toBe(now)

			jestExpect(result2.now).toBe(now)

			jestExpect(result1.abc).toEqual(abc)

			jestExpect(result2.abc).toEqual(abc)

			jestExpect(result1.abc).toBe(result2.abc)

			jestExpect(result1.abc).toBe(abc)

			jestExpect(result2.abc).toBe(abc)
		end)

		it("readQuery can opt out of canonization", function()
			local count = 0

			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							count = function(self)
								return (function()
									local result = count
									count += 1
									return result
								end)()
							end,
						},
					},
				},
			})
			local canon = cache["storeReader"].canon

			local query = gql([[
      query {
        count
      }
      ]])

			local function readQuery(canonizeResults: boolean)
				return cache:readQuery({ query = query, canonizeResults = canonizeResults })
			end

			local nonCanonicalQueryResult0 = readQuery(false)

			jestExpect(canon:isKnown(nonCanonicalQueryResult0)).toBe(false)

			jestExpect(nonCanonicalQueryResult0).toEqual({ count = 0 })

			local canonicalQueryResult0 = readQuery(true)

			jestExpect(canon:isKnown(canonicalQueryResult0)).toBe(true)

			jestExpect(canonicalQueryResult0).toEqual({ count = 0 })

			cache:evict({ fieldName = "count" })

			local canonicalQueryResult1 = readQuery(true)

			jestExpect(canon:isKnown(canonicalQueryResult1)).toBe(true)

			jestExpect(canonicalQueryResult1).toEqual({ count = 1 })

			local nonCanonicalQueryResult1 = readQuery(false)

			jestExpect(nonCanonicalQueryResult1).toBe(canonicalQueryResult1)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xit("readFragment can opt out of canonization", function()
			local count = 0

			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							count = function(self)
								return (function()
									local result = count
									count += 1
									return result
								end)()
							end,
						},
					},
				},
			})

			local canon = cache["storeReader"].canon

			local fragment = gql([[
      fragment CountFragment on Query {
        count
      }
      ]])

			local function readFragment(canonizeResults: boolean)
				return cache:readFragment({ id = "ROOT_QUERY", fragment = fragment, canonizeResults = canonizeResults })
			end
			local canonicalFragmentResult1 = readFragment(true)
			jestExpect(canon:isKnown(canonicalFragmentResult1)).toBe(true)
			jestExpect(canonicalFragmentResult1).toEqual({ count = 0 })

			local nonCanonicalFragmentResult1 = readFragment(false)
			jestExpect(nonCanonicalFragmentResult1).toBe(canonicalFragmentResult1)
			cache:evict({ fieldName = "count" })

			local nonCanonicalFragmentResult2 = readFragment(false)
			jestExpect(readFragment(false)).toBe(nonCanonicalFragmentResult2)
			jestExpect(canon:isKnown(nonCanonicalFragmentResult2)).toBe(false)
			jestExpect(nonCanonicalFragmentResult2).toEqual({ count = 1 })
			jestExpect(readFragment(false)).toBe(nonCanonicalFragmentResult2)

			local canonicalFragmentResult2 = readFragment(true)
			jestExpect(readFragment(true)).toBe(canonicalFragmentResult2)
			jestExpect(canon:isKnown(canonicalFragmentResult2)).toBe(true)
			jestExpect(canonicalFragmentResult2).toEqual({ count = 1 })
		end)
	end)
end
