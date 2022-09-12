-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/writeToStore.ts
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local itFIXME = function(description: string, ...: any)
	it.todo(description)
end
local jest = JestGlobals.jest

local NULL = require(srcWorkspace.utilities).NULL

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object
local Boolean = LuauPolyfill.Boolean
local console = LuauPolyfill.console
local function fail(message: string)
	error(message)
end

type Array<T> = LuauPolyfill.Array<T>
type Record<T, U> = { [T]: U }

local HttpService = game:GetService("HttpService")

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

local graphqlModule = require(rootWorkspace.GraphQL)
type SelectionNode = graphqlModule.SelectionNode
type FieldNode = graphqlModule.FieldNode
type DefinitionNode = graphqlModule.DefinitionNode
type OperationDefinitionNode = graphqlModule.OperationDefinitionNode
type ASTNode = graphqlModule.ASTNode
type DocumentNode = graphqlModule.DocumentNode
local gql = require(rootWorkspace.GraphQLTag).default

local storeUtilsModule = require(script.Parent.Parent.Parent.Parent.utilities.graphql.storeUtils)
local storeKeyNameFromField = storeUtilsModule.storeKeyNameFromField
local makeReference = storeUtilsModule.makeReference
local isReference = storeUtilsModule.isReference
type Reference = storeUtilsModule.Reference
type StoreObject = storeUtilsModule.StoreObject

local addTypenameToDocument =
	require(script.Parent.Parent.Parent.Parent.utilities.graphql.transform).addTypenameToDocument
local cloneDeep = require(script.Parent.Parent.Parent.Parent.utilities.common.cloneDeep).cloneDeep
local itAsync = require(script.Parent.Parent.Parent.Parent.utilities.testing.itAsync).itAsync
local StoreWriter = require(script.Parent.Parent.writeToStore).StoreWriter
local helpersModule = require(script.Parent.helpers)
local defaultNormalizedCacheFactory = helpersModule.defaultNormalizedCacheFactory
local writeQueryToStore = helpersModule.writeQueryToStore
local InMemoryCache = require(script.Parent.Parent.inMemoryCache).InMemoryCache
local withErrorSpy = require(script.Parent.Parent.Parent.Parent.testing).withErrorSpy

local function getIdField(_self, ref: { id: string }): string
	return ref.id
end

