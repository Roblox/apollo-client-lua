--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/hooks/__tests__/useMutation.test.tsx

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local console = LuauPolyfill.console
local setTimeout = LuauPolyfill.setTimeout
local Boolean = LuauPolyfill.Boolean
local sortedEncode = require(srcWorkspace.luaUtils.sortedEncode).sortedEncode

type Array<T> = LuauPolyfill.Array<T>
local Promise = require(rootWorkspace.Promise)

-- ROBLOX FIXME: remove if better solution is found
type FIX_ANALYZE = any

type Function = (...any) -> ...any

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local afterEach = JestGlobals.afterEach
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest

local typesModule = require(script.Parent.Parent.Parent.types.types)
type MutationTupleFirst<TData, TVariables, TContext, TCache> = typesModule.MutationTupleFirst<
	TData,
	TVariables,
	TContext,
	TCache
>
type MutationTupleSecond<TData, TVariables, TContext, TCache> = typesModule.MutationTupleSecond<
	TData,
	TVariables,
	TContext,
	TCache
>

local React = require(rootWorkspace.React)
local useEffect = React.useEffect
local GraphQLError = require(rootWorkspace.GraphQL).GraphQLError

local gql = require(rootWorkspace.GraphQLTag).default
local testUtilsModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = testUtilsModule.render
local cleanup = testUtilsModule.cleanup
local waitFor = testUtilsModule.waitFor
local wait_ = require(srcWorkspace.testUtils.wait).wait
local act = testUtilsModule.act

local coreModule = require(script.Parent.Parent.Parent.Parent.core)
local ApolloClient = coreModule.ApolloClient
local ApolloLink = coreModule.ApolloLink
type ApolloQueryResult<T> = coreModule.ApolloQueryResult<T>
local cacheModule = require(script.Parent.Parent.Parent.Parent.cache)
type Cache_DiffResult<T> = cacheModule.Cache_DiffResult<T>
local NetworkStatus = coreModule.NetworkStatus
local Observable = coreModule.Observable
type ObservableQuery<TData, TVariables> = coreModule.ObservableQuery<TData, TVariables>
type TypedDocumentNode<Result, Variables> = coreModule.TypedDocumentNode<Result, Variables>
type OperationVariables = coreModule.OperationVariables
local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache).InMemoryCache
local testingModule = require(script.Parent.Parent.Parent.Parent.testing)
local itAsync = testingModule.itAsync
local MockedProvider = testingModule.MockedProvider
local mockSingleLink = testingModule.mockSingleLink
local ApolloProvider = require(script.Parent.Parent.Parent.context).ApolloProvider
local useQuery = require(script.Parent.Parent.useQuery).useQuery
local useMutation = require(script.Parent.Parent.useMutation).useMutation

-- ROBLOX TODO: remove when unhandled errors are ... handled
local function rejectOnComponentThrow(reject, fn: Function)
	local trace = debug.traceback()
	local ok, result = pcall(fn)
	if not ok then
		print(result.message .. "\n" .. trace)
		reject(result)
	end
	return result
end

