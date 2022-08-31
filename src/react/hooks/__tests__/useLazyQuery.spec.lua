-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/hooks/__tests__/useLazyQuery.test.tsx

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local setTimeout = LuauPolyfill.setTimeout
local Promise = require(rootWorkspace.Promise)

type Function = (...any) -> ...any

local React = require(rootWorkspace.React)
local graphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphQLModule.DocumentNode
local gql = require(rootWorkspace.GraphQLTag).default
local reactTestingModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = reactTestingModule.render
local wait_ = require(srcWorkspace.testUtils.wait).wait

local ApolloClient = require(srcWorkspace.core).ApolloClient
local InMemoryCache = require(srcWorkspace.cache).InMemoryCache
local ApolloProvider = require(srcWorkspace.react.context).ApolloProvider
local testingModule = require(srcWorkspace.testing)
local itAsync = testingModule.itAsync
local MockedProvider = require(srcWorkspace.utilities.testing.mocking.MockedProvider).MockedProvider
local useLazyQuery = require(srcWorkspace.react.hooks).useLazyQuery

describe("useLazyQuery Hook", function()
	local CAR_QUERY: DocumentNode = gql([[
    query {
      cars {
        make
        model
        vin
      }
    }
  ]])

	local CAR_RESULT_DATA = {
		cars = {
			{
				make = "Audi",
				model = "RS8",
				vin = "DOLLADOLLABILL",
				__typename = "Car",
			},
		},
	}

	local CAR_MOCKS = { {
		request = {
			query = CAR_QUERY,
		},
		result = { data = CAR_RESULT_DATA },
	} }

	it("should hold query execution until manually triggered", function()
		return Promise.resolve()
			:andThen(function()
				local renderCount = 0
				local function Component()
					local ref = useLazyQuery(CAR_QUERY)
					local execute, ref_ = table.unpack(ref, 1, 2)
					local loading, data = ref_.loading, ref_.data
					local condition = renderCount
					if condition == 0 then
						expect(loading).toEqual(false)
						setTimeout(function()
							execute()
						end)
					elseif condition == 1 then
						expect(loading).toEqual(true)
					elseif condition == 2 then
						expect(loading).toEqual(false)
						expect(data).toEqual(CAR_RESULT_DATA)
					else
						-- Do nothing
					end
					renderCount += 1
					return nil
				end

				render(React.createElement(MockedProvider, { mocks = CAR_MOCKS }, React.createElement(Component, nil)))

				return wait_(function()
					expect(renderCount).toBe(3)
				end):expect()
			end)
			:expect()
	end)

	it("should set `called` to false by default", function()
		local function Component()
			local ref = useLazyQuery(CAR_QUERY)
			local _, ref_ = table.unpack(ref, 1, 2)
			local loading, called = ref_.loading, ref_.called
			expect(loading).toBeFalsy()
			expect(called).toBeFalsy()
			return nil
		end
		render(React.createElement(MockedProvider, { mocks = CAR_MOCKS }, React.createElement(Component, nil)))
	end)

	it("should set `called` to true after calling the lazy execute function", function()
		return Promise.resolve()
			:andThen(function()
				local renderCount = 0
				local function Component()
					local ref = useLazyQuery(CAR_QUERY)
					local execute, ref_ = table.unpack(ref, 1, 2)
					local loading, called, data = ref_.loading, ref_.called, ref_.data
					local condition = renderCount
					if condition == 0 then
						expect(loading).toBeFalsy()
						expect(called).toBeFalsy()
						setTimeout(function()
							execute()
						end)
					elseif condition == 1 then
						expect(loading).toBeTruthy()
						expect(called).toBeTruthy()
					elseif condition == 2 then
						expect(loading).toEqual(false)
						expect(called).toBeTruthy()
						expect(data).toEqual(CAR_RESULT_DATA)
					else
						-- Do nothing
					end
					renderCount += 1
					return nil
				end

				render(React.createElement(MockedProvider, { mocks = CAR_MOCKS }, React.createElement(Component, nil)))

				return wait_(function()
					expect(renderCount).toBe(3)
				end):expect()
			end)
			:expect()
	end)

	it("should override `skip` if lazy mode execution function is called", function()
		return Promise.resolve()
			:andThen(function()
				local renderCount = 0
				local function Component()
					local ref = useLazyQuery(CAR_QUERY, {
						skip = true,
					} :: any)
					local execute, ref_ = table.unpack(ref, 1, 2)
					local loading, data = ref_.loading, ref_.data
					local condition = renderCount
					if condition == 0 then
						expect(loading).toBeFalsy()
						setTimeout(function()
							execute()
						end)
					elseif condition == 1 then
						expect(loading).toBeTruthy()
					elseif condition == 2 then
						expect(loading).toEqual(false)
						expect(data).toEqual(CAR_RESULT_DATA)
					else
						-- Do nothing
					end
					renderCount += 1
					return nil
				end

				render(React.createElement(MockedProvider, { mocks = CAR_MOCKS }, React.createElement(Component, nil)))

				return wait_(function()
					expect(renderCount).toBe(3)
				end):expect()
			end)
			:expect()
	end)

	it(
		"should use variables defined in hook options (if any), when running " .. "the lazy execution function",
		function()
			return Promise.resolve()
				:andThen(function()
					local CAR_QUERY: DocumentNode = gql([[

        query AllCars($year: Int!) {
          cars(year: $year) @client {
            make
            year
          }
        }
      ]])

					local CAR_RESULT_DATA = {
						{
							make = "Audi",
							year = 2000,
							__typename = "Car",
						},
						{
							make = "Hyundai",
							year = 2001,
							__typename = "Car",
						},
					}

					local client = ApolloClient.new({
						cache = InMemoryCache.new(),
						resolvers = {
							Query = {
								cars = function(_self, _root, ref)
									local year = ref.year
									return Array.filter(CAR_RESULT_DATA, function(car)
										return car.year == year
									end)
								end,
							},
						},
					})

					local renderCount = 0
					local function Component()
						local ref = useLazyQuery(CAR_QUERY, { variables = { year = 2001 } })
						local execute, ref_ = table.unpack(ref, 1, 2)
						local loading, data = ref_.loading, ref_.data

						if renderCount == 0 then
							expect(loading).toBeFalsy()
							setTimeout(function()
								execute()
							end)
						elseif renderCount == 1 then
							expect(loading).toBeTruthy()
						elseif renderCount == 2 then
							expect(loading).toEqual(false)
							expect(data.cars).toEqual({
								CAR_RESULT_DATA[2],
							})
						else
							-- Do nothing
						end

						renderCount += 1
						return nil
					end

					render(
						React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil))
					)

					return wait_(function()
						expect(renderCount).toBe(3)
					end):expect()
				end)
				:expect()
		end
	)

	it(
		"should use variables passed into lazy execution function, "
			.. "overriding similar variables defined in Hook options",
		function()
			return Promise.resolve()
				:andThen(function()
					local CAR_QUERY: DocumentNode = gql([[

        query AllCars($year: Int!) {
          cars(year: $year) @client {
            make
            year
          }
        }
      ]])

					local CAR_RESULT_DATA = {
						{
							make = "Audi",
							year = 2000,
							__typename = "Car",
						},
						{
							make = "Hyundai",
							year = 2001,
							__typename = "Car",
						},
					}

					local client = ApolloClient.new({
						cache = InMemoryCache.new(),
						resolvers = {
							Query = {
								cars = function(_self, _root, ref)
									local year = ref.year
									return Array.filter(CAR_RESULT_DATA, function(car)
										return car.year == year
									end)
								end,
							},
						},
					})

					local renderCount = 0
					local function Component()
						local ref = useLazyQuery(CAR_QUERY, { variables = { year = 2001 } })
						local execute, lazyQueryState = table.unpack(ref, 1, 2)
						local loading = lazyQueryState.loading
						local data = lazyQueryState.data

						if renderCount == 0 then
							expect(loading).toBeFalsy()
							setTimeout(function()
								execute({ variables = { year = 2000 } })
							end)
						elseif renderCount == 1 then
							expect(loading).toBeTruthy()
						elseif renderCount == 2 then
							expect(loading).toEqual(false)
							expect(data.cars).toEqual({
								CAR_RESULT_DATA[1],
							})
						else
							-- Do nothing
						end

						renderCount += 1
						return nil
					end

					render(
						React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil))
					)

					return wait_(function()
						expect(renderCount).toBe(3)
					end):expect()
				end)
				:expect()
		end
	)

	it(
		"should fetch data each time the execution function is called, when " .. 'using a "network-only" fetch policy',
		function()
			return Promise.resolve()
				:andThen(function()
					local data1 = CAR_RESULT_DATA

					local data2 = {
						cars = {
							{
								make = "Audi",
								model = "SQ5",
								vin = "POWERANDTRUNKSPACE",
								__typename = "Car",
							},
						},
					}

					local mocks = {
						{
							request = {
								query = CAR_QUERY,
							},
							result = { data = data1 },
						},
						{
							request = {
								query = CAR_QUERY,
							},
							result = { data = data2 },
						},
					}

					local renderCount = 0
					local function Component()
						local ref = useLazyQuery(CAR_QUERY, {
							fetchPolicy = "network-only",
						})
						local execute, ref_ = table.unpack(ref, 1, 2)
						local loading, data = ref_.loading, ref_.data
						local condition = renderCount
						if condition == 0 then
							expect(loading).toEqual(false)
							setTimeout(function()
								execute()
							end)
						elseif condition == 1 then
							expect(loading).toEqual(true)
						elseif condition == 2 then
							expect(loading).toEqual(false)
							expect(data).toEqual(data1)
							setTimeout(function()
								execute()
							end)
						elseif condition == 3 then
							expect(loading).toEqual(true)
						elseif condition == 4 then
							expect(loading).toEqual(false)
							expect(data).toEqual(data2)
						else
							-- Do nothing
						end
						renderCount += 1
						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))

					return wait_(function()
						expect(renderCount).toBe(5)
					end):expect()
				end)
				:expect()
		end
	)

	itAsync("should persist previous data when a query is re-run", function(resolve, reject)
		local query = gql([[

      query car {
        car {
          id
          make
        }
      }
    ]])
		local data1 = {
			car = {
				id = 1,
				make = "Venturi",
				__typename = "Car",
			},
		}
		local data2 = {
			car = {
				id = 2,
				make = "Wiesmann",
				__typename = "Car",
			},
		}

		local mocks = {
			{ request = { query = query }, result = { data = data1 } },
			{ request = { query = query }, result = { data = data2 } },
		}

		local renderCount = 0
		local function App()
			local ref = useLazyQuery(query, { notifyOnNetworkStatusChange = true })
			local execute, ref_ = table.unpack(ref, 1, 2)
			local loading, data, previousData, refetch = ref_.loading, ref_.data, ref_.previousData, ref_.refetch

			renderCount += 1
			local condition = renderCount
			if condition == 1 then
				expect(loading).toEqual(false)
				expect(data).toBeUndefined()
				expect(previousData).toBeUndefined()
				setTimeout(execute)
			elseif condition == 2 then
				expect(loading).toBeTruthy()
				expect(data).toBeUndefined()
				expect(previousData).toBeUndefined()
			elseif condition == 3 then
				expect(loading).toBeFalsy()
				expect(data).toEqual(data1)
				expect(previousData).toBeUndefined()
				setTimeout(refetch :: any)
			elseif condition == 4 then
				expect(loading).toBeTruthy()
				expect(data).toEqual(data1)
				expect(previousData).toEqual(data1)
			elseif condition == 5 then
				expect(loading).toBeFalsy()
				expect(data).toEqual(data2)
				expect(previousData).toEqual(data1)
			else
				-- Do nothing
			end

			return nil
		end

		render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(App, nil)))

		return wait_(function()
			expect(renderCount).toBe(5)
		end):andThen(resolve, reject)
	end)
end)

return {}
