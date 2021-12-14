-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/6f579e/packages/apollo-client/benchmark/index.ts

-- ROBLOX deviation: returning it as function to have control over when to execute it
return function()
	-- This file implements some of the basic benchmarks around
	-- Apollo Client.

	local rootWorkspace = script.Parent
	local apolloClientWorkspace = script.Parent.ApolloClient

	local HttpService = game:GetService("HttpService")

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Boolean = LuauPolyfill.Boolean
	local Error = LuauPolyfill.Error
	local Object = LuauPolyfill.Object
	type Promise<T> = LuauPolyfill.Promise<T>
	local setTimeout = LuauPolyfill.setTimeout
	local clearTimeout = LuauPolyfill.clearTimeout
	local console = LuauPolyfill.console

	type Array<T> = LuauPolyfill.Array<T>
	type Error = LuauPolyfill.Error
	type Object = LuauPolyfill.Object

	local Promise = require(rootWorkspace.Promise)

	-- ROBLOX FIXME: remove if better solution is found
	type FIX_ANALYZE = any

	local gql = require(rootWorkspace.GraphQLTag).default

	local utilModule = require(script.util)
	local group = utilModule.group
	type DescriptionObject = utilModule.DescriptionObject
	local dataIdFromObject = utilModule.dataIdFromObject

	local apolloClientModule = require(apolloClientWorkspace)
	local ApolloClient = apolloClientModule.ApolloClient
	type ApolloQueryResult<T> = apolloClientModule.ApolloQueryResult<T>

	-- ROBLOX deviation START: using custom times and cloneDeep implementation
	local function identity<T>(x: T): T
		return x
	end
	local function times<T>(n: number, iteratee_: ((n: number) -> ...T)?): Array<T>
		local iteratee: (n: number) -> ...T = identity :: FIX_ANALYZE
		if iteratee_ ~= nil then
			iteratee = iteratee_
		end

		local result = {} :: Array<T>
		for i = 0, n - 1 do
			local iterateeResult = iteratee(i)
			if iterateeResult then
				table.insert(result, iterateeResult :: FIX_ANALYZE)
			end
		end
		return result
	end
	local cloneDeep = require(rootWorkspace.ApolloClient.utilities.common.cloneDeep).cloneDeep
	-- ROBLOX deviation END

	local InMemoryCache = require(apolloClientWorkspace.cache).InMemoryCache

	local apolloLinkModule = require(apolloClientWorkspace.link.core)
	type Operation = apolloLinkModule.Operation
	local ApolloLink = apolloLinkModule.ApolloLink
	type ApolloLink = apolloLinkModule.ApolloLink
	type FetchResult___ = apolloLinkModule.FetchResult___
	local utilitiesModule = require(apolloClientWorkspace.utilities)
	local Observable = utilitiesModule.Observable

	local print_ = require(rootWorkspace.GraphQL).print

	local collectAndReportBenchmarks = require(script["github-reporter"]).collectAndReportBenchmarks

	type MockedResponse = {
		request: Operation,
		result: FetchResult___?,
		error_: Error?,
		delay: number?,
	}

	-- ROBLOX deviation predefine variable
	local MockLink

	local function mockSingleLink(...): ApolloLink
		local mockedResponses = { ... }
		return MockLink.new(mockedResponses)
	end

	local function requestToKey(request: Operation): string
		local queryString: string | nil = nil
		if request.query then
			queryString = (print_(request.query) :: FIX_ANALYZE) :: string | nil
		end
		return HttpService:JSONEncode({
			variables = request.variables or {},
			query = queryString,
		})
	end

	type MockLink = {
		addMockedResponse: (self: MockLink, mockedResponse: MockedResponse) -> (),
		request: (self: MockLink, operation: Operation) -> any,
	} & ApolloLink

	MockLink = setmetatable({}, { __index = ApolloLink })
	MockLink.__index = MockLink

	function MockLink.new(mockedResponses: Array<MockedResponse>): MockLink
		local self = setmetatable(ApolloLink.new(), MockLink) :: any
		self.mockedResponsesByKey = {}
		Array.forEach(mockedResponses, function(mockedResponse)
			self:addMockedResponse(mockedResponse)
		end)
		return self :: MockLink
	end

	function MockLink:addMockedResponse(mockedResponse: MockedResponse): ()
		local key = requestToKey(mockedResponse.request)
		local mockedResponses = self.mockedResponsesByKey[key]
		if not mockedResponses then
			mockedResponses = {}
			self.mockedResponsesByKey[key] = mockedResponses
		end
		table.insert(mockedResponses, mockedResponse)
	end

	function MockLink:request(operation: Operation): any
		local key = requestToKey(operation)
		local responses = self.mockedResponsesByKey[key]
		if not responses or #responses == 0 then
			error(
				Error.new(
					("No more mocked responses for the query: %s, variables: %s"):format(
						print_(operation.query),
						HttpService:JSONEncode(operation.variables)
					)
				)
			)
		end

		local ref = table.remove(responses, 1) :: any
		local result, error_, delay = ref.result, ref.error, ref.delay
		if not Boolean.toJSBoolean(result) and not Boolean.toJSBoolean(error_) then
			error(Error.new(("Mocked response should contain either result or error: %s"):format(key)))
		end

		return Observable.new(function(observer)
			local timer = setTimeout(function()
				if error_ then
					observer:error(error_)
				else
					if Boolean.toJSBoolean(result) then
						observer:next(result)
					end
					observer:complete()
				end
			end, if Boolean.toJSBoolean(delay) then delay else	0)

			return function()
				clearTimeout(timer)
			end
		end)
	end

	local simpleQuery = gql([[

  query {
    author {
      firstName
      lastName
    }
  }
]])

	local simpleResult = {
		data = {
			author = {
				firstName = "John",
				lastName = "Smith",
			},
		},
	}

	local function getClientInstance()
		local link = mockSingleLink({
			request = { query = simpleQuery } :: Operation,
			result = simpleResult,
		})

		return ApolloClient.new({
			link = link,
			cache = InMemoryCache.new({ addTypename = false }),
		})
	end

	local function createReservations(count: number)
		local reservations: Array<{
			name: string,
			id: string,
		}> = {}
		times(count, function(reservationIndex)
			table.insert(reservations, { name = "Fake Reservation", id = tostring(reservationIndex) })
		end)
		return reservations
	end

	group(function(end_, scope)
		scope.benchmark("baseline", function(done)
			local arr = {}
			for _ = 1, 100 do
				table.insert(arr, math.random())
			end
			Array.sort(arr)
			done()
		end)
		end_()
	end)

	group(function(end_, scope)
		local link = mockSingleLink({
			request = { query = simpleQuery } :: Operation,
			result = simpleResult,
		})

		local cache = InMemoryCache.new()

		scope.benchmark("constructing an instance", function(done)
			ApolloClient.new({ link = link, cache = cache })
			done()
		end)
		end_()
	end)

	group(function(end_, scope)
		scope.benchmark("fetching a query result from mocked server", function(done)
			local client = getClientInstance()
			client:query({ query = simpleQuery }):andThen(function(_)
				done()
			end)
		end)

		end_()
	end)

	group(function(end_, scope)
		scope.benchmark("write data and receive update from the cache", function(done)
			local client = getClientInstance()
			local observable = client:watchQuery({
				query = simpleQuery,
				fetchPolicy = "cache-only",
			})
			observable:subscribe({
				next = function(_self, res: ApolloQueryResult<Object>)
					if #Object.keys(res.data) > 0 then
						done()
					end
				end,
				error = function(_self, _: Error)
					console.warn("Error occurred in observable.")
				end,
			})
			client:query({ query = simpleQuery })
		end)

		end_()
	end)

	group(function(end_, scope)
		-- This benchmark is supposed to check whether the time
		-- taken to deliver updates is linear in the number of subscribers or not.
		-- (Should be linear). When plotting the results from this benchmark,
		-- the `meanTimes` structure can be used.
		local meanTimes: { [string]: number } = {}

		times(4, function(countR)
			local count = 5 * math.pow(4, countR)
			scope.benchmark(
				{ name = ("write data and deliver update to %d subscribers"):format(count), count = count },
				function(done)
					local promises: Array<Promise<nil>> = {}
					local client = getClientInstance()

					times(count, function()
						table.insert(
							promises,
							Promise.new(function(resolve, _)
								client
									:watchQuery({
										query = simpleQuery,
										fetchPolicy = "cache-only",
									})
									:subscribe({
										next = function(_self, res: ApolloQueryResult<Object>)
											if #Object.keys(res.data) > 0 then
												resolve()
											end
										end,
									})
							end)
						)
					end)

					client:query({ query = simpleQuery })
					Promise.all(promises):andThen(function()
						done()
					end)
				end
			)

			-- ROBLOX deviation START: description needs to be `DescriptionObject | string` to make analyze happy
			scope.afterEach(function(description: DescriptionObject | string, event: any)
				if typeof(description) ~= "string" then
					local iterCount = description["count"] :: number
					meanTimes[tostring(iterCount)] = event.target.stats.mean * 1000
				end
			end)
			-- ROBLOX deviation END
		end)
		end_()
	end)

	times(4, function(countR: number)
		local count = 5 * math.pow(4, countR)
		local query = gql([[

    query($id: String) {
      author(id: $id) {
        name
        id
        __typename
      }
    }
  ]])
		local originalResult = {
			data = {
				author = {
					name = "John Smith",
					id = 1,
					__typename = "Author",
				},
			},
		}

		group(function(end_, scope)
			local cache = InMemoryCache.new({
				dataIdFromObject = function(_self, obj: any)
					if obj.id and obj.__typename then
						return obj.__typename .. obj.id
					end
					return nil
				end,
			})

			-- insert a bunch of stuff into the cache
			times(count, function(index)
				local result = cloneDeep(originalResult)
				result.data.author.id = index

				return cache:writeQuery({
					query = query,
					variables = { id = index },
					data = result.data :: any,
				})
			end)

			scope.benchmark({
				name = ("read single item from cache with %d items in cache"):format(count),
				count = count,
			}, function(done)
				local randomIndex = math.floor(math.random() * count)
				cache:readQuery({
					query = query,
					variables = { id = randomIndex },
				})
				done()
			end)

			end_()
		end)
	end)

	-- Measure the amount of time it takes to read a bunch of
	-- objects from the cache.
	times(4, function(index)
		group(function(end_, scope)
			local cache = InMemoryCache.new({
				dataIdFromObject = dataIdFromObject,
				addTypename = false,
			})

			local query = gql([[

      query($id: String) {
        house(id: $id) {
          reservations {
            name
            id
          }
        }
      }
    ]])
			local houseId = "12"
			local reservationCount = 5 * math.pow(4, index)
			local reservations = createReservations(reservationCount)

			local variables = { id = houseId }

			cache:writeQuery({
				query = query,
				variables = variables,
				data = {
					house = {
						reservations = reservations,
					},
				},
			})

			scope.benchmark(
				("read result with %d items associated with the result"):format(reservationCount),
				function(done)
					cache:readQuery({ query = query, variables = variables })
					done()
				end
			)

			end_()
		end)
	end)

	-- Measure only the amount of time it takes to diff a query against the store
	--
	-- This test allows us to differentiate between the fixed cost of .query() and the fixed cost
	-- of actually reading from the store.
	times(4, function(index)
		group(function(end_, scope)
			local reservationCount = 5 * math.pow(4, index)

			-- Prime the cache.
			local query = gql([[

      query($id: String) {
        house(id: $id) {
          reservations {
            name
            id
          }
        }
      }
    ]])
			local variables = { id = "7" }
			local reservations = createReservations(reservationCount)
			local result = {
				house = { reservations = reservations },
			}

			local cache = InMemoryCache.new({
				dataIdFromObject = dataIdFromObject,
				addTypename = false,
			})

			cache:write({
				dataId = "ROOT_QUERY",
				query = query,
				variables = variables,
				result = result,
			})

			-- We only keep track of the results so that V8 doesn't decide to just throw
			-- away our cache read code.
			local _results: any = nil
			scope.benchmark(("diff query against store with %d items"):format(reservationCount), function(done)
				_results = cache:diff({
					query = query,
					variables = variables,
					optimistic = false,
				})
				done()
			end)

			end_()
		end)
	end)

	-- ROBLOX deviation: no process.env.DANGER_GITHUB_API_TOKEN available
	-- if Boolean.toJSBoolean(process.env.DANGER_GITHUB_API_TOKEN) then
	if false then
		collectAndReportBenchmarks(true)
	else
		collectAndReportBenchmarks(false)
	end
end
