-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/entityStore.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Boolean = LuauPolyfill.Boolean
	local Object = LuauPolyfill.Object
	local Map = LuauPolyfill.Map
	local String = LuauPolyfill.String

	type Array<T> = LuauPolyfill.Array<T>
	type Map<K, V> = LuauPolyfill.Map<K, V>
	type Object = LuauPolyfill.Object
	type Record<T, U> = { [T]: U }

	local RegExp = require(rootWorkspace.LuauRegExp)

	local gql = require(rootWorkspace.GraphQLTag).default
	local entityStoreModule = require(script.Parent.Parent.entityStore)
	local EntityStore_Root = entityStoreModule.EntityStore_Root
	local supportsResultCaching = entityStoreModule.supportsResultCaching
	local InMemoryCache = require(script.Parent.Parent.inMemoryCache).InMemoryCache
	local graphQLModule = require(rootWorkspace.GraphQL)
	type DocumentNode = graphQLModule.DocumentNode
	local typesModule = require(script.Parent.Parent.types)
	type StoreObject = typesModule.StoreObject
	local coreCacheModule = require(script.Parent.Parent.Parent.core.cache)
	type ApolloCache<TSerialized> = coreCacheModule.ApolloCache<TSerialized>
	local coreTypesCacheModule = require(script.Parent.Parent.Parent.core.types.Cache)
	type Cache_DiffResult<T> = coreTypesCacheModule.Cache_DiffResult<T>
	local storeUtilsModule = require(script.Parent.Parent.Parent.Parent.utilities.graphql.storeUtils)
	type Reference = storeUtilsModule.Reference
	local makeReference = storeUtilsModule.makeReference
	local isReference = storeUtilsModule.isReference
	type StoreValue = storeUtilsModule.StoreValue

	local MissingFieldError = require(script.Parent.Parent.Parent).MissingFieldError
	local typedDocumentNodeModule = require(srcWorkspace.jsutils.typedDocumentNode)
	type TypedDocumentNode<Result, Variables> = typedDocumentNodeModule.TypedDocumentNode<Result, Variables>

	local cacheCoreTypesCommonModule = require(script.Parent.Parent.Parent.Parent.cache.core.types.common)
	type ReadFieldFunction = cacheCoreTypesCommonModule.ReadFieldFunction
	type ToReferenceFunction = cacheCoreTypesCommonModule.ToReferenceFunction
	type ModifierDetails = {
		readField: ReadFieldFunction,
		toReference: ToReferenceFunction,
		isReference: (self: any, obj: any) -> boolean,
	}

	local inmemoryPoliciesTypesModule = require(script.Parent.Parent.policies_types)
	type FieldFunctionOptions<TArgs, TVars> = inmemoryPoliciesTypesModule.FieldFunctionOptions<TArgs, TVars>
	type FieldFunctionOptions_ = FieldFunctionOptions<Record<string, any>, Record<string, any>>

	describe("EntityStore", function()
		it("should support result caching if so configured", function()
			local cache = InMemoryCache.new()

			local storeWithResultCaching = EntityStore_Root.new({
				policies = cache.policies,
				resultCaching = true,
			})

			local storeWithoutResultCaching = EntityStore_Root.new({
				policies = cache.policies,
				resultCaching = false,
			})

			jestExpect(supportsResultCaching({ some = "arbitrary object " } :: any)).toBe(false)
			jestExpect(supportsResultCaching(storeWithResultCaching)).toBe(true)
			jestExpect(supportsResultCaching(storeWithoutResultCaching)).toBe(false)

			local layerWithCaching = storeWithResultCaching:addLayer("with caching", function() end)
			jestExpect(supportsResultCaching(layerWithCaching)).toBe(true)
			local anotherLayer = layerWithCaching:addLayer("another layer", function() end)
			jestExpect(supportsResultCaching(anotherLayer)).toBe(true)
			jestExpect(anotherLayer:removeLayer("with caching"):removeLayer("another layer")).toBe(
				storeWithResultCaching.stump
			)
			jestExpect(supportsResultCaching(storeWithResultCaching)).toBe(true)

			local layerWithoutCaching = storeWithoutResultCaching:addLayer("with caching", function() end)
			jestExpect(supportsResultCaching(layerWithoutCaching)).toBe(false)
			jestExpect(layerWithoutCaching:removeLayer("with caching")).toBe(storeWithoutResultCaching.stump)
			jestExpect(supportsResultCaching(storeWithoutResultCaching)).toBe(false)
		end)

		local function newBookAuthorCache()
			local cache = InMemoryCache.new({
				resultCaching = true,
				dataIdFromObject = function(_self, value: any)
					local condition
					if Boolean.toJSBoolean(value) then
						condition = value.__typename
					else
						condition = value
					end
					if condition == "Book" then
						return "Book:" .. value.isbn
					elseif condition == "Author" then
						return "Author:" .. value.name
					end
					return nil
				end,
			})

			local query: TypedDocumentNode<{
				book: {
					__typename: string,
					title: string,
					isbn: string,
					author: { __typename: string, name: string },
				},
			}, Object> =
				gql(
					[[

      query {
        book {
          title
          author {
            name
          }
        }
      }
    ]]
				)

			return {
				cache = cache,
				query = query,
			}
		end

		it("should reclaim no-longer-reachable, unretained entities", function()
			local ref = newBookAuthorCache()
			local cache, query = ref.cache, ref.query

			cache:writeQuery({
				query = query,
				data = {
					book = {
						__typename = "Book",
						isbn = "9781451673319",
						title = "Fahrenheit 451",
						author = {
							__typename = "Author",
							name = "Ray Bradbury",
						},
					},
				},
			})

			local extracted = cache:extract()
			jestExpect(extracted.ROOT_QUERY).toEqual({
				__typename = "Query",
				book = {
					__ref = "Book:9781451673319",
				},
			})
			jestExpect(extracted["Book:9781451673319"]).toEqual({
				__typename = "Book",
				title = "Fahrenheit 451",
				author = {
					__ref = "Author:Ray Bradbury",
				},
			})
			jestExpect(extracted["Author:Ray Bradbury"]).toEqual({
				__typename = "Author",
				name = "Ray Bradbury",
			})
			jestExpect(extracted).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:9781451673319",
					},
				},
				["Book:9781451673319"] = {
					__typename = "Book",
					title = "Fahrenheit 451",
					author = {
						__ref = "Author:Ray Bradbury",
					},
				},
				["Author:Ray Bradbury"] = {
					__typename = "Author",
					name = "Ray Bradbury",
				},
			})

			cache:writeQuery({
				query = query,
				data = {
					book = {
						__typename = "Book",
						isbn = "0312429215",
						title = "2666",
						author = {
							__typename = "Author",
							name = "Roberto Bola\u{F1}o",
						},
					},
				},
			})

			local snapshot = cache:extract()

			jestExpect(snapshot).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:0312429215",
					},
				},
				["Book:9781451673319"] = {
					__typename = "Book",
					title = "Fahrenheit 451",
					author = {
						__ref = "Author:Ray Bradbury",
					},
				},
				["Author:Ray Bradbury"] = {
					__typename = "Author",
					name = "Ray Bradbury",
				},
				["Book:0312429215"] = {
					__typename = "Book",
					author = {
						__ref = "Author:Roberto Bola\u{F1}o",
					},
					title = "2666",
				},
				["Author:Roberto Bola\u{F1}o"] = {
					__typename = "Author",
					name = "Roberto Bola\u{F1}o",
				},
			})

			local resultBeforeGC = cache:readQuery({ query = query })

			jestExpect(Array.sort(cache:gc())).toEqual({
				"Author:Ray Bradbury",
				"Book:9781451673319",
			})

			local resultAfterGC = cache:readQuery({ query = query })
			jestExpect(resultBeforeGC).toBe(resultAfterGC)

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:0312429215",
					},
				},
				["Book:0312429215"] = {
					__typename = "Book",
					author = {
						__ref = "Author:Roberto Bola\u{F1}o",
					},
					title = "2666",
				},
				["Author:Roberto Bola\u{F1}o"] = {
					__typename = "Author",
					name = "Roberto Bola\u{F1}o",
				},
			})

			-- Nothing left to collect, but let's also reset the result cache to
			-- demonstrate that the recomputed cache results are unchanged.
			local originalReader = cache["storeReader"]
			jestExpect(cache:gc({
				resetResultCache = true,
			})).toEqual({})
			jestExpect(cache["storeReader"]).never.toBe(originalReader)
			local resultAfterResetResultCache = cache:readQuery({ query = query })
			jestExpect(resultAfterResetResultCache).toBe(resultBeforeGC)
			jestExpect(resultAfterResetResultCache).toBe(resultAfterGC)

			-- Now discard cache.storeReader.canon as well.
			jestExpect(cache:gc({
				resetResultCache = true,
				resetResultIdentities = true,
			})).toEqual({})

			local resultAfterFullGC = cache:readQuery({ query = query })
			jestExpect(resultAfterFullGC).toEqual(resultBeforeGC)
			jestExpect(resultAfterFullGC).toEqual(resultAfterGC)
			-- These !== relations are triggered by passing resetResultIdentities:true
			-- to cache.gc, above.
			jestExpect(resultAfterFullGC).never.toBe(resultBeforeGC)
			jestExpect(resultAfterFullGC).never.toBe(resultAfterGC)
			-- Result caching immediately begins working again after the intial reset.
			jestExpect(cache:readQuery({ query = query })).toBe(resultAfterFullGC)

			-- Go back to the pre-GC snapshot.
			cache:restore(snapshot)
			jestExpect(cache:extract()).toEqual(snapshot)

			-- ROBLOX TODO: fragments are not supported yet
			-- 		-- Reading a specific fragment causes it to be retained during garbage collection.
			-- 		local authorNameFragment = gql([[

			--   fragment AuthorName on Author {
			--     name
			--   }
			-- ]])
			-- 		local ray = cache:readFragment({
			-- 			id = "Author:Ray Bradbury",
			-- 			fragment = authorNameFragment,
			-- 		})

			-- 		jestExpect(cache:retain("Author:Ray Bradbury")).toBe(1)

			-- 		jestExpect(ray).toEqual({
			-- 			__typename = "Author",
			-- 			name = "Ray Bradbury",
			-- 		})

			-- 		jestExpect(cache:gc()).toEqual({
			-- 			-- Only Fahrenheit 451 (the book) is reclaimed this time.
			-- 			"Book:9781451673319",
			-- 		})

			-- 		local rayMeta = {
			-- 			extraRootIds = {
			-- 				"Author:Ray Bradbury",
			-- 			},
			-- 		}

			-- 		jestExpect(cache:extract()).toEqual({
			-- 			__META = rayMeta,
			-- 			ROOT_QUERY = {
			-- 				__typename = "Query",
			-- 				book = {
			-- 					__ref = "Book:0312429215",
			-- 				},
			-- 			},
			-- 			["Author:Ray Bradbury"] = {
			-- 				__typename = "Author",
			-- 				name = "Ray Bradbury",
			-- 			},
			-- 			["Book:0312429215"] = {
			-- 				__typename = "Book",
			-- 				author = {
			-- 					__ref = "Author:Roberto Bola\u{F1}o",
			-- 				},
			-- 				title = "2666",
			-- 			},
			-- 			["Author:Roberto Bola\u{F1}o"] = {
			-- 				__typename = "Author",
			-- 				name = "Roberto Bola\u{F1}o",
			-- 			},
			-- 		})

			-- 		jestExpect(cache:gc()).toEqual({})

			-- 		jestExpect(cache:release("Author:Ray Bradbury")).toBe(0)

			-- 		jestExpect(cache:gc()).toEqual({
			-- 			"Author:Ray Bradbury",
			-- 		})

			-- 		jestExpect(cache:gc()).toEqual({})
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("should respect optimistic updates, when active", function()
			local ref = newBookAuthorCache()
			local cache, query = ref.cache, ref.query

			cache:writeQuery({
				query = query,
				data = {
					book = {
						__typename = "Book",
						isbn = "9781451673319",
						title = "Fahrenheit 451",
						author = {
							__typename = "Author",
							name = "Ray Bradbury",
						},
					},
				},
			})

			jestExpect(cache:gc()).toEqual({})

			-- Orphan the F451 / Ray Bradbury data, but avoid collecting garbage yet.
			cache:writeQuery({
				query = query,
				data = {
					book = {
						__typename = "Book",
						isbn = "1980719802",
						title = "1984",
						author = {
							__typename = "Author",
							name = "George Orwell",
						},
					},
				},
			})

			cache:recordOptimisticTransaction(function(proxy)
				proxy:writeFragment({
					id = "Author:Ray Bradbury",
					fragment = gql([[

			  fragment AuthorBooks on Author {
			    books {
			      title
			    }
			  }
			]]),
					data = {
						books = {
							{
								__typename = "Book",
								isbn = "9781451673319",
								title = "Fahrenheit 451",
							},
						},
					},
				})
			end, "ray books")

			local rayMeta = {
				extraRootIds = {
					"Author:Ray Bradbury",
				},
			}

			jestExpect(cache:extract(true)).toEqual({
				__META = rayMeta,
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:1980719802",
					},
				},
				["Author:Ray Bradbury"] = {
					__typename = "Author",
					name = "Ray Bradbury",
					books = { {
						__ref = "Book:9781451673319",
					} },
				},
				["Book:9781451673319"] = {
					__typename = "Book",
					title = "Fahrenheit 451",
					author = {
						__ref = "Author:Ray Bradbury",
					},
				},
				["Author:George Orwell"] = {
					__typename = "Author",
					name = "George Orwell",
				},
				["Book:1980719802"] = {
					__typename = "Book",
					title = "1984",
					author = {
						__ref = "Author:George Orwell",
					},
				},
			})

			-- Nothing can be reclaimed while the optimistic update is retaining
			-- Fahrenheit 451.
			jestExpect(cache:gc()).toEqual({})

			cache:removeOptimistic("ray books")

			jestExpect(cache:extract(true)).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:1980719802",
					},
				},
				["Author:Ray Bradbury"] = {
					__typename = "Author",
					name = "Ray Bradbury",
					-- Note that the optimistic books field has disappeared, as expected.
				},
				["Book:9781451673319"] = {
					__typename = "Book",
					title = "Fahrenheit 451",
					author = {
						__ref = "Author:Ray Bradbury",
					},
				},
				["Author:George Orwell"] = {
					__typename = "Author",
					name = "George Orwell",
				},
				["Book:1980719802"] = {
					__typename = "Book",
					title = "1984",
					author = {
						__ref = "Author:George Orwell",
					},
				},
			})

			jestExpect(Array.sort(cache:gc())).toEqual({
				"Author:Ray Bradbury",
				"Book:9781451673319",
			})

			jestExpect(cache:extract(true)).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:1980719802",
					},
				},
				["Author:George Orwell"] = {
					__typename = "Author",
					name = "George Orwell",
				},
				["Book:1980719802"] = {
					__typename = "Book",
					title = "1984",
					author = {
						__ref = "Author:George Orwell",
					},
				},
			})
			jestExpect(cache:gc()).toEqual({})
		end)

		it("should respect retain/release methods", function()
			local ref = newBookAuthorCache()
			local query, cache = ref.query, ref.cache

			local eagerBookData = {
				__typename = "Book",
				isbn = "1603589082",
				title = "Eager",
				subtitle = "The Surprising, Secret Life of Beavers and Why They Matter",
				author = {
					__typename = "Author",
					name = "Ben Goldfarb",
				},
			}

			local spinelessBookData = {
				__typename = "Book",
				isbn = "0735211280",
				title = "Spineless",
				subtitle = "The Science of Jellyfish and the Art of Growing a Backbone",
				author = {
					__typename = "Author",
					name = "Juli Berwald",
				},
			}

			cache:writeQuery({
				query = query,
				data = {
					book = spinelessBookData,
				},
			})

			jestExpect(cache:extract(true)).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:0735211280",
					},
				},
				["Book:0735211280"] = {
					__typename = "Book",
					author = {
						__ref = "Author:Juli Berwald",
					},
					title = "Spineless",
				},
				["Author:Juli Berwald"] = {
					__typename = "Author",
					name = "Juli Berwald",
				},
			})

			cache:writeQuery({
				query = query,
				data = {
					book = eagerBookData,
				},
			})

			local snapshotWithBothBooksAndAuthors = {
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:1603589082",
					},
				},
				["Book:0735211280"] = {
					__typename = "Book",
					author = {
						__ref = "Author:Juli Berwald",
					},
					title = "Spineless",
				},
				["Author:Juli Berwald"] = {
					__typename = "Author",
					name = "Juli Berwald",
				},
				["Book:1603589082"] = {
					__typename = "Book",
					author = {
						__ref = "Author:Ben Goldfarb",
					},
					title = "Eager",
				},
				["Author:Ben Goldfarb"] = {
					__typename = "Author",
					name = "Ben Goldfarb",
				},
			}

			jestExpect(cache:extract(true)).toEqual(snapshotWithBothBooksAndAuthors)

			jestExpect(cache:retain("Book:0735211280")).toBe(1)

			jestExpect(cache:gc()).toEqual({})

			jestExpect(cache:retain("Author:Juli Berwald")).toBe(1)

			-- ROBLOX TODO: fragments are not supported yet
			-- 	cache:recordOptimisticTransaction(function(proxy)
			-- 		proxy:writeFragment({
			-- 			id = "Author:Juli Berwald",
			-- 			fragment = gql([[

			--   fragment AuthorBooks on Author {
			--     books {
			--       title
			--     }
			--   }
			-- ]]),
			-- 			data = {
			-- 				books = {
			-- 					{
			-- 						__typename = "Book",
			-- 						isbn = "0735211280",
			-- 						title = "Spineless",
			-- 					},
			-- 				},
			-- 			},
			-- 		})
			-- 	end, "juli books")

			-- 	-- Retain the Spineless book on the optimistic layer (for the first time)
			-- 	-- but release it on the root layer.
			-- 	jestExpect(cache:retain("Book:0735211280", true)).toBe(1)
			-- 	jestExpect(cache:release("Book:0735211280")).toBe(0)

			-- 	-- The Spineless book is still protected by the reference from author Juli
			-- 	-- Berwald's optimistically-added author.books field.
			-- 	jestExpect(cache:gc()).toEqual({})

			-- 	local juliBookMeta = {
			-- 		extraRootIds = {
			-- 			"Author:Juli Berwald",
			-- 			"Book:0735211280",
			-- 		},
			-- 	}

			-- 	jestExpect(cache:extract(true)).toEqual({
			-- 		__META = juliBookMeta,
			-- 		ROOT_QUERY = {
			-- 			__typename = "Query",
			-- 			book = {
			-- 				__ref = "Book:1603589082",
			-- 			},
			-- 		},
			-- 		["Book:0735211280"] = {
			-- 			__typename = "Book",
			-- 			author = {
			-- 				__ref = "Author:Juli Berwald",
			-- 			},
			-- 			title = "Spineless",
			-- 		},
			-- 		["Author:Juli Berwald"] = {
			-- 			__typename = "Author",
			-- 			name = "Juli Berwald",
			-- 			-- Note this extra optimistic field.
			-- 			books = { {
			-- 				__ref = "Book:0735211280",
			-- 			} },
			-- 		},
			-- 		["Book:1603589082"] = {
			-- 			__typename = "Book",
			-- 			author = {
			-- 				__ref = "Author:Ben Goldfarb",
			-- 			},
			-- 			title = "Eager",
			-- 		},
			-- 		["Author:Ben Goldfarb"] = {
			-- 			__typename = "Author",
			-- 			name = "Ben Goldfarb",
			-- 		},
			-- 	})

			-- 	local juliMeta = {
			-- 		extraRootIds = {
			-- 			"Author:Juli Berwald",
			-- 		},
			-- 	}

			-- 	-- A non-optimistic snapshot will not have the extra books field.
			-- 	jestExpect(cache:extract(false)).toEqual(
			-- 		Object.assign({}, snapshotWithBothBooksAndAuthors, { __META = juliMeta })
			-- 	)

			-- 	cache:removeOptimistic("juli books")

			-- 	-- The optimistic books field is gone now that we've removed the optimistic
			-- 	-- layer that added it.
			-- 	jestExpect(cache:extract(true)).toEqual(
			-- 		Object.assign({}, snapshotWithBothBooksAndAuthors, { __META = juliMeta })
			-- 	)

			-- 	-- The Spineless book is no longer retained or kept alive by any other root
			-- 	-- IDs, so it can finally be collected.
			-- 	jestExpect(cache:gc()).toEqual({
			-- 		"Book:0735211280",
			-- 	})

			-- 	jestExpect(cache:release("Author:Juli Berwald")).toBe(0)

			-- 	-- Now that Juli Berwald's author entity is no longer retained, garbage
			-- 	-- collection cometh for her. Look out, Juli!
			-- 	jestExpect(cache:gc()).toEqual({
			-- 		"Author:Juli Berwald",
			-- 	})

			-- 	jestExpect(cache:gc()).toEqual({})
		end)

		it("allows cache eviction", function()
			local ref = newBookAuthorCache()
			local cache, query = ref.cache, ref.query

			local cuckoosCallingBook = {
				__typename = "Book",
				isbn = "031648637X",
				title = "The Cuckoo's Calling",
				author = {
					__typename = "Author",
					name = "Robert Galbraith",
				},
			}

			jestExpect(cache:identify(cuckoosCallingBook)).toBe("Book:031648637X")

			cache:writeQuery({
				query = query,
				data = {
					book = cuckoosCallingBook,
				},
			})

			jestExpect(cache:evict({ id = "Author:J.K. Rowling" })).toBe(false)

			-- ROBLOX TODO: fragments are not supported yet
			-- 		local bookAuthorFragment = gql([[

			--   fragment BookAuthor on Book {
			--     author {
			--       name
			--     }
			--   }
			-- ]])

			-- 		local fragmentResult = cache:readFragment({
			-- 			id = cache:identify(cuckoosCallingBook) :: any,
			-- 			fragment = bookAuthorFragment,
			-- 		})

			-- 		jestExpect(fragmentResult).toEqual({
			-- 			__typename = "Book",
			-- 			author = {
			-- 				__typename = "Author",
			-- 				name = "Robert Galbraith",
			-- 			},
			-- 		})

			-- 		cache:recordOptimisticTransaction(function(proxy)
			-- 			proxy:writeFragment({
			-- 				id = cache:identify(cuckoosCallingBook) :: any,
			-- 				fragment = bookAuthorFragment,
			-- 				data = Object.assign({}, fragmentResult, {
			-- 					author = {
			-- 						__typename = "Author",
			-- 						name = "J.K. Rowling",
			-- 					},
			-- 				}),
			-- 			})
			-- 		end, "real name")

			-- 		local snapshotWithBothNames = {
			-- 			ROOT_QUERY = {
			-- 				__typename = "Query",
			-- 				book = {
			-- 					__ref = "Book:031648637X",
			-- 				},
			-- 			},
			-- 			["Book:031648637X"] = {
			-- 				__typename = "Book",
			-- 				author = {
			-- 					__ref = "Author:J.K. Rowling",
			-- 				},
			-- 				title = "The Cuckoo's Calling",
			-- 			},
			-- 			["Author:Robert Galbraith"] = {
			-- 				__typename = "Author",
			-- 				name = "Robert Galbraith",
			-- 			},
			-- 			["Author:J.K. Rowling"] = {
			-- 				__typename = "Author",
			-- 				name = "J.K. Rowling",
			-- 			},
			-- 		}

			-- 		local cuckooMeta = {
			-- 			extraRootIds = {
			-- 				"Book:031648637X",
			-- 			},
			-- 		}

			-- 		jestExpect(cache:extract(true)).toEqual(Object.assign({}, snapshotWithBothNames, { __META = cuckooMeta }))

			-- 		jestExpect(cache:gc()).toEqual({})

			-- 		jestExpect(cache:retain("Author:Robert Galbraith")).toBe(1)

			-- 		jestExpect(cache:gc()).toEqual({})

			-- 		jestExpect(cache:evict({ id = "Author:Robert Galbraith" })).toBe(true)

			-- 		jestExpect(cache:gc()).toEqual({})

			-- 		cache:removeOptimistic("real name")

			-- 		local robertMeta = {
			-- 			extraRootIds = {
			-- 				"Author:Robert Galbraith",
			-- 			},
			-- 		}

			-- 		jestExpect(cache:extract(true)).toEqual({
			-- 			__META = robertMeta,
			-- 			ROOT_QUERY = {
			-- 				__typename = "Query",
			-- 				book = {
			-- 					__ref = "Book:031648637X",
			-- 				},
			-- 			},
			-- 			["Book:031648637X"] = {
			-- 				__typename = "Book",
			-- 				author = {
			-- 					__ref = "Author:Robert Galbraith",
			-- 				},
			-- 				title = "The Cuckoo's Calling",
			-- 			},
			-- 			-- The Robert Galbraith Author record is no longer here because
			-- 			-- cache.evict evicts data from all EntityStore layers.
			-- 		})

			-- 		cache:writeFragment({
			-- 			id = cache:identify(cuckoosCallingBook) :: any,
			-- 			fragment = bookAuthorFragment,
			-- 			data = Object.assign({}, fragmentResult, {
			-- 				author = {
			-- 					__typename = "Author",
			-- 					name = "J.K. Rowling",
			-- 				},
			-- 			}),
			-- 		})

			-- 		local cuckooRobertMeta = Object.assign({}, cuckooMeta, robertMeta, {
			-- 			extraRootIds = Array.sort(Array.concat({}, cuckooMeta.extraRootIds, robertMeta.extraRootIds)),
			-- 		})

			-- 		jestExpect(cache:extract(true)).toEqual({
			-- 			__META = cuckooRobertMeta,
			-- 			ROOT_QUERY = {
			-- 				__typename = "Query",
			-- 				book = {
			-- 					__ref = "Book:031648637X",
			-- 				},
			-- 			},
			-- 			["Book:031648637X"] = {
			-- 				__typename = "Book",
			-- 				author = {
			-- 					__ref = "Author:J.K. Rowling",
			-- 				},
			-- 				title = "The Cuckoo's Calling",
			-- 			},
			-- 			["Author:J.K. Rowling"] = {
			-- 				__typename = "Author",
			-- 				name = "J.K. Rowling",
			-- 			},
			-- 		})

			-- 		jestExpect(cache:retain("Author:Robert Galbraith")).toBe(2)

			-- 		jestExpect(cache:gc()).toEqual({})

			-- 		jestExpect(cache:release("Author:Robert Galbraith")).toBe(1)
			-- 		jestExpect(cache:release("Author:Robert Galbraith")).toBe(0)

			-- 		jestExpect(cache:gc()).toEqual({})
			-- 		local function checkFalsyEvictId(id: any)
			-- 			jestExpect(id).toBeFalsy()
			-- 			jestExpect(cache:evict({
			-- 				-- Accidentally passing a falsy/undefined options.id to
			-- 				-- cache.evict (perhaps because cache.identify failed) should
			-- 				-- *not* cause the ROOT_QUERY object to be evicted! In order for
			-- 				-- cache.evict to default to ROOT_QUERY, the options.id property
			-- 				-- must be *absent* (not just undefined).
			-- 				id = id,
			-- 			})).toBe(false)
			-- 		end
			-- 		checkFalsyEvictId(nil)
			-- 		checkFalsyEvictId(nil) -- ROBLOX NOTE: null
			-- 		checkFalsyEvictId(false)
			-- 		checkFalsyEvictId(0)
			-- 		checkFalsyEvictId("")

			-- 		-- In other words, this is how you evict the entire ROOT_QUERY
			-- 		-- object. If you're ever tempted to do this, you probably want to use
			-- 		-- cache.clear() instead, but evicting the ROOT_QUERY should work.
			-- 		jestExpect(cache:evict({})).toBe(true)

			-- 		jestExpect(cache:extract(true)).toEqual({
			-- 			__META = cuckooMeta,
			-- 			["Book:031648637X"] = {
			-- 				__typename = "Book",
			-- 				author = {
			-- 					__ref = "Author:J.K. Rowling",
			-- 				},
			-- 				title = "The Cuckoo's Calling",
			-- 			},
			-- 			["Author:J.K. Rowling"] = {
			-- 				__typename = "Author",
			-- 				name = "J.K. Rowling",
			-- 			},
			-- 		})

			-- 		local ccId = cache:identify(cuckoosCallingBook) :: any
			-- 		jestExpect(cache:retain(ccId)).toBe(2)
			-- 		jestExpect(cache:release(ccId)).toBe(1)
			-- 		jestExpect(cache:release(ccId)).toBe(0)

			-- 		jestExpect(Array.sort(cache:gc())).toEqual({
			-- 			"Author:J.K. Rowling",
			-- 			ccId,
			-- 		})
		end)

		it("ignores retainment count for ROOT_QUERY", function()
			local ref = newBookAuthorCache()
			local cache, query = ref.cache, ref.query

			cache:writeQuery({
				query = query,
				data = {
					book = {
						__typename = "Book",
						isbn = "1982156945",
						title = "Solutions and Other Problems",
						author = {
							__typename = "Author",
							name = "Allie Brosh",
						},
					},
				},
			})

			local allieId = cache:identify({
				__typename = "Author",
				name = "Allie Brosh",
			}) :: any
			jestExpect(allieId).toBe("Author:Allie Brosh")
			jestExpect(cache:retain(allieId)).toBe(1)

			local snapshot = cache:extract()
			jestExpect(snapshot).toMatchSnapshot()

			jestExpect(cache:gc()).toEqual({})

			local cache2 = newBookAuthorCache().cache
			cache2:restore(snapshot)

			jestExpect(cache2:extract()).toEqual(snapshot)

			jestExpect(cache2:gc()).toEqual({})

			-- Evicting the whole ROOT_QUERY object is probably a terrible idea in
			-- any real application, but it's worthwhile to test that eviction is
			-- stronger than retainment.
			jestExpect(cache2:evict({
				id = "ROOT_QUERY",
			})).toBe(true)

			jestExpect(Array.sort(cache2:gc())).toEqual({
				"Book:1982156945",
			})

			jestExpect(cache2:extract()).toMatchSnapshot()

			jestExpect(cache2:release(allieId)).toBe(0)

			jestExpect(Array.sort(cache2:gc())).toEqual({
				"Author:Allie Brosh",
			})

			jestExpect(cache2:extract()).toEqual({})
		end)

		it("cache.gc is not confused by StoreObjects with stray __ref fields", function()
			local cache = InMemoryCache.new({ typePolicies = { Person = { keyFields = { "name" } } } })

			local query = gql([[
			
				query {
				  parent {
					name
					child {
					  name
					}
				  }
				}
			  ]])

			local data = {
				parent = {
					__typename = "Person",
					name = "Will Smith",
					child = { __typename = "Person", name = "Jaden Smith" },
				},
			}

			cache:writeQuery({ query = query, data = data })

			jestExpect(cache:gc()).toEqual({})

			local willId = cache:identify(data.parent) :: string
			local store = cache["data"]
			local storeRootData = store["data"];
			-- Hacky way of injecting a stray __ref field into the Will Smith Person
			-- object, clearing store.refs (which was populated by the previous GC).
			(storeRootData[willId] :: any).__ref = willId
			store["refs"] = {}

			jestExpect(cache:extract()).toEqual({
				['Person:{"name":"Jaden Smith"}'] = {
					__typename = "Person",
					name = "Jaden Smith",
				},
				['Person:{"name":"Will Smith"}'] = {
					__typename = "Person",
					name = "Will Smith",
					child = {
						__ref = 'Person:{"name":"Jaden Smith"}',
					},
					-- This is the bogus line that makes this Person object look like a
					-- Reference object to the garbage collector.
					__ref = 'Person:{"name":"Will Smith"}',
				},
				ROOT_QUERY = { __typename = "Query", parent = { __ref = 'Person:{"name":"Will Smith"}' } },
			})

			-- Ensure the garbage collector is not confused by the stray __ref.
			jestExpect(cache:gc()).toEqual({})
		end)

		it("allows evicting specific fields", function()
			local query: DocumentNode = gql([[

      query {
        authorOfBook(isbn: $isbn) {
          name
          hobby
        }
        publisherOfBook(isbn: $isbn) {
          name
          yearOfFounding
        }
      }
    ]])

			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							authorOfBook = {
								keyArgs = { "isbn" },
							},
						},
					},
					Author = {
						keyFields = { "name" },
					},
					Publisher = {
						keyFields = { "name" },
					},
				},
			})

			local TedChiangData = {
				__typename = "Author",
				name = "Ted Chiang",
				hobby = "video games",
			}

			local KnopfData = {
				__typename = "Publisher",
				name = "Alfred A. Knopf",
				yearOfFounding = 1915,
			}

			cache:writeQuery({
				query = query,
				data = {
					authorOfBook = TedChiangData,
					publisherOfBook = KnopfData,
				},
				variables = {
					isbn = "1529014514",
				},
			})

			local justTedRootQueryData = {
				__typename = "Query",
				['authorOfBook:{"isbn":"1529014514"}'] = {
					__ref = 'Author:{"name":"Ted Chiang"}',
				},
				-- This storeFieldName format differs slightly from that of
				-- authorOfBook because we did not define keyArgs for the
				-- publisherOfBook field, so the legacy storeKeyNameFromField
				-- function was used instead.
				['publisherOfBook({"isbn":"1529014514"})'] = {
					__ref = 'Publisher:{"name":"Alfred A. Knopf"}',
				},
			}

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = justTedRootQueryData,
				['Author:{"name":"Ted Chiang"}'] = TedChiangData,
				['Publisher:{"name":"Alfred A. Knopf"}'] = KnopfData,
			})

			local JennyOdellData = {
				__typename = "Author",
				name = "Jenny Odell",
				hobby = "birding",
			}

			local MelvilleData = {
				__typename = "Publisher",
				name = "Melville House",
				yearOfFounding = 2001,
			}

			cache:writeQuery({
				query = query,
				data = {
					authorOfBook = JennyOdellData,
					publisherOfBook = MelvilleData,
				},
				variables = { isbn = "1760641790" },
			})

			local justJennyRootQueryData = {
				__typename = "Query",
				['authorOfBook:{"isbn":"1760641790"}'] = {
					__ref = 'Author:{"name":"Jenny Odell"}',
				},
				['publisherOfBook({"isbn":"1760641790"})'] = {
					__ref = 'Publisher:{"name":"Melville House"}',
				},
			}

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = Object.assign({}, justTedRootQueryData, justJennyRootQueryData),
				['Author:{"name":"Ted Chiang"}'] = TedChiangData,
				['Publisher:{"name":"Alfred A. Knopf"}'] = KnopfData,
				['Author:{"name":"Jenny Odell"}'] = JennyOdellData,
				['Publisher:{"name":"Melville House"}'] = MelvilleData,
			})

			local fullTedResult = cache:readQuery({
				query = query,
				variables = {
					isbn = "1529014514",
				},
			})

			jestExpect(fullTedResult).toEqual({
				authorOfBook = TedChiangData,
				publisherOfBook = KnopfData,
			})

			local fullJennyResult = cache:readQuery({
				query = query,
				variables = {
					isbn = "1760641790",
				},
			})

			jestExpect(fullJennyResult).toEqual({
				authorOfBook = JennyOdellData,
				publisherOfBook = MelvilleData,
			})

			cache:evict({
				id = cache:identify({
					__typename = "Publisher",
					name = "Alfred A. Knopf",
				}) :: any,
				fieldName = "yearOfFounding",
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = Object.assign({}, justTedRootQueryData, justJennyRootQueryData),
				['Author:{"name":"Ted Chiang"}'] = TedChiangData,
				['Publisher:{"name":"Alfred A. Knopf"}'] = {
					__typename = "Publisher",
					name = "Alfred A. Knopf",
					-- yearOfFounding has been removed
				},
				['Author:{"name":"Jenny Odell"}'] = JennyOdellData,
				['Publisher:{"name":"Melville House"}'] = MelvilleData,
			})

			-- Nothing to garbage collect yet.
			jestExpect(cache:gc()).toEqual({})

			cache:evict({
				id = cache:identify({
					__typename = "Publisher",
					name = "Melville House",
				}) :: any,
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = Object.assign({}, justTedRootQueryData, justJennyRootQueryData),
				['Author:{"name":"Ted Chiang"}'] = TedChiangData,
				['Publisher:{"name":"Alfred A. Knopf"}'] = {
					__typename = "Publisher",
					name = "Alfred A. Knopf",
				},
				['Author:{"name":"Jenny Odell"}'] = JennyOdellData,
				-- Melville House has been removed
			})

			cache:evict({ id = "ROOT_QUERY", fieldName = "publisherOfBook" })

			local function withoutPublisherOfBook(obj: Record<string, any>)
				local clean = Object.assign({}, obj)
				Array.forEach(Object.keys(obj), function(key)
					if Boolean.toJSBoolean(String.startsWith(key, "publisherOfBook")) then
						clean[tostring(key)] = nil
					end
				end)
				return clean
			end

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = Object.assign(
					{},
					withoutPublisherOfBook(justTedRootQueryData),
					withoutPublisherOfBook(justJennyRootQueryData)
				),
				['Author:{"name":"Ted Chiang"}'] = TedChiangData,
				['Publisher:{"name":"Alfred A. Knopf"}'] = {
					__typename = "Publisher",
					name = "Alfred A. Knopf",
				},
				['Author:{"name":"Jenny Odell"}'] = JennyOdellData,
			})

			jestExpect(cache:gc()).toEqual({
				'Publisher:{"name":"Alfred A. Knopf"}',
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = Object.assign(
					{},
					withoutPublisherOfBook(justTedRootQueryData),
					withoutPublisherOfBook(justJennyRootQueryData)
				),
				['Author:{"name":"Ted Chiang"}'] = TedChiangData,
				['Author:{"name":"Jenny Odell"}'] = JennyOdellData,
			})

			local partialTedResult = cache:diff({
				query = query,
				returnPartialData = true,
				optimistic = false, -- required but not important
				variables = {
					isbn = "1529014514",
				},
			})
			jestExpect(partialTedResult.complete).toBe(false)
			jestExpect(partialTedResult.result).toEqual({
				authorOfBook = TedChiangData,
			})
			-- The result caching system preserves the referential identity of
			-- unchanged nested result objects.
			jestExpect(partialTedResult.result.authorOfBook).toBe(fullTedResult.authorOfBook)

			local partialJennyResult = cache:diff({
				query = query,
				returnPartialData = true,
				optimistic = true, -- required but not important
				variables = {
					isbn = "1760641790",
				},
			})
			jestExpect(partialJennyResult.complete).toBe(false)
			jestExpect(partialJennyResult.result).toEqual({
				authorOfBook = JennyOdellData,
			})
			-- The result caching system preserves the referential identity of
			-- unchanged nested result objects.
			jestExpect(partialJennyResult.result.authorOfBook).toBe(fullJennyResult.authorOfBook)

			local tedWithoutHobby = {
				__typename = "Author",
				name = "Ted Chiang",
			}

			cache:evict({
				id = cache:identify(tedWithoutHobby) :: any,
				fieldName = "hobby",
			})

			-- ROBLOX deviation: extract a variable to overwrite stack properties with jestExpect.anything() so that they don't cause failures
			local expected = {
				complete = false,
				result = { authorOfBook = tedWithoutHobby },
				missing = {
					MissingFieldError.new(
						'Can\'t find field \'hobby\' on Author:{"name":"Ted Chiang"} object',
						{ "authorOfBook", "hobby" },
						jestExpect.anything(),
						jestExpect.anything()
					),
					MissingFieldError.new(
						"Can't find field 'publisherOfBook' on ROOT_QUERY object",
						{ "publisherOfBook" },
						jestExpect.anything(),
						jestExpect.anything()
					),
				},
			}
			-- ROBLOX deviation: assign jestExpect.anything() to avoid comparing stacks
			expected.missing[1].stack = jestExpect.anything()
			expected.missing[2].stack = jestExpect.anything()
			jestExpect(cache:diff({
				query = query,
				returnPartialData = true,
				optimistic = false, -- required but not important
				variables = {
					isbn = "1529014514",
				},
			})).toEqual(expected)

			cache:evict({ id = "ROOT_QUERY", fieldName = "authorOfBook" })
			jestExpect(Array.sort(cache:gc())).toEqual({
				'Author:{"name":"Jenny Odell"}',
				'Author:{"name":"Ted Chiang"}',
			})
			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					-- Everything else has been removed.
					__typename = "Query",
				},
			})
		end)

		it("allows evicting specific fields with specific arguments", function()
			local query: DocumentNode = gql([[

      query {
        authorOfBook(isbn: $isbn) {
          name
          hobby
        }
      }
    ]])

			local cache = InMemoryCache.new()

			local TedChiangData = {
				__typename = "Author",
				name = "Ted Chiang",
				hobby = "video games",
			}

			local IsaacAsimovData = {
				__typename = "Author",
				name = "Isaac Asimov",
				hobby = "chemistry",
			}

			local JamesCoreyData = {
				__typename = "Author",
				name = "James S.A. Corey",
				hobby = "tabletop games",
			}

			cache:writeQuery({
				query = query,
				data = {
					authorOfBook = TedChiangData,
				},
				variables = {
					isbn = "1",
				},
			})

			cache:writeQuery({
				query = query,
				data = {
					authorOfBook = IsaacAsimovData,
				},
				variables = {
					isbn = "2",
				},
			})

			cache:writeQuery({
				query = query,
				data = {
					authorOfBook = JamesCoreyData,
				},
				variables = {},
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['authorOfBook({"isbn":"1"})'] = {
						__typename = "Author",
						name = "Ted Chiang",
						hobby = "video games",
					},
					['authorOfBook({"isbn":"2"})'] = {
						__typename = "Author",
						name = "Isaac Asimov",
						hobby = "chemistry",
					},
					--[[
						ROBLOX deviation: in Lua we can't distinguish between empty arrays, and objects.
						empty variables will be serialized to "[]"
					]]
					["authorOfBook([])"] = {
						__typename = "Author",
						name = "James S.A. Corey",
						hobby = "tabletop games",
					},
				},
			})

			cache:evict({
				fieldName = "authorOfBook",
				args = { isbn = "1" },
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['authorOfBook({"isbn":"2"})'] = {
						__typename = "Author",
						name = "Isaac Asimov",
						hobby = "chemistry",
					},
					--[[
						ROBLOX deviation: in Lua we can't distinguish between empty arrays, and objects.
						empty variables will be serialized to "[]"
					]]
					["authorOfBook([])"] = {
						__typename = "Author",
						name = "James S.A. Corey",
						hobby = "tabletop games",
					},
				},
			})

			cache:evict({
				fieldName = "authorOfBook",
				args = { isbn = "3" },
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['authorOfBook({"isbn":"2"})'] = {
						__typename = "Author",
						name = "Isaac Asimov",
						hobby = "chemistry",
					},
					--[[
						ROBLOX deviation: in Lua we can't distinguish between empty arrays, and objects.
						empty variables will be serialized to "[]"
					]]
					["authorOfBook([])"] = {
						__typename = "Author",
						name = "James S.A. Corey",
						hobby = "tabletop games",
					},
				},
			})

			cache:evict({
				fieldName = "authorOfBook",
				args = {},
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['authorOfBook({"isbn":"2"})'] = {
						__typename = "Author",
						name = "Isaac Asimov",
						hobby = "chemistry",
					},
				},
			})

			cache:evict({
				fieldName = "authorOfBook",
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
				},
			})
		end)

		it("allows evicting specific fields with specific arguments using EvictOptions", function()
			local query: DocumentNode = gql([[

      query {
        authorOfBook(isbn: $isbn) {
          name
          hobby
        }
      }
    ]])

			local cache = InMemoryCache.new()

			local TedChiangData = {
				__typename = "Author",
				name = "Ted Chiang",
				hobby = "video games",
			}

			local IsaacAsimovData = {
				__typename = "Author",
				name = "Isaac Asimov",
				hobby = "chemistry",
			}

			local JamesCoreyData = {
				__typename = "Author",
				name = "James S.A. Corey",
				hobby = "tabletop games",
			}

			cache:writeQuery({
				query = query,
				data = {
					authorOfBook = TedChiangData,
				},
				variables = {
					isbn = "1",
				},
			})

			cache:writeQuery({
				query = query,
				data = {
					authorOfBook = IsaacAsimovData,
				},
				variables = {
					isbn = "2",
				},
			})

			cache:writeQuery({
				query = query,
				data = {
					authorOfBook = JamesCoreyData,
				},
				variables = {},
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['authorOfBook({"isbn":"1"})'] = {
						__typename = "Author",
						name = "Ted Chiang",
						hobby = "video games",
					},
					['authorOfBook({"isbn":"2"})'] = {
						__typename = "Author",
						name = "Isaac Asimov",
						hobby = "chemistry",
					},
					--[[
						ROBLOX deviation: in Lua we can't distinguish between empty arrays, and objects.
						empty variables will be serialized to "[]"
					]]
					["authorOfBook([])"] = {
						__typename = "Author",
						name = "James S.A. Corey",
						hobby = "tabletop games",
					},
				},
			})

			cache:evict({
				id = "ROOT_QUERY",
				fieldName = "authorOfBook",
				args = { isbn = "1" },
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['authorOfBook({"isbn":"2"})'] = {
						__typename = "Author",
						name = "Isaac Asimov",
						hobby = "chemistry",
					},
					--[[
						ROBLOX deviation: in Lua we can't distinguish between empty arrays, and objects.
						empty variables will be serialized to "[]"
					]]
					["authorOfBook([])"] = {
						__typename = "Author",
						name = "James S.A. Corey",
						hobby = "tabletop games",
					},
				},
			})

			cache:evict({
				id = "ROOT_QUERY",
				fieldName = "authorOfBook",
				args = { isbn = "3" },
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['authorOfBook({"isbn":"2"})'] = {
						__typename = "Author",
						name = "Isaac Asimov",
						hobby = "chemistry",
					},
					--[[
						ROBLOX deviation: in Lua we can't distinguish between empty arrays, and objects.
						empty variables will be serialized to "[]"
					]]
					["authorOfBook([])"] = {
						__typename = "Author",
						name = "James S.A. Corey",
						hobby = "tabletop games",
					},
				},
			})

			cache:evict({
				id = "ROOT_QUERY",
				fieldName = "authorOfBook",
				args = {},
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['authorOfBook({"isbn":"2"})'] = {
						__typename = "Author",
						name = "Isaac Asimov",
						hobby = "chemistry",
					},
				},
			})

			cache:evict({
				id = "ROOT_QUERY",
				fieldName = "authorOfBook",
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
				},
			})
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("supports cache.identify(reference)", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Task = {
						keyFields = { "uuid" },
					},
				},
			})

			jestExpect(cache:identify(makeReference("oyez"))).toBe("oyez")

			local todoRef = cache:writeFragment({
				fragment = gql("fragment TodoId on Todo { id }"),
				data = {
					__typename = "Todo",
					id = 123,
				},
			})

			jestExpect(isReference(todoRef)).toBe(true)
			jestExpect(cache:identify(todoRef :: any)).toBe("Todo:123")

			local taskRef = cache:writeFragment({
				fragment = gql("fragment TaskId on Task { uuid }"),
				data = {
					__typename = "Task",
					uuid = "eb8cffcc-7a9e-4d8b-a517-7d987bf42138",
				},
			})
			jestExpect(isReference(taskRef)).toBe(true)
			jestExpect(cache:identify(taskRef :: any)).toBe('Task:{"uuid":"eb8cffcc-7a9e-4d8b-a517-7d987bf42138"}')
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP("supports cache.identify(object)", function()
			local queryWithAliases: DocumentNode = gql([[

      query {
        abcs {
          first: a
          second: b
          ...Rest
        }
      }
      fragment Rest on ABCs {
        third: c
      }
    ]])

			local queryWithoutAliases: DocumentNode = gql([[

      query {
        abcs {
          a
          b
          ...Rest
        }
      }
      fragment Rest on ABCs {
        c
      }
    ]])

			local cache = InMemoryCache.new({
				typePolicies = { ABCs = {
					keyFields = { "b", "a", "c" },
				} },
			})

			local ABCs = {
				__typename = "ABCs",
				first = "ay",
				second = "bee",
				third = "see",
			}

			cache:writeQuery({
				query = queryWithAliases,
				data = {
					abcs = ABCs,
				},
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					abcs = {
						__ref = 'ABCs:{"b":"bee","a":"ay","c":"see"}',
					},
				},
				['ABCs:{"b":"bee","a":"ay","c":"see"}'] = {
					__typename = "ABCs",
					a = "ay",
					b = "bee",
					c = "see",
				},
			})

			local resultWithAliases = cache:readQuery({
				query = queryWithAliases,
			})

			jestExpect(resultWithAliases).toEqual({
				abcs = ABCs,
			})

			local resultWithoutAliases = cache:readQuery({
				query = queryWithoutAliases,
			})

			jestExpect(resultWithoutAliases).toEqual({
				abcs = {
					__typename = "ABCs",
					a = "ay",
					b = "bee",
					c = "see",
				},
			})

			jestExpect(cache:identify({
				__typename = "ABCs",
				a = 1,
				b = 2,
				c = 3,
			})).toBe('ABCs:{"b":2,"a":1,"c":3}')

			jestExpect(function()
				return cache:identify(ABCs)
			end).toThrowError("Missing field 'b' while computing key fields")

			jestExpect(cache:readFragment({
				id = cache:identify({
					__typename = "ABCs",
					a = "ay",
					b = "bee",
					c = "see",
				}) :: any,
				fragment = gql([[

        fragment JustB on ABCs {
          b
        }
      ]]),
			})).toEqual({
				__typename = "ABCs",
				b = "bee",
			})

			jestExpect(cache:readQuery({
				query = queryWithAliases,
			})).toBe(resultWithAliases)

			jestExpect(cache:readQuery({
				query = queryWithoutAliases,
			})).toBe(resultWithoutAliases)

			cache:evict({
				id = cache:identify({
					__typename = "ABCs",
					a = "ay",
					b = "bee",
					c = "see",
				}),
			})

			jestExpect(cache:extract()).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					abcs = {
						__ref = 'ABCs:{"b":"bee","a":"ay","c":"see"}',
					},
				},
			})

			local function diff(query: DocumentNode)
				return cache:diff({
					query = query,
					optimistic = true,
					returnPartialData = false,
				})
			end

			jestExpect(cache:readQuery({
				query = queryWithAliases,
			})).toBe(nil)

			jestExpect(function()
				return diff(queryWithAliases)
			end).toThrow(RegExp("Dangling reference to missing ABCs:.* object"))

			jestExpect(cache:readQuery({
				query = queryWithoutAliases,
			})).toBe(nil)

			jestExpect(function()
				return diff(queryWithoutAliases)
			end).toThrow(RegExp("Dangling reference to missing ABCs:.* object"))
		end)

		it("gracefully handles eviction amid optimistic updates", function()
			local cache = InMemoryCache.new()
			local query = gql([[

      query {
        book {
          author {
            name
          }
        }
      }
    ]])

			local function writeInitialData(cache: ApolloCache<any>)
				cache:writeQuery({
					query = query,
					data = {
						book = {
							__typename = "Book",
							id = 1,
							author = {
								__typename = "Author",
								id = 2,
								name = "Geoffrey Chaucer",
							},
						},
					},
				})
			end

			writeInitialData(cache)

			-- Writing data in an optimistic transaction to exercise the
			-- interaction between eviction and optimistic layers.
			cache:recordOptimisticTransaction(function(proxy)
				writeInitialData(proxy)
			end, "initial transaction")

			jestExpect(cache:extract(true)).toEqual({
				["Author:2"] = {
					__typename = "Author",
					id = 2,
					name = "Geoffrey Chaucer",
				},
				["Book:1"] = {
					__typename = "Book",
					id = 1,
					author = { __ref = "Author:2" },
				},
				ROOT_QUERY = {
					__typename = "Query",
					book = { __ref = "Book:1" },
				},
			})

			local authorId = cache:identify({
				__typename = "Author",
				id = 2,
			}) :: any

			jestExpect(cache:evict({ id = authorId })).toBe(true)

			jestExpect(cache:extract(true)).toEqual({
				["Book:1"] = {
					__typename = "Book",
					id = 1,
					author = {
						__ref = "Author:2",
					},
				},
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:1",
					},
				},
			})

			jestExpect(cache:evict({ id = authorId })).toBe(false)

			local missing = {
				MissingFieldError.new(
					"Dangling reference to missing Author:2 object",
					{ "book", "author" },
					jestExpect.anything(), -- query
					jestExpect.anything() -- variables
				),
			}
			-- ROBLOX deviation: assign jestExpect.anything() to avoid comparing stacks
			missing[1].stack = jestExpect.anything()

			jestExpect(cache:diff({
				query = query,
				optimistic = true,
				returnPartialData = true,
			})).toEqual({
				complete = false,
				missing = missing,
				result = {
					book = {
						__typename = "Book",
						author = {},
					},
				},
			})

			cache:removeOptimistic("initial transaction")

			-- The root layer is exposed again once the optimistic layer is
			-- removed, but the Author:2 entity has been evicted from all layers.
			jestExpect(cache:extract(true)).toEqual({
				["Book:1"] = {
					__typename = "Book",
					id = 1,
					author = {
						__ref = "Author:2",
					},
				},
				ROOT_QUERY = {
					__typename = "Query",
					book = {
						__ref = "Book:1",
					},
				},
			})

			jestExpect(cache:diff({
				query = query,
				optimistic = true,
				returnPartialData = true,
			})).toEqual({
				complete = false,
				missing = missing,
				result = {
					book = {
						__typename = "Book",
						author = {},
					},
				},
			})

			writeInitialData(cache)

			jestExpect(cache:diff({
				query = query,
				optimistic = true,
				returnPartialData = true,
			})).toEqual({
				complete = true,
				result = {
					book = {
						__typename = "Book",
						author = {
							__typename = "Author",
							name = "Geoffrey Chaucer",
						},
					},
				},
			})
		end)

		it("supports toReference(obj, true) to persist obj", function()
			-- ROBLOX deviation: predefine variable
			local titlesByISBN: Map<string, string>
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							book = function(_self, _, ref_: FieldFunctionOptions_)
								local args = ref_.args
								local ref = ref_:toReference({
									__typename = "Book",
									isbn = (args :: any).isbn,
								}, true) :: Reference

								jestExpect(ref_:readField("__typename", ref)).toEqual("Book")
								local isbn = ref_:readField("isbn", ref)
								jestExpect(isbn).toEqual((args :: any).isbn)
								jestExpect(ref_:readField("title", ref)).toBe(titlesByISBN:get(isbn :: any))

								return ref
							end,

							books = {
								merge = function(_self, existing: Array<Reference>?, incoming: Array<any>, ref_: ModifierDetails)
									if existing == nil then
										existing = {}
									end

									Array.forEach(incoming, function(book)
										jestExpect(ref_:isReference(book)).toBe(false)
										jestExpect(book.__typename).toBeUndefined()
									end)

									local refs = Array.map(incoming, function(book)
										return ref_:toReference(
											Object.assign({}, {
												__typename = "Book",
												title = titlesByISBN:get(book.isbn),
											}, book),
											true
										) :: Reference
									end)

									Array.forEach(refs, function(ref, i)
										jestExpect(ref_:isReference(ref)).toBe(true)
										jestExpect(ref_:readField("__typename", ref)).toBe("Book")
										local isbn = ref_:readField("isbn", ref)
										jestExpect(typeof(isbn)).toBe("string")
										jestExpect(isbn).toBe(ref_:readField("isbn", incoming[i]))
									end)

									return Array.concat({}, existing, refs)
								end,
							},
						},
					},
					Book = {
						keyFields = { "isbn" },
					},
				},
			})

			local booksQuery = gql([[

      query {
        books {
          isbn
        }
      }
    ]])

			local bookQuery = gql([[

      query {
        book(isbn: $isbn) {
          isbn
          title
        }
      }
    ]])

			titlesByISBN = Map.new({
				{ "9781451673319", "Fahrenheit 451" },
				{ "1603589082", "Eager" },
				{ "1760641790", "How To Do Nothing" },
			})

			cache:writeQuery({
				query = booksQuery,
				data = {
					books = {
						{
							-- Note: intentionally omitting __typename:"Book" here.
							isbn = "9781451673319",
						},
						{
							isbn = "1603589082",
						},
					},
				},
			})

			local twoBookSnapshot = {
				ROOT_QUERY = {
					__typename = "Query",
					books = {
						{ __ref = 'Book:{"isbn":"9781451673319"}' },
						{ __ref = 'Book:{"isbn":"1603589082"}' },
					},
				},
				['Book:{"isbn":"9781451673319"}'] = {
					__typename = "Book",
					isbn = "9781451673319",
					title = "Fahrenheit 451",
				},
				['Book:{"isbn":"1603589082"}'] = {
					__typename = "Book",
					isbn = "1603589082",
					title = "Eager",
				},
			}

			-- Check that the __typenames were appropriately added.
			jestExpect(cache:extract()).toEqual(twoBookSnapshot)

			cache:writeQuery({
				query = booksQuery,
				data = {
					books = { {
						isbn = "1760641790",
					} },
				},
			})

			local threeBookSnapshot = Object.assign({}, twoBookSnapshot, {
				ROOT_QUERY = Object.assign({}, twoBookSnapshot.ROOT_QUERY, {
					books = Array.concat(
						{},
						twoBookSnapshot.ROOT_QUERY.books,
						{ { __ref = 'Book:{"isbn":"1760641790"}' } }
					),
				}),
				['Book:{"isbn":"1760641790"}'] = {
					__typename = "Book",
					isbn = "1760641790",
					title = "How To Do Nothing",
				},
			})

			jestExpect(cache:extract()).toEqual(threeBookSnapshot)

			local howToDoNothingResult = cache:readQuery({
				query = bookQuery,
				variables = { isbn = "1760641790" },
			})
			jestExpect(howToDoNothingResult).toEqual({
				book = { __typename = "Book", isbn = "1760641790", title = "How To Do Nothing" },
			})

			-- Check that reading the query didn't change anything.
			jestExpect(cache:extract()).toEqual(threeBookSnapshot)

			local f451Result = cache:readQuery({
				query = bookQuery,
				variables = {
					isbn = "9781451673319",
				},
			})

			jestExpect(f451Result).toEqual({
				book = {
					__typename = "Book",
					isbn = "9781451673319",
					title = "Fahrenheit 451",
				},
			})

			local cuckoosCallingDiffResult = cache:diff({
				query = bookQuery,
				optimistic = true,
				variables = {
					isbn = "031648637X",
				},
			})

			-- ROBLOX deviation: extract a variable to overwrite stack properties with jestExpect.anything() so that they don't cause failures
			local expected = {
				complete = false,
				result = {
					book = {
						__typename = "Book",
						isbn = "031648637X",
					},
				},
				missing = {
					MissingFieldError.new(
						'Can\'t find field \'title\' on Book:{"isbn":"031648637X"} object',
						{ "book", "title" },
						jestExpect.anything(), -- query
						jestExpect.anything() -- variables
					),
				},
			}
			-- ROBLOX deviation: assign jestExpect.anything() to avoid comparing stacks
			expected.missing[1].stack = jestExpect.anything()

			jestExpect(cuckoosCallingDiffResult).toEqual(expected)

			jestExpect(cache:extract()).toEqual(Object.assign(
				{},
				threeBookSnapshot,
				-- This book was added as a side effect of the read function.
				{ ['Book:{"isbn":"031648637X"}'] = {
					__typename = "Book",
					isbn = "031648637X",
				} }
			))

			local cuckoosCallingId = cache:identify({
				__typename = "Book",
				isbn = "031648637X",
			}) :: any

			jestExpect(cuckoosCallingId).toBe('Book:{"isbn":"031648637X"}')

			cache:writeQuery({
				id = cuckoosCallingId,
				query = gql("{ title }"),
				data = {
					title = "The Cuckoo's Calling",
				},
			})

			local cuckooMeta = {
				extraRootIds = {
					'Book:{"isbn":"031648637X"}',
				},
			}

			jestExpect(cache:extract()).toEqual(Object.assign({}, threeBookSnapshot, {
				__META = cuckooMeta,
				-- This book was added as a side effect of the read function.
				['Book:{"isbn":"031648637X"}'] = {
					__typename = "Book",
					isbn = "031648637X",
					title = "The Cuckoo's Calling",
				},
			}))

			cache:modify({
				id = cuckoosCallingId,
				fields = {
					title = function(_self, title: string, ref_: ModifierDetails)
						local book = {
							__typename = "Book",
							isbn = ref_:readField("isbn"),
							author = "J.K. Rowling",
						}

						-- By not passing true as the second argument to toReference, we
						-- get back a Reference object, but the book.author field is not
						-- persisted into the store.
						local refWithoutAuthor = ref_:toReference(book)
						jestExpect(ref_:isReference(refWithoutAuthor)).toBe(true)
						jestExpect(ref_:readField("author", refWithoutAuthor :: Reference)).toBeUndefined()

						-- Update this very Book entity before we modify its title.
						-- Passing true for the second argument causes the extra
						-- book.author field to be persisted into the store.
						local ref = ref_:toReference(book, true)
						jestExpect(ref_:isReference(ref)).toBe(true)
						jestExpect(ref_:readField("author", ref :: Reference)).toBe("J.K. Rowling")

						-- In fact, readField doesn't need the ref if we're reading from
						-- the same entity that we're modifying.
						jestExpect(ref_:readField("author")).toBe("J.K. Rowling")

						-- Typography matters!
						return Array.join(String.split(title, "'"), "’")
					end,
				},
			})

			jestExpect(cache:extract()).toEqual(Object.assign({}, threeBookSnapshot, {
				__META = cuckooMeta,
				['Book:{"isbn":"031648637X"}'] = {
					__typename = "Book",
					isbn = "031648637X",
					title = "The Cuckoo’s Calling",
					author = "J.K. Rowling",
				},
			}))
		end)

		it("supports toReference(id)", function()
			-- ROBLOX deviation: predefine variable
			local titlesByISBN: Map<string, string>
			local cache = InMemoryCache.new({
				typePolicies = {
					Book = {
						fields = {
							favorited = function(_self, _, ref: ModifierDetails)
								local rootQueryRef = ref:toReference("ROOT_QUERY")
								jestExpect(rootQueryRef).toEqual(makeReference("ROOT_QUERY"))
								local favoritedBooks = ref:readField("favoritedBooks", rootQueryRef)
								return Array.some((favoritedBooks :: any), function(bookRef)
									return ref:readField("isbn") == ref:readField("isbn", bookRef)
								end)
							end,
						},
						keyFields = { "isbn" },
					},
					Query = {
						fields = {
							book = function(_self, _, ref_: FieldFunctionOptions_)
								local args = ref_.args
								local ref = ref_:toReference({
									__typename = "Book",
									isbn = (args :: any).isbn,
									title = titlesByISBN:get((args :: any).isbn),
								}, true)

								return ref
							end,
						},
					},
				},
			})

			cache:writeQuery({
				query = gql([[{
        favoritedBooks {
          isbn
          title
        }
      }]]),
				data = {
					favoritedBooks = {
						{
							__typename = "Book",
							isbn = "9781784295547",
							title = "Shrill",
							author = "Lindy West",
						},
					},
				},
			})

			titlesByISBN = Map.new({
				{ "9780062569714", "Hunger" },
				{ "9781784295547", "Shrill" },
				{ "9780807083109", "Kindred" },
			})

			local bookQuery = gql([[

      query {
        book(isbn: $isbn) {
          isbn
          title
          favorited @client
        }
      }
    ]])

			local shrillResult = cache:readQuery({
				query = bookQuery,
				variables = {
					isbn = "9781784295547",
				},
			})

			jestExpect(shrillResult).toEqual({
				book = {
					__typename = "Book",
					isbn = "9781784295547",
					title = "Shrill",
					favorited = true,
				},
			})

			local kindredResult = cache:readQuery({
				query = bookQuery,
				variables = {
					isbn = "9780807083109",
				},
			})

			jestExpect(kindredResult).toEqual({
				book = {
					__typename = "Book",
					isbn = "9780807083109",
					title = "Kindred",
					favorited = false,
				},
			})
		end)

		it("should not over-invalidate fields with keyArgs", function()
			local isbnsWeHaveRead: Array<string> = {}

			local cache = InMemoryCache.new({
				typePolicies = {
					Query = {
						fields = {
							book = {
								-- The presence of this keyArgs configuration permits the
								-- cache to track result caching dependencies at the level
								-- of individual Books, so writing one Book does not
								-- invalidate other Books with different ISBNs. If the cache
								-- doesn't know which arguments are "important," it can't
								-- make any assumptions about the relationships between
								-- field values with the same field name but different
								-- arguments, so it has to err on the side of invalidating
								-- all Query.book data whenever any Book is written.
								keyArgs = { "isbn" },
								read = function(_self, book, ref: FieldFunctionOptions_)
									local args = ref.args
									table.insert(isbnsWeHaveRead, (args :: any).isbn)
									return Boolean.toJSBoolean(book) and book
										or ref:toReference({
											__typename = "Book",
											isbn = (args :: any).isbn,
										})
								end,
							},
						},
					},
					Book = { keyFields = { "isbn" } },
				},
			})

			local query = gql([[

      query Book($isbn: string) {
        book(isbn: $isbn) {
          title
          isbn
          author {
            name
          }
        }
      }
    ]])

			local diffs: Array<Cache_DiffResult<any>> = {}
			cache:watch({
				query = query,
				optimistic = true,
				variables = {
					isbn = "1449373321",
				},
				callback = function(_self, diff)
					table.insert(diffs, diff)
				end,
			})

			local ddiaData = {
				book = {
					__typename = "Book",
					isbn = "1449373321",
					title = "Designing Data-Intensive Applications",
					author = {
						__typename = "Author",
						name = "Martin Kleppmann",
					},
				},
			}

			jestExpect(isbnsWeHaveRead).toEqual({})

			cache:writeQuery({
				query = query,
				variables = {
					isbn = "1449373321",
				},
				data = ddiaData,
			})

			jestExpect(isbnsWeHaveRead).toEqual({
				"1449373321",
			})

			jestExpect(diffs).toEqual({ {
				complete = true,
				result = ddiaData,
			} })

			local theEndData = {
				book = {
					__typename = "Book",
					isbn = "1982103558",
					title = "The End of Everything",
					author = {
						__typename = "Author",
						name = "Katie Mack",
					},
				},
			}

			cache:writeQuery({
				query = query,
				variables = {
					isbn = "1982103558",
				},
				data = theEndData,
			})

			-- This list does not include the book we just wrote, because the
			-- cache.watch we started above only depends on the Query.book field
			-- value corresponding to the 1449373321 ISBN.
			jestExpect(diffs).toEqual({ {
				complete = true,
				result = ddiaData,
			} })

			-- Likewise, this list is unchanged, because we did not need to read
			-- the 1449373321 Book again after writing the 1982103558 data.
			jestExpect(isbnsWeHaveRead).toEqual({
				"1449373321",
			})

			local theEndResult = cache:readQuery({
				query = query,
				variables = {
					isbn = "1982103558",
				},
				-- TODO It's a regrettable accident of history that cache.readQuery is
				-- non-optimistic by default. Perhaps the default can be swapped to true
				-- in the next major version of Apollo Client.
				optimistic = true,
			})

			jestExpect(theEndResult).toEqual(theEndData)

			jestExpect(isbnsWeHaveRead).toEqual({
				"1449373321",
				"1982103558",
			})

			jestExpect(cache:readQuery({
				query = query,
				variables = {
					isbn = "1449373321",
				},
				optimistic = true,
			})).toBe(diffs[1].result)

			jestExpect(cache:readQuery({
				query = query,
				variables = {
					isbn = "1982103558",
				},
				optimistic = true,
			})).toBe(theEndResult)

			-- Still no additional reads, because both books are cached.
			jestExpect(isbnsWeHaveRead).toEqual({
				"1449373321",
				"1982103558",
			})

			-- Evicting the 1982103558 Book should not invalidate the 1449373321
			-- Book, so diffs and isbnsWeHaveRead should remain unchanged.
			jestExpect(cache:evict({
				id = cache:identify({
					__typename = "Book",
					isbn = "1982103558",
				}),
			})).toBe(true)

			jestExpect(diffs).toEqual({ {
				complete = true,
				result = ddiaData,
			} })

			jestExpect(isbnsWeHaveRead).toEqual({
				"1449373321",
				"1982103558",
			})

			jestExpect(cache:readQuery({
				query = query,
				variables = {
					isbn = "1449373321",
				},
				-- Read this query non-optimistically, to test that the read function
				-- runs again, adding "1449373321" again to isbnsWeHaveRead.
				optimistic = false,
			})).toBe(diffs[1].result)

			jestExpect(isbnsWeHaveRead).toEqual({
				"1449373321",
				"1982103558",
				"1449373321",
			})
		end)

		it("Refuses to merge { __ref } objects as StoreObjects", function()
			local cache = InMemoryCache.new({
				typePolicies = {
					Query = { fields = { book = { keyArgs = { "isbn" } } } },
					Book = {
						keyFields = { "isbn" },
					},
				},
			})

			local store = cache["data"]

			local query = gql([[
			
				query Book($isbn: string) {
				  book(isbn: $isbn) {
					title
				  }
				}
			  ]])

			local data = {
				book = { __typename = "Book", isbn = "1449373321", title = "Designing Data-Intensive Applications" },
			}

			cache:writeQuery({ query = query, data = data, variables = { isbn = data.book.isbn } })

			local bookId = cache:identify(data.book) :: any

			store:merge(bookId, (makeReference(bookId) :: StoreValue) :: StoreObject)

			local snapshot = cache:extract()
			jestExpect(snapshot).toEqual({
				ROOT_QUERY = {
					__typename = "Query",
					['book:{"isbn":"1449373321"}'] = { __ref = 'Book:{"isbn":"1449373321"}' },
				},
				['Book:{"isbn":"1449373321"}'] = {
					__typename = "Book",
					isbn = "1449373321",
					title = "Designing Data-Intensive Applications",
				},
			})

			store:merge((makeReference(bookId) :: StoreValue) :: StoreObject, bookId)

			jestExpect(cache:extract()).toEqual(snapshot)
		end)
	end)
end