describe("writing to the store", function()
	local cache = InMemoryCache.new({
		dataIdFromObject = function(self, object: any)
			if Boolean.toJSBoolean(object.__typename) and Boolean.toJSBoolean(object.id) then
				return object.__typename .. "__" .. object.id
			end
			return nil
		end,
	})
	local writer = StoreWriter.new(cache)

	it("properly normalizes a trivial item", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
      }
    ]])
		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
		}
		expect(writeQueryToStore({ writer = writer, query = query, result = cloneDeep(result) }):toObject()).toEqual({
			ROOT_QUERY = Object.assign({}, { __typename = "Query" }, result),
		})
	end)

	it("properly normalizes an aliased field", function()
		local query = gql([[

      {
        id
        aliasedField: stringField
        numberField
        nullField
      }
    ]])
		local result: any = {
			id = "abcd",
			aliasedField = "This is a string!",
			numberField = 5,
			nullField = NULL,
		}
		local normalized = writeQueryToStore({ writer = writer, result = result, query = query })
		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				id = "abcd",
				stringField = "This is a string!",
				numberField = 5,
				nullField = NULL,
			},
		})
	end)

	it("properly normalizes a aliased fields with arguments", function()
		local query = gql([[

      {
        id
        aliasedField1: stringField(arg: 1)
        aliasedField2: stringField(arg: 2)
        numberField
        nullField
      }
    ]])
		local result: any = {
			id = "abcd",
			aliasedField1 = "The arg was 1!",
			aliasedField2 = "The arg was 2!",
			numberField = 5,
			nullField = NULL,
		}
		local normalized = writeQueryToStore({ writer = writer, result = result, query = query })
		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				id = "abcd",
				['stringField({"arg":1})'] = "The arg was 1!",
				['stringField({"arg":2})'] = "The arg was 2!",
				numberField = 5,
				nullField = NULL,
			},
		})
	end)

	it("properly normalizes a query with variables", function()
		local query = gql([[

      {
        id
        stringField(arg: $stringArg)
        numberField(intArg: $intArg, floatArg: $floatArg)
        nullField
      }
    ]])
		local variables = { intArg = 5, floatArg = 3.14, stringArg = "This is a string!" }
		local result: any = { id = "abcd", stringField = "Heyo", numberField = 5, nullField = NULL }
		local normalized = writeQueryToStore({
			writer = writer,
			result = result,
			query = query,
			variables = variables,
		})

		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				id = "abcd",
				nullField = NULL,
				-- ROBLOX deviation: HttpService:JSONEncode(3.14) output is different than JSON.stringify(3.14) (JSONEncode gives more precision)
				[('numberField({"floatArg":%s,"intArg":5})'):format(HttpService:JSONEncode(3.14))] = 5,
				['stringField({"arg":"This is a string!"})'] = "Heyo",
			},
		})
	end)

	it("properly normalizes a query with default values", function()
		local query = gql([[

      query someBigQuery(
        $stringArg: String = "This is a default string!"
        $intArg: Int
        $floatArg: Float
      ) {
        id
        stringField(arg: $stringArg)
        numberField(intArg: $intArg, floatArg: $floatArg)
        nullField
      }
    ]])
		local variables = { intArg = 5, floatArg = 3.14 }
		local result: any = { id = "abcd", stringField = "Heyo", numberField = 5, nullField = NULL }
		local normalized = writeQueryToStore({
			writer = writer,
			result = result,
			query = query,
			variables = variables,
		})
		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				id = "abcd",
				nullField = NULL,
				-- ROBLOX deviation: HttpService:JSONEncode(3.14) output is different than JSON.stringify(3.14) (JSONEncode gives more precision)
				[('numberField({"floatArg":%s,"intArg":5})'):format(HttpService:JSONEncode(3.14))] = 5,
				['stringField({"arg":"This is a default string!"})'] = "Heyo",
			},
		})
	end)

	it("properly normalizes a query with custom directives", function()
		local query = gql([[

      query {
        id
        firstName @include(if: true)
        lastName @upperCase
        birthDate @dateFormat(format: "DD-MM-YYYY")
      }
    ]])

		local result: any = {
			id = "abcd",
			firstName = "James",
			lastName = "BOND",
			birthDate = "20-05-1940",
		}

		local normalized = writeQueryToStore({
			writer = writer,
			result = result,
			query = query,
		})

		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				id = "abcd",
				firstName = "James",
				["lastName@upperCase"] = "BOND",
				['birthDate@dateFormat({"format":"DD-MM-YYYY"})'] = "20-05-1940",
			},
		})
	end)

	it("properly normalizes a nested object with an ID", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        nestedObj {
          id
          stringField
          numberField
          nullField
        }
      }
    ]])
		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			nestedObj = {
				id = "abcde",
				stringField = "This is a string too!",
				numberField = 6,
				nullField = NULL,
			},
		}

		local writer = StoreWriter.new(InMemoryCache.new({
			dataIdFromObject = getIdField,
		}))

		expect(writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		}):toObject()).toEqual({
			ROOT_QUERY = Object.assign(
				{},
				{ __typename = "Query" },
				result,
				{ nestedObj = makeReference(result.nestedObj.id) }
			),
			[result.nestedObj.id] = result.nestedObj,
		})
	end)

	it("properly normalizes a nested object without an ID", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        nestedObj {
          stringField
          numberField
          nullField
        }
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			nestedObj = {
				stringField = "This is a string too!",
				numberField = 6,
				nullField = NULL,
			},
		}

		expect(writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		}):toObject()).toEqual({
			ROOT_QUERY = Object.assign({}, {
				__typename = "Query",
			}, result),
		})
	end)

	it("properly normalizes a nested object with arguments but without an ID", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        nestedObj(arg: "val") {
          stringField
          numberField
          nullField
        }
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			nestedObj = {
				stringField = "This is a string too!",
				numberField = 6,
				nullField = NULL,
			},
		}

		expect(writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		}):toObject()).toEqual({
			ROOT_QUERY = assign(omit(result, "nestedObj"), {
				__typename = "Query",
				['nestedObj({"arg":"val"})'] = result.nestedObj,
			}),
		})
	end)

	it("properly normalizes a nested array with IDs", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        nestedArray {
          id
          stringField
          numberField
          nullField
        }
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			nestedArray = {
				{
					id = "abcde",
					stringField = "This is a string too!",
					numberField = 6,
					nullField = NULL,
				},
				{
					id = "abcdef",
					stringField = "This is a string also!",
					numberField = 7,
					nullField = NULL,
				},
			},
		}

		local writer = StoreWriter.new(InMemoryCache.new({
			dataIdFromObject = getIdField,
		}))

		expect(writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		}):toObject()).toEqual({
			ROOT_QUERY = assign({}, assign({}, omit(result, "nestedArray")), {
				__typename = "Query",
				nestedArray = Array.map(result.nestedArray, function(obj: any)
					return makeReference(obj.id)
				end),
			}),
			[result.nestedArray[1].id] = result.nestedArray[1],
			[result.nestedArray[2].id] = result.nestedArray[2],
		})
	end)

	it("properly normalizes a nested array with IDs and a null", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        nestedArray {
          id
          stringField
          numberField
          nullField
        }
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			nestedArray = {
				{
					id = "abcde",
					stringField = "This is a string too!",
					numberField = 6,
					nullField = NULL,
				} :: any,
				NULL,
			},
		}

		local writer = StoreWriter.new(InMemoryCache.new({
			dataIdFromObject = getIdField,
		}))

		expect(writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		}):toObject()).toEqual({
			ROOT_QUERY = assign({}, assign({}, omit(result, "nestedArray")), {
				__typename = "Query",
				nestedArray = {
					makeReference(result.nestedArray[1].id) :: any,
					NULL,
				},
			}),
			[result.nestedArray[1].id] = result.nestedArray[1],
		})
	end)

	it("properly normalizes a nested array without IDs", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        nestedArray {
          stringField
          numberField
          nullField
        }
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			nestedArray = {
				{
					stringField = "This is a string too!",
					numberField = 6,
					nullField = NULL,
				},
				{
					stringField = "This is a string also!",
					numberField = 7,
					nullField = NULL,
				},
			},
		}

		local normalized = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})
		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = Object.assign({}, {
				__typename = "Query",
			}, result),
		})
	end)

	it("properly normalizes a nested array without IDs and a null item", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        nestedArray {
          stringField
          numberField
          nullField
        }
      }
    ]])
		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			nestedArray = {
				NULL :: any,
				{
					stringField = "This is a string also!",
					numberField = 7,
					nullField = NULL,
				},
			},
		}

		local normalized = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})

		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = Object.assign({}, {
				__typename = "Query",
			}, result),
		})
	end)

	it("properly normalizes an array of non-objects", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        simpleArray
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			simpleArray = { "one", "two", "three" },
		}

		local writer = StoreWriter.new(InMemoryCache.new({
			dataIdFromObject = getIdField,
		}))

		local normalized = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})

		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = Object.assign({}, {
				__typename = "Query",
			}, result),
		})
	end)

	it("properly normalizes an array of non-objects with null", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        simpleArray
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			simpleArray = { NULL :: any, "two", "three" },
		}

		local normalized = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})

		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = Object.assign({}, {
				__typename = "Query",
			}, result),
		})
	end)

	it("properly normalizes an object occurring in different graphql paths twice", function()
		local query = gql([[

      {
        id
        object1 {
          id
          stringField
        }
        object2 {
          id
          numberField
        }
      }
    ]])

		local result: any = {
			id = "a",
			object1 = {
				id = "aa",
				stringField = "string",
			},
			object2 = {
				id = "aa",
				numberField = 1,
			},
		}

		local writer = StoreWriter.new(InMemoryCache.new({
			dataIdFromObject = getIdField,
		}))

		local normalized = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})

		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				id = "a",
				object1 = makeReference("aa"),
				object2 = makeReference("aa"),
			},
			aa = {
				id = "aa",
				stringField = "string",
				numberField = 1,
			},
		})
	end)

	it("properly normalizes an object occurring in different graphql array paths twice", function()
		local query = gql([[

      {
        id
        array1 {
          id
          stringField
          obj {
            id
            stringField
          }
        }
        array2 {
          id
          stringField
          obj {
            id
            numberField
          }
        }
      }
    ]])

		local result: any = {
			id = "a",
			array1 = {
				{
					id = "aa",
					stringField = "string",
					obj = {
						id = "aaa",
						stringField = "string",
					},
				},
			},
			array2 = {
				{
					id = "ab",
					stringField = "string2",
					obj = {
						id = "aaa",
						numberField = 1,
					},
				},
			},
		}

		local writer = StoreWriter.new(InMemoryCache.new({
			dataIdFromObject = getIdField,
		}))

		local normalized = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})

		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				id = "a",
				array1 = { makeReference("aa") },
				array2 = { makeReference("ab") },
			},
			aa = {
				id = "aa",
				stringField = "string",
				obj = makeReference("aaa"),
			},
			ab = {
				id = "ab",
				stringField = "string2",
				obj = makeReference("aaa"),
			},
			aaa = {
				id = "aaa",
				stringField = "string",
				numberField = 1,
			},
		})
	end)

	it("properly normalizes an object occurring in the same graphql array path twice", function()
		local query = gql([[

      {
        id
        array1 {
          id
          stringField
          obj {
            id
            stringField
            numberField
          }
        }
      }
    ]])

		local result: any = {
			id = "a",
			array1 = {
				{
					id = "aa",
					stringField = "string",
					obj = {
						id = "aaa",
						stringField = "string",
						numberField = 1,
					},
				},
				{
					id = "ab",
					stringField = "string2",
					obj = {
						id = "aaa",
						stringField = "should not be written",
						numberField = 2,
					},
				},
			},
		}

		local writer = StoreWriter.new(InMemoryCache.new({
			dataIdFromObject = getIdField,
		}))

		local normalized = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})

		expect(normalized:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				id = "a",
				array1 = { makeReference("aa"), makeReference("ab") },
			},
			aa = {
				id = "aa",
				stringField = "string",
				obj = makeReference("aaa"),
			},
			ab = {
				id = "ab",
				stringField = "string2",
				obj = makeReference("aaa"),
			},
			aaa = {
				id = "aaa",
				stringField = "string",
				numberField = 1,
			},
		})
	end)

	it("merges nodes", function()
		local query = gql([[

      {
        id
        numberField
        nullField
      }
    ]])

		local result: any = {
			id = "abcd",
			numberField = 5,
			nullField = NULL,
		}

		local writer = StoreWriter.new(InMemoryCache.new({
			dataIdFromObject = getIdField,
		}))

		local store = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})
		local query2 = gql([[

      {
        id
        stringField
        nullField
      }
    ]])
		local result2: any = {
			id = "abcd",
			stringField = "This is a string!",
			nullField = NULL,
		}

		local store2 = writeQueryToStore({
			writer = writer,
			store = store,
			query = query2,
			result = result2,
		})

		expect(store2:toObject()).toEqual({
			ROOT_QUERY = Object.assign({}, {
				__typename = "Query",
			}, result, result2),
		})
	end)

	it("properly normalizes a nested object that returns null", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
        nestedObj {
          id
          stringField
          numberField
          nullField
        }
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
			nestedObj = NULL,
		}

		expect(writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		}):toObject()).toEqual({
			ROOT_QUERY = Object.assign(
				{},
				{
					__typename = "Query",
				},
				result,
				{
					nestedObj = NULL,
				}
			),
		})
	end)

	it("properly normalizes an object with an ID when no extension is passed", function()
		local query = gql([[

      {
        people_one(id: "5") {
          id
          stringField
        }
      }
    ]])

		local result: any = {
			people_one = {
				id = "abcd",
				stringField = "This is a string!",
			},
		}

		expect(writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		}):toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				['people_one({"id":"5"})'] = {
					id = "abcd",
					stringField = "This is a string!",
				},
			},
		})
	end)

	it("consistently serialize different types of input when passed inlined or as variable", function()
		local testData = {
			{
				mutation = gql([[

          mutation mut($in: Int!) {
            mut(inline: 5, variable: $in) {
              id
            }
          }
        ]]),
				variables = { ["in"] = 5 } :: any,
				expected = 'mut({"inline":5,"variable":5})',
			},
			{
				mutation = gql([[

          mutation mut($in: Float!) {
            mut(inline: 5.5, variable: $in) {
              id
            }
          }
        ]]),
				variables = { ["in"] = 5.5 },
				expected = 'mut({"inline":5.5,"variable":5.5})',
			},
			{
				mutation = gql([[

          mutation mut($in: String!) {
            mut(inline: "abc", variable: $in) {
              id
            }
          }
        ]]),
				variables = { ["in"] = "abc" },
				expected = 'mut({"inline":"abc","variable":"abc"})',
			},
			{
				mutation = gql([[

          mutation mut($in: Array!) {
            mut(inline: [1, 2], variable: $in) {
              id
            }
          }
        ]]),
				variables = { ["in"] = { 1, 2 } },
				expected = 'mut({"inline":[1,2],"variable":[1,2]})',
			},
			{
				mutation = gql([[

          mutation mut($in: Object!) {
            mut(inline: { a: 1 }, variable: $in) {
              id
            }
          }
        ]]),
				variables = { ["in"] = { a = 1 } },
				expected = 'mut({"inline":{"a":1},"variable":{"a":1}})',
			},
			{
				mutation = gql([[

          mutation mut($in: Boolean!) {
            mut(inline: true, variable: $in) {
              id
            }
          }
        ]]),
				variables = { ["in"] = true },
				expected = 'mut({"inline":true,"variable":true})',
			},
		}

		local function isOperationDefinition(definition: DefinitionNode): boolean
			return definition.kind == "OperationDefinition"
		end

		local function isField(selection: SelectionNode): boolean
			return selection.kind == "Field"
		end

		Array.forEach(testData, function(data)
			Array.forEach(data.mutation.definitions, function(definition: OperationDefinitionNode)
				if isOperationDefinition(definition) then
					Array.forEach(definition.selectionSet.selections, function(selection)
						if isField(selection) then
							expect(storeKeyNameFromField(selection :: FieldNode, data.variables)).toEqual(data.expected)
						end
					end)
				end
			end)
		end)
	end)

	it("properly normalizes a mutation with object or array parameters and variables", function()
		local mutation = gql([[

      mutation some_mutation($nil: ID, $in: Object) {
        some_mutation(
          input: {
            id: "5"
            arr: [1, { a: "b" }]
            obj: { a: "b" }
            num: 5.5
            nil: $nil
            bo: true
          }
        ) {
          id
        }
        some_mutation_with_variables(input: $in) {
          id
        }
      }
    ]])

		local result: any = {
			some_mutation = {
				id = "id",
			},
			some_mutation_with_variables = {
				id = "id",
			},
		}

		local variables: any = {
			["nil"] = NULL,
			["in"] = {
				id = "5",
				arr = { 1 :: any, { a = "b" } },
				obj = { a = "b" },
				num = 5.5,
				["nil"] = NULL,
				bo = true,
			},
		}

		local function isOperationDefinition(value: ASTNode): boolean
			return value.kind == "OperationDefinition"
		end

		Array.map(mutation.definitions, function(def: OperationDefinitionNode)
			if isOperationDefinition(def) then
				local writer = StoreWriter.new(InMemoryCache.new({
					dataIdFromObject = function(self)
						return "5"
					end,
				}))

				expect(writeQueryToStore({
					writer = writer,
					query = {
						kind = "Document",
						definitions = { def },
					} :: DocumentNode,
					dataId = "5",
					result = result,
					variables = variables,
				}):toObject()).toEqual({
					["5"] = {
						id = "id",
						[(
							'some_mutation({"input":{"arr":[1,{"a":"b"}],"bo":true,"id":"5","nil":%s,"num":5.5,"obj":{"a":"b"}}})'
						):format(HttpService:JSONEncode(NULL))] = makeReference("5"),
						[(
							'some_mutation_with_variables({"input":{"arr":[1,{"a":"b"}],"bo":true,"id":"5","nil":%s,"num":5.5,"obj":{"a":"b"}}})'
						):format(HttpService:JSONEncode(NULL))] = makeReference("5"),
					},
				})
			else
				error("No operation definition found")
			end
			return nil
		end)
	end)

	describe("type escaping", function()
		it("should correctly escape generated ids", function()
			local query = gql([[

        query {
          author {
            firstName
            lastName
          }
        }
      ]])
			local data = {
				author = {
					firstName = "John",
					lastName = "Smith",
				},
			}
			local expStore = defaultNormalizedCacheFactory({
				ROOT_QUERY = Object.assign({}, {
					__typename = "Query",
				}, data),
			})
			expect(writeQueryToStore({
				writer = writer,
				result = data,
				query = query,
			}):toObject()).toEqual(expStore:toObject())
		end)

		it("should correctly escape real ids", function()
			local query = gql([[

        query {
          author {
            firstName
            id
            __typename
          }
        }
      ]])
			local data = {
				author = {
					firstName = "John",
					id = "129",
					__typename = "Author",
				},
			}
			local expStore = defaultNormalizedCacheFactory({
				ROOT_QUERY = {
					__typename = "Query",
					author = makeReference(cache:identify(data.author) :: string),
				},
				[cache:identify(data.author) :: string] = {
					firstName = data.author.firstName,
					id = data.author.id,
					__typename = data.author.__typename,
				},
			})
			expect(writeQueryToStore({
				writer = writer,
				result = data,
				query = query,
			}):toObject()).toEqual(expStore:toObject())
		end)

		it("should not need to escape json blobs", function()
			local query = gql([[

        query {
          author {
            info
            id
            __typename
          }
        }
      ]])
			local data = {
				author = {
					info = { name = "John" },
					id = "129",
					__typename = "Author",
				},
			}
			local expStore = defaultNormalizedCacheFactory({
				ROOT_QUERY = {
					__typename = "Query",
					author = makeReference(cache:identify(data.author) :: any),
				},
				[cache:identify(data.author) :: string] = {
					__typename = data.author.__typename,
					id = data.author.id,
					info = data.author.info,
				},
			})
			expect(writeQueryToStore({
				writer = writer,
				result = data,
				query = query,
			}):toObject()).toEqual(expStore:toObject())
		end)
	end)

	it("should not merge unidentified data when replacing with ID reference", function()
		local dataWithoutId = {
			author = {
				firstName = "John",
				lastName = "Smith",
				__typename = "Author",
			},
		}

		local dataWithId = {
			author = {
				firstName = "John",
				id = "129",
				__typename = "Author",
			},
		}

		local queryWithoutId = gql([[

      query {
        author {
          firstName
          lastName
          __typename
        }
      }
    ]])
		local queryWithId = gql([[

      query {
        author {
          firstName
          id
          __typename
        }
      }
    ]])

		local cache = InMemoryCache.new({
			typePolicies = {
				Query = {
					fields = {
						-- Silence "Cache data may be lost..." warnings by always
						-- preferring the incoming value.
						author = {
							merge = function(_self, existing, incoming, ref)
								if Boolean.toJSBoolean(existing) then
									expect(ref:isReference(existing)).toBe(false)
									expect(ref:readField({
										fieldName = "__typename",
										from = existing,
									})).toBe("Author")
									expect(ref:isReference(incoming)).toBe(true)
									expect(ref:readField({
										fieldName = "__typename",
										from = incoming,
									})).toBe("Author")
								end
								return incoming
							end,
						},
					},
				},
			},
			dataIdFromObject = function(_self, object: any)
				if Boolean.toJSBoolean(object.__typename) and Boolean.toJSBoolean(object.id) then
					return object.__typename .. "__" .. tostring(object.id)
				end
				return nil
			end,
		})

		cache:writeQuery({
			query = queryWithoutId,
			data = dataWithoutId,
		})

		expect(cache:extract()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				author = {
					firstName = "John",
					lastName = "Smith",
					__typename = "Author",
				},
			},
		})

		cache:writeQuery({
			query = queryWithId,
			data = dataWithId,
		})

		expect(cache:extract()).toEqual({
			Author__129 = {
				firstName = "John",
				id = "129",
				__typename = "Author",
			},
			ROOT_QUERY = {
				__typename = "Query",
				author = makeReference("Author__129"),
			},
		})
	end)

	-- ROBLOX TODO: fragments are not supported yet
	it.skip("correctly merges fragment fields along multiple paths", function()
		local cache = InMemoryCache.new({
			typePolicies = {
				Container = {
					-- Uncommenting this line fixes the test, but should not be necessary,
					-- since the Container response object in question has the same
					-- identity along both paths.
					-- merge: true,
				},
			},
		})

		local query = gql([[

      query Query {
        item(id: "123") {
          id
          value {
            ...ContainerFragment
          }
        }
      }

      fragment ContainerFragment on Container {
        value {
          ...ValueFragment
          item {
            id
            value {
              text
            }
          }
        }
      }

      fragment ValueFragment on Value {
        item {
          ...ItemFragment
        }
      }

      fragment ItemFragment on Item {
        value {
          value {
            __typename
          }
        }
      }
    ]])

		local data = {
			item = {
				__typename = "Item",
				id = "0f47f85d-8081-466e-9121-c94069a77c3e",
				value = {
					__typename = "Container",
					value = {
						__typename = "Value",
						item = {
							__typename = "Item",
							id = "6dc3530b-6731-435e-b12a-0089d0ae05ac",
							value = {
								__typename = "Container",
								text = "Hello World",
								value = { __typename = "Value" },
							},
						},
					},
				},
			},
		}

		cache:writeQuery({
			query = query,
			data = data,
		})

		expect(cache:readQuery({ query = query })).toEqual(data)
		expect(cache:extract()).toMatchSnapshot()
	end)

	-- ROBLOX TODO: fragments are not supported yet
	it.skip("should respect id fields added by fragments", function()
		local query = gql([[

      query ABCQuery {
        __typename
        a {
          __typename
          id
          ...SharedFragment
          b {
            __typename
            c {
              __typename
              title
              titleSize
            }
          }
        }
      }
      fragment SharedFragment on AShared {
        __typename
        b {
          __typename
          id
          c {
            __typename
          }
        }
      }
    ]])

		local data = {
			__typename = "Query",
			a = {
				__typename = "AType",
				id = "a-id",
				b = {
					{
						__typename = "BType",
						id = "b-id",
						c = {
							__typename = "CType",
							title = "Your experience",
							titleSize = NULL,
						},
					},
				},
			},
		}

		local cache = InMemoryCache.new({
			possibleTypes = { AShared = { "AType" } },
		})

		cache:writeQuery({ query = query, data = data })
		expect(cache:readQuery({ query = query })).toEqual(data)

		expect(cache:extract()).toMatchSnapshot()
	end)

	-- ROBLOX TODO: fragments are not supported yet
	it.skip(
		"should allow a union of objects of a different type, when overwriting a generated id with a real id",
		function()
			local dataWithPlaceholder = {
				author = { hello = "Foo", __typename = "Placeholder" },
			}
			local dataWithAuthor = {
				author = {
					firstName = "John",
					lastName = "Smith",
					id = "129",
					__typename = "Author",
				},
			}
			local query = gql([[

      query {
        author {
          ... on Author {
            firstName
            lastName
            id
            __typename
          }
          ... on Placeholder {
            hello
            __typename
          }
        }
      }
    ]])

			local mergeCount = 0
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							author = {
								merge = function(_self, existing, incoming, ref)
									mergeCount += 1
									local condition = mergeCount
									if condition == 1 then
										expect(existing).toBeUndefined()
										expect(ref:isReference(incoming)).toBe(false)
										expect(incoming).toEqual(dataWithPlaceholder.author)
									elseif condition == 2 then
										expect(existing).toEqual(dataWithPlaceholder.author)
										expect(ref:isReference(incoming)).toBe(true)
										expect(ref:readField("__typename", incoming)).toBe("Author")
									elseif condition == 3 then
										expect(ref:isReference(existing)).toBe(true)
										expect(ref:readField("__typename", existing)).toBe("Author")
										expect(incoming).toEqual(dataWithPlaceholder.author)
									else
										fail("unreached")
									end
									return incoming
								end,
							},
						},
					},
				},
			})

			-- write the first object, without an ID, placeholder
			cache:writeQuery({
				query = query,
				data = dataWithPlaceholder,
			})

			expect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					author = {
						hello = "Foo",
						__typename = "Placeholder",
					},
				},
			})

			-- replace with another one of different type with ID
			cache:writeQuery({
				query = query,
				data = dataWithAuthor,
			})

			expect(cache:extract()).toEqual({
				["Author:129"] = {
					firstName = "John",
					lastName = "Smith",
					id = "129",
					__typename = "Author",
				},
				ROOT_QUERY = {
					__typename = "Query",
					author = makeReference("Author:129"),
				},
			})

			-- and go back to the original:
			cache:writeQuery({
				query = query,
				data = dataWithPlaceholder,
			})

			-- Author__129 will remain in the store,
			-- but will not be referenced by any of the fields,
			-- hence we combine, and in that very order
			expect(cache:extract()).toEqual({
				["Author:129"] = {
					firstName = "John",
					lastName = "Smith",
					id = "129",
					__typename = "Author",
				},
				ROOT_QUERY = {
					__typename = "Query",
					author = {
						hello = "Foo",
						__typename = "Placeholder",
					},
				},
			})
		end
	)

	-- ROBLOX TODO: fragments are not supported yet
	it.skip("does not swallow errors other than field errors", function()
		local query = gql([[

      query {
        ...notARealFragment
        fortuneCookie
      }
    ]])
		local result: any = {
			fortuneCookie = "Star Wars unit tests are boring",
		}
		expect(function()
			writeQueryToStore({
				writer = writer,
				result = result,
				query = query,
			})
		end).toThrowError("No fragment")
	end)

	it("does not change object references if the value is the same", function()
		local query = gql([[

      {
        id
        stringField
        numberField
        nullField
      }
    ]])

		local result: any = {
			id = "abcd",
			stringField = "This is a string!",
			numberField = 5,
			nullField = NULL,
		}
		local store = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
		})

		local newStore = writeQueryToStore({
			writer = writer,
			query = query,
			result = cloneDeep(result),
			store = defaultNormalizedCacheFactory(store:toObject()),
		})

		Array.forEach(Object.keys(store:toObject()), function(field)
			expect((store :: any):lookup(field)).toEqual((newStore :: any):lookup(field))
		end)
	end)

	describe('"Cache data maybe lost..." warnings', function()
		local warn = console.warn
		local warnings: Array<Array<any>> = {}

		beforeEach(function()
			warnings = {}
			console.warn = function(...: any)
				local args = { ... }
				table.insert(warnings, args)
			end
		end)

		afterEach(function()
			console.warn = warn
		end)

		it("should not warn when scalar fields are updated", function()
			local cache = InMemoryCache.new()

			local query = gql([[

        query {
          someJSON
          currentTime(tz: "UTC-5")
        }
      ]])

			expect(warnings).toEqual({})

			--[[
					ROBLOX deviation: using already formatted date string
					original code:
					const date = new Date(1601053713081);
				]]
			local msSinceEpoch = 1601053713081
			local localeString = "9/25/2020, 1:08:33 PM"

			cache:writeQuery({
				query = query,
				data = {
					someJSON = {
						oyez = 3,
						foos = { "bar", "baz" },
					},
					currentTime = {
						--[[
								ROBLOX deviation: using already formatted date string
								original code:
								localeString: date.toLocaleString("en-US", {
								  timeZone: "America/New_York",
								}),
							]]
						localeString = localeString,
					},
				},
			})

			expect(cache:extract()).toMatchSnapshot()
			expect(warnings).toEqual({})

			cache:writeQuery({
				query = query,
				data = {
					someJSON = {
						qwer = "upper",
						asdf = "middle",
						zxcv = "lower",
					},
					currentTime = {
						--[[
								ROBLOX deviation: using msSinceEpoch directly
								original code:
								msSinceEpoch: date.getTime(),
							]]
						msSinceEpoch = msSinceEpoch,
					},
				},
			})

			expect(cache:extract()).toMatchSnapshot()
			expect(warnings).toEqual({})
		end)
	end)

	describe("writeResultToStore shape checking", function()
		local query = gql([[

      query {
        todos {
          id
          name
          description
        }
      }
    ]])

		withErrorSpy(
			it,
			"should write the result data without validating its shape when a fragment matcher is not provided",
			function()
				local result = {
					todos = { {
						id = "1",
						name = "Todo 1",
					} },
				}

				local writer = StoreWriter.new(InMemoryCache.new({
					dataIdFromObject = getIdField,
				}))

				local newStore = writeQueryToStore({
					writer = writer,
					query = query,
					result = result,
				})

				expect((newStore :: any):lookup("1")).toEqual(result.todos[1])
			end
		)

		withErrorSpy(it, "should warn when it receives the wrong data with non-union fragments", function()
			local result = {
				todos = { {
					id = "1",
					name = "Todo 1",
				} },
			}

			local writer = StoreWriter.new(InMemoryCache.new({
				dataIdFromObject = getIdField,
				possibleTypes = {},
			}))

			writeQueryToStore({
				writer = writer,
				query = query,
				result = result,
			})
		end)

		-- ROBLOX TODO: fragments are not supported yet
		it.skip("should warn when it receives the wrong data inside a fragment", function()
			local queryWithInterface = gql([[

        query {
          todos {
            id
            name
            description
            ...TodoFragment
          }
        }

        fragment TodoFragment on Todo {
          ... on ShoppingCartItem {
            price
            __typename
          }
          ... on TaskItem {
            date
            __typename
          }
          __typename
        }
      ]])

			local result = {
				todos = {
					{
						id = "1",
						name = "Todo 1",
						description = "Description 1",
						__typename = "ShoppingCartItem",
					},
				},
			}

			local writer = StoreWriter.new(InMemoryCache.new({
				dataIdFromObject = getIdField,
				possibleTypes = {
					Todo = { "ShoppingCartItem", "TaskItem" },
				},
			}))

			writeQueryToStore({
				writer = writer,
				query = queryWithInterface,
				result = result,
			})
		end)

		it("should warn if a result is missing __typename when required", function()
			local result: any = {
				todos = {
					{
						id = "1",
						name = "Todo 1",
						description = "Description 1",
					},
				},
			}

			local writer = StoreWriter.new(InMemoryCache.new({
				dataIdFromObject = getIdField,
				possibleTypes = {},
			}))

			writeQueryToStore({
				writer = writer,
				query = addTypenameToDocument(query),
				result = result,
			})
		end)

		it("should not warn if a field is null", function()
			local result: any = {
				todos = NULL,
			}

			local writer = StoreWriter.new(InMemoryCache.new({
				dataIdFromObject = getIdField,
			}))

			local newStore = writeQueryToStore({
				writer = writer,
				query = query,
				result = result,
			})

			expect((newStore :: any):lookup("ROOT_QUERY")).toEqual({
				__typename = "Query",
				todos = NULL,
			})
		end)
		it("should not warn if a field is defered", function()
			local originalWarn = console.warn
			console.warn = jest.fn(function(...: any) end)
			local defered = gql([[

        query LazyLoad {
          id
          expensive @defer
        }
      ]])
			local result: any = {
				id = 1,
			}

			local writer = StoreWriter.new(InMemoryCache.new({
				dataIdFromObject = getIdField,
			}))

			local newStore = writeQueryToStore({
				writer = writer,
				query = defered,
				result = result,
			})

			expect((newStore :: any):lookup("ROOT_QUERY")).toEqual({ __typename = "Query", id = 1 })
			expect(console.warn).never.toBeCalled()
			console.warn = originalWarn
		end)
	end)

	it("properly handles the @connection directive", function()
		local store = defaultNormalizedCacheFactory()

		writeQueryToStore({
			writer = writer,
			query = gql([[

        {
          books(skip: 0, limit: 2) @connection(key: "abc") {
            name
          }
        }
      ]]),
			result = {
				books = {
					{
						name = "abcd",
					},
				},
			},
			store = store,
		})

		writeQueryToStore({
			writer = writer,
			query = gql([[

        {
          books(skip: 2, limit: 4) @connection(key: "abc") {
            name
          }
        }
      ]]),
			result = {
				books = {
					{
						name = "efgh",
					},
				},
			},
			store = store,
		})

		expect(store:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				["books:abc"] = {
					{
						name = "efgh",
					},
				},
			},
		})
	end)

	it("can use keyArgs function instead of @connection directive", function()
		local store = defaultNormalizedCacheFactory()
		local writer = StoreWriter.new(InMemoryCache.new({
			typePolicies = {
				Query = {
					fields = { books = {
						keyArgs = function()
							return "abc"
						end,
					} },
				},
			},
		}))

		writeQueryToStore({
			writer = writer,
			query = gql([[

        {
          books(skip: 0, limit: 2) {
            name
          }
        }
      ]]),
			result = {
				books = {
					{
						name = "abcd",
					},
				},
			},
			store = store,
		})

		expect(store:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				["books:abc"] = {
					{
						name = "abcd",
					},
				},
			},
		})

		writeQueryToStore({
			writer = writer,
			query = gql([[

        {
          books(skip: 2, limit: 4) {
            name
          }
        }
      ]]),
			result = {
				books = {
					{
						name = "efgh",
					},
				},
			},
			store = store,
		})

		expect(store:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				["books:abc"] = {
					{
						name = "efgh",
					},
				},
			},
		})
	end)

	it("should keep reference when type of mixed inlined field changes", function()
		local store = defaultNormalizedCacheFactory()

		local query = gql([[

    	  query {
    	    animals {
    	      species {
    	        name
    	      }
    	    }
    	  }
    	]])

		writeQueryToStore({
			writer = writer,
			query = query,
			result = {
				animals = {
					{
						__typename = "Animal",
						species = {
							__typename = "Cat",
							name = "cat",
						},
					},
				},
			},
			store = store,
		})

		expect(store:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				animals = {
					{
						__typename = "Animal",
						species = {
							__typename = "Cat",
							name = "cat",
						},
					},
				},
			},
		})

		writeQueryToStore({
			writer = writer,
			query = query,
			result = {
				animals = {
					{
						__typename = "Animal",
						species = {
							__typename = "Dog",
							name = "dog",
						},
					},
				},
			},
			store = store,
		})

		expect(store:toObject()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				animals = {
					{
						__typename = "Animal",
						species = {
							__typename = "Dog",
							name = "dog",
						},
					},
				},
			},
		})
	end)

	-- ROBLOX FIXME: this test is affected by previous tests.
	withErrorSpy(
		itFIXME,
		"should not keep reference when type of mixed inlined field changes to non-inlined field",
		function()
			local store = defaultNormalizedCacheFactory()

			local query = gql([[

    			  query {
    			    animals {
    			      species {
    			        id
    			        name
    			      }
    			    }
    			  }
    			]])

			writeQueryToStore({
				writer = writer,
				query = query,
				result = {
					animals = {
						{
							__typename = "Animal",
							species = {
								__typename = "Cat",
								name = "cat",
							},
						},
					},
				},
				store = store,
			})

			expect(store:toObject()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					animals = {
						{
							__typename = "Animal",
							species = {
								__typename = "Cat",
								name = "cat",
							},
						},
					},
				},
			})

			writeQueryToStore({
				writer = writer,
				query = query,
				result = {
					animals = {
						{
							__typename = "Animal",
							species = {
								id = "dog-species",
								__typename = "Dog",
								name = "dog",
							},
						},
					},
				},
				store = store,
			})

			expect(store:toObject()).toEqual({
				["Dog__dog-species"] = {
					id = "dog-species",
					__typename = "Dog",
					name = "dog",
				},
				ROOT_QUERY = {
					__typename = "Query",
					animals = {
						{
							__typename = "Animal",
							species = makeReference("Dog__dog-species"),
						},
					},
				},
			})
		end
	)

	it("should not merge { __ref } as StoreObject when mergeObjects used", function()
		local merges: Array<{ existing: Reference | nil, incoming: Reference | StoreObject, merged: Reference }> = {}

		local cache = InMemoryCache.new({
			typePolicies = {
				Account = {
					merge = function(_self, existing, incoming, ref)
						local merged = ref:mergeObjects(existing, incoming)
						table.insert(merges, { existing = existing, incoming = incoming, merged = merged })
						-- ROBLOX comment: not required
						-- debugger;
						return merged
					end,
				},
			},
		})

		local contactLocationQuery = gql([[
			
				query {
				  account {
					contact
					location
				  }
				}
			  ]])

		local contactOnlyQuery = gql([[
			
				query {
				  account {
					contact
				  }
				}
			  ]])

		local locationOnlyQuery = gql([[
			
				query {
				  account {
					location
				  }
				}
			  ]])

		cache:writeQuery({
			query = contactLocationQuery,
			data = {
				account = {
					__typename = "Account",
					contact = "billing@example.com",
					location = "Exampleville, Ohio",
				},
			},
		})

		expect(cache:extract()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				account = {
					__typename = "Account",
					contact = "billing@example.com",
					location = "Exampleville, Ohio",
				},
			},
		})

		cache:writeQuery({
			query = contactOnlyQuery,
			data = { account = { __typename = "Account", id = 12345, contact = "support@example.com" } },
		})

		expect(cache:extract()).toEqual({
			["Account:12345"] = {
				__typename = "Account",
				id = 12345,
				contact = "support@example.com",
				location = "Exampleville, Ohio",
			},
			ROOT_QUERY = { __typename = "Query", account = { __ref = "Account:12345" } },
		})

		cache:writeQuery({
			query = locationOnlyQuery,
			data = { account = { __typename = "Account", location = "Nowhere, New Mexico" } },
		})

		expect(cache:extract()).toEqual({
			["Account:12345"] = {
				__typename = "Account",
				id = 12345,
				contact = "support@example.com",
				location = "Nowhere, New Mexico",
			},
			ROOT_QUERY = { __typename = "Query", account = { __ref = "Account:12345" } },
		})

		expect(merges).toEqual({
			{
				existing = nil,
				incoming = {
					__typename = "Account",
					contact = "billing@example.com",
					location = "Exampleville, Ohio",
				},
				merged = {
					__typename = "Account",
					contact = "billing@example.com",
					location = "Exampleville, Ohio",
				},
			},
			{
				existing = {
					__typename = "Account",
					contact = "billing@example.com",
					location = "Exampleville, Ohio",
				},
				incoming = { __ref = "Account:12345" },
				merged = { __ref = "Account:12345" },
			},
			{
				existing = { __ref = "Account:12345" },
				incoming = { __typename = "Account", location = "Nowhere, New Mexico" },
				merged = { __ref = "Account:12345" },
			},
		})
	end)

	it("should not deep-freeze scalar objects", function()
		local query = gql([[

      query {
        scalarFieldWithObjectValue
      }
    ]])

		local scalarObject = {
			a = 1,
			b = { 2, 3 },
			c = {
				d = 4,
				e = 5,
			},
		}

		local cache = InMemoryCache.new()

		cache:writeQuery({
			query = query,
			data = {
				scalarFieldWithObjectValue = scalarObject,
			},
		})

		expect(table.isfrozen(scalarObject)).toBe(false)
		expect(table.isfrozen(scalarObject.b)).toBe(false)
		expect(table.isfrozen(scalarObject.c)).toBe(false)

		local result = cache:readQuery({ query = query })
		expect(result.scalarFieldWithObjectValue).never.toBe(scalarObject)
		expect(table.isfrozen(result.scalarFieldWithObjectValue)).toBe(true)
		expect(table.isfrozen(result.scalarFieldWithObjectValue.b)).toBe(true)
		expect(table.isfrozen(result.scalarFieldWithObjectValue.c)).toBe(true)
	end)

	it("should skip writing still-fresh result objects", function()
		-- ROBLOX deviation: predefine variable
		local mergeCounts: Record<string, number>
		local cache = InMemoryCache.new({
			typePolicies = {
				Todo = {
					fields = {
						text = {
							merge = function(_self, _, text: string)
								mergeCounts[text] = bit32.bnot(bit32.bnot(mergeCounts[text] or 0)) + 1
								return text
							end,
						},
					},
				},
			},
		})

		mergeCounts = {}

		local query = gql([[

      query {
        todos {
          id
          text
        }
      }
    ]])

		expect(mergeCounts).toEqual({})

		cache:writeQuery({
			query = query,
			data = {
				todos = {
					{ __typename = "Todo", id = 1, text = "first" },
					{ __typename = "Todo", id = 2, text = "second" },
				},
			},
		})

		expect(mergeCounts).toEqual({ first = 1, second = 1 })

		local function read()
			return (cache:readQuery({ query = query }) :: any).todos
		end

		local twoTodos = read()

		expect(mergeCounts).toEqual({ first = 1, second = 1 })

		local threeTodos = Array.concat({}, twoTodos, { { __typename = "Todo", id = 3, text = "third" } })

		cache:writeQuery({
			query = query,
			data = {
				todos = threeTodos,
			},
		})

		expect(mergeCounts).toEqual({ first = 1, second = 1, third = 1 })

		local threeTodosAgain = read()
		Array.forEach(twoTodos, function(todo, i)
			return expect(todo).toBe(threeTodosAgain[i])
		end)

		local fourTodos = {
			threeTodosAgain[3],
			threeTodosAgain[1],
			{ __typename = "Todo", id = 4, text = "fourth" },
			threeTodosAgain[2],
		}

		cache:writeQuery({
			query = query,
			data = {
				todos = fourTodos,
			},
		})

		expect(mergeCounts).toEqual({ first = 1, second = 1, third = 1, fourth = 1 })
	end)

	itAsync("should allow silencing broadcast of cache updates", function(resolve, reject)
		local cache = InMemoryCache.new({
			typePolicies = {
				Counter = {
					-- Counter is a singleton, but we want to be able to test
					-- writing to it with writeFragment, so it needs to have an ID.
					keyFields = {},
				},
			},
		})

		local query = gql([[

      query {
        counter {
          count
        }
      }
    ]])

		local results: Array<number> = {}

		cache:watch({
			query = query,
			optimistic = true,
			callback = function(_self, diff)
				table.insert(results, diff.result)
				expect(diff.result).toEqual({
					counter = {
						__typename = "Counter",
						count = 3,
					},
				})
				resolve()
			end,
		})

		local count = 0

		cache:writeQuery({
			query = query,
			data = {
				counter = {
					__typename = "Counter",
					count = (function()
						count += 1
						return count
					end)(),
				},
			},
			broadcast = false,
		})

		expect(cache:extract()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				counter = {
					--[[
							ROBLOX deviation: in Lua we can't distinguish between empty arrays, and objects.
							empty variables will be serialized to "[]"
						]]
					__ref = "Counter:[]",
				},
			},
			--[[
					ROBLOX deviation: in Lua we can't distinguish between empty arrays, and objects.
					empty variables will be serialized to "[]"
				]]
			["Counter:[]"] = {
				__typename = "Counter",
				count = 1,
			},
		})

		expect(results).toEqual({})

		-- ROBLOX TODO: fragments are not supported yet
		-- local counterId = cache:identify({
		-- 	__typename = "Counter",
		-- }) :: string

		-- cache:writeFragment({
		-- 	id = counterId,
		-- 	fragment = gql("fragment Count on Counter { count }"),
		-- 	data = { count = (function()
		-- 		count += 1
		-- 		return count
		-- 	end)() },
		-- 	broadcast = false,
		-- })

		-- local counterMeta = {
		-- 	extraRootIds = {
		-- 		"Counter:{}",
		-- 	},
		-- }

		-- expect(cache:extract()).toEqual({
		-- 	__META = counterMeta,
		-- 	ROOT_QUERY = {
		-- 		__typename = "Query",
		-- 		counter = {
		-- 			__ref = "Counter:{}",
		-- 		},
		-- 	},
		-- 	["Counter:{}"] = {
		-- 		__typename = "Counter",
		-- 		count = 2,
		-- 	},
		-- })

		-- expect(results).toEqual({})

		-- expect(cache:evict({
		-- 	id = counterId,
		-- 	fieldName = "count",
		-- 	broadcast = false,
		-- })).toBe(true)

		-- expect(cache:extract()).toEqual({
		-- 	__META = counterMeta,
		-- 	ROOT_QUERY = {
		-- 		__typename = "Query",
		-- 		counter = {
		-- 			__ref = "Counter:{}",
		-- 		},
		-- 	},
		-- 	["Counter:{}"] = {
		-- 		__typename = "Counter",
		-- 	},
		-- })

		-- expect(results).toEqual({})

		-- Only this write should trigger a broadcast.
		cache:writeQuery({
			query = query,
			data = {
				counter = {
					__typename = "Counter",
					count = 3,
				},
			},
		})
	end)

	-- ROBLOX TODO: fragments are not supported yet
	it.skip("writeFragment should be able to infer ROOT_QUERY", function()
		local cache = InMemoryCache.new()

		local ref = cache:writeFragment({
			fragment = gql("fragment RootField on Query { field }"),
			data = {
				__typename = "Query",
				field = "value",
			},
		})

		expect(isReference(ref)).toBe(true)
		expect((ref :: any).__ref).toBe("ROOT_QUERY")

		expect(cache:extract()).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				field = "value",
			},
		})
	end)

	-- ROBLOX TODO: fragments are not supported yet
	it.skip("should warn if it cannot identify the result object", function()
		local cache = InMemoryCache.new()

		expect(function()
			cache:writeFragment({
				fragment = gql("fragment Count on Counter { count }"),
				data = {
					count = 1,
				},
			})
		end).toThrowError("Could not identify object")
	end)

	-- ROBLOX TODO: subscriptions are not supported yet
	it.skip('user objects should be able to have { __typename: "Subscription" }', function()
		local cache = InMemoryCache.new({
			typePolicies = {
				Subscription = {
					keyFields = { "subId" },
				},
			},
		})

		local query = gql([[

      query {
        subscriptions {
          __typename
          subscriber {
            name
          }
        }
      }
    ]])

		cache:writeQuery({
			query = query,
			data = {
				subscriptions = {
					{
						__typename = "Subscription",
						subId = 1,
						subscriber = {
							name = "Alice",
						},
					},
					{
						__typename = "Subscription",
						subId = 2,
						subscriber = {
							name = "Bob",
						},
					},
					{
						__typename = "Subscription",
						subId = 3,
						subscriber = {
							name = "Clytemnestra",
						},
					},
				},
			},
		})

		expect(cache:extract()).toMatchSnapshot()
		expect(cache:readQuery({ query = query })).toEqual({
			subscriptions = {
				{ __typename = "Subscription", subscriber = { name = "Alice" } },
				{ __typename = "Subscription", subscriber = { name = "Bob" } },
				{ __typename = "Subscription", subscriber = { name = "Clytemnestra" } },
			},
		})
	end)

	it('user objects should be able to have { __typename: "Mutation" }', function()
		local cache = InMemoryCache.new({
			typePolicies = {
				Mutation = {
					keyFields = { "gene" :: any, { "id" }, "name" },
				},
				Gene = {
					keyFields = { "id" },
				},
			},
		})

		local query = gql([[

      query {
        mutations {
          __typename
          gene { id }
          name
        }
      }
    ]])

		cache:writeQuery({
			query = query,
			data = {
				mutations = {
					{
						__typename = "Mutation",
						gene = {
							__typename = "Gene",
							id = "SLC45A2",
						},
						name = "albinism",
					},
					{
						__typename = "Mutation",
						gene = {
							__typename = "Gene",
							id = "SNAI2",
						},
						name = "piebaldism",
					},
				},
			},
		})

		expect(cache:extract()).toMatchSnapshot()
		expect(cache:readQuery({ query = query })).toEqual({
			mutations = {
				{
					__typename = "Mutation",
					gene = { __typename = "Gene", id = "SLC45A2" },
					name = "albinism",
				},
				{
					__typename = "Mutation",
					gene = { __typename = "Gene", id = "SNAI2" },
					name = "piebaldism",
				},
			},
		})
	end)
end)

return {}