describe("useMutation Hook", function()
	type Todo = { id: number, description: string, priority: string }

	local CREATE_TODO_MUTATION = gql([[
    mutation createTodo($description: String!, $priority: String) {
      createTodo(description: $description, priority: $priority) {
        id
        description
        priority
      }
    }
]])
	local CREATE_TODO_RESULT = {
		createTodo = {
			id = 1,
			description = "Get milk!",
			priority = "High",
			__typename = "Todo",
		},
	}
	local CREATE_TODO_ERROR = "Failed to create item"

	afterEach(cleanup)

	describe("General use", function()
		it("should handle a simple mutation properly", function()
			return Promise.resolve()
				:andThen(function()
					local variables = {
						description = "Get milk!",
					}

					local mocks = {
						{
							request = {
								query = CREATE_TODO_MUTATION,
								variables = variables,
							},
							result = { data = CREATE_TODO_RESULT },
						},
					}

					local renderCount = 0
					local function Component()
						local ref = useMutation(CREATE_TODO_MUTATION)
						local refFirst = ref[1] :: MutationTupleFirst<any, any, any, any>
						local refSecond = ref[2] :: MutationTupleSecond<any, any, any, any>
						local createTodo, loading, data = refFirst, refSecond.loading, refSecond.data
						if renderCount == 0 then
							expect(loading).toBeFalsy()
							expect(data).toBeUndefined()
							createTodo({ variables = variables })
						elseif renderCount == 1 then
							expect(loading).toBeTruthy()
							expect(data).toBeUndefined()
						elseif renderCount == 2 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(CREATE_TODO_RESULT)
						end
						renderCount += 1
						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

					return waitFor(function()
						expect(renderCount).toBe(3)
					end)
				end)
				:expect()
		end)

		it("should be able to call mutations as an effect", function()
			return Promise.resolve()
				:andThen(function()
					local variables = {
						description = "Get milk!",
					}

					local mocks = {
						{
							request = {
								query = CREATE_TODO_MUTATION,
								variables = variables,
							},
							result = { data = CREATE_TODO_RESULT },
						},
					}

					local renderCount = 0
					local function useCreateTodo()
						local ref = useMutation(CREATE_TODO_MUTATION)
						local refFirst = ref[1] :: MutationTupleFirst<any, any, any, any>
						local refSecond = ref[2] :: MutationTupleSecond<any, any, any, any>
						local createTodo, loading, data = refFirst, refSecond.loading, refSecond.data

						useEffect(function()
							createTodo({ variables = variables })
						end, { variables })

						if renderCount == 0 then
							expect(loading).toBeFalsy()
							expect(data).toBeUndefined()
						elseif renderCount == 1 then
							expect(loading).toBeTruthy()
							expect(data).toBeUndefined()
						elseif renderCount == 2 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(CREATE_TODO_RESULT)
						end
						renderCount += 1
						return nil
					end

					local function Component()
						useCreateTodo()
						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

					return waitFor(function()
						expect(renderCount).toBe(3)
					end)
				end)
				:expect()
		end)

		it("should ensure the mutation callback function has a stable identity", function()
			return Promise.resolve()
				:andThen(function()
					local variables = {
						description = "Get milk!",
					}

					local mocks = {
						{
							request = {
								query = CREATE_TODO_MUTATION,
								variables = variables,
							},
							result = { data = CREATE_TODO_RESULT },
						},
					}

					local mutationFn: any
					local renderCount = 0
					local function Component()
						local ref = useMutation(CREATE_TODO_MUTATION)
						local refFirst = ref[1] :: MutationTupleFirst<any, any, any, any>
						local refSecond = ref[2] :: MutationTupleSecond<any, any, any, any>
						local createTodo, loading, data = refFirst, refSecond.loading, refSecond.data
						if renderCount == 0 then
							mutationFn = createTodo
							expect(loading).toBeFalsy()
							expect(data).toBeUndefined()
							setTimeout(function()
								createTodo({ variables = variables })
							end)
						elseif renderCount == 1 then
							expect(mutationFn).toBe(createTodo)
							expect(loading).toBeTruthy()
							expect(data).toBeUndefined()
						elseif renderCount == 2 then
							expect(loading).toBeFalsy()
							expect(data).toEqual(CREATE_TODO_RESULT)
						end
						renderCount += 1
						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

					return waitFor(function()
						expect(renderCount).toBe(3)
					end)
				end)
				:expect()
		end)

		it("should resolve mutate function promise with mutation results", function()
			return Promise.new(function(resolve, reject)
				local variables = {
					description = "Get milk!",
				}

				local mocks = {
					{
						request = {
							query = CREATE_TODO_MUTATION,
							variables = variables,
						},
						result = { data = CREATE_TODO_RESULT },
					},
				}

				local function Component()
					local createTodo = useMutation(CREATE_TODO_MUTATION)[1] :: MutationTupleFirst<any, any, any, any>

					local function doIt()
						return Promise.resolve():andThen(function()
							-- ROBLOX FIXME: using rejectOnComponentThrow to propagate error to test runner
							rejectOnComponentThrow(reject, function()
								local ref = createTodo({ variables = variables }):expect()
								local data = ref.data
								expect(data).toEqual(CREATE_TODO_RESULT)
								expect(data.createTodo.description).toEqual(CREATE_TODO_RESULT.createTodo.description)
							end)
						end)
					end

					useEffect(function()
						doIt()
					end, {})
					return nil
				end

				render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

				return wait_():andThen(resolve, reject)
			end):expect()
		end)

		describe("mutate function upon error", function()
			itAsync("resolves with the resulting data and errors", function(resolve, reject)
				return Promise.resolve():andThen(function()
					local variables = {
						description = "Get milk!",
					}

					local mocks = {
						{
							request = {
								query = CREATE_TODO_MUTATION,
								variables = variables,
							},
							result = {
								data = CREATE_TODO_RESULT,
								errors = { GraphQLError.new(CREATE_TODO_ERROR) },
							},
						},
					}

					local fetchResult: any
					local function Component()
						local createTodo = useMutation(CREATE_TODO_MUTATION, {
							onError = function(_self, error_)
								expect(error_.message).toEqual(CREATE_TODO_ERROR)
							end,
						} :: any)[1] :: MutationTupleFirst<any, any, any, any>

						local function runMutation()
							return Promise.resolve():andThen(function()
								fetchResult = createTodo({ variables = variables }):expect()
							end)
						end

						useEffect(function()
							runMutation()
						end, {})

						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

					return waitFor(function()
						expect(fetchResult.data).toBeUndefined()
						expect(fetchResult.errors.message).toEqual(CREATE_TODO_ERROR)
					end):andThen(resolve, reject)
				end)
			end)

			it("should reject when errorPolicy is 'none'", function()
				return Promise.new(function(resolve, reject)
					local variables = {
						description = "Get milk!",
					}

					local mocks = {
						{
							request = {
								query = CREATE_TODO_MUTATION,
								variables = variables,
							},
							result = {
								data = CREATE_TODO_RESULT,
								errors = { GraphQLError.new(CREATE_TODO_ERROR) },
							},
						},
					}

					local function Component()
						local createTodo =
							useMutation(CREATE_TODO_MUTATION, { errorPolicy = "none" })[1] :: MutationTupleFirst<any, any, any, any>

						local function doIt()
							return Promise.resolve():andThen(function()
								-- ROBLOX FIXME: using rejectOnComponentThrow to propagate error to test runner
								rejectOnComponentThrow(reject, function()
									local ok, error_ = pcall(function()
										createTodo({ variables = variables }):expect()
									end)
									if not ok then
										expect(error_.message).toEqual(expect.stringContaining(CREATE_TODO_ERROR))
									end
								end)
							end)
						end

						useEffect(function()
							doIt()
						end, {})

						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

					return wait_():andThen(resolve, reject)
				end):expect()
			end)

			it("should resolve with 'data' and 'error' properties when errorPolicy is 'all'", function()
				return Promise.new(function(resolve, reject)
					local variables = {
						description = "Get milk!",
					}

					local mocks = {
						{
							request = {
								query = CREATE_TODO_MUTATION,
								variables = variables,
							},
							result = {
								data = CREATE_TODO_RESULT,
								errors = { GraphQLError.new(CREATE_TODO_ERROR) },
							},
						},
					}

					local function Component()
						local createTodo =
							useMutation(CREATE_TODO_MUTATION, { errorPolicy = "all" })[1] :: MutationTupleFirst<any, any, any, any>

						local function doIt()
							return Promise.resolve():andThen(function()
								-- ROBLOX FIXME: using rejectOnComponentThrow to propagate error to test runner
								rejectOnComponentThrow(reject, function()
									local ref = createTodo({ variables = variables }):expect()
									local data, errors = ref.data, ref.errors

									expect(data).toEqual(CREATE_TODO_RESULT)
									expect(data.createTodo.description).toEqual(
										CREATE_TODO_RESULT.createTodo.description
									)
									expect((errors :: any)[1].message).toEqual(
										expect.stringContaining(CREATE_TODO_ERROR)
									)
								end)
							end)
						end
						useEffect(function()
							doIt()
						end, {})

						return nil
					end

					render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

					return wait_():andThen(resolve, reject)
				end):expect()
			end)
		end)

		it("should return the current client instance in the result object", function()
			return Promise.new(function(resolve, reject)
				local function Component()
					local ref = useMutation(CREATE_TODO_MUTATION)
					-- ROBLOX FIXME: using rejectOnComponentThrow to propagate error to test runner
					rejectOnComponentThrow(reject, function()
						local refSecond = ref[2] :: MutationTupleSecond<any, any, any, any>
						local client = refSecond.client
						expect(client).toBeDefined()
						expect(client).toBeInstanceOf(ApolloClient)
					end)
					return nil
				end

				render(React.createElement(MockedProvider, nil, React.createElement(Component)))

				return wait_():andThen(resolve, reject)
			end):expect()
		end)

		it("should merge provided variables", function()
			return Promise.resolve()
				:andThen(function()
					local mocks = {
						{
							request = {
								query = CREATE_TODO_MUTATION,
								variables = {
									priority = "Low",
									description = "Get milk.",
								},
							},
							result = {
								data = {
									createTodo = {
										id = 1,
										description = "Get milk!",
										priority = "Low",
										__typename = "Todo",
									},
								},
							},
						},
					}

					local function Component()
						local ref = useMutation(CREATE_TODO_MUTATION, { variables = { priority = "Low" } })
						local createTodo, result =
							ref[1] :: MutationTupleFirst<any, any, any, any>,
							ref[2] :: MutationTupleSecond<any, any, any, any>

						useEffect(function()
							createTodo({ variables = { description = "Get milk." } })
						end, {})

						-- ROBLOX deviation: using TextLabel instead of empty wrapper
						local data: any = result.data
						return React.createElement("TextLabel", {
							Text = Boolean.toJSBoolean(data) and sortedEncode(data.createTodo) or nil,
						})
					end

					local getByText = render(
						React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component))
					).getByText

					waitFor(function()
						-- ROBLOX deviation: sortedEncode prints object fields alphabetical order. Adjusting expectations to account for that.
						getByText('{"__typename":"Todo","description":"Get milk!","id":1,"priority":"Low"}')
					end):expect()
				end)
				:expect()
		end)
	end)

	describe("ROOT_MUTATION cache data", function()
		local startTime = DateTime.now().UnixTimestampMillis
		local link = ApolloLink.new(function(_self, operation)
			return Observable.new(function(observer)
				observer:next({
					data = {
						__typename = "Mutation",
						doSomething = {
							__typename = "MutationPayload",
							time = startTime,
						},
					},
				})
				observer:complete()
			end)
		end)

		local mutation = gql([[

      mutation DoSomething {
        doSomething {
          time
        }
      }
    ]])

		itAsync("should be removed by default after the mutation", function(resolve, reject)
			local timeReadCount = 0
			local timeMergeCount = 0

			local client = ApolloClient.new({
				link = link,
				cache = InMemoryCache.new({
					typePolicies = {
						MutationPayload = {
							fields = {
								time = {
									read = function(_self, ms: number?)
										if ms == nil then
											ms = DateTime.now().UnixTimestampMillis
										end
										timeReadCount += 1
										return DateTime.fromUnixTimestampMillis(ms :: number)
									end,
									merge = function(_self, existing, incoming: number)
										timeMergeCount += 1
										expect(existing).toBeUndefined()
										return incoming
									end,
								},
							},
						},
					},
				} :: FIX_ANALYZE),
			})

			local renderCount = 0
			local function Component()
				-- This test differs from the following test primarily by *not* passing
				-- keepRootFields: true in the useMutation options.
				local ref = useMutation(mutation)
				local mutate = ref[1] :: MutationTupleFirst<any, any, any, any>
				local result = ref[2] :: MutationTupleSecond<any, any, any, any>

				renderCount += 1
				local condition = renderCount
				if condition == 1 then
					do
						expect(result.loading).toBe(false)
						expect(result.called).toBe(false)
						expect(result.data).toBeUndefined()

						mutate({
								update = function(_self, cache, ref)
									local __typename, time = ref.data.doSomething.__typename, ref.data.doSomething.time
									expect(__typename).toBe("MutationPayload")
									-- ROBLOX deviation START: not Date object in Lua
									expect(typeof(time)).toBe("DateTime")
									expect(time.UnixTimestampMillis).toBe(startTime)
									-- ROBLOX deviation END
									expect(timeReadCount).toBe(1)
									expect(timeMergeCount).toBe(1)
									-- The contents of the ROOT_MUTATION object exist only briefly,
									-- for the duration of the mutation update, and are removed
									-- after the mutation write is finished.
									expect(cache:extract()).toEqual({
										ROOT_MUTATION = {
											__typename = "Mutation",
											doSomething = {
												__typename = "MutationPayload",
												time = startTime,
											},
										},
									})
								end,
							})
							:andThen(function(ref: any)
								local __typename, time = ref.data.doSomething.__typename, ref.data.doSomething.time
								expect(__typename).toBe("MutationPayload")
								-- ROBLOX deviation START: not Date object in Lua
								expect(typeof(time)).toBe("DateTime")
								expect(time.UnixTimestampMillis).toBe(startTime)
								-- ROBLOX deviation END
								expect(timeReadCount).toBe(1)
								expect(timeMergeCount).toBe(1)
								-- The contents of the ROOT_MUTATION object exist only briefly,
								-- for the duration of the mutation update, and are removed after
								-- the mutation write is finished.
								expect(client.cache:extract()).toEqual({
									ROOT_MUTATION = { __typename = "Mutation" },
								})
							end)
							:catch(reject)
					end
				elseif condition == 2 then
					do
						expect(result.loading).toBe(true)
						expect(result.called).toBe(true)
						expect(result.data).toBeUndefined()
					end
				elseif condition == 3 then
					do
						expect(result.loading).toBe(false)
						expect(result.called).toBe(true)
						local data: any = result.data
						local __typename, time = data.doSomething.__typename, data.doSomething.time
						expect(__typename).toBe("MutationPayload")
						-- ROBLOX deviation START: not Date object in Lua
						expect(typeof(time)).toBe("DateTime")
						expect(time.UnixTimestampMillis).toBe(startTime)
						-- ROBLOX deviation END
					end
				else
					console.log(result)
					reject("too many renders")
				end

				return nil
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component)))

			return waitFor(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)

		itAsync("can be preserved by passing keepRootFields: true", function(resolve, reject)
			local timeReadCount = 0
			local timeMergeCount = 0

			local client = ApolloClient.new({
				link = link,
				cache = InMemoryCache.new({
					typePolicies = {
						MutationPayload = {
							fields = {
								time = {
									read = function(_self, ms: number)
										if ms == nil then
											ms = DateTime.now().UnixTimestampMillis
										end
										timeReadCount += 1
										return DateTime.fromUnixTimestampMillis(ms)
									end,
									merge = function(_self, existing, incoming: number)
										timeMergeCount += 1
										expect(existing).toBeUndefined()
										return incoming
									end,
								},
							},
						},
					},
				} :: FIX_ANALYZE),
			})

			local renderCount = 0
			local function Component()
				local ref = useMutation(mutation, {
					-- This test differs from the previous test primarily by passing
					-- keepRootFields:true in the useMutation options.
					keepRootFields = true,
				})
				local mutate, result =
					ref[1] :: MutationTupleFirst<any, any, any, any>, ref[2] :: MutationTupleSecond<any, any, any, any>

				renderCount += 1
				local condition = renderCount
				if condition == 1 then
					do
						expect(result.loading).toBe(false)
						expect(result.called).toBe(false)
						expect(result.data).toBeUndefined()
						mutate({
								update = function(_self, cache, ref)
									local __typename, time = ref.data.doSomething.__typename, ref.data.doSomething.time
									expect(__typename).toBe("MutationPayload")
									-- ROBLOX deviation START: not Date object in Lua
									expect(typeof(time)).toBe("DateTime")
									expect(time.UnixTimestampMillis).toBe(startTime)
									-- ROBLOX deviation END
									expect(timeReadCount).toBe(1)
									expect(timeMergeCount).toBe(1)
									expect(cache:extract()).toEqual({
										ROOT_MUTATION = {
											__typename = "Mutation",
											doSomething = {
												__typename = "MutationPayload",
												time = startTime,
											},
										},
									})
								end,
							})
							:andThen(function(ref: any)
								local __typename, time = ref.data.doSomething.__typename, ref.data.doSomething.time
								expect(__typename).toBe("MutationPayload")
								-- ROBLOX deviation START: not Date object in Lua
								expect(typeof(time)).toBe("DateTime")
								expect(time.UnixTimestampMillis).toBe(startTime)
								-- ROBLOX deviation END
								expect(timeReadCount).toBe(1)
								expect(timeMergeCount).toBe(1)
								expect(client.cache:extract()).toEqual({
									ROOT_MUTATION = {
										__typename = "Mutation",
										doSomething = {
											__typename = "MutationPayload",
											time = startTime,
										},
									},
								})
							end)
							:catch(reject)
					end
				elseif condition == 2 then
					do
						expect(result.loading).toBe(true)
						expect(result.called).toBe(true)
						expect(result.data).toBeUndefined()
					end
				elseif condition == 3 then
					do
						expect(result.loading).toBe(false)
						expect(result.called).toBe(true)
						local data: any = result.data
						local __typename, time = data.doSomething.__typename, data.doSomething.time
						expect(__typename).toBe("MutationPayload")
						-- ROBLOX deviation START: not Date object in Lua
						expect(typeof(time)).toBe("DateTime")
						expect(time.UnixTimestampMillis).toBe(startTime)
						-- ROBLOX deviation END
					end
				else
					console.log(result)
					reject("too many renders")
				end

				return nil
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component)))

			return waitFor(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)
	end)

	describe("Update function", function()
		itAsync("should be called with the provided variables", function(resolve, reject)
			local variables = {
				description = "Get milk!",
			}

			local mocks = {
				{
					request = {
						query = CREATE_TODO_MUTATION,
						variables = variables,
					},
					result = { data = CREATE_TODO_RESULT },
				},
			}

			local variablesMatched = false
			local function Component()
				local createTodo = useMutation(CREATE_TODO_MUTATION, {
					update = function(_self, _, __, options)
						expect(options.variables).toEqual(variables)
						variablesMatched = true
					end,
				})[1] :: MutationTupleFirst<any, any, any, any>

				useEffect(function()
					createTodo({ variables = variables })
				end, {})

				return nil
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

			return waitFor(function()
				expect(variablesMatched).toBe(true)
			end):andThen(resolve, reject)
		end)

		itAsync("should be called with the provided context", function(resolve, reject)
			local context = { id = 3 }

			local variables = {
				description = "Get milk!",
			}

			local mocks = {
				{
					request = {
						query = CREATE_TODO_MUTATION,
						variables = variables,
					},
					result = { data = CREATE_TODO_RESULT },
				},
			}

			local foundContext = false
			local function Component()
				local createTodo = useMutation(CREATE_TODO_MUTATION, {
					context = context,
					update = function(_self, _, __, options)
						expect(options.context).toEqual(context)
						foundContext = true
					end,
				})[1] :: MutationTupleFirst<any, any, any, any>

				useEffect(function()
					createTodo({ variables = variables })
				end, {})

				return nil
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

			return waitFor(function()
				expect(foundContext).toBe(true)
			end):andThen(resolve, reject)
		end)

		describe("If context is not provided", function()
			itAsync("should be undefined", function(resolve, reject)
				local variables = {
					description = "Get milk!",
				}

				local mocks = {
					{
						request = {
							query = CREATE_TODO_MUTATION,
							variables = variables,
						},
						result = { data = CREATE_TODO_RESULT },
					},
				}

				local checkedContext = false
				local function Component()
					local createTodo = useMutation(CREATE_TODO_MUTATION, {
						update = function(_self, _, __, options)
							expect(options.context).toBeUndefined()
							checkedContext = true
						end,
					})[1] :: MutationTupleFirst<any, any, any, any>

					useEffect(function()
						createTodo({ variables = variables })
					end, {})

					return nil
				end

				render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

				return waitFor(function()
					expect(checkedContext).toBe(true)
				end):andThen(resolve, reject)
			end)
		end)
	end)

	describe("Optimistic response", function()
		itAsync("should support optimistic response handling", function(resolve, reject)
			local optimisticResponse = {
				__typename = "Mutation",
				createTodo = {
					id = 1,
					description = "TEMPORARY",
					priority = "High",
					__typename = "Todo",
				},
			}

			local variables = {
				description = "Get milk!",
			}

			local mocks = {
				{
					request = {
						query = CREATE_TODO_MUTATION,
						variables = variables,
					},
					result = { data = CREATE_TODO_RESULT },
				},
			}

			local link = mockSingleLink(table.unpack(mocks)):setOnError(reject)
			local cache = InMemoryCache.new()
			local client = ApolloClient.new({
				cache = cache,
				link = link,
			})

			local renderCount = 0
			local function Component()
				local ref = useMutation(CREATE_TODO_MUTATION, { optimisticResponse = optimisticResponse })
				local refFirst = ref[1] :: MutationTupleFirst<any, any, any, any>
				local refSecond = ref[2] :: MutationTupleSecond<any, any, any, any>
				local createTodo, loading, data = refFirst, refSecond.loading, refSecond.data

				local condition = renderCount
				if condition == 0 then
					expect(loading).toBeFalsy()
					expect(data).toBeUndefined()
					createTodo({ variables = variables })
					local dataInStore = client.cache:extract(true)
					expect(dataInStore["Todo:1"]).toEqual(optimisticResponse.createTodo)
				elseif condition == 1 then
					expect(loading).toBeTruthy()
					expect(data).toBeUndefined()
				elseif condition == 2 then
					expect(loading).toBeFalsy()
					expect(data).toEqual(CREATE_TODO_RESULT)
				end
				renderCount += 1
				return nil
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component)))

			return waitFor(function()
				expect(renderCount).toBe(3)
			end):andThen(resolve, reject)
		end)

		itAsync("should be called with the provided context", function(resolve, reject)
			local optimisticResponse = {
				__typename = "Mutation",
				createTodo = {
					id = 1,
					description = "TEMPORARY",
					priority = "High",
					__typename = "Todo",
				},
			}

			local context = { id = 3 }

			local variables = {
				description = "Get milk!",
			}

			local mocks = {
				{
					request = {
						query = CREATE_TODO_MUTATION,
						variables = variables,
					},
					result = { data = CREATE_TODO_RESULT },
				},
			}

			local contextFn = jest.fn()

			local function Component()
				local createTodo = useMutation(CREATE_TODO_MUTATION, {
					optimisticResponse = optimisticResponse,
					context = context,
					update = function(_self, _, __, options)
						contextFn(options.context)
					end,
				})[1] :: MutationTupleFirst<any, any, any, any>

				useEffect(function()
					createTodo({ variables = variables })
				end, {})

				return nil
			end

			render(React.createElement(MockedProvider, { mocks = mocks }, React.createElement(Component)))

			return waitFor(function()
				expect(contextFn).toHaveBeenCalledTimes(2)
				expect(contextFn).toHaveBeenCalledWith(context)
			end):andThen(resolve, reject)
		end)
	end)

	describe("refetching queries", function()
		-- ROBLOX FIXME: flaky test
		itAsync.skip("can pass onQueryUpdated to useMutation", function(resolve, reject)
			type TData = {
				todoCount: number,
			}
			local countQuery: TypedDocumentNode<TData, { [string]: any }> = gql([[

        query Count { todoCount @client }
      ]])

			local optimisticResponse = {
				__typename = "Mutation",
				createTodo = {
					id = 1,
					description = "TEMPORARY",
					priority = "High",
					__typename = "Todo",
				},
			}

			local variables = {
				description = "Get milk!",
			}

			local client = ApolloClient.new({
				cache = InMemoryCache.new({
					typePolicies = {
						Query = {
							fields = {
								todoCount = function(_self, count: number?)
									if count == nil then
										count = 0
									end
									return count
								end,
							},
						},
					},
				} :: FIX_ANALYZE),
				link = mockSingleLink({
					request = {
						query = CREATE_TODO_MUTATION,
						variables = variables,
					},
					result = { data = CREATE_TODO_RESULT },
				}):setOnError(reject),
			})

			-- The goal of this test is to make sure onQueryUpdated gets called as
			-- part of the createTodo mutation, so we use this reobservePromise to
			-- await the calling of onQueryUpdated.
			type OnQueryUpdatedResults = {
				obsQuery: ObservableQuery<any, OperationVariables>,
				diff: Cache_DiffResult<TData>,
				result: ApolloQueryResult<TData>,
			}
			local resolveOnUpdate: (OnQueryUpdatedResults) -> any
			local onUpdatePromise = Promise.new(function(resolve)
				resolveOnUpdate = resolve
			end)
			local finishedReobserving = false

			local renderCount = 0
			local function Component()
				local count = useQuery(countQuery)

				local ref = useMutation(CREATE_TODO_MUTATION, {
					optimisticResponse = optimisticResponse,
					update = function(_self, cache, mutationResult)
						local result = cache:readQuery({
							query = countQuery,
						})

						cache:writeQuery({
							query = countQuery,
							data = {
								todoCount = (Boolean.toJSBoolean(result) and result.todoCount or 0) + 1,
							},
						})
					end,
				})
				local refFirst = ref[1] :: MutationTupleFirst<any, any, any, any>
				local refSecond = ref[2] :: MutationTupleSecond<any, any, any, any>
				local createTodo, loading, data = refFirst, refSecond.loading, refSecond.data

				renderCount += 1
				local condition = renderCount
				if condition == 1 then
					expect(count.loading).toBe(false)
					expect(count.data).toEqual({ todoCount = 0 })

					expect(loading).toBeFalsy()
					expect(data).toBeUndefined()

					act(function()
						createTodo({
							variables = variables,
							onQueryUpdated = function(
								_self,
								obsQuery: ObservableQuery<any, OperationVariables>,
								diff: Cache_DiffResult<any>
							)
								return obsQuery:reobserve():andThen(function(result)
									finishedReobserving = true
									resolveOnUpdate({
										obsQuery = obsQuery,
										diff = diff,
										result = result,
									})
									return result
								end)
							end,
						})
					end)
				elseif condition == 2 then
					expect(count.loading).toBe(false)
					expect(count.data).toEqual({ todoCount = 0 })

					expect(loading).toBeTruthy()
					expect(data).toBeUndefined()

					expect(finishedReobserving).toBe(false)
				elseif condition == 3 then
					expect(count.loading).toBe(false)
					expect(count.data).toEqual({ todoCount = 1 })

					expect(loading).toBe(true)
					expect(data).toBeUndefined()

					expect(finishedReobserving).toBe(false)
				elseif condition == 4 then
					expect(count.loading).toBe(false)
					expect(count.data).toEqual({ todoCount = 1 })

					expect(loading).toBe(false)
					expect(data).toEqual(CREATE_TODO_RESULT)

					expect(finishedReobserving).toBe(true)
				else
					reject("too many renders")
				end

				return nil
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(Component)))

			return wait_(function()
				return onUpdatePromise:andThen(function(results)
					expect(finishedReobserving).toBe(true)
					expect(renderCount).toBe(4)

					expect(results.diff).toEqual({
						complete = true,
						result = {
							todoCount = 1,
						},
					})

					expect(results.result).toEqual({
						loading = false,
						networkStatus = NetworkStatus.ready,
						data = {
							todoCount = 1,
						},
					})
				end)
			end):andThen(resolve, reject)
		end)

		local GET_TODOS_QUERY = gql([[

      query getTodos {
        todos {
          id
          description
          priority
        }
      }
    ]])

		local GET_TODOS_RESULT_1 = {
			todos = {
				{
					id = 2,
					description = "Walk the dog",
					priority = "Medium",
					__typename = "Todo",
				},
				{
					id = 3,
					description = "Call mom",
					priority = "Low",
					__typename = "Todo",
				},
			},
		}

		local GET_TODOS_RESULT_2 = {
			todos = {
				{
					id = 1,
					description = "Get milk!",
					priority = "High",
					__typename = "Todo",
				},
				{
					id = 2,
					description = "Walk the dog",
					priority = "Medium",
					__typename = "Todo",
				},
				{
					id = 3,
					description = "Call mom",
					priority = "Low",
					__typename = "Todo",
				},
			},
		}

		itAsync("refetchQueries with operation names should update cache", function(resolve, reject)
			local variables = { description = "Get milk!" }
			local mocks: Array<any> = {
				{
					request = { query = GET_TODOS_QUERY },
					result = { data = GET_TODOS_RESULT_1 },
				},
				{
					request = { query = CREATE_TODO_MUTATION, variables = variables },
					result = { data = CREATE_TODO_RESULT },
				},
				{
					request = { query = GET_TODOS_QUERY },
					result = { data = GET_TODOS_RESULT_2 },
				},
			}

			local link = mockSingleLink(table.unpack(mocks)):setOnError(reject)
			local client = ApolloClient.new({
				link = link,
				cache = InMemoryCache.new(),
			})

			local renderCount = 0
			local function QueryComponent()
				local ref = useQuery(GET_TODOS_QUERY)
				local loading, data = ref.loading, ref.data
				local mutate = useMutation(CREATE_TODO_MUTATION)[1] :: MutationTupleFirst<any, any, any, any>
				renderCount += 1
				local condition = renderCount
				if condition == 1 then
					expect(loading).toBe(true)
					expect(data).toBeUndefined()
				elseif condition == 2 then
					expect(loading).toBe(false)
					expect(data).toEqual(mocks[1].result.data)
					setTimeout(function()
						act(function()
							mutate({ variables = variables, refetchQueries = { "getTodos" } })
						end)
					end)
				elseif condition == 3 or condition == 4 then
					expect(loading).toBe(false)
					expect(data).toEqual(mocks[1].result.data)
				elseif condition == 5 then
					expect(loading).toBe(false)
					expect(data).toEqual(mocks[3].result.data)
				else
					reject("too many renders")
				end

				return nil
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(QueryComponent)))

			return waitFor(function()
					expect(renderCount).toBe(5)
				end)
				:andThen(function()
					expect(client:readQuery({ query = GET_TODOS_QUERY })).toEqual(mocks[3].result.data)
				end)
				:andThen(resolve, reject)
		end)

		itAsync("refetchQueries with document nodes should update cache", function(resolve, reject)
			local variables = { description = "Get milk!" }
			local mocks: Array<any> = {
				{
					request = {
						query = GET_TODOS_QUERY,
					},
					result = { data = GET_TODOS_RESULT_1 },
				},
				{
					request = {
						query = CREATE_TODO_MUTATION,
						variables = variables,
					},
					result = { data = CREATE_TODO_RESULT },
				},
				{
					request = {
						query = GET_TODOS_QUERY,
					},
					result = { data = GET_TODOS_RESULT_2 },
				},
			}

			local link = mockSingleLink(table.unpack(mocks)):setOnError(reject)
			local client = ApolloClient.new({
				link = link,
				cache = InMemoryCache.new(),
			})

			local renderCount = 0
			local function QueryComponent()
				local ref = useQuery(GET_TODOS_QUERY)
				local loading, data = ref.loading, ref.data
				local mutate = useMutation(CREATE_TODO_MUTATION)[1] :: MutationTupleFirst<any, any, any, any>
				renderCount += 1
				local condition = renderCount
				if condition == 1 then
					expect(loading).toBe(true)
					expect(data).toBeUndefined()
				elseif condition == 2 then
					expect(loading).toBe(false)
					expect(data).toEqual(mocks[1].result.data)
					setTimeout(function()
						act(function()
							mutate({ variables = variables, refetchQueries = { GET_TODOS_QUERY } })
						end)
					end)
				elseif condition == 3 or condition == 4 then
					expect(loading).toBe(false)
					expect(data).toEqual(mocks[1].result.data)
				elseif condition == 5 then
					expect(loading).toBe(false)
					expect(data).toEqual(mocks[3].result.data)
				else
					reject("too many renders")
				end

				return nil
			end

			render(React.createElement(ApolloProvider, { client = client }, React.createElement(QueryComponent)))

			return waitFor(function()
					expect(renderCount).toBe(5)
				end)
				:andThen(function()
					expect(client:readQuery({ query = GET_TODOS_QUERY })).toEqual(mocks[3].result.data)
				end)
				:andThen(resolve, reject)
		end)

		--[[
				ROBLOX FIXME:
				the test is passing intermittently
				it seems to fail due to the setTimeout and Promise resolution order not being deterministic
			]]
		itAsync.skip("refetchQueries should update cache after unmount", function(resolve, reject)
			local variables = { description = "Get milk!" }
			local mocks: Array<any> = {
				{
					request = {
						query = GET_TODOS_QUERY,
					},
					result = { data = GET_TODOS_RESULT_1 },
				},
				{
					request = {
						query = CREATE_TODO_MUTATION,
						variables = variables,
					},
					result = {
						data = CREATE_TODO_RESULT,
					},
				},
				{
					request = {
						query = GET_TODOS_QUERY,
					},
					result = { data = GET_TODOS_RESULT_2 },
				},
			}

			local link = mockSingleLink(table.unpack(mocks)):setOnError(reject)
			local client = ApolloClient.new({
				link = link,
				cache = InMemoryCache.new(),
			})

			local unmount: Function
			local renderCount = 0
			local function QueryComponent()
				local ref = useQuery(GET_TODOS_QUERY)
				local loading, data = ref.loading, ref.data
				local mutate = useMutation(CREATE_TODO_MUTATION)[1] :: MutationTupleFirst<any, any, any, any>
				renderCount += 1
				local condition = renderCount
				if condition == 1 then
					expect(loading).toBe(true)
					expect(data).toBeUndefined()
				elseif condition == 2 then
					expect(loading).toBe(false)
					expect(data).toEqual(mocks[1].result.data)
					setTimeout(function()
						act(function()
							mutate({
								variables = variables,
								refetchQueries = { "getTodos" },
								update = function(_self)
									unmount()
								end,
							})
						end)
					end)
				elseif condition == 3 then
					expect(loading).toBe(false)
					expect(data).toEqual(mocks[1].result.data)
				else
					reject("too many renders")
				end

				return nil
			end

			--[[
					ROBLOX deviation:
					ROBLOX FIXME
					due to the the order of delayed task not following the same sequence as in JS
					wrapping with jest.fn to be able to wait for unmount being called
				]]
			unmount = jest.fn(
				render(React.createElement(ApolloProvider, { client = client }, React.createElement(QueryComponent))).unmount
			)

			return waitFor(function()
					expect(renderCount).toBe(3)
					--[[
						ROBLOX deviation:
						ROBLOX FIXME
						due to the the order of delayed task not following the same sequence as in JS
						waiting for unmount to be called
					]]
					expect(unmount).toHaveBeenCalled()
				end)
				:andThen(function()
					expect(client:readQuery({ query = GET_TODOS_QUERY })).toEqual(mocks[3].result.data)
				end)
				:andThen(resolve, reject)
		end)
	end)
end)

return {}
