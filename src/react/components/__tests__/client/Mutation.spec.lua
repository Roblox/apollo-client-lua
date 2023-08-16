--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/components/__tests__/client/Mutation.test.tsx

local srcWorkspace = script.Parent.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
local console = LuauPolyfill.console
local setTimeout = LuauPolyfill.setTimeout

type Array<T> = LuauPolyfill.Array<T>
type Error = LuauPolyfill.Error

type FIX_ANALYZE = any

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest
type DoneFn = ((string | Error)?) -> ()

local Promise = require(rootWorkspace.Promise)

-- ROBLOX TODO: remove when unhandled errors are ... handled
local function rejectOnComponentThrow(reject, fn: (...any) -> ...any)
	local trace = debug.traceback()
	local ok, result = pcall(fn)
	if not ok then
		print(result.message .. "\n" .. trace)
		reject(result)
	end
	return result
end

-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
local TICK = 1000 / 30

local React = require(rootWorkspace.React)
local useState = React.useState

local gql = require(rootWorkspace.GraphQLTag).default

local graphQLModule = require(rootWorkspace.GraphQL)
type ExecutionResult = graphQLModule.ExecutionResult
local GraphQLError = graphQLModule.GraphQLError

local testingLibraryModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = testingLibraryModule.render
local cleanup = testingLibraryModule.cleanup
local fireEvent = testingLibraryModule.fireEvent
local waitFor = testingLibraryModule.waitFor
local act = testingLibraryModule.act

local wait_ = require(srcWorkspace.testUtils.wait).wait

local ApolloClient = require(script.Parent.Parent.Parent.Parent.Parent.core).ApolloClient
local ApolloError = require(script.Parent.Parent.Parent.Parent.Parent.errors).ApolloError
local cacheModule = require(script.Parent.Parent.Parent.Parent.Parent.cache)
type DataProxy = cacheModule.DataProxy

local Cache = require(script.Parent.Parent.Parent.Parent.Parent.cache.inmemory.inMemoryCache).InMemoryCache

local ApolloProvider = require(script.Parent.Parent.Parent.Parent.context).ApolloProvider

local testingModule = require(script.Parent.Parent.Parent.Parent.Parent.testing)
local stripSymbols = testingModule.stripSymbols
local MockedProvider = testingModule.MockedProvider
local MockLink = testingModule.MockLink
local mockSingleLink = testingModule.mockSingleLink

local Query = require(script.Parent.Parent.Parent.Query).Query
local Mutation = require(script.Parent.Parent.Parent.Mutation).Mutation

local mutation = gql([[

  mutation createTodo($text: String!) {
    createTodo {
      id
      text
      completed
      __typename
    }
    __typename
  }
]])

type Data = { createTodo: { __typename: string, id: string, text: string, completed: boolean }, __typename: string }

local data: Data = {
	createTodo = {
		__typename = "Todo",
		id = "99",
		text = "This one was created with a mutation.",
		completed = true,
	},
	__typename = "Mutation",
}

local data2: Data = {
	createTodo = {
		__typename = "Todo",
		id = "100",
		text = "This one was created with a mutation.",
		completed = true,
	},
	__typename = "Mutation",
}

local mocks = {
	{ request = { query = mutation }, result = { data = data } },
	{ request = { query = mutation }, result = { data = data2 } },
} :: Array<any>

local cache = Cache.new({ addTypename = false })

