--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/optimistic.ts
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Array = LuauPolyfill.Array

type Array<T> = LuauPolyfill.Array<T>

type ReturnType<T> = any

local gql = require(rootWorkspace.GraphQLTag).default
local inMemoryCacheModule = require(script.Parent.Parent.inMemoryCache)
local InMemoryCache = inMemoryCacheModule.InMemoryCache
type InMemoryCache = inMemoryCacheModule.InMemoryCache

describe("optimistic cache layers", function()
	it("return === results for repeated reads", function()
		local cache = InMemoryCache.new({
			resultCaching = true,
			dataIdFromObject = function(_self, value: any)
				local condition = if Boolean.toJSBoolean(value) then value.__typename else value
				if condition == "Book" then
					return "Book:" .. value.isbn
				end
				if condition == "Author" then
					return "Author:" .. tostring(value.name)
				end
				return
			end,
		})

		local query = gql([[

      {
        book {
          title
          author {
            name
          }
        }
      }
    ]])

		local function readOptimistic(cache: InMemoryCache)
			return cache:readQuery({ query = query }, true)
		end

		local function readRealistic(cache: InMemoryCache)
			return cache:readQuery({ query = query }, false)
		end

		cache:writeQuery({
			query = query,
			data = {
				book = {
					__typename = "Book",
					isbn = "1980719802",
					title = "1984",
					author = { __typename = "Author", name = "George Orwell" },
				},
			},
		})

		local result1984 = readOptimistic(cache)
		expect(result1984).toEqual({
			book = {
				__typename = "Book",
				title = "1984",
				author = { __typename = "Author", name = "George Orwell" },
			},
		})

		expect(result1984).toBe(readOptimistic(cache))
		expect(result1984).toBe(readRealistic(cache))

		local result2666InTransaction: ReturnType<typeof(readOptimistic)> | nil = nil
		cache:performTransaction(function(proxy)
			expect(readOptimistic(cache)).toEqual(result1984)

			proxy:writeQuery({
				query = query,
				data = {
					book = {
						__typename = "Book",
						isbn = "0312429215",
						title = "2666",
						author = { __typename = "Author", name = "Roberto Bola\u{F1}o" },
					},
				},
			})

			result2666InTransaction = readOptimistic(proxy)
			expect(result2666InTransaction).toEqual({
				book = {
					__typename = "Book",
					title = "2666",
					author = { __typename = "Author", name = "Roberto Bola\u{F1}o" },
				},
			})
		end, "first")

		expect(readOptimistic(cache)).toBe(result2666InTransaction)

		expect(result1984).toBe(readRealistic(cache))

		local resultCatch22: ReturnType<typeof(readOptimistic)> | nil = nil
		cache:performTransaction(function(proxy)
			proxy:writeQuery({
				query = query,
				data = {
					book = {
						__typename = "Book",
						isbn = "1451626657",
						title = "Catch-22",
						author = { __typename = "Author", name = "Joseph Heller" },
					},
				},
			})

			resultCatch22 = readOptimistic(proxy)
			expect(resultCatch22).toEqual({
				book = {
					__typename = "Book",
					title = "Catch-22",
					author = { __typename = "Author", name = "Joseph Heller" },
				},
			})
		end, "second")

		expect(readOptimistic(cache)).toBe(resultCatch22)

		expect(result1984).toBe(readRealistic(cache))

		cache:removeOptimistic("first")

		expect(readOptimistic(cache)).toBe(resultCatch22)

		-- Write a new book to the root Query.book field, which should not affect
		-- the 'second' optimistic layer that is still applied.
		cache:writeQuery({
			query = query,
			data = {
				book = {
					__typename = "Book",
					isbn = "9781451673319",
					title = "Fahrenheit 451",
					author = { __typename = "Author", name = "Ray Bradbury" },
				},
			},
		})

		expect(readOptimistic(cache)).toBe(resultCatch22)

		local resultF451 = readRealistic(cache)
		expect(resultF451).toEqual({
			book = {
				__typename = "Book",
				title = "Fahrenheit 451",
				author = { __typename = "Author", name = "Ray Bradbury" },
			},
		})

		cache:removeOptimistic("second")

		expect(resultF451).toBe(readRealistic(cache))
		expect(resultF451).toBe(readOptimistic(cache))

		expect(cache:extract(true)).toEqual({
			ROOT_QUERY = { __typename = "Query", book = { __ref = "Book:9781451673319" } },
			["Book:1980719802"] = {
				title = "1984",
				author = { __ref = "Author:George Orwell" },
				__typename = "Book",
			},
			["Book:9781451673319"] = {
				title = "Fahrenheit 451",
				author = { __ref = "Author:Ray Bradbury" },
				__typename = "Book",
			},
			["Author:George Orwell"] = { __typename = "Author", name = "George Orwell" },
			["Author:Ray Bradbury"] = { __typename = "Author", name = "Ray Bradbury" },
		})
	end)

	it("dirties appropriate IDs when optimistic layers are removed", function()
		local cache = InMemoryCache.new({
			resultCaching = true,
			dataIdFromObject = function(_self, value: any)
				local condition = if Boolean.toJSBoolean(value) then value.__typename else value
				if condition == "Book" then
					return "Book:" .. value.isbn
				end
				if condition == "Author" then
					return "Author:" .. value.name
				end
				return
			end,
		})

		type Q = { books: Array<any> }

		local query = gql([[

      {
        books {
          title
          subtitle
        }
      }
    ]])

		local eagerBookData = {
			__typename = "Book",
			isbn = "1603589082",
			title = "Eager",
			subtitle = "The Surprising, Secret Life of Beavers and Why They Matter",
			author = { __typename = "Author", name = "Ben Goldfarb" },
		}

		local spinelessBookData = {
			__typename = "Book",
			isbn = "0735211280",
			title = "Spineless",
			subtitle = "The Science of Jellyfish and the Art of Growing a Backbone",
			author = { __typename = "Author", name = "Juli Berwald" },
		}

		cache:writeQuery({ query = query, data = { books = { eagerBookData, spinelessBookData } } })

		expect(cache:extract(true)).toEqual({
			ROOT_QUERY = {
				__typename = "Query",
				books = { { __ref = "Book:1603589082" }, { __ref = "Book:0735211280" } },
			},
			["Book:1603589082"] = {
				title = "Eager",
				subtitle = eagerBookData.subtitle,
				__typename = "Book",
			},
			["Book:0735211280"] = {
				title = "Spineless",
				subtitle = spinelessBookData.subtitle,
				__typename = "Book",
			},
		})

		local function read()
			return cache:readQuery({ query = query }, true) :: any
		end

		local result = read()
		expect(result).toEqual({
			books = {
				{
					__typename = "Book",
					title = "Eager",
					subtitle = "The Surprising, Secret Life of Beavers and Why They Matter",
				},
				{
					__typename = "Book",
					title = "Spineless",
					subtitle = "The Science of Jellyfish and the Art of Growing a Backbone",
				},
			},
		})
		expect(read()).toBe(result)

		local bookAuthorNameFragment = gql([[

      fragment BookAuthorName on Book {
        author {
          name
        }
      }
    ]])

		cache:writeFragment({
			id = "Book:0735211280",
			fragment = bookAuthorNameFragment,
			data = { author = spinelessBookData.author },
		})

		-- Adding an author doesn't change the structure of the original result,
		-- because the original query did not ask for author information.
		local resultWithSpinlessAuthor = read()
		expect(resultWithSpinlessAuthor).toEqual(result)
		expect(resultWithSpinlessAuthor).toBe(result)
		expect(resultWithSpinlessAuthor.books[1]).toBe(result.books[1])
		expect(resultWithSpinlessAuthor.books[2]).toBe(result.books[2])

		cache:recordOptimisticTransaction(function(proxy)
			proxy:writeFragment({
				id = "Book:1603589082",
				fragment = bookAuthorNameFragment,
				data = { author = eagerBookData.author },
			})
		end, "eager author")

		expect(read()).toEqual(result)

		local queryWithAuthors = gql([[

      {
        books {
          title
          subtitle
          author {
            name
          }
        }
      }
    ]])

		local function readWithAuthors(optimistic: boolean?)
			if optimistic == nil then
				optimistic = true
			end
			return cache:readQuery({ query = queryWithAuthors }, optimistic) :: any
		end

		local function withoutISBN(data: any)
			-- ROBLOX DEVIATION: clone data and nil isbn
			local newData = table.clone(data)
			newData["isbn"] = nil
			return newData
		end

		local resultWithTwoAuthors = readWithAuthors()
		expect(resultWithTwoAuthors).toEqual({
			books = { withoutISBN(eagerBookData), withoutISBN(spinelessBookData) },
		})

		local buzzBookData = {
			__typename = "Book",
			isbn = "0465052614",
			title = "Buzz",
			subtitle = "The Nature and Necessity of Bees",
			author = { __typename = "Author", name = "Thor Hanson" },
		}

		cache:recordOptimisticTransaction(function(proxy)
			proxy:writeQuery({
				query = queryWithAuthors,
				data = { books = { eagerBookData, spinelessBookData, buzzBookData } },
			})
		end, "buzz book")

		local resultWithBuzz = readWithAuthors()

		expect(resultWithBuzz).toEqual({
			books = {
				withoutISBN(eagerBookData),
				withoutISBN(spinelessBookData),
				withoutISBN(buzzBookData),
			},
		})
		expect(resultWithBuzz.books[1]).toEqual(resultWithTwoAuthors.books[1])
		expect(resultWithBuzz.books[2]).toEqual(resultWithTwoAuthors.books[2])

		-- Before removing the Buzz optimistic layer from the cache, write the same
		-- data to the root layer of the cache.
		cache:writeQuery({
			query = queryWithAuthors,
			data = { books = { eagerBookData, spinelessBookData, buzzBookData } },
		})

		expect(readWithAuthors()).toBe(resultWithBuzz)

		local function readSpinelessFragment()
			return cache:readFragment({
				id = "Book:" .. tostring(spinelessBookData.isbn),
				fragment = bookAuthorNameFragment,
			}, true)
		end

		local spinelessBeforeRemovingBuzz = readSpinelessFragment()
		cache:removeOptimistic("buzz book")
		local spinelessAfterRemovingBuzz = readSpinelessFragment()
		expect(spinelessBeforeRemovingBuzz).toEqual(spinelessAfterRemovingBuzz)
		expect(spinelessBeforeRemovingBuzz).toBe(spinelessAfterRemovingBuzz)

		local resultAfterRemovingBuzzLayer = readWithAuthors()
		expect(resultAfterRemovingBuzzLayer).toEqual(resultWithBuzz)
		expect(resultAfterRemovingBuzzLayer).toBe(resultWithBuzz)
		Array.forEach(resultWithTwoAuthors.books, function(book, i)
			expect(book).toEqual(resultAfterRemovingBuzzLayer.books[i])
			expect(book).toBe(resultAfterRemovingBuzzLayer.books[i])
		end)

		local nonOptimisticResult = readWithAuthors(false)
		expect(nonOptimisticResult).toEqual(resultWithBuzz)
		cache:removeOptimistic("eager author")
		local resultWithoutOptimisticLayers = readWithAuthors()
		expect(resultWithoutOptimisticLayers).toBe(nonOptimisticResult)
	end)
end)

return {}
