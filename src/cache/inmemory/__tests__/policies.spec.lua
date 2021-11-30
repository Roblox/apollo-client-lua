-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/__tests__/policies.ts
return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local _jest = JestGlobals.jest

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Object_ = LuauPolyfill.Object
	local Boolean = LuauPolyfill.Boolean
	local Set = LuauPolyfill.Set
	local Map = LuauPolyfill.Map
	local Error = LuauPolyfill.Error
	local setTimeout = LuauPolyfill.setTimeout
	type Array<T> = LuauPolyfill.Array<T>
	type Record<T, U> = { [T]: U }

	type ReturnType<T> = any

	-- ROBLOX TODO: replace when fn generic types are avaliable
	type TData_ = any
	type TVars_ = any

	-- No way to check if isFrozen
	local Object = Object_.assign(Object_, {
		isFrozen = function(...)
			return true
		end,
	})

	local RegExp = require(rootWorkspace.LuauRegExp)

	local NULL = require(srcWorkspace.utilities).NULL

	local gql = require(rootWorkspace.Dev.GraphQLTag).default

	local inMemoryCacheModule = require(script.Parent.Parent.inMemoryCache)
	local InMemoryCache = inMemoryCacheModule.InMemoryCache
	type InMemoryCache = inMemoryCacheModule.InMemoryCache

	local reactiveVarsModule = require(script.Parent.Parent.reactiveVars)
	type ReactiveVar<T> = reactiveVarsModule.ReactiveVar<T>
	local makeVar = reactiveVarsModule.makeVar

	local coreModule = require(srcWorkspace.core)
	type Reference = coreModule.Reference
	type StoreObject = coreModule.StoreObject
	local ApolloClient = coreModule.ApolloClient
	local NetworkStatus = coreModule.NetworkStatus
	type TypedDocumentNode<Result, Variables> = coreModule.TypedDocumentNode<Result, Variables>
	local GraphQL = require(rootWorkspace.GraphQL)
	type DocumentNode = GraphQL.DocumentNode

	local MissingFieldError = require(script.Parent.Parent.Parent).MissingFieldError

	local relayStylePagination =
		require(script.Parent.Parent.Parent.Parent.utilities.policies.pagination).relayStylePagination

	local MockLink = require(script.Parent.Parent.Parent.Parent.utilities.testing.mocking.mockLink).MockLink
	-- ROBLOX TODO: use real dependency when implemented
	-- local subscribeAndCount = require(script.Parent.Parent.Parent.Parent.utilities.testing.subscribeAndCount).default
	local subscribeAndCount = function(...) end
	local itAsync = require(script.Parent.Parent.Parent.Parent.utilities.testing).itAsync

	local policiesModule = require(script.Parent.Parent.policies)
	type FieldPolicy<TExisting, TIncoming, TReadResult> = policiesModule.FieldPolicy<TExisting, TIncoming, TReadResult>
	type StorageType = policiesModule.StorageType

	local withErrorSpy = require(script.Parent.Parent.Parent.Parent.utilities.testing).withErrorSpy

	local function reverse(s: string)
		-- ROBLOX deviation: using built-in string.reverse function instead
		return string.reverse(s)
	end

	describe("type policies", function()
		local bookQuery = gql([[
		
			query {
			  book {
				title
				author {
				  name
				}
			  }
			}
		  ]])

		local theInformationBookData = {
			__typename = "Book",
			isbn = "1400096235",
			title = "The Information",
			subtitle = "A History, a Theory, a Flood",
			author = { name = "James Gleick" },
		}

		local function checkAuthorName(cache: InMemoryCache)
			jestExpect(cache:readQuery({
				query = gql([[
		
				query {
				  book {
					author {
					  name
					}
				  }
				}
			  ]]),
			})).toEqual({ book = { __typename = "Book", author = { name = theInformationBookData.author.name } } })
		end

		it("can specify basic keyFields", function()
			local cache = InMemoryCache.new({ typePolicies = { Book = { keyFields = { "isbn" } } } })

			cache:writeQuery({ query = bookQuery, data = { book = theInformationBookData } })

			jestExpect(cache:extract(true)).toEqual({
				ROOT_QUERY = { __typename = "Query", book = { __ref = 'Book:{"isbn":"1400096235"}' } },
				['Book:{"isbn":"1400096235"}'] = {
					__typename = "Book",
					isbn = "1400096235",
					title = "The Information",
					author = { name = "James Gleick" },
				},
			})

			checkAuthorName(cache)
		end)

		it("can specify composite keyFields", function()
			local cache = InMemoryCache.new({
				typePolicies = { Book = { keyFields = { "title", "author", { "name" } } } },
			})

			cache:writeQuery({ query = bookQuery, data = { book = theInformationBookData } })

			jestExpect(cache:extract(true)).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = { __ref = 'Book:{"title":"The Information","author":{"name":"James Gleick"}}' },
				},
				['Book:{"title":"The Information","author":{"name":"James Gleick"}}'] = {
					__typename = "Book",
					title = "The Information",
					author = { name = "James Gleick" },
				},
			})

			checkAuthorName(cache)
		end)

		it("keeps keyFields in specified order", function()
			local cache = InMemoryCache.new({
				typePolicies = { Book = { keyFields = { "author", { "name" }, "title" } } },
			})

			cache:writeQuery({ query = bookQuery, data = { book = theInformationBookData } })

			jestExpect(cache:extract(true)).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = { __ref = 'Book:{"author":{"name":"James Gleick"},"title":"The Information"}' },
				},
				['Book:{"author":{"name":"James Gleick"},"title":"The Information"}'] = {
					__typename = "Book",
					title = "The Information",
					author = { name = "James Gleick" },
				},
			})

			checkAuthorName(cache)
		end)

		it("accepts keyFields functions", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Book = {
						keyFields = function(self, book, context)
							jestExpect(context.typename).toBe("Book")
							jestExpect((context.selectionSet :: any).kind).toBe("SelectionSet")
							jestExpect(context.fragmentMap).toEqual({})
							return { "isbn" }
						end,
					},
				},
			})

			cache:writeQuery({ query = bookQuery, data = { book = theInformationBookData } })

			jestExpect(cache:extract(true)).toEqual({
				ROOT_QUERY = { __typename = "Query", book = { __ref = 'Book:{"isbn":"1400096235"}' } },
				['Book:{"isbn":"1400096235"}'] = {
					__typename = "Book",
					isbn = "1400096235",
					title = "The Information",
					author = { name = "James Gleick" },
				},
			})

			checkAuthorName(cache)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xit("works with fragments that contain aliased key fields", function()
			local cache = InMemoryCache.new({ typePolicies = { Book = { keyFields = { "ISBN", "title" } } } })

			cache:writeQuery({
				query = gql([[
		
				query {
				  book {
					...BookFragment
					author {
					  name
					}
				  }
				}
				fragment BookFragment on Book {
				  isbn: ISBN
				  title
				}
			  ]]),
				data = { book = theInformationBookData },
			})

			jestExpect(cache:extract(true)).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = { __ref = 'Book:{"ISBN":"1400096235","title":"The Information"}' },
				},
				['Book:{"ISBN":"1400096235","title":"The Information"}'] = {
					__typename = "Book",
					ISBN = "1400096235",
					title = "The Information",
					author = { name = "James Gleick" },
				},
			})

			checkAuthorName(cache)
		end)

		withErrorSpy(it, "complains about missing key fields", function()
			local cache = InMemoryCache.new({ typePolicies = { Book = { keyFields = { "title", "year" } } } })

			local query = gql([[
		
			  query {
				book {
				  title
				  year
				}
			  }
			]])

			cache:writeQuery({
				query = query,
				data = { book = { year = 2011, theInformationBookData = theInformationBookData } },
			})

			jestExpect(function()
				cache:writeQuery({ query = query, data = { book = theInformationBookData } })
			end).toThrowError("Missing field 'year' while computing key fields")
		end)

		it("does not clobber previous keyFields with undefined", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Movie = {
						keyFields = function(self, incoming)
							return ("MotionPicture::%s"):format(incoming.id)
						end,
					},
				},
			})

			cache.policies:addTypePolicies({
				Movie = { fields = {
					isPurchased = function(self)
						return false
					end,
				} },
			})

			jestExpect(cache:identify({ __typename = "Movie", id = "3993d4118143" })).toBe(
				"MotionPicture::3993d4118143"
			)
		end)

		it("does not remove previous typePolicies", function()
			local cache = InMemoryCache.new({
				typePolicies = { Query = { fields = {
					foo = function()
						return "foo"
					end,
				} } },
			})

			cache.policies:addTypePolicies({
				Query = { fields = {
					bar = function()
						return "bar"
					end,
				} },
			})

			jestExpect(cache:readQuery({ query = gql(" { foo } ") })).toEqual({ foo = "foo" })

			jestExpect(cache:readQuery({ query = gql(" { bar } ") })).toEqual({ bar = "bar" })
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xit("support inheritance", function()
			local cache = InMemoryCache.new({
				possibleTypes = {
					Reptile = { "Snake", "Turtle" },
					Snake = { "Python", "Viper", "Cobra" },
					Viper = { "Cottonmouth" },
				},
				typePolicies = {
					Reptile = {
						keyFields = { "tagId" },
						fields = {
							scientificName = {
								merge = function(self, _, incoming)
									return string.lower(incoming)
								end,
							},
						},
					},
					Snake = {
						fields = {
							venomous = function(self, status: string?)
								if status == nil then
									status = "unknown"
								end
								return status
							end,
						},
					},
				},
			})

			local query: TypedDocumentNode<{ reptiles: Array<Record<string, any>> }, any> = gql([[
		
			  query {
				reptiles {
				  tagId
				  scientificName
				  ... on Snake {
					venomous
				  }
				}
			  }
			]])

			local reptiles = {
				{ __typename = "Turtle", tagId = "RedEaredSlider42", scientificName = "Trachemys scripta elegans" },
				{
					__typename = "Python",
					tagId = "BigHug4U",
					scientificName = "Malayopython reticulatus",
					venomous = false,
				},
				{ __typename = "Cobra", tagId = "Egypt30BC", scientificName = "Naja haje", venomous = true },
				{
					__typename = "Cottonmouth",
					tagId = "CM420",
					scientificName = "Agkistrodon piscivorus",
					venomous = true,
				},
			}

			cache:writeQuery({ query = query, data = { reptiles = reptiles } })

			jestExpect(cache:extract()).toMatchSnapshot()

			local result1 = cache:readQuery({ query = query }) :: any

			jestExpect(result1).toEqual({
				reptiles = Array.map(reptiles, function(reptile)
					return Object.assign({}, reptile, { scientificName = string.lower(reptile.scientificName) })
				end),
			})

			local cmId = cache:identify({ __typename = "Cottonmouth", tagId = "CM420" })

			jestExpect(cache:evict({ id = cmId, fieldName = "venomous" })).toBe(true)

			local result2 = cache:readQuery({ query = query }) :: any

			Array.forEach(result2.reptiles, function(reptile, i)
				if reptile.__typename == "Cottonmouth" then
					jestExpect(reptile).never.toBe(result1.reptiles[tostring(i)])
					jestExpect(reptile).never.toEqual(result1.reptiles[tostring(i)])
					jestExpect(reptile).toEqual({
						__typename = "Cottonmouth",
						tagId = "CM420",
						scientificName = "agkistrodon piscivorus",
						venomous = "unknown",
					})
				else
					jestExpect(reptile).toBe(result1.reptiles[tostring(i)])
				end
			end)

			cache.policies:addPossibleTypes({ Viper = { "DeathAdder" } })

			jestExpect(cache:identify({ __typename = "DeathAdder", tagId = "LethalAbacus666" })).toBe(
				'DeathAdder:{"tagId":"LethalAbacus666"}'
			)
		end)

		describe("field policies", function()
			it("can filter key arguments", function()
				local cache = InMemoryCache.new({
					typePolicies = { Query = { fields = { book = { keyArgs = { "isbn" } } } } },
				})

				cache:writeQuery({
					query = gql([[
		
				  query {
					book(junk: "ignored", isbn: "0465030793") {
					  title
					}
				  }
				]]),
					data = { book = { __typename = "Book", isbn = "0465030793", title = "I Am a Strange Loop" } },
				})

				jestExpect(cache:extract(true)).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						['book:{"isbn":"0465030793"}'] = { __typename = "Book", title = "I Am a Strange Loop" },
					},
				})
			end)

			it("can filter key arguments in non-Query fields", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Book = {
							keyFields = { "isbn" },
							fields = { author = { keyArgs = { "firstName", "lastName" } } },
						},
						Author = { keyFields = { "name" } },
					},
				})

				local query = gql([[
		
				query {
				  book {
					isbn
					title
					author(
					  firstName: "Douglas",
					  middleName: "Richard",
					  lastName: "Hofstadter"
					) {
					  name
					}
				  }
				}
			  ]])

				local data = {
					book = {
						__typename = "Book",
						isbn = "0465030793",
						title = "I Am a Strange Loop",
						author = { __typename = "Author", name = "Douglas Hofstadter" },
					},
				}

				cache:writeQuery({ query = query, data = data })

				jestExpect(cache:extract(true)).toEqual({
					ROOT_QUERY = { __typename = "Query", book = { __ref = 'Book:{"isbn":"0465030793"}' } },
					['Book:{"isbn":"0465030793"}'] = {
						__typename = "Book",
						isbn = "0465030793",
						title = "I Am a Strange Loop",
						['author:{"firstName":"Douglas","lastName":"Hofstadter"}'] = {
							__ref = 'Author:{"name":"Douglas Hofstadter"}',
						},
					},
					['Author:{"name":"Douglas Hofstadter"}'] = { __typename = "Author", name = "Douglas Hofstadter" },
				})

				local result = cache:readQuery({ query = query })

				jestExpect(result).toEqual(data)
			end)

			-- ROBLOX TODO: fragments are not supported yet
			withErrorSpy(xit, "assumes keyArgs:false when read and merge function present", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						TypeA = { fields = {
							a = function(self)
								return "a"
							end,
						} },
						TypeB = {
							fields = {
								b = {
									keyArgs = { "x" },
									read = function(self)
										return "b"
									end,
								},
							},
						},
						TypeC = {
							fields = {
								c = {
									keyArgs = false,
									merge = function(self, existing, incoming: string)
										return reverse(incoming)
									end,
								},
							},
						},
						TypeD = {
							fields = {
								d = {
									keyArgs = function(self)
										return "d"
									end,
									read = function(self, existing: string)
										return string.lower(existing)
									end,
									merge = function(self, existing: string, incoming: string)
										return string.upper(incoming)
									end,
								},
							},
						},
						TypeE = {
							fields = {
								e = {
									read = function(self, existing: string)
										return Array.slice(existing, 2)
									end,
									merge = function(self, existing: string, incoming: string)
										return "*" .. tostring(incoming)
									end,
								},
							},
						},
						TypeF = { fields = { f = {} } },
						Query = {
							fields = {
								types = function(self, existing: Array<any>, ref)
									local args = ref.args
									local fromCode = string.byte((args :: any).from)
									local toCode = string.byte((args :: any).to)
									local e = 0
									for code = fromCode, toCode, 1 do
										local upper = string.upper(string.char(code))
										local obj = existing[e]
										e += 1

										jestExpect(obj.__typename).toBe("Type" .. upper)
									end
									return existing
								end,
							},
						},
					},
				})

				local query = gql([[
		
				query {
				  types(from: "A", to: "F") {
					... on TypeA { a }
					... on TypeB { b(x: 1, y: 2, z: 3) }
					... on TypeC { c(see: "si") }
					... on TypeD { d }
					... on TypeE { e(eee: "ee") }
					... on TypeF { f(g: "h") }
				  }
				}
			  ]])

				cache:writeQuery({
					query = query,
					data = {
						types = {
							{ __typename = "TypeA" },
							{ __typename = "TypeB", b = "x1" },
							{ __typename = "TypeC", c = "naive" },
							{ __typename = "TypeD", d = "quiet" },
							{ __typename = "TypeE", e = "asterisk" },
							{ __typename = "TypeF", f = "effigy" },
						},
					},
				})

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						['types({"from":"A","to":"F"})'] = {
							{ __typename = "TypeA" },
							{ __typename = "TypeB", ['b:{"x":1}'] = "x1" },
							{ __typename = "TypeC", c = "evian" },
							{ __typename = "TypeD", d = "QUIET" },
							{ __typename = "TypeE", e = "*asterisk" },
							{ __typename = "TypeF", ['f({"g":"h"})'] = "effigy" },
						},
					},
				})

				local result = cache:readQuery({ query = query })

				jestExpect(result).toEqual({
					types = {
						{ __typename = "TypeA", a = "a" },
						{ __typename = "TypeB", b = "b" },
						{ __typename = "TypeC", c = "evian" },
						{ __typename = "TypeD", d = "quiet" },
						{ __typename = "TypeE", e = "asterisk" },
						{ __typename = "TypeF", f = "effigy" },
					},
				})
			end)

			-- ROBLOX TODO: fragments are not supported yet
			xit("can include optional arguments in keyArgs", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Author = {
							keyFields = { "name" },
							fields = { writings = { keyArgs = { "a", "b", "type" } } },
						},
					},
				})

				local data = {
					author = {
						__typename = "Author",
						name = "Nadia Eghbal",
						writings = {
							{
								__typename = "Book",
								isbn = "0578675862",
								title = "Working in Public: The Making and Maintenance of " .. "Open Source Software",
							},
						},
					},
				}

				local function check(query: DocumentNode | TypedDocumentNode<TData_, TVars_>, variables: TVars_?)
					cache:writeQuery({ query = query, variables = variables, data = data })
					jestExpect(cache:readQuery({ query = query, variables = variables })).toEqual(data)
				end

				check(gql([[
		
				query {
				  author {
					name
					writings(type: "Book") {
					  ... on Book {
						title
						isbn
					  }
					}
				  }
				}
			  ]]))

				jestExpect(cache:extract()).toMatchSnapshot()

				check(gql([[
		
				query {
				  author {
					name
					writings(type: "Book", b: 2, a: 1) {
					  ... on Book {
						title
						isbn
					  }
					}
				  }
				}
			  ]]))

				jestExpect(cache:extract()).toMatchSnapshot()

				check(gql([[
		
				query {
				  author {
					name
					writings(b: 2, a: 1) {
					  ... on Book {
						title
						isbn
					  }
					}
				  }
				}
			  ]]))

				jestExpect(cache:extract()).toMatchSnapshot()

				check(gql([[
		
				query {
				  author {
					name
					writings(b: 2) {
					  ... on Book {
						title
						isbn
					  }
					}
				  }
				}
			  ]]))

				jestExpect(cache:extract()).toMatchSnapshot()

				check(gql([[
		
				query {
				  author {
					name
					writings(a: 3) {
					  ... on Book {
						title
						isbn
					  }
					}
				  }
				}
			  ]]))

				jestExpect(cache:extract()).toMatchSnapshot()

				check(gql([[
		
				query {
				  author {
					name
					writings(unrelated: "oyez") {
					  ... on Book {
						title
						isbn
					  }
					}
				  }
				}
			  ]]))

				jestExpect(cache:extract()).toMatchSnapshot()

				check(
					gql([[
		
				query AuthorWritings ($type: String) {
				  author {
					name
					writings(b: 4, type: $type, unrelated: "oyez") {
					  ... on Book {
						title
						isbn
					  }
					}
				  }
				}
			  ]]),
					{ type = nil :: any }
				)

				jestExpect(cache:extract()).toMatchSnapshot()

				check(gql([[
		
				query {
				  author {
					name
					writings {
					  ... on Book {
						title
						isbn
					  }
					}
				  }
				}
			  ]]))

				jestExpect(cache:extract()).toMatchSnapshot()

				local storeFieldNames: Array<string> = {}

				cache:modify({
					id = cache:identify({ __typename = "Author", name = "Nadia Eghbal" }),
					fields = {
						writings = function(self, value, ref)
							local storeFieldName = ref.storeFieldName
							table.insert(storeFieldNames, storeFieldName)
							jestExpect(value).toEqual(data.author.writings)
							return value
						end,
					},
				})

				jestExpect(Array.sort(storeFieldNames)).toEqual({
					"writings",
					'writings:{"a":1,"b":2,"type":"Book"}',
					'writings:{"a":1,"b":2}',
					'writings:{"a":3}',
					'writings:{"b":2}',
					'writings:{"b":4}',
					'writings:{"type":"Book"}',
					"writings:{}",
				})
			end)

			it("can return KeySpecifier arrays from keyArgs functions", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Thread = {
							keyFields = { "tid" },
							fields = {
								comments = {
									keyArgs = function(args, context)
										jestExpect(context.typename).toBe("Thread")
										jestExpect(context.fieldName).toBe("comments")
										jestExpect((context.field :: any).name.value).toBe("comments")
										jestExpect(context.variables).toEqual({ unused = "check me" })
										if typeof((args :: any).limit) == "number" then
											if typeof((args :: any).offset) == "number" then
												jestExpect(args).toEqual({ offset = 0, limit = 2 })
												return { "offset", "limit" }
											end
											if Boolean.toJSBoolean((args :: any).beforeId) then
												jestExpect(args).toEqual({ beforeId = "asdf", limit = 2 })
												return { "beforeId", "limit" }
											end
										end
										return nil
									end,
								},
							},
						},
						Comment = { keyFields = { "author", { "name" } } },
					},
				})

				local query = gql([[
		
				query {
				  thread {
					tid
					offsetComments: comments(offset: 0, limit: 2) {
					  author { name }
					}
					beforeIdComments: comments(beforeId: "asdf", limit: 2) {
					  author { name }
					}
				  }
				}
			  ]])

				cache:writeQuery({
					query = query,
					data = {
						thread = {
							__typename = "Thread",
							tid = "12345",
							offsetComments = {
								{ __typename = "Comment", author = { name = "Alice" } },
								{ __typename = "Comment", author = { name = "Bobby" } },
							},
							beforeIdComments = {
								{ __typename = "Comment", author = { name = "Calvin" } },
								{ __typename = "Comment", author = { name = "Hobbes" } },
							},
						},
					},
					variables = { unused = "check me" },
				})

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", thread = { __ref = 'Thread:{"tid":"12345"}' } },
					['Thread:{"tid":"12345"}'] = {
						__typename = "Thread",
						tid = "12345",
						['comments:{"beforeId":"asdf","limit":2}'] = {
							{ __ref = 'Comment:{"author":{"name":"Calvin"}}' },
							{ __ref = 'Comment:{"author":{"name":"Hobbes"}}' },
						},
						['comments:{"offset":0,"limit":2}'] = {
							{ __ref = 'Comment:{"author":{"name":"Alice"}}' },
							{ __ref = 'Comment:{"author":{"name":"Bobby"}}' },
						},
					},
					['Comment:{"author":{"name":"Alice"}}'] = { __typename = "Comment", author = { name = "Alice" } },
					['Comment:{"author":{"name":"Bobby"}}'] = { __typename = "Comment", author = { name = "Bobby" } },
					['Comment:{"author":{"name":"Calvin"}}'] = {
						__typename = "Comment",
						author = { name = "Calvin" },
					},
					['Comment:{"author":{"name":"Hobbes"}}'] = {
						__typename = "Comment",
						author = { name = "Hobbes" },
					},
				})
			end)

			it("can use options.storage in read functions", function()
				-- ROBLOX deviation: predefine function
				local compute

				local storageSet = Set.new()

				local cache = InMemoryCache.new({
					typePolicies = {
						Task = {
							fields = {
								result = function(_self, _existing, ref)
									local _args, storage = ref.args, ref.storage
									storageSet:add(storage)
									if Boolean.toJSBoolean(storage.result) then
										return storage.result
									end
									storage.result = compute()
									return storage.result
								end,
							},
						},
					},
				})

				local computeCount = 0

				function compute()
					return ("expensive result %s"):format((function()
						computeCount += 1
						return computeCount
					end)())
				end

				cache:writeQuery({
					query = gql([[
		
				  query {
					tasks {
					  id
					}
				  }
				]]),
					data = { tasks = { { __typename = "Task", id = 1 }, { __typename = "Task", id = 2 } } },
				})

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", tasks = { { __ref = "Task:1" }, { __ref = "Task:2" } } },
					["Task:1"] = { __typename = "Task", id = 1 },
					["Task:2"] = { __typename = "Task", id = 2 },
				})

				local result1 = cache:readQuery({
					query = gql([[
		
				  query {
					tasks {
					  result
					}
				  }
				]]),
				})

				jestExpect(result1).toEqual({
					tasks = {
						{ __typename = "Task", result = "expensive result 1" },
						{ __typename = "Task", result = "expensive result 2" },
					},
				})

				local result2 = cache:readQuery({
					query = gql([[
		
				  query {
					tasks {
					  id
					  result
					}
				  }
				]]),
				})

				jestExpect(result2).toEqual({
					tasks = {
						{ __typename = "Task", id = 1, result = "expensive result 1" },
						{ __typename = "Task", id = 2, result = "expensive result 2" },
					},
				})

				for _, storage in storageSet:ipairs() do
					storage.result = nil
				end

				local result3 = cache:readQuery({
					query = gql([[
		
				  query {
					tasks {
					  __typename
					  result
					}
				  }
				]]),
				})

				jestExpect(result3).toEqual({
					tasks = {
						{ __typename = "Task", result = "expensive result 3" },
						{ __typename = "Task", result = "expensive result 4" },
					},
				})
			end)

			it("can use read function to implement synthetic/computed keys", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Person = {
							keyFields = { "firstName", "lastName" },
							fields = {
								fullName = function(self, _, ref)
									local firstName = ref:readField("firstName")
									local lastName = ref:readField("lastName")
									return ("%s %s"):format(firstName, lastName)
								end,
							},
						},
					},
				})

				cache:writeQuery({
					query = gql([[
		
				  query {
					me {
					  firstName
					  lastName
					}
				  }
				]]),
					data = { me = { __typename = "Person", firstName = "Ben", lastName = "Newman" } },
				})

				local expectedExtraction = {
					ROOT_QUERY = {
						__typename = "Query",
						me = { __ref = 'Person:{"firstName":"Ben","lastName":"Newman"}' },
					},
					['Person:{"firstName":"Ben","lastName":"Newman"}'] = {
						__typename = "Person",
						firstName = "Ben",
						lastName = "Newman",
					},
				}

				jestExpect(cache:extract(true)).toEqual(expectedExtraction)

				local expectedResult = { me = { __typename = "Person", fullName = "Ben Newman" } }

				jestExpect(cache:readQuery({
					query = gql([[
		
				  query {
					me {
					  fullName
					}
				  }
				]]),
				})).toEqual(expectedResult)

				jestExpect(cache:readQuery({
					query = gql([[
		
				  query {
					me {
					  fullName @client
					}
				  }
				]]),
				})).toEqual(expectedResult)

				jestExpect(cache:extract(true)).toEqual(expectedExtraction)
			end)

			withErrorSpy(it, "read and merge can cooperate through options.storage", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Query = {
							fields = {
								jobs = {
									merge = function(self, existing: Array<any>?, incoming: Array<any>)
										if existing == nil then
											existing = {}
										end
										return Array.concat({}, existing, incoming)
									end,
								},
							},
						},
						Job = {
							keyFields = { "name" },
							fields = {
								result = {
									read = function(_self, _, ref)
										local storage = ref.storage
										if not Boolean.toJSBoolean(storage.jobName) then
											storage.jobName = makeVar(nil)
										end
										return storage.jobName()
									end,
									merge = function(self, _, incoming: string, ref)
										local storage = ref.storage
										if Boolean.toJSBoolean(storage.jobName) then
											storage.jobName(incoming)
										else
											storage.jobName = makeVar(incoming)
										end
									end,
								},
							},
						},
					},
				})

				local query = gql([[
		
				query {
				  jobs {
					name
					result
				  }
				}
			  ]])

				cache:writeQuery({
					query = query,
					data = {
						jobs = {
							{ __typename = "Job", name = "Job #1" },
							{ __typename = "Job", name = "Job #2" },
							{ __typename = "Job", name = "Job #3" },
						},
					},
				})

				local snapshot1 = {
					ROOT_QUERY = {
						__typename = "Query",
						jobs = {
							{ __ref = 'Job:{"name":"Job #1"}' },
							{ __ref = 'Job:{"name":"Job #2"}' },
							{ __ref = 'Job:{"name":"Job #3"}' },
						},
					},
					['Job:{"name":"Job #1"}'] = { __typename = "Job", name = "Job #1" },
					['Job:{"name":"Job #2"}'] = { __typename = "Job", name = "Job #2" },
					['Job:{"name":"Job #3"}'] = { __typename = "Job", name = "Job #3" },
				}

				jestExpect(cache:extract()).toEqual(snapshot1)

				local function makeMissingError(jobNumber: number)
					local err = MissingFieldError.new(
						('Can\'t find field \'result\' on Job:{"name":"Job #%s"} object'):format(tostring(jobNumber)),
						-- ROBLOX deviation: indexing in Lua starts from 1
						{ "jobs" :: any, jobNumber, "result" },
						jestExpect.anything(),
						jestExpect.anything()
					)
					-- ROBLOX deviation: assign jestExpect.anything() to avoid comparing stacks
					err.stack = jestExpect.anything()
					return err
				end

				jestExpect(cache:diff({ query = query, optimistic = false, returnPartialData = true })).toEqual({
					result = {
						jobs = {
							{ __typename = "Job", name = "Job #1" },
							{ __typename = "Job", name = "Job #2" },
							{ __typename = "Job", name = "Job #3" },
						},
					},
					complete = false,
					missing = { makeMissingError(1), makeMissingError(2), makeMissingError(3) },
				})

				-- ROBLOX TODO: fragments are not supported yet
				-- local function setResult(jobNum: number)
				-- 	cache:writeFragment({
				-- 		id = cache:identify({ __typename = "Job", name = ("Job #%s"):format(tostring(jobNum)) }) :: any,
				-- 		fragment = gql([[

				-- 	fragment JobResult on Job {
				-- 	  result
				-- 	}
				--   ]]),
				-- 		data = {
				-- 			__typename = "Job",
				-- 			name = ("Job #%s"):format(tostring(jobNum)),
				-- 			result = ("result for job %s"):format(tostring(jobNum)),
				-- 		},
				-- 	})
				-- end

				-- setResult(2)

				-- jestExpect(cache:extract()).toEqual(
				-- 	Object.assign({}, snapshot1, { __META = { extraRootIds = { 'Job:{"name":"Job #2"}' } } })
				-- )

				-- jestExpect(cache:diff({ query = query, optimistic = false, returnPartialData = true })).toEqual({

				-- 	result = {
				-- 		jobs = {
				-- 			{ __typename = "Job", name = "Job #1" },
				-- 			{ __typename = "Job", name = "Job #2", result = "result for job 2" },
				-- 			{ __typename = "Job", name = "Job #3" },
				-- 		},
				-- 	},
				-- 	complete = false,
				-- 	missing = { makeMissingError(1), makeMissingError(3) },
				-- })

				-- cache:writeQuery({
				-- 	query = query,
				-- 	data = { jobs = { { __typename = "Job", name = "Job #4", result = "result for job 4" } } },
				-- })

				-- local snapshot2 = Object.assign({}, snapshot1, {
				-- 	ROOT_QUERY = Object.assign({}, snapshot1.ROOT_QUERY, {
				-- 		jobs = Array.concat({}, snapshot1.ROOT_QUERY.jobs, { { __ref = 'Job:{"name":"Job #4"}' } }),
				-- 	}),
				-- 	['Job:{"name":"Job #4"}'] = { __typename = "Job", name = "Job #4" },
				-- })

				-- jestExpect(cache:extract()).toEqual(
				-- 	Object.assign({}, snapshot2, { __META = { extraRootIds = { 'Job:{"name":"Job #2"}' } } })
				-- )

				-- jestExpect(cache:diff({ query = query, optimistic = false, returnPartialData = true })).toEqual({
				-- 	result = {
				-- 		jobs = {
				-- 			{ __typename = "Job", name = "Job #1" },
				-- 			{ __typename = "Job", name = "Job #2", result = "result for job 2" },
				-- 			{ __typename = "Job", name = "Job #3" },
				-- 			{ __typename = "Job", name = "Job #4", result = "result for job 4" },
				-- 		},
				-- 	},
				-- 	complete = false,
				-- 	missing = { makeMissingError(1), makeMissingError(3) },
				-- })

				-- setResult(1)

				-- setResult(3)

				-- jestExpect(cache:diff({ query = query, optimistic = false, returnPartialData = true })).toEqual({
				-- 	result = {
				-- 		jobs = {
				-- 			{ __typename = "Job", name = "Job #1", result = "result for job 1" },
				-- 			{ __typename = "Job", name = "Job #2", result = "result for job 2" },
				-- 			{ __typename = "Job", name = "Job #3", result = "result for job 3" },
				-- 			{ __typename = "Job", name = "Job #4", result = "result for job 4" },
				-- 		},
				-- 	},
				-- 	complete = true,
				-- })

				-- jestExpect(cache:readQuery({ query = query })).toEqual({
				-- 	jobs = {
				-- 		{ __typename = "Job", name = "Job #1", result = "result for job 1" },
				-- 		{ __typename = "Job", name = "Job #2", result = "result for job 2" },
				-- 		{ __typename = "Job", name = "Job #3", result = "result for job 3" },
				-- 		{ __typename = "Job", name = "Job #4", result = "result for job 4" },
				-- 	},
				-- })
			end)

			it("read, merge, and modify functions can access options.storage", function()
				local storageByFieldName = Map.new()

				local function recordStorageOnce(fieldName: string, storage: StorageType)
					if storageByFieldName:has(fieldName) then
						jestExpect(storageByFieldName:get(fieldName)).toBe(storage)
					else
						storageByFieldName:set(fieldName, storage)
					end
				end

				local function makeFieldPolicy(): FieldPolicy<number, any, any>
					return {
						read = function(_self, existing: number?, ref)
							if existing == nil then
								existing = 0
							end
							local fieldName, storage = ref.fieldName, ref.storage
							storage.readCount = bit32.bor(storage.readCount or 0, 0) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
								+ 1
							recordStorageOnce(fieldName, storage)
							return existing
						end,
						merge = function(_self, existing: number?, incoming, ref)
							if existing == nil then
								existing = 0
							end
							local fieldName, storage = ref.fieldName, ref.storage
							storage.mergeCount = bit32.bor(storage.mergeCount or 0, 0) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
								+ 1
							recordStorageOnce(fieldName, storage)
							return existing + incoming
						end,
					}
				end

				local cache = InMemoryCache.new({
					typePolicies = {
						Query = {
							fields = {
								mergeRead = makeFieldPolicy(),
								mergeModify = makeFieldPolicy(),
								mergeReadModify = makeFieldPolicy(),
							},
						},
					},
				})

				local query: TypedDocumentNode<{ mergeRead: number, mergeModify: number, mergeReadModify: number }, any> =
					gql(
						[[
		
				query {
				  mergeRead
				  mergeModify
				  mergeReadModify
				}
			  ]]
					)

				cache:writeQuery({ query = query, data = { mergeRead = 1, mergeModify = 10, mergeReadModify = 100 } })

				jestExpect(storageByFieldName:get("mergeRead")).toEqual({ mergeCount = 1 })

				jestExpect(storageByFieldName:get("mergeModify")).toEqual({ mergeCount = 1 })

				jestExpect(storageByFieldName:get("mergeReadModify")).toEqual({ mergeCount = 1 })

				jestExpect(cache:readQuery({ query = gql("query { mergeRead mergeReadModify }") })).toEqual({
					mergeRead = 1,
					mergeReadModify = 100,
				})

				jestExpect(storageByFieldName:get("mergeRead")).toEqual({ mergeCount = 1, readCount = 1 })

				jestExpect(storageByFieldName:get("mergeModify")).toEqual({ mergeCount = 1 })

				jestExpect(storageByFieldName:get("mergeReadModify")).toEqual({ mergeCount = 1, readCount = 1 })

				jestExpect(cache:modify({
					fields = {
						mergeModify = function(self, value, ref)
							local fieldName, storage = ref.fieldName, ref.storage
							storage.modifyCount = bit32.bor(storage.modifyCount or 0, 0) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
								+ 1
							recordStorageOnce(fieldName, storage)
							return value + 1
						end,
						mergeReadModify = function(self, value, ref)
							local fieldName, storage = ref.fieldName, ref.storage
							storage.modifyCount = bit32.bor(storage.modifyCount or 0, 0) --[[ ROBLOX CHECK: `bit32.bor` clamps arguments and result to [0,2^32 - 1] ]]
								+ 1
							recordStorageOnce(fieldName, storage)
							return value + 1
						end,
					},
				})).toBe(true)

				-- replace when snapshot tests are in place
				cache:extract()
				-- jestExpect(cache:extract()).toMatchSnapshot()

				jestExpect(storageByFieldName:get("mergeRead")).toEqual({ mergeCount = 1, readCount = 1 })

				jestExpect(storageByFieldName:get("mergeModify")).toEqual({ mergeCount = 1, modifyCount = 1 })

				jestExpect(storageByFieldName:get("mergeReadModify")).toEqual({
					mergeCount = 1,
					readCount = 1,
					modifyCount = 1,
				})

				jestExpect(cache:readQuery({ query = query })).toEqual({
					mergeRead = 1,
					mergeModify = 11,
					mergeReadModify = 101,
				})

				jestExpect(storageByFieldName:get("mergeRead")).toEqual({ mergeCount = 1, readCount = 2 })

				jestExpect(storageByFieldName:get("mergeModify")).toEqual({
					mergeCount = 1,
					modifyCount = 1,
					readCount = 1,
				})

				jestExpect(storageByFieldName:get("mergeReadModify")).toEqual({
					mergeCount = 1,
					readCount = 2,
					modifyCount = 1,
				})

				-- jestExpect(cache:extract()).toMatchSnapshot()
			end)

			it("merge functions can deduplicate items using readField", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Query = {
							fields = {
								books = {
									merge = function(self, existing: Array<any>?, incoming: Array<any>, ref)
										if existing == nil then
											existing = {}
										end
										if Boolean.toJSBoolean(existing) then
											local merged = Array.slice(existing, 1)
											local existingIsbnSet = Set.new(Array.map(merged, function(book)
												return ref:readField("isbn", book)
											end))
											Array.forEach(incoming, function(book)
												local isbn = ref:readField("isbn", book)
												if not Boolean.toJSBoolean(existingIsbnSet:has(isbn)) then
													existingIsbnSet:add(isbn)
													table.insert(merged, book)
												end
											end)
											return merged
										end
										return incoming
									end,
									read = function(self, existing: Array<any>, ref)
										if Boolean.toJSBoolean(existing) then
											return Array.sort(Array.slice(existing, 1), function(a, b)
												local aTitle = ref:readField("title", a)
												local bTitle = ref:readField("title", b)
												if aTitle == bTitle then
													return 0
												end
												if (aTitle :: any) < (bTitle :: any) then
													return -1
												end
												return 1
											end)
										end
										return {}
									end,
								},
							},
						},
						Book = { keyFields = { "isbn" } },
					},
				})

				local query = gql([[
		
				query {
				  books {
					isbn
					title
				  }
				}
			  ]])

				local programmingRustBook = {
					__typename = "Book",
					isbn = "9781491927281",
					title = "Programming Rust: Fast, Safe Systems Development",
				}

				local officialRustBook = {
					__typename = "Book",
					isbn = "1593278284",
					title = "The Rust Programming Language",
				}

				local handsOnConcurrencyBook = {
					__typename = "Book",
					isbn = "1788399978",
					title = "Hands-On Concurrency with Rust",
				}

				local wasmWithRustBook = {
					__typename = "Book",
					isbn = "1680506366",
					title = "Programming WebAssembly with Rust",
				}

				local function addBooks(...)
					local books = { ... }
					cache:writeQuery({ query = query, data = { books = books } })
				end

				addBooks(officialRustBook)

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", books = { { __ref = 'Book:{"isbn":"1593278284"}' } } },
					['Book:{"isbn":"1593278284"}'] = {
						__typename = "Book",
						isbn = "1593278284",
						title = "The Rust Programming Language",
					},
				})

				addBooks(programmingRustBook, officialRustBook)

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						books = {
							{ __ref = 'Book:{"isbn":"1593278284"}' },
							{ __ref = 'Book:{"isbn":"9781491927281"}' },
						},
					},
					['Book:{"isbn":"1593278284"}'] = officialRustBook,
					['Book:{"isbn":"9781491927281"}'] = programmingRustBook,
				})

				addBooks(wasmWithRustBook, wasmWithRustBook, programmingRustBook, wasmWithRustBook)

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						books = {
							{ __ref = 'Book:{"isbn":"1593278284"}' },
							{ __ref = 'Book:{"isbn":"9781491927281"}' },
							{ __ref = 'Book:{"isbn":"1680506366"}' },
						},
					},
					['Book:{"isbn":"1593278284"}'] = officialRustBook,
					['Book:{"isbn":"9781491927281"}'] = programmingRustBook,
					['Book:{"isbn":"1680506366"}'] = wasmWithRustBook,
				})

				addBooks(programmingRustBook, officialRustBook, handsOnConcurrencyBook, wasmWithRustBook)

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						books = {
							{ __ref = 'Book:{"isbn":"1593278284"}' },
							{ __ref = 'Book:{"isbn":"9781491927281"}' },
							{ __ref = 'Book:{"isbn":"1680506366"}' },
							{ __ref = 'Book:{"isbn":"1788399978"}' },
						},
					},
					['Book:{"isbn":"1593278284"}'] = officialRustBook,
					['Book:{"isbn":"9781491927281"}'] = programmingRustBook,
					['Book:{"isbn":"1680506366"}'] = wasmWithRustBook,
					['Book:{"isbn":"1788399978"}'] = handsOnConcurrencyBook,
				})

				jestExpect(cache:readQuery({ query = query })).toEqual({
					["books"] = {
						{
							["__typename"] = "Book",
							["isbn"] = "1788399978",
							["title"] = "Hands-On Concurrency with Rust",
						},
						{
							["__typename"] = "Book",
							["isbn"] = "9781491927281",
							["title"] = "Programming Rust: Fast, Safe Systems Development",
						},
						{
							["__typename"] = "Book",
							["isbn"] = "1680506366",
							["title"] = "Programming WebAssembly with Rust",
						},
						{
							["__typename"] = "Book",
							["isbn"] = "1593278284",
							["title"] = "The Rust Programming Language",
						},
					},
				})
			end)

			withErrorSpy(it, "readField helper function calls custom read functions", function()
				local ownTimes: Record<string, ReactiveVar<number>> = {
					["parent task"] = makeVar(2),
					["child task 1"] = makeVar(3),
					["child task 2"] = makeVar(4),
					["grandchild task"] = makeVar(5),
					["independent task"] = makeVar(11),
				}

				local cache = InMemoryCache.new({
					typePolicies = {
						Agenda = {
							fields = {
								taskCount = function(_self, _, ref)
									return #(ref:readField("tasks") :: any)
								end,
								tasks = {
									-- Thanks to this read function, the readField("tasks")
									-- call above will always return an array, so we don't
									-- have to guard against the possibility that the tasks
									-- data is undefined above.
									read = function(_self, existing: Array<any>?)
										if existing == nil then
											existing = {}
										end
										return existing
									end,
									merge = function(_self, existing: Array<Reference>, incoming: Array<Reference>)
										local merged = (function()
											if Boolean.toJSBoolean(existing) then
												return Array.slice(existing, 1)
											else
												return {}
											end
										end)()
										for _, ref in ipairs(incoming) do
											table.insert(merged, ref)
										end
										return merged
									end,
								},
							},
						},
						Task = {
							fields = {
								ownTime = function(_self, _, ref)
									local description: string = ref:readField("description")
									local ref_ = (ownTimes[description] :: any)()
									return Boolean.toJSBoolean(ref_) and ref_ or 0
								end,
								totalTime = function(_self, _, ref)
									local function total(
										blockers: Array<Reference>? --[[Readonly]],
										seen: any?
									)
										if blockers == nil then
											blockers = {}
										end
										if seen == nil then
											seen = Set.new()
										end
										local time = 0
										Array.forEach(blockers, function(blocker)
											if not (seen :: any):has(blocker.__ref) then
												(seen :: any):add(blocker.__ref)
												time += ref:readField("ownTime", blocker) :: any
												time += total(ref:readField("blockers", blocker), seen)
											end
										end)
										return time
									end
									return total({
										ref:toReference({ __typename = "Task", id = ref:readField("id") }) :: Reference,
									})
								end,
								blockers = {
									merge = function(_self, existing: Array<Reference>?, incoming: Array<Reference>)
										if existing == nil then
											existing = {}
										end
										local seenIDs = Set.new(Array.map(existing, function(ref)
											return ref.__ref
										end))
										local merged = Array.slice(existing, 1)
										Array.forEach(incoming, function(ref)
											if not seenIDs:has(ref.__ref) then
												seenIDs:add(ref.__ref)
												table.insert(merged, ref)
											end
										end)
										return merged
									end,
								},
							},
						},
					},
				})

				cache:writeQuery({
					query = gql([[
		
				  query {
					agenda {
					  id
					  tasks {
						id
						description
						blockers {
						  id
						}
					  }
					}
				  }
				]]),
					data = {
						agenda = {
							__typename = "Agenda",
							id = 1,
							tasks = {
								{
									__typename = "Task",
									id = 1,
									description = "parent task",
									blockers = { { __typename = "Task", id = 2 }, { __typename = "Task", id = 3 } },
								},
								{
									__typename = "Task",
									id = 2,
									description = "child task 1",
									blockers = { { __typename = "Task", id = 4 } },
								},
								{
									__typename = "Task",
									id = 3,
									description = "child task 2",
									blockers = { { __typename = "Task", id = 4 } },
								},
								{ __typename = "Task", id = 4, description = "grandchild task" },
							},
						},
					},
				})

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", agenda = { __ref = "Agenda:1" } },
					["Agenda:1"] = {
						__typename = "Agenda",
						id = 1,
						tasks = {
							{ __ref = "Task:1" },
							{ __ref = "Task:2" },
							{ __ref = "Task:3" },
							{ __ref = "Task:4" },
						},
					},
					["Task:1"] = {
						__typename = "Task",
						blockers = { { __ref = "Task:2" }, { __ref = "Task:3" } },
						description = "parent task",
						id = 1,
					},
					["Task:2"] = {
						__typename = "Task",
						blockers = { { __ref = "Task:4" } },
						description = "child task 1",
						id = 2,
					},
					["Task:3"] = {
						__typename = "Task",
						blockers = { { __ref = "Task:4" } },
						description = "child task 2",
						id = 3,
					},
					["Task:4"] = { __typename = "Task", description = "grandchild task", id = 4 },
				})

				local query = gql([[
		
				query {
				  agenda {
					taskCount
					tasks {
					  description
					  ownTime
					  totalTime
					}
				  }
				}
			  ]])

				local function read(): { agenda: any } | nil
					return cache:readQuery({ query = query })
				end

				local firstResult = read()

				jestExpect(firstResult).toEqual({
					agenda = {
						__typename = "Agenda",
						taskCount = 4,
						tasks = {
							{
								__typename = "Task",
								description = "parent task",
								ownTime = 2,
								totalTime = 2 + 3 + 4 + 5,
							},
							{ __typename = "Task", description = "child task 1", ownTime = 3, totalTime = 3 + 5 },
							{ __typename = "Task", description = "child task 2", ownTime = 4, totalTime = 4 + 5 },
							{ __typename = "Task", description = "grandchild task", ownTime = 5, totalTime = 5 },
						},
					},
				})

				jestExpect(read()).toBe(firstResult);

				(ownTimes["child task 2"] :: any)(6)

				local secondResult = read()

				jestExpect(secondResult).never.toBe(firstResult)

				jestExpect(secondResult).toEqual({
					agenda = {
						__typename = "Agenda",
						taskCount = 4,
						tasks = {
							{
								__typename = "Task",
								description = "parent task",
								ownTime = 2,
								totalTime = 2 + 3 + 6 + 5,
							},
							{ __typename = "Task", description = "child task 1", ownTime = 3, totalTime = 3 + 5 },
							{ __typename = "Task", description = "child task 2", ownTime = 6, totalTime = 6 + 5 },
							{ __typename = "Task", description = "grandchild task", ownTime = 5, totalTime = 5 },
						},
					},
				})

				jestExpect((secondResult :: any).agenda.tasks[1]).never.toBe((firstResult :: any).agenda.tasks[1])

				jestExpect((secondResult :: any).agenda.tasks[2]).toBe((firstResult :: any).agenda.tasks[2])

				jestExpect((secondResult :: any).agenda.tasks[3]).never.toBe((firstResult :: any).agenda.tasks[3])

				jestExpect((secondResult :: any).agenda.tasks[4]).toBe((firstResult :: any).agenda.tasks[4]);

				(ownTimes["grandchild task"] :: any)(7)

				local thirdResult = read()

				jestExpect(thirdResult).never.toBe(secondResult)

				jestExpect(thirdResult).toEqual({
					agenda = {
						__typename = "Agenda",
						taskCount = 4,
						tasks = {
							{
								__typename = "Task",
								description = "parent task",
								ownTime = 2,
								totalTime = 2 + 3 + 6 + 7,
							},
							{ __typename = "Task", description = "child task 1", ownTime = 3, totalTime = 3 + 7 },
							{ __typename = "Task", description = "child task 2", ownTime = 6, totalTime = 6 + 7 },
							{ __typename = "Task", description = "grandchild task", ownTime = 7, totalTime = 7 },
						},
					},
				})

				cache:writeQuery({
					query = gql([[
		
				  query {
					agenda {
					  id
					  tasks {
						id
						description
					  }
					}
				  }
				]]),
					data = {
						agenda = {
							__typename = "Agenda",
							id = 1,
							tasks = { { __typename = "Task", id = 5, description = "independent task" } },
						},
					},
				})

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", agenda = { __ref = "Agenda:1" } },
					["Agenda:1"] = {
						__typename = "Agenda",
						id = 1,
						tasks = {
							{ __ref = "Task:1" },
							{ __ref = "Task:2" },
							{ __ref = "Task:3" },
							{ __ref = "Task:4" },
							{ __ref = "Task:5" },
						},
					},
					["Task:1"] = {
						__typename = "Task",
						blockers = { { __ref = "Task:2" }, { __ref = "Task:3" } },
						description = "parent task",
						id = 1,
					},
					["Task:2"] = {
						__typename = "Task",
						blockers = { { __ref = "Task:4" } },
						description = "child task 1",
						id = 2,
					},
					["Task:3"] = {
						__typename = "Task",
						blockers = { { __ref = "Task:4" } },
						description = "child task 2",
						id = 3,
					},
					["Task:4"] = { __typename = "Task", description = "grandchild task", id = 4 },
					["Task:5"] = { __typename = "Task", description = "independent task", id = 5 },
				})

				local fourthResult = read()

				jestExpect(fourthResult).never.toBe(thirdResult)

				jestExpect(fourthResult).toEqual({
					agenda = {
						__typename = "Agenda",
						taskCount = 5,
						tasks = {
							{
								__typename = "Task",
								description = "parent task",
								ownTime = 2,
								totalTime = 2 + 3 + 6 + 7,
							},
							{ __typename = "Task", description = "child task 1", ownTime = 3, totalTime = 3 + 7 },
							{ __typename = "Task", description = "child task 2", ownTime = 6, totalTime = 6 + 7 },
							{ __typename = "Task", description = "grandchild task", ownTime = 7, totalTime = 7 },
							{ __typename = "Task", description = "independent task", ownTime = 11, totalTime = 11 },
						},
					},
				})

				local function checkFirstFourIdentical(
					result: ReturnType<any --[[ ROBLOX TODO: Unhandled node for type: TSTypeQuery ]] --[[ typeof read ]]>
				)
					for i = 1, 4, 1 do
						jestExpect(result.agenda.tasks[i]).toBe(thirdResult.agenda.tasks[i])
					end
				end

				checkFirstFourIdentical(fourthResult)

				local indVar = ownTimes["independent task"]

				indVar(indVar() + 1)

				local fifthResult = read()

				jestExpect(fifthResult).never.toBe(fourthResult)

				jestExpect(fifthResult).toEqual({
					agenda = {
						__typename = "Agenda",
						taskCount = 5,
						tasks = {
							(fourthResult :: any).agenda.tasks[1],
							(fourthResult :: any).agenda.tasks[2],
							(fourthResult :: any).agenda.tasks[3],
							(fourthResult :: any).agenda.tasks[4],
							{ __typename = "Task", description = "independent task", ownTime = 12, totalTime = 12 },
						},
					},
				})

				checkFirstFourIdentical(fifthResult)
			end)

			it("can return void to indicate missing field", function()
				local secretReadAttempted = false

				local cache = InMemoryCache.new({
					typePolicies = {
						Person = {
							fields = {
								secret = function(self)
									secretReadAttempted = true
								end,
							},
						},
					},
				})

				local query = gql([[
		
				query {
				  me {
					name
				  }
				}
			  ]])

				cache:writeQuery({ query = query, data = { me = { __typename = "Person", name = "Ben Newman" } } })

				jestExpect(secretReadAttempted).toBe(false)

				jestExpect(cache:readQuery({
					query = gql([[
		
				  query {
					me {
					  secret
					}
				  }
				]]),
				})).toBe(NULL)

				jestExpect(function()
					return cache:diff({
						optimistic = true,
						returnPartialData = false,
						query = gql([[
		
				  query {
					me {
					  secret
					}
				  }
				]]),
					})
				end).toThrowError("Can't find field 'secret' ")

				jestExpect(secretReadAttempted).toBe(true)
			end)

			it("can define custom merge functions", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Person = {
							-- Disables normalization for the Person type, which means the
							-- todos field will be nested inside a non-normalized object
							-- (with __typename "Person") directly under the ROOT_QUERY.me
							-- field, which exercises what happens when mergeOverrides
							-- becomes nested (see writeToStore.ts).
							keyFields = false,
							fields = {
								todos = {
									keyArgs = {},
									read = function(_self, existing: Array<any>, ref_)
										local args = ref_.args
										jestExpect(not Boolean.toJSBoolean(existing) or Object.isFrozen(existing)).toBe(
											true
										)
										jestExpect(typeof(ref_.toReference)).toBe("function")
										local slice = Array.slice(
											existing,
											-- ROBLOX deviation START: adjust indexes to work with Lua indexing
											(args :: any).offset + 1,
											(args :: any).offset + (args :: any).limit + 1
											-- ROBLOX deviation END
										)
										Array.forEach(slice, function(ref)
											return jestExpect(ref_:isReference(ref)).toBe(true)
										end)
										return slice
									end,
									merge = function(_self, existing: Array<any>, incoming: Array<any>, ref)
										local args = ref.args
										jestExpect(not Boolean.toJSBoolean(existing) or Object.isFrozen(existing)).toBe(
											true
										)
										jestExpect(typeof(ref.toReference)).toBe("function")
										local copy = (function()
											if Boolean.toJSBoolean(existing) then
												return Array.slice(existing, 1)
											else
												return {}
											end
										end)()
										local limit = (args :: any).offset + (args :: any).limit
										-- ROBLOX deviation: adjust indexes to work with Lua indexing
										for i = args.offset + 1, limit do
											copy[i] = incoming[i - args.offset]
										end
										-- ROBLOX deviation START: fill in missing elements so that sparse arrays work
										for i = #copy + 1, args.offset do
											copy[i] = nil
										end
										-- ROBLOX deviation END
										Array.forEach(copy, function(todo)
											-- ROBLOX deviation: since an array may be sparse we allow for `nil` values. In JS they would be omitted.
											return jestExpect(todo == nil or ref:isReference(todo)).toBe(true)
										end)
										return copy
									end,
								},
							},
						},
						Todo = { keyFields = { "id" } },
					},
				})

				local query = gql([[
		
				query {
				  me {
					todos(offset: $offset, limit: $limit) {
					  text
					}
				  }
				}
			  ]])

				cache:writeQuery({
					query = query,
					data = {
						me = {
							__typename = "Person",
							id = "ignored",
							todos = {
								{ __typename = "Todo", id = 1, text = "Write more merge tests" },
								{ __typename = "Todo", id = 2, text = "Write pagination tests" },
							},
						},
					},
					variables = { offset = 0, limit = 2 },
				})

				jestExpect(cache:extract(true)).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						me = {
							__typename = "Person",
							-- ROBLOX deviation: empty object is stringified to `[]`
							["todos:[]"] = { { __ref = 'Todo:{"id":1}' }, { __ref = 'Todo:{"id":2}' } },
						},
					},
					['Todo:{"id":1}'] = { __typename = "Todo", id = 1, text = "Write more merge tests" },
					['Todo:{"id":2}'] = { __typename = "Todo", id = 2, text = "Write pagination tests" },
				})

				cache:writeQuery({
					query = query,
					data = {
						me = {
							__typename = "Person",
							todos = {
								{ __typename = "Todo", id = 5, text = "Submit pull request" },
								{ __typename = "Todo", id = 6, text = "Merge pull request" },
							},
						},
					},
					variables = { offset = 4, limit = 2 },
				})

				jestExpect(cache:extract(true)).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						me = {
							__typename = "Person",
							-- ROBLOX deviation: empty object is stringified to `[]`
							["todos:[]"] = {
								{ __ref = 'Todo:{"id":1}' },
								{ __ref = 'Todo:{"id":2}' },
								nil,
								nil,
								{ __ref = 'Todo:{"id":5}' },
								{ __ref = 'Todo:{"id":6}' },
							},
						},
					},
					['Todo:{"id":1}'] = { __typename = "Todo", id = 1, text = "Write more merge tests" },
					['Todo:{"id":2}'] = { __typename = "Todo", id = 2, text = "Write pagination tests" },
					['Todo:{"id":5}'] = { __typename = "Todo", id = 5, text = "Submit pull request" },
					['Todo:{"id":6}'] = { __typename = "Todo", id = 6, text = "Merge pull request" },
				})

				cache:writeQuery({
					query = query,
					data = {
						me = {
							__typename = "Person",
							todos = {
								{ __typename = "Todo", id = 3, text = "Iron out merge API" },
								{ __typename = "Todo", id = 4, text = "Take a nap" },
							},
						},
					},
					variables = { offset = 2, limit = 2 },
				})

				jestExpect(cache:extract(true)).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						me = {
							__typename = "Person",
							-- ROBLOX deviation: empty object is stringified to `[]`
							["todos:[]"] = {
								{ __ref = 'Todo:{"id":1}' },
								{ __ref = 'Todo:{"id":2}' },
								{ __ref = 'Todo:{"id":3}' },
								{ __ref = 'Todo:{"id":4}' },
								{ __ref = 'Todo:{"id":5}' },
								{ __ref = 'Todo:{"id":6}' },
							},
						},
					},
					['Todo:{"id":1}'] = { __typename = "Todo", id = 1, text = "Write more merge tests" },
					['Todo:{"id":2}'] = { __typename = "Todo", id = 2, text = "Write pagination tests" },
					['Todo:{"id":3}'] = { __typename = "Todo", id = 3, text = "Iron out merge API" },
					['Todo:{"id":4}'] = { __typename = "Todo", id = 4, text = "Take a nap" },
					['Todo:{"id":5}'] = { __typename = "Todo", id = 5, text = "Submit pull request" },
					['Todo:{"id":6}'] = { __typename = "Todo", id = 6, text = "Merge pull request" },
				})

				jestExpect(cache:gc()).toEqual({})

				jestExpect(cache:readQuery({ query = query, variables = { offset = 1, limit = 4 } })).toEqual({
					me = {
						__typename = "Person",
						todos = {
							{ __typename = "Todo", text = "Write pagination tests" },
							{ __typename = "Todo", text = "Iron out merge API" },
							{ __typename = "Todo", text = "Take a nap" },
							{ __typename = "Todo", text = "Submit pull request" },
						},
					},
				})
			end)

			-- ROBLOX TODO: requires ApolloClient
			itAsync(xit)("can handle Relay-style pagination without args", function(resolve, reject)
				local cache = InMemoryCache.new({
					addTypename = false,
					typePolicies = { Query = { fields = { todos = relayStylePagination() } } },
				})

				local firstQuery = gql([[
		
				query TodoQuery {
				  todos {
					totalCount
				  }
				}
			  ]])

				local secondQuery = gql([[
		
				query TodoQuery {
				  todos(after: $after, first: $first) {
					pageInfo {
					  __typename
					  hasNextPage
					  endCursor
					}
					totalCount
					edges {
					  __typename
					  id
					  node {
						__typename
						id
						title
					  }
					}
				  }
				}
			  ]])

				local thirdQuery = gql([[
		
				query TodoQuery {
				  todos {
					totalCount
					extraMetaData
				  }
				}
			  ]])

				local secondVariables = { first = 1 }

				local secondEdges = {
					{
						__typename = "TodoEdge",
						id = "edge1",
						node = { __typename = "Todo", id = "1", title = "Fix the tests" },
					},
				}

				local secondPageInfo = {
					__typename = "PageInfo",
					endCursor = "YXJyYXljb25uZWN0aW9uOjI=",
					hasNextPage = true,
				}

				local link = MockLink.new({
					{ request = { query = firstQuery }, result = { data = { todos = { totalCount = 1292 } } } },
					{
						request = { query = secondQuery, variables = secondVariables },
						result = {
							data = { todos = { edges = secondEdges, pageInfo = secondPageInfo, totalCount = 1292 } },
						},
					},
					{
						request = { query = thirdQuery },
						result = { data = { todos = { totalCount = 1293, extraMetaData = "extra" } } },
					},
				}):setOnError(reject)

				local client = ApolloClient.new({ link = link, cache = cache })

				client:query({ query = firstQuery }):andThen(function(result)
					jestExpect(result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = { todos = { totalCount = 1292 } },
					})
					jestExpect(cache:extract()).toEqual({
						ROOT_QUERY = {
							__typename = "Query",
							todos = {
								edges = {},
								pageInfo = {
									["endCursor"] = "",
									["hasNextPage"] = true,
									["hasPreviousPage"] = false,
									["startCursor"] = "",
								},
								totalCount = 1292,
							},
						},
					})

					client:query({ query = secondQuery, variables = secondVariables }):andThen(function(result)
						jestExpect(result).toEqual({
							loading = false,
							networkStatus = NetworkStatus.ready,
							data = { todos = { edges = secondEdges, pageInfo = secondPageInfo, totalCount = 1292 } },
						})
						jestExpect(cache:extract()).toMatchSnapshot()

						client:query({ query = thirdQuery }):andThen(function(result)
							jestExpect(result).toEqual({
								loading = false,
								networkStatus = NetworkStatus.ready,
								data = { todos = { totalCount = 1293, extraMetaData = "extra" } },
							})
							jestExpect(cache:extract()).toMatchSnapshot()
							resolve()
						end)
					end)
				end)
			end)

			-- ROBLOX TODO: requires ApolloClient, subscribeAndCount
			itAsync(xit)("can handle Relay-style pagination", function(resolve, reject)
				local cache = InMemoryCache.new({
					addTypename = false,
					typePolicies = {
						Query = {
							fields = {
								search = relayStylePagination(function(args, ref)
									local fieldName = ref.fieldName
									jestExpect(typeof((args :: any).query)).toBe("string")
									jestExpect(fieldName).toBe("search")
									return string.lower((args :: any).query)
								end),
							},
						},
						Artist = { keyFields = { "href" } },
					},
				})

				local query = gql([[
		
				query ArtsySearch(
				  $query: String!,
				  $after: String, $first: Int,
				  $before: String, $last: Int,
				) {
				  search(
					query: $query,
					after: $after, first: $first,
					before: $before, last: $last,
				  ) {
					edges {
					  __typename
					  node {
						__typename
						displayLabel
						... on Artist { __typename href bio }
						... on SearchableItem { __typename description }
					  }
					}
					pageInfo {
					  __typename
					  startCursor
					  endCursor
					  hasPreviousPage
					  hasNextPage
					}
					totalCount
				  }
				}
			  ]])

				local firstVariables = { query = "Basquiat", first = 3 }

				local firstEdges = {
					{
						__typename = "SearchableEdge",
						node = {
							__typename = "Artist",
							href = "/artist/jean-michel-basquiat",
							displayLabel = "Jean-Michel Basquiat",
							bio = "American, 1960-1988, New York, New York, based in New York, New York",
						},
					},
					{
						__typename = "SearchableEdge",
						node = {
							displayLabel = "ephemera BASQUIAT",
							__typename = "SearchableItem",
							description = "Past show featuring works by Damien Hirst, "
								.. "James Rosenquist, David Salle, Andy Warhol, Jeff Koons, "
								.. "Jean-Michel Basquiat, Keith Haring, Kiki Smith, Sandro Chia, "
								.. "Kenny Scharf, Mike Bidlo, Jon Schueler, William Wegman, "
								.. "David Wojnarowicz, Taylor Mead, William S. Burroughs, "
								.. "Michael Halsband, Rene Ricard, and Chris DAZE Ellis",
						},
					},
					{
						__typename = "SearchableEdge",
						node = {
							displayLabel = "Jean-Michel Basquiat | Xerox",
							__typename = "SearchableItem",
							description = "Past show featuring works by Jean-Michel "
								.. "Basquiat at Nahmad Contemporary Mar 12th \u{2013} May 31st 2019",
						},
					},
				}

				local firstPageInfo = {
					__typename = "PageInfo",
					startCursor = "YXJyYXljb25uZWN0aW9uOjA=",
					endCursor = "YXJyYXljb25uZWN0aW9uOjI=",
					hasPreviousPage = false,
					hasNextPage = true,
				}

				local secondVariables = { query = "Basquiat", after = firstPageInfo.endCursor, first = 3 }

				local secondEdges = {
					{
						__typename = "SearchableEdge",
						node = {
							displayLabel = "STREET ART: From Basquiat to Banksy",
							__typename = "SearchableItem",
							description = "Past show featuring works by Banksy, SEEN, "
								.. "JonOne and QUIK at Artrust Oct 8th \u{2013} Dec 16th 2017",
						},
					},
					{
						__typename = "SearchableEdge",
						node = {
							__typename = "SearchableItem",
							displayLabel = "STREET ART 2: From Basquiat to Banksy",
							description = "Past show featuring works by Jean-Michel Basquiat, "
								.. "Shepard Fairey, COPE2, Pure Evil, Sickboy, Blade, "
								.. "Kurar, and LARS at Artrust",
						},
					},
					{
						__typename = "SearchableEdge",
						node = {
							__typename = "Artist",
							href = "/artist/reminiscent-of-basquiat",
							displayLabel = "Reminiscent of Basquiat",
							bio = "",
						},
					},
				}

				local secondPageInfo = {
					__typename = "PageInfo",
					startCursor = "YXJyYXljb25uZWN0aW9uOjM=",
					endCursor = "YXJyYXljb25uZWN0aW9uOjU=",
					hasPreviousPage = false,
					hasNextPage = true,
				}

				local thirdVariables = {
					query = "basquiat",
					before = secondPageInfo.startCursor,
					last = 2,
					after = nil,
					first = nil,
				}

				local thirdEdges = Array.slice(firstEdges, 2)

				local thirdPageInfo = {
					__typename = "PageInfo",
					startCursor = "YXJyYXljb25uZWN0aW9uOjE=",
					endCursor = "YXJyYXljb25uZWN0aW9uOjM=",
					hasPreviousPage = true,
					hasNextPage = true,
				}

				local fourthVariables = {
					query = "basquiat",
					before = thirdPageInfo.startCursor,
					last = 1,
					after = nil,
					first = nil,
				}

				local fourthEdges = Array.slice(firstEdges, 1, 2)

				local fourthPageInfo = {
					__typename = "PageInfo",
					startCursor = "YXJyYXljb25uZWN0aW9uOjA=",
					endCursor = "YXJyYXljb25uZWN0aW9uOjA=",
					hasPreviousPage = false,
					hasNextPage = true,
				}

				local fifthVariables = { query = "Basquiat", after = secondPageInfo.endCursor, first = 1 }

				local fifthEdges = {
					{
						__typename = "SearchableEdge",
						node = {
							__typename = "SearchableItem",
							displayLabel = "Basquiat: The Unknown Notebooks",
							description = "Past show featuring works by Jean-Michel Basquiat "
								.. "at Brooklyn Museum Apr 3rd \u{2013} Aug 23rd 2015",
						},
					},
				}

				local fifthPageInfo = {
					__typename = "PageInfo",
					startCursor = "YXJyYXljb25uZWN0aW9uOjY=",
					endCursor = "YXJyYXljb25uZWN0aW9uOjY=",
					hasPreviousPage = true,
					hasNextPage = true,
				}

				local turrellVariables1 = { query = "James Turrell", first = 1 }

				local turrellVariables2 = { query = "James Turrell", first = 2 }

				local turrellEdges = {
					{
						__typename = "SearchableEdge",
						node = {
							__typename = "Artist",
							href = "/artist/james-turrell",
							displayLabel = "James Turrell",
							bio = "American, born 1943, Los Angeles, California",
						},
					},
					{
						__typename = "SearchableEdge",
						node = {
							__typename = "SearchableItem",
							displayLabel = "James Turrell: Light knows when we\u{2019}re looking",
							description = "<placeholder for unknown description>",
						},
					},
				}

				local turrellPageInfo1 = {
					__typename = "PageInfo",
					startCursor = "YXJyYXljb25uZWN0aW9uOjA=",
					endCursor = "YXJyYXljb25uZWN0aW9uOjA=",
					hasPreviousPage = false,
					hasNextPage = true,
				}

				local turrellPageInfo2 = Object.assign({}, turrellPageInfo1, { endCursor = "YXJyYXljb25uZWN0aW9uOjEx" })

				local link = MockLink.new({
					{
						request = { query = query, variables = firstVariables },
						result = {
							data = { search = { edges = firstEdges, pageInfo = firstPageInfo, totalCount = 1292 } },
						},
					},
					{
						request = { query = query, variables = secondVariables },
						result = {
							data = { search = { edges = secondEdges, pageInfo = secondPageInfo, totalCount = 1292 } },
						},
					},
					{
						request = { query = query, variables = thirdVariables },
						result = {
							data = { search = { edges = thirdEdges, pageInfo = thirdPageInfo, totalCount = 1292 } },
						},
					},
					{
						request = { query = query, variables = fourthVariables },
						result = {
							data = { search = { edges = fourthEdges, pageInfo = fourthPageInfo, totalCount = 1292 } },
						},
					},
					{
						request = { query = query, variables = fifthVariables },
						result = {
							data = { search = { edges = fifthEdges, pageInfo = fifthPageInfo, totalCount = 1292 } },
						},
					},
					{
						request = { query = query, variables = turrellVariables1 },
						result = {
							data = {
								search = {
									edges = Array.slice(turrellEdges, 1, 2),
									pageInfo = turrellPageInfo1,
									totalCount = 13531,
								},
							},
						},
					},
					{
						request = { query = query, variables = turrellVariables2 },
						result = {
							data = {
								search = { edges = turrellEdges, pageInfo = turrellPageInfo2, totalCount = 13531 },
							},
						},
					},
				}):setOnError(reject)

				local client = ApolloClient.new({ link = link, cache = cache })

				local observable = client:watchQuery({ query = query, variables = { query = "Basquiat", first = 3 } })

				subscribeAndCount(reject, observable, function(count, result)
					if count == 1 then
						jestExpect(result).toEqual({
							loading = false,
							networkStatus = NetworkStatus.ready,
							data = { search = { edges = firstEdges, pageInfo = firstPageInfo, totalCount = 1292 } },
						})
						jestExpect(cache:extract()).toMatchSnapshot()
						observable:fetchMore({ variables = secondVariables })
					elseif count == 2 then
						jestExpect(result).toEqual({
							loading = false,
							networkStatus = NetworkStatus.ready,
							data = {
								search = {
									edges = Array.concat({}, firstEdges, secondEdges),
									pageInfo = {
										__typename = "PageInfo",
										startCursor = firstPageInfo.startCursor,
										endCursor = secondPageInfo.endCursor,
										hasPreviousPage = false,
										hasNextPage = true,
									},
									totalCount = 1292,
								},
							},
						})
						jestExpect(cache:extract()).toMatchSnapshot()
						observable:fetchMore({ variables = thirdVariables })
					elseif count == 3 then
						jestExpect(result.data.search.edges.length).toBe(5)
						jestExpect(result).toEqual({
							loading = false,
							networkStatus = NetworkStatus.ready,
							data = {
								search = {
									edges = Array.concat({}, thirdEdges, secondEdges),
									pageInfo = {
										__typename = "PageInfo",
										startCursor = thirdPageInfo.startCursor,
										endCursor = secondPageInfo.endCursor,
										hasPreviousPage = true,
										hasNextPage = true,
									},
									totalCount = 1292,
								},
							},
						})
						jestExpect(cache:extract()).toMatchSnapshot()
						observable:fetchMore({ variables = fourthVariables })
					elseif count == 4 then
						jestExpect(result).toEqual({
							loading = false,
							networkStatus = NetworkStatus.ready,
							data = {
								search = {
									edges = Array.concat({}, fourthEdges, thirdEdges, secondEdges),
									pageInfo = {
										__typename = "PageInfo",
										startCursor = firstPageInfo.startCursor,
										endCursor = secondPageInfo.endCursor,
										hasPreviousPage = false,
										hasNextPage = true,
									},
									totalCount = 1292,
								},
							},
						})
						jestExpect(result.data.search.edges).toEqual(Array.concat({}, firstEdges, secondEdges))
						jestExpect(cache:extract()).toMatchSnapshot()
						observable:fetchMore({ variables = fifthVariables })
					elseif count == 5 then
						jestExpect(result.data.search.edges.length).toBe(7)
						jestExpect(result).toEqual({
							loading = false,
							networkStatus = NetworkStatus.ready,
							data = {
								search = {
									edges = Array.concat({}, firstEdges, secondEdges, fifthEdges),
									pageInfo = {
										__typename = "PageInfo",
										startCursor = firstPageInfo.startCursor,
										endCursor = fifthPageInfo.endCursor,
										hasPreviousPage = false,
										hasNextPage = true,
									},
									totalCount = 1292,
								},
							},
						})
						jestExpect(cache:extract()).toMatchSnapshot()
						client
							:query({ query = query, variables = { query = "James Turrell", first = 1 } })
							:andThen(function(result)
								jestExpect(result).toEqual({
									loading = false,
									networkStatus = NetworkStatus.ready,
									data = {
										search = {
											edges = Array.slice(turrellEdges, 1, 2),
											pageInfo = turrellPageInfo1,
											totalCount = 13531,
										},
									},
								})
								local snapshot = cache:extract()
								jestExpect(snapshot).toMatchSnapshot()
								jestExpect((snapshot.ROOT_QUERY :: any)["search:james turrell"]).toEqual({
									edges = Array.map(Array.slice(turrellEdges, 1, 2), function(edge)
										return Object.assign({}, edge, {
											cursor = turrellPageInfo1.startCursor,
											node = { __ref = 'Artist:{"href":"/artist/james-turrell"}' },
										})
									end),
									pageInfo = turrellPageInfo1,
									totalCount = 13531,
								})
								jestExpect(cache:evict({
									id = cache:identify({
										__typename = "Artist",
										href = "/artist/jean-michel-basquiat",
									}),
								})).toBe(true)
							end, reject)
					elseif count == 6 then
						local edges = Array.concat({}, firstEdges, secondEdges, fifthEdges)
						jestExpect(edges:shift()).toEqual({
							__typename = "SearchableEdge",
							node = {
								__typename = "Artist",
								href = "/artist/jean-michel-basquiat",
								displayLabel = "Jean-Michel Basquiat",
								bio = "American, 1960-1988, New York, New York, based in New York, New York",
							},
						})
						jestExpect(result).toEqual({
							loading = false,
							networkStatus = NetworkStatus.ready,
							data = {
								search = {
									edges = edges,
									pageInfo = {
										__typename = "PageInfo",
										startCursor = fourthPageInfo.startCursor,
										endCursor = fifthPageInfo.endCursor,
										hasPreviousPage = false,
										hasNextPage = true,
									},
									totalCount = 1292,
								},
							},
						})
						jestExpect(cache:extract()).toMatchSnapshot()
						client
							:query({ query = query, variables = turrellVariables2, fetchPolicy = "network-only" })
							:andThen(function(result)
								jestExpect(result).toEqual({
									loading = false,
									networkStatus = NetworkStatus.ready,
									data = {
										search = {
											edges = turrellEdges,
											pageInfo = turrellPageInfo2,
											totalCount = 13531,
										},
									},
								})
								local snapshot = cache:extract()
								jestExpect(snapshot).toMatchSnapshot()
								jestExpect((snapshot.ROOT_QUERY :: any)["search:james turrell"]).toEqual({
									edges = Array.map(turrellEdges, function(edge, i)
										return Object.assign({}, edge, {
											cursor = ({ turrellPageInfo2.startCursor, turrellPageInfo2.endCursor })[i],
											node = ({
												{ __ref = 'Artist:{"href":"/artist/james-turrell"}' },
												edge.node,
											})[i],
										})
									end),
									pageInfo = turrellPageInfo2,
									totalCount = 13531,
								})
								setTimeout(resolve, 100)
							end)
					else
						reject("should not receive another result for Basquiat")
					end
				end)
			end)

			withErrorSpy(it, "runs nested merge functions as well as ancestors", function()
				local eventMergeCount = 0

				local attendeeMergeCount = 0

				local cache = InMemoryCache.new({
					typePolicies = {
						Event = {
							fields = {
								attendees = {
									merge = function(_self, existing: Array<any>, incoming: Array<any>)
										eventMergeCount += 1
										jestExpect(Array.isArray(incoming)).toBe(true)
										if Boolean.toJSBoolean(existing) then
											return Array.concat(existing, incoming)
										else
											return incoming
										end
									end,
								},
							},
						},
						Attendee = {
							fields = {
								events = {
									merge = function(_self, existing: Array<any>, incoming: Array<any>)
										attendeeMergeCount += 1
										jestExpect(Array.isArray(incoming)).toBe(true)
										if Boolean.toJSBoolean(existing) then
											return Array.concat(existing, incoming)
										else
											return incoming
										end
									end,
								},
							},
						},
					},
				})

				cache:writeQuery({
					query = gql([[
		
				  query {
					eventsToday {
					  name
					  attendees {
						name
						events {
						  time
						}
					  }
					}
				  }
				]]),
					data = {
						eventsToday = {
							{
								__typename = "Event",
								id = 123,
								name = "One-person party",
								time = "noonish",
								attendees = {
									{
										__typename = "Attendee",
										id = 234,
										name = "Ben Newman",
										events = { { __typename = "Event", id = 123 } },
									},
								},
							},
						},
					},
				})

				jestExpect(eventMergeCount).toBe(1)

				jestExpect(attendeeMergeCount).toBe(1)

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = { __typename = "Query", eventsToday = { { __ref = "Event:123" } } },
					["Event:123"] = {
						__typename = "Event",
						id = 123,
						name = "One-person party",
						attendees = { { __ref = "Attendee:234" } },
					},
					["Attendee:234"] = {
						__typename = "Attendee",
						id = 234,
						name = "Ben Newman",
						events = { { __ref = "Event:123" } },
					},
				})

				cache:writeQuery({
					query = gql([[
		
				  query {
					people {
					  name
					  events {
						time
						attendees {
						  name
						}
					  }
					}
				  }
				]]),
					data = {
						people = {
							{
								__typename = "Attendee",
								id = 234,
								name = "Ben Newman",
								events = {
									{
										__typename = "Event",
										id = 345,
										name = "Rooftop dog party",
										attendees = {
											{ __typename = "Attendee", id = 456, name = "Inspector Beckett" },
											{ __typename = "Attendee", id = 234 },
										},
									},
								},
							},
						},
					},
				})

				jestExpect(eventMergeCount).toBe(2)

				jestExpect(attendeeMergeCount).toBe(2)

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						eventsToday = { { __ref = "Event:123" } },
						people = { { __ref = "Attendee:234" } },
					},
					["Event:123"] = {
						__typename = "Event",
						id = 123,
						name = "One-person party",
						attendees = { { __ref = "Attendee:234" } },
					},
					["Event:345"] = {
						__typename = "Event",
						id = 345,
						attendees = { { __ref = "Attendee:456" }, { __ref = "Attendee:234" } },
					},
					["Attendee:234"] = {
						__typename = "Attendee",
						id = 234,
						name = "Ben Newman",
						events = { { __ref = "Event:123" }, { __ref = "Event:345" } },
					},
					["Attendee:456"] = { __typename = "Attendee", id = 456, name = "Inspector Beckett" },
				})

				jestExpect(cache:gc()).toEqual({})
			end)

			it("should report dangling references returned by read functions", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Query = {
							fields = {
								book = {
									keyArgs = { "isbn" },
									read = function(self, existing, ref)
										local args = ref.args
										return Boolean.toJSBoolean(existing) and existing
											or ref:toReference({ __typename = "Book", isbn = (args :: any).isbn })
									end,
								},
							},
						},
						Book = { keyFields = { "isbn" } },
					},
				})

				local query = gql([[
		
				query {
				  book(isbn: $isbn) {
					title
					author
				  }
				}
			  ]])

				local function read(isbn: string?)
					if isbn == nil then
						isbn = "156858217X"
					end
					return cache:readQuery({ query = query, variables = { isbn = isbn } })
				end

				local function diff(isbn: string?)
					if isbn == nil then
						isbn = "156858217X"
					end
					return cache:diff({
						query = query,
						variables = { isbn = isbn },
						returnPartialData = false,
						optimistic = true,
					})
				end

				jestExpect(read()).toBe(NULL)

				cache:writeQuery({
					query = query,
					variables = { isbn = "0393354326" },
					data = {
						book = {
							__typename = "Book",
							isbn = "0393354326",
							title = "Guns, Germs, and Steel",
							author = "Jared Diamond",
						},
					},
				})

				jestExpect(read()).toBe(NULL)

				jestExpect(diff).toThrow(RegExp('Dangling reference to missing Book:{"isbn":"156858217X"} object'))

				-- ROBLOX TODO: fragments are not supported yet
				-- local stealThisData = {
				-- 	__typename = "Book",
				-- 	isbn = "156858217X",
				-- 	title = "Steal This Book",
				-- 	author = "Abbie Hoffman",
				-- }

				-- local stealThisID = cache:identify(stealThisData) :: any

				-- cache:writeFragment({
				-- 	id = stealThisID,
				-- 	fragment = gql([[

				--   fragment BookTitleAuthor on Book {
				-- 	title
				-- 	author
				--   }
				-- ]]),
				-- 	data = stealThisData,
				-- })

				-- jestExpect(read()).toEqual({
				-- 	book = { __typename = "Book", title = "Steal This Book", author = "Abbie Hoffman" },
				-- })

				-- jestExpect(read("0393354326")).toEqual({
				-- 	book = { __typename = "Book", title = "Guns, Germs, and Steel", author = "Jared Diamond" },
				-- })

				-- jestExpect(cache:extract()).toEqual({
				-- 	__META = { extraRootIds = { 'Book:{"isbn":"156858217X"}' } },
				-- 	ROOT_QUERY = {
				-- 		__typename = "Query",
				-- 		['book:{"isbn":"0393354326"}'] = { __ref = 'Book:{"isbn":"0393354326"}' },
				-- 	},
				-- 	['Book:{"isbn":"0393354326"}'] = {
				-- 		__typename = "Book",
				-- 		isbn = "0393354326",
				-- 		author = "Jared Diamond",
				-- 		title = "Guns, Germs, and Steel",
				-- 	},
				-- 	['Book:{"isbn":"156858217X"}'] = {
				-- 		__typename = "Book",
				-- 		isbn = "156858217X",
				-- 		author = "Abbie Hoffman",
				-- 		title = "Steal This Book",
				-- 	},
				-- })

				-- jestExpect(cache:gc()).toEqual({})

				-- jestExpect(cache:release(stealThisID)).toBe(0)

				-- jestExpect(cache:gc()).toEqual({ stealThisID })

				-- jestExpect(cache:extract()).toEqual({
				-- 	ROOT_QUERY = {
				-- 		__typename = "Query",
				-- 		['book:{"isbn":"0393354326"}'] = { __ref = 'Book:{"isbn":"0393354326"}' },
				-- 	},
				-- 	['Book:{"isbn":"0393354326"}'] = {
				-- 		__typename = "Book",
				-- 		isbn = "0393354326",
				-- 		author = "Jared Diamond",
				-- 		title = "Guns, Germs, and Steel",
				-- 	},
				-- })

				-- cache:writeQuery({
				-- 	query = query,
				-- 	variables = { isbn = "156858217X" },
				-- 	data = { book = stealThisData },
				-- })

				-- jestExpect(cache:extract()).toEqual({
				-- 	ROOT_QUERY = {
				-- 		__typename = "Query",
				-- 		['book:{"isbn":"0393354326"}'] = { __ref = 'Book:{"isbn":"0393354326"}' },
				-- 		['book:{"isbn":"156858217X"}'] = { __ref = 'Book:{"isbn":"156858217X"}' },
				-- 	},
				-- 	['Book:{"isbn":"0393354326"}'] = {
				-- 		__typename = "Book",
				-- 		isbn = "0393354326",
				-- 		author = "Jared Diamond",
				-- 		title = "Guns, Germs, and Steel",
				-- 	},
				-- 	['Book:{"isbn":"156858217X"}'] = {
				-- 		__typename = "Book",
				-- 		isbn = "156858217X",
				-- 		author = "Abbie Hoffman",
				-- 		title = "Steal This Book",
				-- 	},
				-- })

				-- jestExpect(cache:gc()).toEqual({})

				-- jestExpect(cache:evict({ fieldName = "book" })).toBe(true)

				-- jestExpect(cache:gc():sort()).toEqual({
				-- 	'Book:{"isbn":"0393354326"}',
				-- 	'Book:{"isbn":"156858217X"}',
				-- })

				-- jestExpect(cache:extract()).toEqual({ ROOT_QUERY = { __typename = "Query" } })

				-- jestExpect(read("0393354326")).toBe(nil)

				-- jestExpect(function()
				-- 	return diff("0393354326")
				-- end).toThrow(RegExp('Dangling reference to missing Book:{"isbn":"0393354326"} object'))

				-- jestExpect(read("156858217X")).toBe(nil)

				-- jestExpect(function()
				-- 	return diff("156858217X")
				-- end).toThrow(RegExp('Dangling reference to missing Book:{"isbn":"156858217X"} object'))
			end)

			--ROBLOX deviation: predefine functions
			local testForceMerges
			local booksMergePolicy

			it("can force merging of unidentified non-normalized data", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Book = {
							keyFields = { "isbn" },
							fields = {
								author = {
									merge = function(_self, existing: StoreObject, incoming: StoreObject, ref)
										jestExpect(ref:mergeObjects(nil :: any, nil)).toBe(nil)
										jestExpect(function()
											ref:mergeObjects(
												({ 1, 2, 3 } :: any) :: StoreObject,
												({ 4 } :: any) :: StoreObject
											)
										end).toThrow(RegExp("Cannot automatically merge arrays"))
										local a = { __typename = "A", a = "ay" }
										local b = { __typename = "B", a = "bee" }
										jestExpect(ref:mergeObjects(a, b)).toBe(b)
										jestExpect(ref:mergeObjects(b, a)).toBe(a)
										return ref:mergeObjects(existing, incoming)
									end,
								},
							},
						},
						Author = { keyFields = false, fields = { books = booksMergePolicy() } },
					},
				})
				testForceMerges(cache)
			end)

			function booksMergePolicy(): FieldPolicy<Array<any>, any, any>
				return {
					merge = function(self, existing, incoming, ref)
						local merged = (function()
							if Boolean.toJSBoolean(existing) then
								return Array.slice(existing, 1)
							else
								return {}
							end
						end)()
						local seen = Set.new()
						if Boolean.toJSBoolean(existing) then
							Array.forEach(existing, function(book)
								if ref:isReference(book) then
									seen:add(book.__ref)
								end
							end)
						end
						Array.forEach(incoming, function(book)
							if ref:isReference(book) then
								if not seen:has(book.__ref) then
									table.insert(merged, book)
									seen:add(book.__ref)
								end
							else
								table.insert(merged, book)
							end
						end)
						return merged
					end,
				}
			end

			function testForceMerges(cache: InMemoryCache)
				local queryWithAuthorName = gql([[
		
				query {
				  currentlyReading {
					isbn
					title
					author {
					  name
					}
				  }
				}
			  ]])

				local queryWithAuthorBooks = gql([[
		
				query {
				  currentlyReading {
					isbn
					author {
					  books {
						isbn
						title
					  }
					}
				  }
				}
			  ]])

				cache:writeQuery({
					query = queryWithAuthorName,
					data = {
						currentlyReading = {
							__typename = "Book",
							isbn = "1250758009",
							title = "The Topeka School",
							author = { __typename = "Author", name = "Ben Lerner" },
						},
					},
				})

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						currentlyReading = { __ref = 'Book:{"isbn":"1250758009"}' },
					},
					['Book:{"isbn":"1250758009"}'] = {
						__typename = "Book",
						author = { __typename = "Author", name = "Ben Lerner" },
						isbn = "1250758009",
						title = "The Topeka School",
					},
				})

				cache:writeQuery({
					query = queryWithAuthorBooks,
					data = {
						currentlyReading = {
							__typename = "Book",
							isbn = "1250758009",
							author = {
								__typename = "Author",
								books = { { __typename = "Book", isbn = "1250758009", title = "The Topeka School" } },
							},
						},
					},
				})

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						currentlyReading = { __ref = 'Book:{"isbn":"1250758009"}' },
					},
					['Book:{"isbn":"1250758009"}'] = {
						__typename = "Book",
						author = {
							__typename = "Author",
							name = "Ben Lerner",
							books = { { __ref = 'Book:{"isbn":"1250758009"}' } },
						},
						isbn = "1250758009",
						title = "The Topeka School",
					},
				})

				cache:writeQuery({
					query = queryWithAuthorBooks,
					data = {
						currentlyReading = {
							__typename = "Book",
							isbn = "1250758009",
							author = {
								__typename = "Author",
								books = {
									{
										__typename = "Book",
										isbn = "1566892740",
										title = "Leaving the Atocha Station",
									},
								},
							},
						},
					},
				})

				jestExpect(cache:extract()).toEqual({
					ROOT_QUERY = {
						__typename = "Query",
						currentlyReading = { __ref = 'Book:{"isbn":"1250758009"}' },
					},
					['Book:{"isbn":"1250758009"}'] = {
						__typename = "Book",
						author = {
							__typename = "Author",
							name = "Ben Lerner",
							books = {
								{ __ref = 'Book:{"isbn":"1250758009"}' },
								{ __ref = 'Book:{"isbn":"1566892740"}' },
							},
						},
						isbn = "1250758009",
						title = "The Topeka School",
					},
					['Book:{"isbn":"1566892740"}'] = {
						__typename = "Book",
						isbn = "1566892740",
						title = "Leaving the Atocha Station",
					},
				})

				jestExpect(cache:readQuery({ query = queryWithAuthorBooks })).toEqual({
					currentlyReading = {
						__typename = "Book",
						isbn = "1250758009",
						author = {
							__typename = "Author",
							books = {
								{ __typename = "Book", isbn = "1250758009", title = "The Topeka School" },
								{ __typename = "Book", isbn = "1566892740", title = "Leaving the Atocha Station" },
							},
						},
					},
				})

				jestExpect(cache:readQuery({ query = queryWithAuthorName })).toEqual({
					currentlyReading = {
						__typename = "Book",
						isbn = "1250758009",
						title = "The Topeka School",
						author = { __typename = "Author", name = "Ben Lerner" },
					},
				})
			end

			-- Same as previous test, except with merge:true for Book.author.
			it("can force merging with merge:true field policy", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Book = { keyFields = { "isbn" }, fields = { author = { merge = true } } },
						Author = { keyFields = false, fields = { books = booksMergePolicy() } },
					},
				})

				testForceMerges(cache)
			end)

			-- Same as previous test, except configuring merge:true for the Author
			-- type instead of for the Book.author field.
			it("can force merging with merge:true type policy", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Book = { keyFields = { "isbn" } },
						Author = { keyFields = false, merge = true, fields = { books = booksMergePolicy() } },
					},
				})

				testForceMerges(cache)
			end)

			it("can force merging with inherited merge:true field policy", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Authored = { fields = { author = { merge = true } } },
						Book = { keyFields = { "isbn" } },
						Author = { keyFields = false, fields = { books = booksMergePolicy() } },
					},
					possibleTypes = { Authored = { "Book", "Destruction" } },
				})

				testForceMerges(cache)
			end)

			it("can force merging with inherited merge:true type policy", function()
				local cache = InMemoryCache.new({
					typePolicies = {
						Book = { keyFields = { "isbn" } },
						Author = { fields = { books = booksMergePolicy() } },
						Person = { keyFields = false, merge = true },
					},
					possibleTypes = { Person = { "Author" } },
				})

				testForceMerges(cache)
			end)

			local function checkAuthor(data: TData_, canBeUndefined: boolean?)
				if canBeUndefined == nil then
					canBeUndefined = false
				end
				if Boolean.toJSBoolean(data) or not canBeUndefined then
					jestExpect(data).toBeTruthy()
					jestExpect(typeof(data)).toBe("table")
					jestExpect((data :: any).__typename).toBe("Author")
				end
				return data
			end

			it("can force merging with inherited type policy merge function", function()
				local personMergeCount = 0
				local cache = InMemoryCache.new({
					typePolicies = {
						Book = { keyFields = { "isbn" } },
						Author = { fields = { books = booksMergePolicy() } },
						Person = {
							keyFields = false,
							merge = function(self, existing, incoming)
								checkAuthor(existing, true)
								checkAuthor(incoming)
								personMergeCount += 1
								return Object.assign({}, existing, incoming)
							end,
						},
					},
					possibleTypes = { Person = { "Author" } },
				})

				testForceMerges(cache)

				jestExpect(personMergeCount).toBe(3)
			end)

			it("can force merging references with non-normalized objects", function()
				-- ROBLOX deviation: predefine function
				local check

				local nameQuery = gql([[
		
				query GetName {
				  viewer {
					name
				  }
				}
			  ]])

				local emailQuery = gql([[
		
				query GetEmail {
				  viewer {
					id
					email
				  }
				}
			  ]])

				-- ROBLOX deviation: hoist function declaration
				function check(cache: InMemoryCache)
					cache:writeQuery({
						query = nameQuery,
						data = { viewer = { __typename = "User", name = "Alice" } },
					})

					jestExpect(cache:extract()).toEqual({
						ROOT_QUERY = { __typename = "Query", viewer = { __typename = "User", name = "Alice" } },
					})

					cache:writeQuery({
						query = emailQuery,
						data = { viewer = { __typename = "User", id = 12345, email = "alice@example.com" } },
					})

					jestExpect(cache:extract()).toEqual({
						ROOT_QUERY = { __typename = "Query", viewer = { __ref = "User:12345" } },
						["User:12345"] = {
							__typename = "User",
							name = "Alice",
							id = 12345,
							email = "alice@example.com",
						},
					})

					jestExpect(cache:readQuery({ query = nameQuery })).toEqual({
						viewer = { __typename = "User", name = "Alice" },
					})

					jestExpect(cache:readQuery({ query = emailQuery })).toEqual({
						viewer = { __typename = "User", id = 12345, email = "alice@example.com" },
					})

					cache:reset()

					jestExpect(cache:extract()).toEqual({})

					cache:writeQuery({
						query = emailQuery,
						data = { viewer = { __typename = "User", id = 12345, email = "alice@example.com" } },
					})

					jestExpect(cache:extract()).toEqual({
						["User:12345"] = { id = 12345, __typename = "User", email = "alice@example.com" },
						ROOT_QUERY = { __typename = "Query", viewer = { __ref = "User:12345" } },
					})

					cache:writeQuery({
						query = nameQuery,
						data = { viewer = { __typename = "User", name = "Alice" } },
					})

					jestExpect(cache:extract()).toEqual({
						["User:12345"] = {
							id = 12345,
							__typename = "User",
							email = "alice@example.com",
							name = "Alice",
						},
						ROOT_QUERY = { __typename = "Query", viewer = { __ref = "User:12345" } },
					})

					jestExpect(cache:readQuery({ query = nameQuery })).toEqual({
						viewer = { __typename = "User", name = "Alice" },
					})

					jestExpect(cache:readQuery({ query = emailQuery })).toEqual({
						viewer = { __typename = "User", id = 12345, email = "alice@example.com" },
					})
				end

				check(InMemoryCache.new({ typePolicies = { Query = { fields = { viewer = { merge = true } } } } }))

				check(InMemoryCache.new({ typePolicies = { User = { merge = true } } }))
			end)

			it("can force merging with inherited field merge function", function()
				local authorMergeCount = 0
				local cache = InMemoryCache.new({
					typePolicies = {
						Book = { keyFields = { "isbn" } },
						Authored = {
							fields = {
								author = {
									merge = function(self, existing, incoming)
										checkAuthor(existing, true)
										checkAuthor(incoming)
										authorMergeCount += 1
										return Object.assign({}, existing, incoming)
									end,
								},
							},
						},
						Author = { fields = { books = booksMergePolicy() } },
						Person = { keyFields = false },
					},
					possibleTypes = { Authored = { "Destiny", "Book" }, Person = { "Author" } },
				})

				testForceMerges(cache)

				jestExpect(authorMergeCount).toBe(3)
			end)
		end)

		it("runs read and merge functions for unidentified data", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Book = { keyFields = { "isbn" } },
					Author = {
						keyFields = false,
						fields = {
							name = {
								read = function(self, name: string)
									return string.upper(reverse(name))
								end,
								merge = function(self, oldName, newName: string)
									jestExpect(oldName).toBe(nil)
									jestExpect(typeof(newName)).toBe("string")
									return reverse(newName)
								end,
							},
						},
					},
				},
			})

			local query = gql([[
		
			  query {
				currentlyReading {
				  title
				  authors {
					name
				  }
				}
			  }
			]])

			cache:writeQuery({
				query = query,
				data = {
					currentlyReading = {
						{
							__typename = "Book",
							isbn = "0525558616",
							title = "Human Compatible: Artificial Intelligence and the Problem of Control",
							authors = { { __typename = "Author", name = "Stuart Russell" } },
						},
						{
							__typename = "Book",
							isbn = "1541698967",
							title = "The Book of Why: The New Science of Cause and Effect",
							authors = {
								{ __typename = "Author", name = "Judea Pearl" },
								{ __typename = "Author", name = "Dana Mackenzie" },
							},
						},
					},
				},
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					currentlyReading = {
						{ __ref = 'Book:{"isbn":"0525558616"}' },
						{ __ref = 'Book:{"isbn":"1541698967"}' },
					},
				},
				['Book:{"isbn":"0525558616"}'] = {
					__typename = "Book",
					isbn = "0525558616",
					authors = { { __typename = "Author", name = "llessuR trautS" } },
					title = "Human Compatible: Artificial Intelligence and the Problem of Control",
				},
				['Book:{"isbn":"1541698967"}'] = {
					__typename = "Book",
					isbn = "1541698967",
					authors = {
						{ __typename = "Author", name = "lraeP aeduJ" },
						{ __typename = "Author", name = "eiznekcaM anaD" },
					},
					title = "The Book of Why: The New Science of Cause and Effect",
				},
			})

			jestExpect(cache:readQuery({ query = query })).toEqual({
				currentlyReading = {
					{
						__typename = "Book",
						title = "Human Compatible: Artificial Intelligence and the Problem of Control",
						authors = { { __typename = "Author", name = "STUART RUSSELL" } },
					},
					{
						__typename = "Book",
						title = "The Book of Why: The New Science of Cause and Effect",
						authors = {
							{ __typename = "Author", name = "JUDEA PEARL" },
							{ __typename = "Author", name = "DANA MACKENZIE" },
						},
					},
				},
			})
		end)

		it("allows keyFields and keyArgs functions to return false", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Person = {
						keyFields = function(self)
							return false
						end,
						fields = {
							height = {
								keyArgs = function(self)
									return false
								end,
								merge = function(self, _, height, ref)
									local args = ref.args
									if Boolean.toJSBoolean(args) then
										if args.units == "feet" then
											return height
										end
										if args.units == "meters" then
											return height * 3.28084
										end
									end
									error(Error.new("unexpected units: " .. tostring(args)))
								end,
							},
						},
					},
				},
			})

			local query = gql([[
		
			  query GetUser ($units: string) {
				people {
				  id
				  height(units: $units)
				}
			  }
			]])

			cache:writeQuery({
				query = query,
				variables = { units = "meters" },
				data = {
					people = {
						{ __typename = "Person", id = 12345, height = 1.75 },
						{ __typename = "Person", id = 23456, height = 2 },
					},
				},
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					people = {
						{ __typename = "Person", height = 5.74147, id = 12345 },
						{ __typename = "Person", height = 6.56168, id = 23456 },
					},
				},
			})
		end)

		it("can read from foreign references using read helper", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Author = {
						keyFields = { "name" },
						fields = {
							books = {
								merge = function(self, existing: Array<Reference>?, incoming: Array<Reference>)
									if existing == nil then
										existing = {}
									end
									return Array.concat({}, existing, incoming)
								end,
							},
							firstBook = function(self, _, ref)
								local firstBook: Reference | nil = nil
								local firstYear: number
								local ref_ = ref:readField("books")
								local bookRefs = Boolean.toJSBoolean(ref_) and ref_ or {}
								Array.forEach(bookRefs, function(bookRef)
									jestExpect(ref:isReference(bookRef)).toBe(true)
									local year = ref:readField("year", bookRef)
									if firstYear == nil or (year :: any) < firstYear then
										firstBook = bookRef
										firstYear = year :: any
									end
								end)
								return firstBook
							end,
						},
					},
					Book = { keyFields = { "isbn" } },
				},
			})

			type BookData = {
				__typename: string, --[[ 'Book' ]]
				isbn: string,
				title: string,
				year: number,
			}

			local function addBook(bookData: BookData)
				cache:writeQuery({
					query = gql([[
		
				  query {
					author {
					  name
					  books {
						isbn
						title
						year
					  }
					}
				  }
				]]),
					data = { author = { __typename = "Author", name = "Virginia Woolf", books = { bookData } } },
				})
			end

			addBook({ __typename = "Book", isbn = "1853262390", title = "Orlando", year = 1928 })

			addBook({ __typename = "Book", isbn = "9353420717", title = "A Room of One's Own", year = 1929 })

			addBook({ __typename = "Book", isbn = "0156907399", title = "To the Lighthouse", year = 1927 })

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = { __typename = "Query", author = { __ref = 'Author:{"name":"Virginia Woolf"}' } },
				['Author:{"name":"Virginia Woolf"}'] = {
					__typename = "Author",
					name = "Virginia Woolf",
					books = {
						{ __ref = 'Book:{"isbn":"1853262390"}' },
						{ __ref = 'Book:{"isbn":"9353420717"}' },
						{ __ref = 'Book:{"isbn":"0156907399"}' },
					},
				},
				['Book:{"isbn":"1853262390"}'] = {
					__typename = "Book",
					isbn = "1853262390",
					title = "Orlando",
					year = 1928,
				},
				['Book:{"isbn":"9353420717"}'] = {
					__typename = "Book",
					isbn = "9353420717",
					title = "A Room of One's Own",
					year = 1929,
				},
				['Book:{"isbn":"0156907399"}'] = {
					__typename = "Book",
					isbn = "0156907399",
					title = "To the Lighthouse",
					year = 1927,
				},
			})

			local firstBookQuery = gql([[
		
			  query {
				author {
				  name
				  firstBook {
					title
					year
				  }
				}
			  }
			]])

			local function readFirstBookResult()
				return cache:readQuery({ query = firstBookQuery }) :: any
			end

			local firstBookResult = readFirstBookResult()

			jestExpect(firstBookResult).toEqual({
				author = {
					__typename = "Author",
					name = "Virginia Woolf",
					firstBook = { __typename = "Book", title = "To the Lighthouse", year = 1927 },
				},
			})

			jestExpect(readFirstBookResult()).toBe(firstBookResult)

			addBook({ __typename = "Book", isbn = "1420959719", title = "The Voyage Out", year = 1915 })

			local secondFirstBookResult = readFirstBookResult()

			jestExpect(secondFirstBookResult).never.toBe(firstBookResult)

			jestExpect(secondFirstBookResult).toEqual({
				author = {
					__typename = "Author",
					name = "Virginia Woolf",
					firstBook = { __typename = "Book", title = "The Voyage Out", year = 1915 },
				},
			})

			cache:writeQuery({
				query = gql("query { author { afraidCount } }"),
				data = { author = { __typename = "Author", name = "Virginia Woolf", afraidCount = 2 } },
			})

			-- ROBLOX TODO: fragments are not supported yet
			-- jestExpect(cache:readFragment({
			-- 	id = cache:identify({ __typename = "Author", name = "Virginia Woolf" }) :: any,
			-- 	fragment = gql([[

			-- 	fragment AfraidFragment on Author {
			-- 	  name
			-- 	  afraidCount
			-- 	}
			--   ]]),
			-- })).toEqual({ __typename = "Author", name = "Virginia Woolf", afraidCount = 2 })

			jestExpect(readFirstBookResult()).toBe(secondFirstBookResult)

			addBook({ __typename = "Book", isbn = "9780156949606", title = "The Waves", year = 1931 })

			local thirdFirstBookResult = readFirstBookResult()

			jestExpect(thirdFirstBookResult).toEqual(secondFirstBookResult)

			jestExpect(thirdFirstBookResult).toBe(secondFirstBookResult)
		end)

		it("readField can read fields with arguments", function()
			type Style = { [string]: number }

			local Style = { UPPER = 0, LOWER = 1, TITLE = 2 }

			local cache = InMemoryCache.new({
				typePolicies = {
					Word = {
						keyFields = { "text" },
						fields = {
							style = function(self, _, ref)
								local args = ref.args
								local text = ref:readField("text")
								local condition_ = args.style

								if condition_ == Style.UPPER then
									return text and string.upper(text) or text
								end
								if condition_ == Style.LOWER then
									return text and string.lower(text) or text
								end
								if condition_ == Style.TITLE then
									if Boolean.toJSBoolean(text) then
										return string.upper(string.sub(text, 1, 1)) .. string.lower(string.sub(text, 2))
									else
										return text
									end
								end

								return nil
							end,
							upperCase = function(self, _, ref)
								return ref:readField({ fieldName = "style", args = { style = Style.UPPER } })
							end,
							lowerCase = function(self, _, ref)
								return ref:readField({ fieldName = "style", args = { style = Style.LOWER } })
							end,
							titleCase = function(self, _, ref)
								return ref:readField({ fieldName = "style", args = { style = Style.TITLE } })
							end,
						},
					},
				},
			})

			cache:writeQuery({
				query = gql("query { wordOfTheDay { text } }"),
				data = { wordOfTheDay = { __typename = "Word", text = "inveigle" } },
			})

			jestExpect(cache:readQuery({
				query = gql([[
		
				query {
				  wordOfTheDay {
					upperCase
					lowerCase
					titleCase
				  }
				}
			  ]]),
			})).toEqual({
				wordOfTheDay = {
					__typename = "Word",
					upperCase = "INVEIGLE",
					lowerCase = "inveigle",
					titleCase = "Inveigle",
				},
			})
		end)

		it("can return existing object from merge function (issue #6245)", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Person = {
						fields = {
							currentTask = {
								merge = function(self, existing, incoming)
									return Boolean.toJSBoolean(existing) and existing or incoming
								end,
							},
						},
					},
					Task = { keyFields = false },
				},
			})

			local query = gql([[
		
			  query {
				person {
				  currentTask {
					__typename
					description
				  }
				}
			  }
			]])

			cache:writeQuery({
				query = query,
				data = {
					person = {
						__typename = "Person",
						id = 1234,
						currentTask = { __typename = "Task", description = "writing tests" },
					},
				},
			})

			local snapshot = cache:extract()

			jestExpect(snapshot).toEqual({
				["Person:1234"] = {
					__typename = "Person",
					id = 1234,
					currentTask = { __typename = "Task", description = "writing tests" },
				},
				ROOT_QUERY = { __typename = "Query", person = { __ref = "Person:1234" } },
			})

			cache:writeQuery({
				query = query,
				data = {
					person = {
						__typename = "Person",
						id = 1234,
						currentTask = { __typename = "Task", description = "polishing knives" },
					},
				},
			})

			jestExpect(cache:extract()).toEqual(snapshot)
		end)

		it("can alter the root query __typename", function()
			local cache = InMemoryCache.new({ typePolicies = { RootQuery = { queryType = true } } })

			jestExpect(cache:readQuery({ query = gql("query { __typename }") })).toEqual({ __typename = "RootQuery" })

			local ALL_ITEMS = gql([[
		
			  query Items {
				__typename
				items {
				  id
				  query {
					id
				  }
				}
			  }
			]])

			local function makeItem(id: number)
				return { id = id, query = { __typename = "Query", id = id } }
			end

			cache:writeQuery({
				query = ALL_ITEMS,
				data = { __typename = "RootQuery", items = { makeItem(0), makeItem(1), makeItem(2), makeItem(3) } },
			})
			--ROBLOX TODO: snapshot test, remove call below when enabñed
			cache:extract()
			-- jestExpect(cache:extract()).toMatchSnapshot()

			jestExpect(cache:readQuery({ query = ALL_ITEMS })).toEqual({
				__typename = "RootQuery",
				items = { makeItem(0), makeItem(1), makeItem(2), makeItem(3) },
			})
		end)

		-- ROBLOX TODO: fragments are not supported yet
		xit("can configure {query,mutation,subscription}Type:true", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					RootQuery = { queryType = true },
					RootMutation = { mutationType = true },
					RootSubscription = { subscriptionType = true },
				},
			})

			jestExpect(cache:readQuery({ query = gql("query { __typename }") })).toEqual({ __typename = "RootQuery" })

			jestExpect(cache:readFragment({
				id = "ROOT_MUTATION",
				fragment = gql([[
		
				fragment MutationTypename on RootMutation {
				  __typename
				}
			  ]]),
			})).toEqual({ __typename = "RootMutation" })

			jestExpect(cache:readFragment({
				id = "ROOT_SUBSCRIPTION",
				fragment = gql([[
		
				fragment SubscriptionTypename on RootSubscription {
				  __typename
				}
			  ]]),
			})).toEqual({ __typename = "RootSubscription" })
		end)
	end)
end