describe("General Mutation testing", function()
	afterEach(cleanup)

	it("pick prop client over context client", function()
		local function mock(text: string)
			return {
				{
					request = { query = mutation },
					result = {
						data = {
							createTodo = { __typename = "Todo", id = "99", text = text, completed = true },
							__typename = "Mutation",
						},
					},
				},
				{
					request = { query = mutation },
					result = {
						data = {
							createTodo = { __typename = "Todo", id = "100", text = text, completed = true },
							__typename = "Mutation",
						},
					},
				},
			}
		end

		local mocksProps = mock("This is the result of the prop client mutation.")
		local mocksContext = mock("This is the result of the context client mutation.")

		local function mockClient(m: any)
			return ApolloClient.new({ link = MockLink.new(m, false), cache = Cache.new({ addTypename = false }) })
		end

		local contextClient = mockClient(mocksContext)
		local propsClient = mockClient(mocksProps)
		local spy = jest.fn()

		local function Component(props: any)
			return React.createElement(
				ApolloProvider,
				{ client = contextClient },
				React.createElement(
					Mutation,
					{ client = props.propsClient, mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any)
						return React.createElement("TextButton", {
							[React.Event.Activated] = function()
								return createTodo():andThen(function(...)
									spy(...)
								end)
							end,
							Text = "Create",
						})
					end
				)
			)
		end

		local ref = render(React.createElement(Component, nil))
		local getByText, rerender = ref.getByText, ref.rerender

		local button = getByText("Create")
		-- context client mutation
		fireEvent.click(button)

		-- props client mutation
		rerender(React.createElement(Component, { propsClient = propsClient }))
		fireEvent.click(button)

		-- context client mutation
		rerender(React.createElement(Component, { propsClient = nil }))
		fireEvent.click(button)

		-- props client mutation
		rerender(React.createElement(Component, { propsClient = propsClient }))
		fireEvent.click(button)

		wait_():expect()

		expect(spy).toHaveBeenCalledTimes(4)
		expect(spy).toHaveBeenCalledWith(mocksContext[1].result)
		expect(spy).toHaveBeenCalledWith(mocksProps[1].result)
		expect(spy).toHaveBeenCalledWith(mocksContext[2].result)
		expect(spy).toHaveBeenCalledWith(mocksProps[2].result)
	end)

	it("performs a mutation", function()
		-- ROBLOX deviation: wrap in promise async fn
		Promise.new(function(resolve, reject)
			local count = 0
			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								expect(result.loading).toEqual(false)
								expect(result.called).toEqual(false)
								createTodo()
							elseif count == 1 then
								expect(result.called).toEqual(true)
								expect(result.loading).toEqual(true)
							elseif count == 2 then
								expect(result.called).toEqual(true)
								expect(result.loading).toEqual(false)
								expect(result.data).toEqual(data)
							end
							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end
			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))
			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("can bind only the mutation and not rerender by props", function(_, done: DoneFn)
		local count = 0
		local function Component()
			return React.createElement(
				Mutation,
				{ mutation = mutation, ignoreResults = true } :: FIX_ANALYZE,
				function(createTodo: any, result: any)
					if count == 0 then
						expect(result.loading).toEqual(false)
						expect(result.called).toEqual(false)
						setTimeout(function()
							createTodo():andThen(function(r: any)
								expect((r :: any).data).toEqual(data)
								done()
							end)
						end)
					elseif count == 1 then
						-- ROBLOX deviation START: using done(error) instead of done.fail(error)
						done("rerender happened with ignoreResults turned on")
						-- ROBLOX deviation END
					end
					count += 1
					-- ROBLOX deviation: using text element instead of div
					return React.createElement("TextLabel", { Text = "" })
				end
			)
		end
		render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))
	end)

	it("returns a resolved promise when calling the mutation function", function()
		Promise.new(function(resolve, reject)
			local called = false
			local function Component()
				return React.createElement(Mutation, { mutation = mutation } :: FIX_ANALYZE, function(createTodo: any)
					rejectOnComponentThrow(reject, function()
						if not called then
							createTodo():andThen(function(result: any)
								expect((result :: any).data).toEqual(data)
							end)
						end
						called = true
					end)
					return nil
				end)
			end
			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))
			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("returns rejected promise when calling the mutation function", function()
		Promise.new(function(resolve, reject)
			local called = false
			local function Component()
				return React.createElement(Mutation, { mutation = mutation } :: FIX_ANALYZE, function(createTodo: any)
					rejectOnComponentThrow(reject, function()
						if not called then
							createTodo():catch(function(error_)
								-- ROBLOX deviation: comparing error messages
								expect(error_.message).toEqual(Error.new("Error 1").message)
							end)
						end
						called = true
					end)
					return nil
				end)
			end

			local mocksWithErrors = { { request = { query = mutation }, error = Error.new("Error 1") } }

			render(
				React.createElement(MockedProvider, { mocks = mocksWithErrors }, React.createElement(Component, nil))
			)

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("only shows result for the latest mutation that is in flight", function()
		Promise.new(function(resolve, reject)
			local count = 0

			local function onCompleted(dataMutation: Data)
				if count == 1 then
					expect(dataMutation).toEqual(data)
				elseif count == 3 then
					expect(dataMutation).toEqual(data2)
				end
			end

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation, onCompleted = onCompleted } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								expect(result.called).toEqual(false)
								expect(result.loading).toEqual(false)
								createTodo()
								createTodo()
							elseif count == 1 then
								expect(result.called).toEqual(true)
								expect(result.loading).toEqual(true)
							elseif count == 2 then
								expect(result.loading).toEqual(false)
								expect(result.called).toEqual(true)
								expect(result.data).toEqual(data2)
							end
							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end
			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))
			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("only shows the error for the latest mutation in flight", function()
		Promise.new(function(resolve, reject)
			local count = 0

			local function onError(_self, error_)
				-- ROBLOX deviation: compare error messages
				if count == 1 then
					expect(error_.message).toEqual(Error.new("Error 1").message)
				elseif count == 3 then
					expect(error_.message).toEqual(Error.new("Error 2").message)
				end
			end

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation, onError = onError } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								expect(result.called).toEqual(false)
								expect(result.loading).toEqual(false)
								createTodo()
								createTodo()
							elseif count == 1 then
								expect(result.loading).toEqual(true)
								expect(result.called).toEqual(true)
							elseif count == 2 then
								expect(result.loading).toEqual(false)
								expect(result.data).toEqual(nil)
								expect(result.called).toEqual(true)
								-- ROBLOX deviation: compare error message
								expect(result.error.message).toEqual(Error.new("Error 2").message)
							end
							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			local mocksWithErrors = {
				{ request = { query = mutation }, error = Error.new("Error 2") },
				{ request = { query = mutation }, error = Error.new("Error 2") },
			}

			render(
				React.createElement(MockedProvider, { mocks = mocksWithErrors }, React.createElement(Component, nil))
			)

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("calls the onCompleted prop as soon as the mutation is complete", function()
		Promise.new(function(resolve, reject)
			local onCompletedCalled = false

			local Component = React.Component:extend("Component")

			function Component:init()
				self.state = {
					mutationDone = false,
				}

				self.onCompleted = function(mutationData: Data)
					expect(mutationData).toEqual(data)
					onCompletedCalled = true
					self:setState({
						mutationDone = true,
					})
				end
			end

			function Component:render()
				return React.createElement(
					Mutation,
					{ mutation = mutation, onCompleted = self.onCompleted } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if not Boolean.toJSBoolean(result.called) then
								expect(self.state.mutationDone).toBe(false)
								createTodo()
							end
							if Boolean.toJSBoolean(onCompletedCalled) then
								expect(self.state.mutationDone).toBe(true)
							end
						end)
						return nil
					end
				)
			end
			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))
			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("renders result of the children render prop", function()
		local function Component()
			return React.createElement(Mutation, { mutation = mutation } :: FIX_ANALYZE, function()
				-- ROBLOX deviation: using text element instead of div
				return React.createElement("TextLabel", { Text = "result" })
			end)
		end
		local getByText = render(
			React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil))
		).getByText

		expect(getByText("result")).toBeTruthy()
	end)

	it("renders an error state", function()
		Promise.new(function(resolve, reject)
			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo():catch(function(err: any)
									-- ROBLOX deviation: compare error message
									expect(err.message).toEqual(Error.new("error occurred").message)
								end)
							elseif count == 1 then
								expect(result.loading).toBeTruthy()
							elseif count == 2 then
								-- ROBLOX deviation: compare error message
								expect(result.error.message).toEqual(Error.new("error occurred").message)
							end
							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			local mockError = { { request = { query = mutation }, error = Error.new("error occurred") } }

			render(React.createElement(MockedProvider, { mocks = mockError }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("renders an error state and throws when encountering graphql errors", function()
		Promise.new(function(resolve, reject)
			local count = 0

			local expectedError = ApolloError.new({ graphQLErrors = { GraphQLError.new("error occurred") } })

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo()
									:andThen(function()
										error(Error.new("Did not expect a result"))
									end)
									:catch(function(e: any)
										-- ROBLOX deviation: comparing error messages
										expect(e.message).toEqual(expectedError.message)
									end)
							elseif count == 1 then
								expect(result.loading).toBeTruthy()
							elseif count == 2 then
								-- ROBLOX deviation: comparing error messages
								expect(result.error.message).toEqual(expectedError.message)
							end
							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			local mockError = {
				{ request = { query = mutation }, result = { errors = { GraphQLError.new("error occurred") } } },
			}

			render(React.createElement(MockedProvider, { mocks = mockError }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("renders an error state and does not throw when encountering graphql errors when errorPolicy=all", function()
		Promise.new(function(resolve, reject)
			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo()
									:andThen(function(fetchResult: any)
										if
											Boolean.toJSBoolean(fetchResult)
											and Boolean.toJSBoolean(fetchResult.errors)
										then
											expect(#fetchResult.errors).toEqual(1)
											-- ROBLOX deviation: compare error message
											expect(fetchResult.errors[1].message).toEqual(
												GraphQLError.new("error occurred").message
											)
										else
											error(
												Error.new(
													("Expected an object with array of errors but got %s"):format(
														fetchResult
													)
												)
											)
										end
									end)
									:catch(function(e: any)
										error(e)
									end)
							elseif count == 1 then
								expect(result.loading).toBeTruthy()
							elseif count == 2 then
								-- ROBLOX deviation: compare error message
								expect(result.error.message).toEqual(
									ApolloError.new({ graphQLErrors = { GraphQLError.new("error occurred") } }).message
								)
							end

							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			local mockError = {
				{ request = { query = mutation }, result = { errors = { GraphQLError.new("error occurred") } } },
			}

			render(
				React.createElement(
					MockedProvider,
					{ defaultOptions = { mutate = { errorPolicy = "all" } }, mocks = mockError },
					React.createElement(Component, nil)
				)
			)

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("renders an error state and throws when encountering network errors when errorPolicy=all", function()
		Promise.new(function(resolve, reject)
			local count = 0
			local expectedError = ApolloError.new({ networkError = Error.new("network error") })

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo()
									:andThen(function()
										error(Error.new("Did not expect a result"))
									end)
									:catch(function(e: any)
										-- ROBLOX deviation: compare error message
										expect(e.message).toEqual(expectedError.message)
									end)
							elseif count == 1 then
								expect(result.loading).toBeTruthy()
							elseif count == 2 then
								-- ROBLOX deviation: compare error message

								expect(result.error.message).toEqual(expectedError.message)
							end

							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			local mockError = { { request = { query = mutation }, error = Error.new("network error") } }

			render(
				React.createElement(
					MockedProvider,
					{ defaultOptions = { mutate = { errorPolicy = "all" } }, mocks = mockError },
					React.createElement(Component, nil)
				)
			)

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("calls the onError prop if the mutation encounters an error", function()
		Promise.new(function(resolve, reject)
			local onRenderCalled = false

			local Component = React.Component:extend("Component")

			function Component:init()
				self.state = {
					mutationError = false,
				}

				self.onError = function(_self, error_: Error)
					expect(error_.message).toMatch("error occurred")
					onRenderCalled = true
					self:setState({ mutationError = true })
				end
			end

			function Component:render()
				local mutationError = self.state.mutationError
				return React.createElement(
					Mutation,
					{ mutation = mutation, onError = self.onError } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if not Boolean.toJSBoolean(result.called) then
								expect(mutationError).toBe(false)
								createTodo()
							end
							if Boolean.toJSBoolean(onRenderCalled) then
								expect(mutationError).toBe(true)
							end
						end)
						return nil
					end
				)
			end

			local mockError = { { request = { query = mutation }, error = Error.new("error occurred") } }

			render(React.createElement(MockedProvider, { mocks = mockError }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("performs a mutation with variables prop", function()
		Promise.new(function(resolve, reject)
			local variables = { text = "play tennis" }

			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation, variables = variables } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo()
							elseif count == 1 then
								expect(result.loading).toEqual(true)
								expect(result.called).toEqual(true)
							elseif count == 2 then
								expect(result.loading).toEqual(false)
								expect(result.called).toEqual(true)
								expect(result.data).toEqual(data)
							end

							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			local mocks1 = { { request = { query = mutation, variables = variables }, result = { data = data } } }

			render(React.createElement(MockedProvider, { mocks = mocks1 }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("allows passing a variable to the mutate function", function()
		Promise.new(function(resolve, reject)
			local variables = { text = "play tennis" }

			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo({ variables = variables })
							elseif count == 1 then
								expect(result.loading).toEqual(true)
								expect(result.called).toEqual(true)
							elseif count == 2 then
								expect(result.loading).toEqual(false)
								expect(result.called).toEqual(true)
								expect(result.data).toEqual(data)
							end

							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			local mocks1 = { { request = { query = mutation, variables = variables }, result = { data = data } } }

			render(React.createElement(MockedProvider, { mocks = mocks1 }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("allows an optimistic response prop", function()
		Promise.new(function(resolve, reject)
			local link = mockSingleLink(table.unpack(mocks))

			local client = ApolloClient.new({ link = link, cache = cache })

			local optimisticResponse = {
				createTodo = {
					id = "99",
					text = "This is an optimistic response",
					completed = false,
					__typename = "Todo",
				},
				__typename = "Mutation",
			}

			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation, optimisticResponse = optimisticResponse } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo()
								local dataInStore = client.cache:extract(true)
								expect(dataInStore["Todo:99"]).toEqual(optimisticResponse.createTodo)
							elseif count == 1 then
								expect(result.loading).toEqual(true)
								expect(result.called).toEqual(true)
							elseif count == 2 then
								expect(result.loading).toEqual(false)
								expect(result.called).toEqual(true)
								expect(result.data).toEqual(data)
							end

							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("allows passing an optimistic response to the mutate function", function()
		Promise.new(function(resolve, reject)
			local link = mockSingleLink(table.unpack(mocks))

			local client = ApolloClient.new({ link = link, cache = cache })

			local optimisticResponse = {
				createTodo = {
					id = "99",
					text = "This is an optimistic response",
					completed = false,
					__typename = "Todo",
				},
				__typename = "Mutation",
			}

			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo({ optimisticResponse = optimisticResponse })
								local dataInStore = client.cache:extract(true)
								expect(dataInStore["Todo:99"]).toEqual(optimisticResponse.createTodo)
							elseif count == 2 then
								expect(result.loading).toEqual(false)
								expect(result.called).toEqual(true)
								expect(result.data).toEqual(data)
							end
							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("allows a refetchQueries prop", function()
		Promise.new(function(resolve, reject)
			local query = gql([[

        query getTodo {
          todo {
            id
            text
            completed
            __typename
          }
          __typename
        }
      ]])

			local queryData = {
				todo = { id = "1", text = "todo from query", completed = false, __typename = "Todo" },
				__typename = "Query",
			}

			local mocksWithQuery = Array.concat({}, mocks, {
				{ request = { query = query }, result = { data = queryData } },
				{ request = { query = query }, result = { data = queryData } },
			})

			local refetchQueries = { { query = query } }

			local renderCount = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation, refetchQueries = refetchQueries } :: FIX_ANALYZE,
					function(createTodo: any, resultMutation: any)
						return React.createElement(Query, { query = query }, function(resultQuery: any)
							rejectOnComponentThrow(reject, function()
								renderCount += 1
								if renderCount == 1 then
									setTimeout(
										function()
											return createTodo()
										end,
										-- ROBLOX deviation: min interval
										10 * TICK
									)
								elseif renderCount == 2 then
									expect(resultMutation.loading).toBe(false)
									expect(resultQuery.loading).toBe(false)
								elseif renderCount == 3 then
									expect(resultMutation.loading).toBe(true)
									expect(stripSymbols(resultQuery.data)).toEqual(queryData)
								elseif renderCount == 4 then
									expect(resultMutation.loading).toBe(false)
								end
							end)
							return nil
						end)
					end
				)
			end

			render(React.createElement(MockedProvider, { mocks = mocksWithQuery }, React.createElement(Component, nil)))

			return waitFor(function()
				expect(renderCount).toBe(4)
			end):andThen(resolve, reject)
		end):expect()
	end)

	it("allows a refetchQueries prop as string and variables have updated", function()
		Promise.new(function(resolve, reject)
			local query = gql([[

        query people($first: Int) {
          allPeople(first: $first) {
            people {
              name
            }
          }
        }
      ]])

			local peopleData1 = {
				allPeople = {
					people = { { name = "Luke Skywalker", __typename = "Person" } },
					__typename = "People",
				},
			}

			local peopleData2 = {
				allPeople = { people = { { name = "Han Solo", __typename = "Person" } }, __typename = "People" },
			}

			local peopleData3 = {
				allPeople = { people = { { name = "Lord Vader", __typename = "Person" } }, __typename = "People" },
			}

			local peopleMocks = Array.concat({}, mocks, {
				{ request = { query = query, variables = { first = 1 } }, result = { data = peopleData1 } },
				{ request = { query = query, variables = { first = 2 } }, result = { data = peopleData2 } },
				{ request = { query = query, variables = { first = 2 } }, result = { data = peopleData3 } },
			})

			local refetchQueries = { "people" }

			local count = 0

			local function Component(props)
				local variables, setVariables = useState(props.variables)

				return React.createElement(
					Mutation,
					{ mutation = mutation, refetchQueries = refetchQueries } :: FIX_ANALYZE,
					function(createTodo: any, resultMutation: any)
						return React.createElement(
							Query,
							{ query = query, variables = variables },
							function(resultQuery: any)
								rejectOnComponentThrow(reject, function()
									if count == 0 then
										-- "first: 1" loading
										expect(resultQuery.loading).toBe(true)
									elseif count == 1 then
										-- "first: 1" loaded
										expect(resultQuery.loading).toBe(false)
										setTimeout(function()
											return setVariables({ first = 2 })
										end)
									elseif count == 2 then
										-- "first: 2" loading
										expect(resultQuery.loading).toBe(true)
									elseif count == 3 then
										-- "first: 2" loaded
										expect(resultQuery.loading).toBe(false)
										setTimeout(function()
											return createTodo()
										end)
									elseif count == 4 then
										-- mutation loading
										expect(resultMutation.loading).toBe(true)
									elseif count == 5 then
										-- mutation loaded
										expect(resultMutation.loading).toBe(false)
									elseif count == 6 then
										-- query refetched
										expect(resultQuery.loading).toBe(false)
										expect(resultMutation.loading).toBe(false)
										expect(stripSymbols(resultQuery.data)).toEqual(peopleData3)
									end

									count += 1
								end)
								return nil
							end
						)
					end
				)
			end

			render(
				React.createElement(
					MockedProvider,
					{ mocks = peopleMocks },
					React.createElement(Component, { variables = { first = 1 } })
				)
			)

			wait_(function()
				expect(count).toBe(7)
			end):andThen(resolve, reject)
		end):expect()
	end)

	it("allows refetchQueries to be passed to the mutate function", function()
		Promise.new(function(resolve, reject)
			local query = gql([[

        query getTodo {
          todo {
            id
            text
            completed
            __typename
          }
          __typename
        }
      ]])

			local queryData = {
				todo = { id = "1", text = "todo from query", completed = false, __typename = "Todo" },
				__typename = "Query",
			}

			local mocksWithQuery = Array.concat({}, mocks, {
				{ request = { query = query }, result = { data = queryData } },
				{ request = { query = query }, result = { data = queryData } },
			})

			local refetchQueries = { { query = query } }

			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation } :: FIX_ANALYZE,
					function(createTodo: any, resultMutation: any)
						return React.createElement(Query, { query = query }, function(resultQuery: any)
							rejectOnComponentThrow(reject, function()
								if count == 0 then
									setTimeout(
										function()
											return createTodo({ refetchQueries = refetchQueries })
										end,
										--ROBLOX deviation: min interval
										10 * TICK
									)
								elseif count == 1 then
									expect(resultMutation.loading).toBe(false)
									expect(resultQuery.loading).toBe(false)
								elseif count == 2 then
									expect(resultMutation.loading).toBe(true)
									expect(stripSymbols(resultQuery.data)).toEqual(queryData)
								elseif count == 3 then
									expect(resultMutation.loading).toBe(false)
								end

								count += 1
							end)
							return nil
						end)
					end
				)
			end

			render(React.createElement(MockedProvider, { mocks = mocksWithQuery }, React.createElement(Component, nil)))

			waitFor(function()
				expect(count).toBe(4)
			end):andThen(resolve, reject)
		end):expect()
	end)

	it("has an update prop for updating the store after the mutation", function()
		Promise.new(function(resolve, reject)
			local function update(_self, _proxy: DataProxy, response: ExecutionResult)
				expect(response.data).toEqual(data)
			end

			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation, update = update } :: FIX_ANALYZE,
					function(createTodo: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo():andThen(function(response: any)
									expect((response :: any).data).toEqual(data)
								end)
							end
							count += 1
						end)
						return nil
					end
				)
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("allows update to be passed to the mutate function", function()
		Promise.new(function(resolve, reject)
			local function update(_self, _proxy: DataProxy, response: ExecutionResult)
				expect(response.data).toEqual(data)
			end

			local count = 0

			local function Component()
				return React.createElement(Mutation, { mutation = mutation } :: FIX_ANALYZE, function(createTodo: any)
					rejectOnComponentThrow(reject, function()
						if count == 0 then
							createTodo({ update = update }):andThen(function(response: any)
								expect((response :: any).data).toEqual(data)
							end)
						end

						count += 1
					end)
					return nil
				end)
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))

			wait_():andThen(resolve, reject)
		end):expect()
	end)

	it("allows for overriding the options passed in the props by passing them in the mutate function", function()
		Promise.new(function(resolve, reject)
			local variablesProp = { text = "play tennis" }

			local variablesMutateFn = { text = "go swimming" }

			local count = 0

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation, variables = variablesProp } :: FIX_ANALYZE,
					function(createTodo: any, result: any)
						rejectOnComponentThrow(reject, function()
							if count == 0 then
								createTodo({ variables = variablesMutateFn })
							elseif count == 2 then
								expect(result.loading).toEqual(false)
								expect(result.called).toEqual(true)
								expect(result.data).toEqual(data2)
							end

							count += 1
						end)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end
				)
			end

			local mocks1 = {
				{ request = { query = mutation, variables = variablesProp }, result = { data = data } },
				{ request = { query = mutation, variables = variablesMutateFn }, result = { data = data2 } },
			}

			render(React.createElement(MockedProvider, { mocks = mocks1 }, React.createElement(Component, nil)))

			waitFor(function()
				expect(count).toBe(3)
			end):andThen(resolve, reject)
		end):expect()
	end)

	it("updates if the client changes", function()
		Promise.new(function(resolve, reject)
			local link1 = mockSingleLink({ request = { query = mutation }, result = { data = data } })

			local client1 = ApolloClient.new({ link = link1, cache = Cache.new({ addTypename = false }) })

			local data3 = {
				createTodo = {
					__typename = "Todo",
					id = "100",
					text = "After updating client.",
					completed = false,
				},
				__typename = "Mutation",
			}

			local link2 = mockSingleLink({ request = { query = mutation }, result = { data = data3 } })

			local client2 = ApolloClient.new({ link = link2, cache = Cache.new({ addTypename = false }) })

			local count = 0

			local Component = React.Component:extend("Component")

			function Component:init()
				self.state = {
					client = client1,
				}
			end

			function Component:render()
				return React.createElement(
					ApolloProvider,
					{ client = self.state.client },
					React.createElement(
						Mutation,
						{ mutation = mutation } :: FIX_ANALYZE,
						function(createTodo: any, result: any)
							rejectOnComponentThrow(reject, function()
								if count == 0 then
									expect(result.called).toEqual(false)
									expect(result.loading).toEqual(false)
									createTodo()
								elseif count == 2 and Boolean.toJSBoolean(result) then
									expect(result.data).toEqual(data)
									setTimeout(function()
										self:setState({ client = client2 })
									end)
								elseif count == 3 then
									expect(result.loading).toEqual(false)
									createTodo()
								elseif count == 5 then
									expect(result.data).toEqual(data3)
								end

								count += 1
							end)
							return nil
						end
					)
				)
			end

			render(React.createElement(Component, nil))

			waitFor(function()
				expect(count).toBe(6)
			end):andThen(resolve, reject)
		end):expect()
	end)

	it("uses client from props instead of one provided by context", function()
		Promise.new(function(resolve, reject)
			local link1 = mockSingleLink({ request = { query = mutation }, result = { data = data } })

			local client1 = ApolloClient.new({ link = link1, cache = Cache.new({ addTypename = false }) })

			local link2 = mockSingleLink({ request = { query = mutation }, result = { data = data2 } })

			local client2 = ApolloClient.new({ link = link2, cache = Cache.new({ addTypename = false }) })

			local count = 0

			render(
				React.createElement(
					ApolloProvider,
					{ client = client1 },
					React.createElement(
						Mutation,
						{ client = client2, mutation = mutation } :: FIX_ANALYZE,
						function(createTodo: any, result: any)
							rejectOnComponentThrow(reject, function()
								if not Boolean.toJSBoolean(result.called) then
									act(function()
										createTodo()
									end)
								end
								if count == 2 then
									expect(result.loading).toEqual(false)
									expect(result.called).toEqual(true)
									expect(result.data).toEqual(data2)
								end
								count += 1
							end)
							-- ROBLOX deviation: using text element instead of div
							return React.createElement("TextLabel", { Text = "" })
						end
					)
				)
			)

			waitFor(function()
				expect(count).toBe(3)
			end):andThen(resolve, reject)
		end):expect()
	end)

	it("errors if a query is passed instead of a mutation", function()
		local query = gql([[

		  query todos {
		    todos {
		      id
		    }
		  }
		]])

		-- Prevent error from being logged in console of test.
		local errorLogger = console.error

		console.error = function() end

		expect(function()
			render(
				React.createElement(
					MockedProvider,
					nil,
					React.createElement(Mutation, { mutation = query } :: FIX_ANALYZE, function()
						return nil
					end)
				)
			)
		end).toThrowError("Running a Mutation requires a graphql Mutation, but a Query was used " .. "instead.")

		console.log = errorLogger
	end)

	it("errors when changing from mutation to a query", function(_, done)
		local query = gql([[

        query todos {
          todos {
            id
          }
        }
      ]])

		local Component = React.Component:extend("Component")

		function Component:init()
			self.state = {
				query = mutation,
			}
		end

		function Component:componentDidCatch(e: Error)
			-- ROBLOX deviation START: error stacks differ, split expectations
			expect(e).toBeInstanceOf(Error)
			expect(e.message).toEqual(
				Error.new("Running a Mutation requires a graphql Mutation, but a Query " .. "was used instead.").message
			)
			-- ROBLOX deviation END
			done()
		end

		function Component:render()
			return React.createElement(Mutation, { mutation = self.state.query } :: FIX_ANALYZE, function()
				setTimeout(function()
					self:setState({ query = query })
				end)
				return nil
			end)
		end

		-- Prevent error from being logged in console of test.
		local errorLogger = console.error
		console.error = function() end

		render(React.createElement(MockedProvider, nil, React.createElement(Component, nil)))

		console.log = errorLogger
	end)

	it("errors if a subscription is passed instead of a mutation", function()
		local subscription = gql([[

		  subscription todos {
		    todos {
		      id
		    }
		  }
		]])

		-- Prevent error from being logged in console of test.
		local errorLogger = console.error
		console.error = function() end

		expect(function()
			render(
				React.createElement(
					MockedProvider,
					nil,
					React.createElement(Mutation, { mutation = subscription } :: FIX_ANALYZE, function()
						return nil
					end)
				)
			)
		end).toThrowError(
			"Running a Mutation requires a graphql Mutation, but a Subscription " .. "was used instead."
		)

		console.log = errorLogger
	end)

	it("errors when changing from mutation to a subscription", function(_, done)
		local subscription = gql([[

		subscription todos {
		  todos {
		    id
		  }
		}
	  ]])

		local Component = React.Component:extend("Component")

		function Component:init()
			self.state = {
				query = mutation,
			}
		end

		function Component:componentDidCatch(e: Error)
			expect(e.message).toEqual(
				Error.new("Running a Mutation requires a graphql Mutation, but a " .. "Subscription was used instead.").message
			)
			done()
		end

		function Component:render()
			return React.createElement(Mutation, { mutation = self.state.query } :: FIX_ANALYZE, function()
				setTimeout(function()
					self:setState({ query = subscription })
				end)
				return nil
			end)
		end

		-- Prevent error from being logged in console of test.
		local errorLogger = console.error
		console.error = function() end

		render(React.createElement(MockedProvider, nil, React.createElement(Component, nil)))

		console.log = errorLogger
	end)

	describe("after it has been unmounted", function()
		it("calls the onCompleted prop after the mutation is complete", function(_, done: DoneFn)
			local success = false

			local onCompletedFn = jest.fn()

			local function checker()
				setTimeout(function()
					success = true
					expect(onCompletedFn).toHaveBeenCalledWith(data)
					done()
				end, 100)
			end

			local Component = React.Component:extend("Component")

			function Component:init()
				self.state = {
					called = false,
				}
			end

			function Component:render()
				local called = self.state.called

				if called == true then
					return nil
				else
					return React.createElement(
						Mutation,
						{ mutation = mutation, onCompleted = onCompletedFn } :: FIX_ANALYZE,
						function(createTodo: any)
							-- ROBLOX deviation START: minimum timeout
							setTimeout(function()
								createTodo()
								self:setState({ called = true }, checker)
							end, TICK)
							-- ROBLOX deviation END
							return nil
						end
					)
				end
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component, nil)))

			setTimeout(function()
				if not success then
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					done("timeout passed")
					-- ROBLOX deviation END
				end
			end, 500)
		end)
	end)

	it("calls the onError prop if the mutation encounters an error_", function()
		Promise.new(function(resolve, reject)
			local onErrorCalled = false

			local function onError(_self, error_)
				expect(error_.message).toEqual("error occurred")
				onErrorCalled = true
			end

			local function Component()
				return React.createElement(
					Mutation,
					{ mutation = mutation, onError = onError } :: FIX_ANALYZE,
					function(createTodo: any, ref)
						local called = ref.called
						if not called then
							return createTodo()
						end
						return nil
					end
				)
			end

			local mockError = { { request = { query = mutation }, error = Error.new("error occurred") } }

			render(React.createElement(MockedProvider, { mocks = mockError }, React.createElement(Component, nil)))

			waitFor(function()
				expect(onErrorCalled).toBeTruthy()
			end):andThen(resolve, reject)
		end):expect()
	end)
end)

return {}
