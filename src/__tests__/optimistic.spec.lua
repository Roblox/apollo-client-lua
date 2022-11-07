-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/__tests__/optimistic.ts
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local jest = JestGlobals.jest

local function assertions(count: number, fn: (...any) -> ...any)
	local originalexpect = expect
	local spy = jest.fn(originalexpect)
	expect = spy

	fn()

	expect = originalexpect
	expect(spy).toHaveBeenCalledTimes(count)
end

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
local Object = LuauPolyfill.Object

type Array<T> = LuauPolyfill.Array<T>
type ReturnType<T> = any

-- ROBLOX FIXME: remove if better solution is found
type FIX_ANALYZE = any

local Promise = require(rootWorkspace.Promise)

-- ROBLOX deviation START: no RxJS avaialable
-- local rxjsModule = require(Packages.rxjs)
-- local from = rxjsModule.from
-- local ObservableInput = rxjsModule.ObservableInput
-- local operatorsModule = require(Packages.rxjs.operators)
-- local take = operatorsModule.take
-- local toArray = operatorsModule.toArray
-- local map = operatorsModule.map
-- ROBLOX deviation END
-- ROBLOX deviation START: using other deps instead of lodash
-- local lodashModule = require(Packages.lodash)
local assign = Object.assign
local cloneDeep = require(srcWorkspace.utilities.common.cloneDeep).cloneDeep
-- ROBLOX deviation END
local gql = require(rootWorkspace.GraphQLTag).default

local coreModule = require(script.Parent.Parent.core)
local ApolloClient = coreModule.ApolloClient
local makeReference = coreModule.makeReference
local ApolloLink = coreModule.ApolloLink
-- ROBLOX deviation START: importing ApolloCache from Cache
local cacheModule = require(script.Parent.Parent.cache)
type ApolloCache<TSerialized> = cacheModule.ApolloCache<TSerialized>
-- ROBLOX deviation END
type MutationQueryReducersMap<T> = coreModule.MutationQueryReducersMap<T>

local queryManagerModule = require(script.Parent.Parent.core.QueryManager)
type QueryManager<TStore> = queryManagerModule.QueryManager<TStore>

type Cache_DiffResult<T> = cacheModule.Cache_DiffResult<T>
local InMemoryCache = cacheModule.InMemoryCache
type InMemoryCache = cacheModule.InMemoryCache

local utilitiesModule = require(script.Parent.Parent.utilities)
local Observable = utilitiesModule.Observable
type Subscription = utilitiesModule.ObservableSubscription
local addTypenameToDocument = utilitiesModule.addTypenameToDocument

local testingModule = require(script.Parent.Parent.testing)
local stripSymbols = testingModule.stripSymbols
local itAsync = testingModule.itAsync
local mockSingleLink = testingModule.mockSingleLink

describe("optimistic mutation results", function()
	local query = gql([[

    query todoList {
      __typename
      todoList(id: 5) {
        __typename
        id
        todos {
          id
          __typename
          text
          completed
        }
        filteredTodos: todos(completed: true) {
          id
          __typename
          text
          completed
        }
      }
      noIdList: todoList(id: 6) {
        __typename
        id
        todos {
          __typename
          text
          completed
        }
      }
    }
  ]])

	local result: any = {
		data = {
			__typename = "Query",
			todoList = {
				__typename = "TodoList",
				id = "5",
				todos = {
					{ __typename = "Todo", id = "3", text = "Hello world", completed = false },
					{ __typename = "Todo", id = "6", text = "Second task", completed = false },
					{ __typename = "Todo", id = "12", text = "Do other stuff", completed = false },
				},
				filteredTodos = {},
			},
			noIdList = {
				__typename = "TodoList",
				id = "7",
				todos = {
					{ __typename = "Todo", text = "Hello world", completed = false },
					{ __typename = "Todo", text = "Second task", completed = false },
					{ __typename = "Todo", text = "Do other stuff", completed = false },
				},
			},
		},
	}

	local function setup(reject: (reason: any) -> any, ...: any)
		local mockedResponses = { ... }

		return Promise.resolve():andThen(function()
			local link = mockSingleLink({ request = { query = query }, result = result }, table.unpack(mockedResponses))

			local client = ApolloClient.new({
				link = link,
				cache = InMemoryCache.new({
					typePolicies = {
						TodoList = {
							fields = {
								-- Deliberately silence "Cache data may be lost..."
								-- warnings by favoring the incoming data, rather than
								-- (say) concatenating the arrays together.
								todos = { merge = false },
							} :: FIX_ANALYZE,
						},
					},
					dataIdFromObject = function(_self, obj: any)
						if Boolean.toJSBoolean(obj.id) and Boolean.toJSBoolean(obj.__typename) then
							return obj.__typename .. obj.id
						end
						return nil
					end,
				}),
				-- Enable client.queryManager.mutationStore tracking.
				connectToDevTools = true,
			})

			local obsHandle = client:watchQuery({ query = query })
			obsHandle:result():expect()

			return client
		end)
	end

	describe("error handling", function()
		local mutation = gql([[

      mutation createTodo {
        # skipping arguments in the test since they don't matter
        createTodo {
          id
          text
          completed
          __typename
        }
        __typename
      }
    ]])

		local mutationResult = {
			data = {
				__typename = "Mutation",
				createTodo = {
					__typename = "Todo",
					id = "99",
					text = "This one was created with a mutation.",
					completed = true,
				},
			},
		}

		local mutationResult2 = {
			data = assign({}, mutationResult.data, {
				createTodo = assign({}, mutationResult.data.createTodo, { id = "66", text = "Second mutation." }),
			}),
		}

		local optimisticResponse = {
			__typename = "Mutation",
			createTodo = {
				__typename = "Todo",
				id = "99",
				text = "Optimistically generated",
				completed = true,
			},
		}

		local optimisticResponse2 = assign({}, optimisticResponse, {
			createTodo = assign({}, optimisticResponse.createTodo, { id = "66", text = "Optimistically generated 2" }),
		})

		describe("with `updateQueries`", function()
			local updateQueries = {
				todoList = function(_self, prev: any, options: any)
					local state = cloneDeep(prev)
					table.insert(state.todoList.todos, 1, options.mutationResult.data.createTodo)
					return state
				end,
			}
			itAsync("handles a single error for a single mutation", function(resolve, reject)
				Promise.resolve():andThen(function()
					--[[
							ROBLOX deviation: using custom assertions function to verify nr of assertions called
							original code:
							expect.assertions(6)
						]]
					assertions(6, function()
						local client = setup(
							reject,
							{ request = { query = mutation }, error = Error.new("forbidden (test error)") }
						):expect()
						local ok, result = pcall(function()
							local promise = client:mutate({
								mutation = mutation,
								optimisticResponse = optimisticResponse,
								updateQueries = updateQueries,
							})
							local dataInStore = (client.cache :: InMemoryCache):extract(true)
							expect(#(dataInStore["TodoList5"] :: any).todos).toBe(4)
							expect((dataInStore["Todo99"] :: any).text).toBe("Optimistically generated")
							promise:expect()
						end)
						if not ok then
							local err = result
							expect(err).toBeInstanceOf(Error)
							expect(err.message).toBe("forbidden (test error)")
							local dataInStore = (client.cache :: InMemoryCache):extract(true)
							expect(#(dataInStore["TodoList5"] :: any).todos).toBe(3)
							expect(stripSymbols(dataInStore)).never.toHaveProperty("Todo99")
						end
					end)

					resolve()
				end)
			end)

			itAsync("handles errors produced by one mutation in a series", function(resolve, reject)
				Promise.resolve():andThen(function()
					--[[
							ROBLOX deviation: using custom assertions function to verify nr of assertions called
							original code:
							expect.assertions(10)
						]]
					assertions(10, function()
						local subscriptionHandle: Subscription
						local client = setup(
							reject,
							{ request = { query = mutation }, error = Error.new("forbidden (test error)") },
							{ request = { query = mutation }, result = mutationResult2 }
						):expect()

						-- we have to actually subscribe to the query to be able to update it
						Promise.new(function(resolve)
							local handle = client:watchQuery({ query = query })
							subscriptionHandle = handle:subscribe({
								next = function(self, res: any)
									resolve(res)
								end,
							})
						end):expect()

						local promise = client
							:mutate({
								mutation = mutation,
								optimisticResponse = optimisticResponse,
								updateQueries = updateQueries,
							})
							:catch(function(err: any)
								-- it is ok to fail here
								expect(err).toBeInstanceOf(Error)
								expect(err.message).toBe("forbidden (test error)")
								return nil
							end)

						local promise2 = client:mutate({
							mutation = mutation,
							optimisticResponse = optimisticResponse2,
							updateQueries = updateQueries,
						})

						local dataInStore = (client.cache :: InMemoryCache):extract(true)
						expect(#(dataInStore["TodoList5"] :: any).todos).toBe(5)
						expect((dataInStore["Todo99"] :: any).text).toBe("Optimistically generated")
						expect((dataInStore["Todo66"] :: any).text).toBe("Optimistically generated 2")

						Promise.all({ promise, promise2 }):expect();

						(subscriptionHandle :: any):unsubscribe()
						do
							local dataInStore_ = (client.cache :: InMemoryCache):extract(true)
							expect(#(dataInStore_["TodoList5"] :: any).todos).toBe(4)
							expect(stripSymbols(dataInStore_)).never.toHaveProperty("Todo99")
							expect(dataInStore_).toHaveProperty("Todo66")
							expect((dataInStore_["TodoList5"] :: any).todos).toContainEqual(makeReference("Todo66"))
							expect((dataInStore_["TodoList5"] :: any).todos).never.toContainEqual(
								makeReference("Todo99")
							)
						end
					end)
					-- ROBLOX deviation: move resolve after assertions count check
					resolve()
				end)
			end)

			itAsync(
				"can run 2 mutations concurrently and handles all intermediate states well",
				function(resolve, reject)
					Promise.resolve():andThen(function()
						--[[
								ROBLOX deviation: using custom assertions function to verify nr of assertions called
								original code:
								expect.assertions(34)
							]]
						assertions(34, function()
							-- ROBLOX deviation: predefine variable
							local client
							local function checkBothMutationsAreApplied(expectedText1: any, expectedText2: any)
								local dataInStore = (client.cache :: InMemoryCache):extract(true)
								expect(#(dataInStore["TodoList5"] :: any).todos).toBe(5)
								expect(dataInStore).toHaveProperty("Todo99")
								expect(dataInStore).toHaveProperty("Todo66")
								-- <any> can be removed once @types/chai adds deepInclude
								expect((dataInStore["TodoList5"] :: any).todos).toContainEqual(makeReference("Todo66"))
								expect((dataInStore["TodoList5"] :: any).todos).toContainEqual(makeReference("Todo99"))
								expect((dataInStore["Todo99"] :: any).text).toBe(expectedText1)
								expect((dataInStore["Todo66"] :: any).text).toBe(expectedText2)
							end
							local subscriptionHandle: Subscription

							client = setup(reject, {
								request = { query = mutation },
								result = mutationResult,
							}, {
								request = { query = mutation },
								result = mutationResult2,
								-- make sure it always happens later
								delay = 100,
							}):expect()
							-- we have to actually subscribe to the query to be able to update it
							Promise.new(function(resolve)
								local handle = client:watchQuery({ query = query })
								subscriptionHandle = handle:subscribe({
									next = function(_self, res: any)
										resolve(res)
									end,
								})
							end):expect()

							local queryManager: QueryManager<any> = (client :: any).queryManager

							local promise = client
								:mutate({
									mutation = mutation,
									optimisticResponse = optimisticResponse,
									updateQueries = updateQueries,
								})
								:andThen(function(res: any)
									checkBothMutationsAreApplied(
										"This one was created with a mutation.",
										"Optimistically generated 2"
									)

									-- @ts-ignore
									local latestState = queryManager.mutationStore :: any
									-- ROBLOX deviation START: latestState is an object so we need to index like an object
									expect(latestState[tostring(1)].loading).toBe(false)
									expect(latestState[tostring(2)].loading).toBe(true)
									-- ROBLOX deviation END

									return res
								end)

							local promise2 = client
								:mutate({
									mutation = mutation,
									optimisticResponse = optimisticResponse2,
									updateQueries = updateQueries,
								})
								:andThen(function(res: any)
									checkBothMutationsAreApplied(
										"This one was created with a mutation.",
										"Second mutation."
									)

									-- @ts-ignore
									local latestState = queryManager.mutationStore :: any
									-- ROBLOX deviation START: latestState is an object so we need to index like an object
									expect(latestState[tostring(1)].loading).toBe(false)
									expect(latestState[tostring(2)].loading).toBe(false)
									-- ROBLOX deviation END

									return res
								end)

							-- @ts-ignore
							local mutationsState = queryManager.mutationStore :: any
							-- ROBLOX deviation START: mutationsState is an object so we need to index like an object
							expect(mutationsState[tostring(1)].loading).toBe(true)
							expect(mutationsState[tostring(2)].loading).toBe(true)
							-- ROBLOX deviation END

							checkBothMutationsAreApplied("Optimistically generated", "Optimistically generated 2")

							Promise.all({ promise, promise2 }):expect();

							(subscriptionHandle :: any):unsubscribe()
							checkBothMutationsAreApplied("This one was created with a mutation.", "Second mutation.")
						end)

						resolve()
					end)
				end
			)
		end)

		describe("with `update`", function()
			local function update(_self, proxy: any, mResult: any)
				local data: any = proxy:readFragment({
					id = "TodoList5",
					fragment = gql([[

            fragment todoList on TodoList {
              todos {
                id
                text
                completed
                __typename
              }
            }
          ]]),
				})

				proxy:writeFragment({
					data = Object.assign({}, data, {
						todos = Array.concat({}, { mResult.data.createTodo }, data.todos),
					}),
					id = "TodoList5",
					fragment = gql([[

            fragment todoList on TodoList {
              todos {
                id
                text
                completed
                __typename
              }
            }
          ]]),
				})
			end

			itAsync("handles a single error for a single mutation", function(resolve, reject)
				Promise.resolve():andThen(function()
					--[[
							ROBLOX deviation: using custom assertions function to verify nr of assertions called
							original code:
							expect.assertions(6)
						]]
					assertions(6, function()
						local client = setup(
							reject,
							{ request = { query = mutation }, error = Error.new("forbidden (test error)") }
						):expect()

						local ok, err = pcall(function()
							local promise = client:mutate({
								mutation = mutation,
								optimisticResponse = optimisticResponse,
								update = update,
							})

							local dataInStore = (client.cache :: InMemoryCache):extract(true)
							expect(#(dataInStore["TodoList5"] :: any).todos).toBe(4)
							expect((dataInStore["Todo99"] :: any).text).toBe("Optimistically generated")

							promise:expect()
						end)
						if not ok then
							expect(err).toBeInstanceOf(Error)
							expect(err.message).toBe("forbidden (test error)")

							local dataInStore = (client.cache :: InMemoryCache):extract(true)
							expect(#(dataInStore["TodoList5"] :: any).todos).toBe(3)
							expect(stripSymbols(dataInStore)).never.toHaveProperty("Todo99")
						end
					end)

					resolve()
				end)
			end)

			itAsync("handles errors produced by one mutation in a series", function(resolve, reject)
				Promise.resolve():andThen(function()
					--[[
							ROBLOX deviation: using custom assertions function to verify nr of assertions called
							original code:
							expect.assertions(10)
						]]
					assertions(10, function()
						local subscriptionHandle: Subscription
						local client = setup(
							reject,
							{ request = { query = mutation }, error = Error.new("forbidden (test error)") },
							{ request = { query = mutation }, result = mutationResult2 }
						):expect()

						-- we have to actually subscribe to the query to be able to update it
						Promise.new(function(resolve)
							local handle = client:watchQuery({ query = query })
							subscriptionHandle = handle:subscribe({
								next = function(self, res: any)
									resolve(res)
								end,
							})
						end):expect()

						local promise = client
							:mutate({
								mutation = mutation,
								optimisticResponse = optimisticResponse,
								update = update,
							})
							:catch(function(err: any)
								-- it is ok to fail here
								expect(err).toBeInstanceOf(Error)
								expect(err.message).toBe("forbidden (test error)")
								return nil
							end)

						local promise2 = client:mutate({
							mutation = mutation,
							optimisticResponse = optimisticResponse2,
							update = update,
						})

						local dataInStore = (client.cache :: InMemoryCache):extract(true)
						expect(#(dataInStore["TodoList5"] :: any).todos).toBe(5)
						expect((dataInStore["Todo99"] :: any).text).toBe("Optimistically generated")
						expect((dataInStore["Todo66"] :: any).text).toBe("Optimistically generated 2")

						Promise.all({ promise, promise2 }):expect();

						(subscriptionHandle :: any):unsubscribe()
						do
							local dataInStore_ = (client.cache :: InMemoryCache):extract(true)
							expect(#(dataInStore_["TodoList5"] :: any).todos).toBe(4)
							expect(stripSymbols(dataInStore_)).never.toHaveProperty("Todo99")
							expect(dataInStore_).toHaveProperty("Todo66")
							expect((dataInStore_["TodoList5"] :: any).todos).toContainEqual(makeReference("Todo66"))
							expect((dataInStore_["TodoList5"] :: any).todos).never.toContainEqual(
								makeReference("Todo99")
							)
						end
					end)
					-- ROBLOX deviation: move resolve after assertions count check
					resolve()
				end)
			end)

			itAsync(
				"can run 2 mutations concurrently and handles all intermediate states well",
				function(resolve, reject)
					Promise.resolve():andThen(function()
						--[[
								ROBLOX deviation: using custom assertions function to verify nr of assertions called
								original code:
								expect.assertions(34)
							]]
						assertions(34, function()
							-- ROBLOX deviation: predefine variable
							local client
							local function checkBothMutationsAreApplied(expectedText1: any, expectedText2: any)
								local dataInStore = (client.cache :: InMemoryCache):extract(true)
								expect(#(dataInStore["TodoList5"] :: any).todos).toBe(5)
								expect(dataInStore).toHaveProperty("Todo99")
								expect(dataInStore).toHaveProperty("Todo66")
								expect((dataInStore["TodoList5"] :: any).todos).toContainEqual(makeReference("Todo66"))
								expect((dataInStore["TodoList5"] :: any).todos).toContainEqual(makeReference("Todo99"))
								expect((dataInStore["Todo99"] :: any).text).toBe(expectedText1)
								expect((dataInStore["Todo66"] :: any).text).toBe(expectedText2)
							end
							local subscriptionHandle: Subscription

							client = setup(reject, {
								request = { query = mutation },
								result = mutationResult,
							}, {
								request = { query = mutation },
								result = mutationResult2,
								-- make sure it always happens later
								delay = 100,
							}):expect()

							-- we have to actually subscribe to the query to be able to update it
							Promise.new(function(resolve)
								local handle = client:watchQuery({ query = query })
								subscriptionHandle = handle:subscribe({
									next = function(self, res: any)
										resolve(res)
									end,
								})
							end):expect()

							local promise = client
								:mutate({
									mutation = mutation,
									optimisticResponse = optimisticResponse,
									update = update,
								})
								:andThen(function(res: any)
									checkBothMutationsAreApplied(
										"This one was created with a mutation.",
										"Optimistically generated 2"
									)

									-- @ts-ignore
									local latestState = client.queryManager.mutationStore :: any
									-- ROBLOX deviation START: mutationId is a string that is initialized to 1 instead of a number.
									expect(latestState["1"].loading).toBe(false)
									expect(latestState["2"].loading).toBe(true)
									-- ROBLOX deviation END

									return res
								end)

							local promise2 = client
								:mutate({
									mutation = mutation,
									optimisticResponse = optimisticResponse2,
									update = update,
								})
								:andThen(function(res: any)
									checkBothMutationsAreApplied(
										"This one was created with a mutation.",
										"Second mutation."
									)

									-- @ts-ignore
									local latestState = client.queryManager.mutationStore :: any
									-- ROBLOX deviation START: mutationId is a string that is initialized to 1 instead of a number.
									expect(latestState["1"].loading).toBe(false)
									expect(latestState["2"].loading).toBe(false)
									-- ROBLOX deviation END

									return res
								end)

							-- @ts-ignore
							local mutationsState = client.queryManager.mutationStore :: any
							-- ROBLOX deviation START: mutationId is a string that is initialized to 1 instead of a number.
							expect(mutationsState["1"].loading).toBe(true)
							expect(mutationsState["2"].loading).toBe(true)
							-- ROBLOX deviation END

							checkBothMutationsAreApplied("Optimistically generated", "Optimistically generated 2")

							Promise.all({ promise, promise2 }):expect();

							(subscriptionHandle :: any):unsubscribe()
							checkBothMutationsAreApplied("This one was created with a mutation.", "Second mutation.")
						end)

						resolve()
					end)
				end
			)
		end)
	end)

	describe("Apollo Client readQuery/readFragment optimistic results", function()
		local todoListMutation = gql([[

      mutation createTodo {
        # skipping arguments in the test since they don't matter
        createTodo {
          __typename
          id
          todos {
            id
            text
            completed
            __typename
          }
        }
      }
    ]])

		local todoListMutationResult = {
			data = {
				__typename = "Mutation",
				createTodo = {
					__typename = "TodoList",
					id = "5",
					todos = {
						{
							__typename = "Todo",
							id = "99",
							text = "This one was created with a mutation.",
							completed = true,
						},
					},
				},
			},
		}

		local todoListOptimisticResponse = {
			__typename = "Mutation",
			createTodo = {
				__typename = "TodoList",
				id = "5",
				todos = {
					{
						__typename = "Todo",
						id = "99",
						text = "Optimistically generated",
						completed = true,
					},
				},
			},
		}

		local todoListQuery = gql([[

      query todoList {
        todoList(id: 5) {
          __typename
          id
          todos {
            id
            __typename
            text
            completed
          }
        }
      }
    ]])

		itAsync(
			"client.readQuery should read the optimistic response of a mutation "
				.. "only when update function is called optimistically",
			function(resolve, reject)
				return setup(reject, { request = { query = todoListMutation }, result = todoListMutationResult })
					:andThen(function(client)
						local updateCount = 0
						return client:mutate({
							mutation = todoListMutation,
							optimisticResponse = todoListOptimisticResponse,
							update = function(_self, proxy: any, mResult: any)
								updateCount += 1
								local data = proxy:readQuery({ query = todoListQuery })
								local readText = data.todoList.todos[1].text
								if updateCount == 1 then
									local optimisticText = todoListOptimisticResponse.createTodo.todos[1].text
									expect(readText).toEqual(optimisticText)
								elseif updateCount == 2 then
									local incomingText = mResult.data.createTodo.todos[1].text
									expect(readText).toEqual(incomingText)
								else
									-- ROBLOX deviation: use reject instead of fail
									reject("too many update calls")
								end
							end,
						})
					end)
					:andThen(resolve, reject)
			end
		)

		local todoListFragment = gql([[

      fragment todoList on TodoList {
        todos {
          id
          text
          completed
          __typename
        }
      }
    ]])

		itAsync(
			"should read the optimistic response of a mutation when making an "
				.. "ApolloClient.readFragment() call, if the `optimistic` param is set "
				.. "to true",
			function(resolve, reject)
				return setup(reject, { request = { query = todoListMutation }, result = todoListMutationResult })
					:andThen(function(client)
						local updateCount = 0
						return client:mutate({
							mutation = todoListMutation,
							optimisticResponse = todoListOptimisticResponse,
							update = function(_self, proxy: any, mResult: any)
								updateCount += 1
								local data: any =
									proxy:readFragment({ id = "TodoList5", fragment = todoListFragment }, true)
								if updateCount == 1 then
									expect(data.todos[1].text).toEqual(
										todoListOptimisticResponse.createTodo.todos[1].text
									)
								elseif updateCount == 2 then
									expect(data.todos[1].text).toEqual(mResult.data.createTodo.todos[1].text)
									expect(data.todos[1].text).toEqual(
										todoListMutationResult.data.createTodo.todos[1].text
									)
								else
									-- ROBLOX deviation: use reject instead of fail
									reject("too many update calls")
								end
							end,
						})
					end)
					:andThen(resolve, reject)
			end
		)

		itAsync(
			"should not read the optimistic response of a mutation when making "
				.. "an ApolloClient.readFragment() call, if the `optimistic` param is "
				.. "set to false",
			function(resolve, reject)
				return setup(reject, { request = { query = todoListMutation }, result = todoListMutationResult })
					:andThen(function(client)
						return client:mutate({
							mutation = todoListMutation,
							optimisticResponse = todoListOptimisticResponse,
							update = function(_self, proxy: any, mResult: any)
								local incomingText = mResult.data.createTodo.todos[1].text
								local data: any =
									proxy:readFragment({ id = "TodoList5", fragment = todoListFragment }, false)
								expect(data.todos[1].text).toEqual(incomingText)
							end,
						})
					end)
					:andThen(resolve, reject)
			end
		)
	end)

	describe("passing a function to optimisticResponse", function()
		local mutation = gql([[

      mutation createTodo($text: String) {
        createTodo(text: $text) {
          id
          text
          completed
          __typename
        }
        __typename
      }
    ]])

		local variables = { text = "Optimistically generated from variables" }

		local mutationResult = {
			data = {
				__typename = "Mutation",
				createTodo = {
					id = "99",
					__typename = "Todo",
					text = "This one was created with a mutation.",
					completed = true,
				},
			},
		}

		local function optimisticResponse(ref)
			local text = ref.text
			return {
				__typename = "Mutation",
				createTodo = { __typename = "Todo", id = "99", text = text, completed = true },
			}
		end

		itAsync("will use a passed variable in optimisticResponse", function(resolve, reject)
			Promise.resolve():andThen(function()
				--[[
						ROBLOX deviation: using custom assertions function to verify nr of assertions called
						original code:
						expect.assertions(6)
					]]
				assertions(6, function()
					local subscriptionHandle: Subscription
					local client = setup(
						reject,
						{ request = { query = mutation, variables = variables }, result = mutationResult }
					):expect()

					-- we have to actually subscribe to the query to be able to update it
					Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(self, res: any)
								resolve(res)
							end,
						})
					end):expect()

					local promise = client:mutate({
						mutation = mutation,
						variables = variables,
						optimisticResponse = optimisticResponse,
						update = function(_self, proxy: any, mResult: any)
							expect(mResult.data.createTodo.id).toBe("99")

							local id = "TodoList5"
							local fragment = gql([[

            fragment todoList on TodoList {
              todos {
                id
                text
                completed
                __typename
              }
            }
          ]])

							local data: any = proxy:readFragment({ id = id, fragment = fragment })

							proxy:writeFragment({
								data = Object.assign({}, data, {
									todos = Array.concat({}, { mResult.data.createTodo }, data.todos),
								}),
								id = id,
								fragment = fragment,
							})
						end,
					})

					local dataInStore = (client.cache :: InMemoryCache):extract(true)
					expect(#(dataInStore["TodoList5"] :: any).todos).toEqual(4)
					expect((dataInStore["Todo99"] :: any).text).toEqual("Optimistically generated from variables")

					promise:expect()

					local newResult: any = client:query({ query = query }):expect();

					(subscriptionHandle :: any):unsubscribe()
					-- There should be one more todo item than before
					expect(#newResult.data.todoList.todos).toEqual(4)

					-- Since we used `prepend` it should be at the front
					expect(newResult.data.todoList.todos[1].text).toEqual("This one was created with a mutation.")
				end)

				resolve()
			end)
		end)
	end)

	describe("optimistic updates using `updateQueries`", function()
		local mutation = gql([[

      mutation createTodo {
        # skipping arguments in the test since they don't matter
        createTodo {
          id
          text
          completed
          __typename
        }
        __typename
      }
    ]])

		type IMutationResult = {
			__typename: string,
			createTodo: { id: string, __typename: string, text: string, completed: boolean },
		}

		local mutationResult = {
			data = {
				__typename = "Mutation",
				createTodo = {
					id = "99",
					__typename = "Todo",
					text = "This one was created with a mutation.",
					completed = true,
				},
			},
		}

		local optimisticResponse = {
			__typename = "Mutation",
			createTodo = {
				__typename = "Todo",
				id = "99",
				text = "Optimistically generated",
				completed = true,
			},
		}

		local mutationResult2 = {
			data = assign({}, mutationResult.data, {
				createTodo = assign({}, mutationResult.data.createTodo, { id = "66", text = "Second mutation." }),
			}),
		}

		local optimisticResponse2 = {
			__typename = "Mutation",
			createTodo = {
				__typename = "Todo",
				id = "66",
				text = "Optimistically generated 2",
				completed = true,
			},
		}

		--[[
				ROBLOX FIXME:
				the test is passing intermittently
				it seems to fail due to the setTimeout and Promise resolution order not being deterministic
			]]
		itAsync.skip("will insert a single itemAsync to the beginning", function(resolve, reject)
			Promise.resolve():andThen(function()
				--[[
						ROBLOX deviation: using custom assertions function to verify nr of assertions called
						original code:
						expect.assertions(7)
					]]
				assertions(7, function()
					local subscriptionHandle: Subscription
					local client = setup(reject, { request = { query = mutation }, result = mutationResult }):expect()

					-- we have to actually subscribe to the query to be able to update it
					Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(_self, res: any)
								resolve(res)
							end,
						})
					end):expect()

					local promise = client:mutate({
						mutation = mutation,
						optimisticResponse = optimisticResponse,
						updateQueries = {
							todoList = function(_self, prev: any, options: any)
								local mResult = options.mutationResult :: any
								expect(mResult.data.createTodo.id).toEqual("99")
								return Object.assign({}, prev, {
									todoList = Object.assign({}, prev.todoList, {
										todos = Array.concat({}, { mResult.data.createTodo }, prev.todoList.todos),
									}),
								})
							end,
						},
					})

					local dataInStore = (client.cache :: InMemoryCache):extract(true)
					expect(#(dataInStore["TodoList5"] :: any).todos).toEqual(4)
					expect((dataInStore["Todo99"] :: any).text).toEqual("Optimistically generated")

					promise:expect()

					local newResult: any = client:query({ query = query }):expect();

					(subscriptionHandle :: any):unsubscribe()
					-- There should be one more todo item than before
					expect(#newResult.data.todoList.todos).toEqual(4)

					-- Since we used `prepend` it should be at the front
					expect(newResult.data.todoList.todos[1].text).toEqual("This one was created with a mutation.")
				end)

				resolve()
			end)
		end)

		itAsync("two array insert like mutations", function(resolve, reject)
			Promise.resolve():andThen(function()
				--[[
						ROBLOX deviation: using custom assertions function to verify nr of assertions called
						original code:
						expect.assertions(9)
					]]
				assertions(9, function()
					local subscriptionHandle: Subscription
					local client = setup(
						reject,
						{ request = { query = mutation }, result = mutationResult },
						{ request = { query = mutation }, result = mutationResult2, delay = 50 }
					):expect()

					-- we have to actually subscribe to the query to be able to update it
					Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(self, res: any)
								resolve(res)
							end,
						})
					end):expect()

					local updateQueries = {
						todoList = function(_self, prev: any, options: any)
							local mResult = options.mutationResult

							local state = cloneDeep(prev)

							if Boolean.toJSBoolean(mResult.data) then
								table.insert(state.todoList.todos, 1, mResult.data.createTodo)
							end

							return state
						end :: FIX_ANALYZE,
					} :: MutationQueryReducersMap<IMutationResult>
					local promise = client
						:mutate({
							mutation = mutation,
							optimisticResponse = optimisticResponse,
							updateQueries = updateQueries,
						})
						:andThen(function(res: any)
							local currentDataInStore = (client.cache :: InMemoryCache):extract(true)
							expect(#(currentDataInStore["TodoList5"] :: any).todos).toEqual(5)
							expect((currentDataInStore["Todo99"] :: any).text).toEqual(
								"This one was created with a mutation."
							)
							expect((currentDataInStore["Todo66"] :: any).text).toEqual("Optimistically generated 2")
							return res
						end)

					local promise2 = client:mutate({
						mutation = mutation,
						optimisticResponse = optimisticResponse2,
						updateQueries = updateQueries,
					})

					local dataInStore = (client.cache :: InMemoryCache):extract(true)
					expect(#(dataInStore["TodoList5"] :: any).todos).toEqual(5)
					expect((dataInStore["Todo99"] :: any).text).toEqual("Optimistically generated")
					expect((dataInStore["Todo66"] :: any).text).toEqual("Optimistically generated 2")

					Promise.all({ promise, promise2 }):expect()

					local newResult: any = client:query({ query = query }):expect();

					(subscriptionHandle :: any):unsubscribe()
					-- There should be one more todo item than before
					expect(#newResult.data.todoList.todos).toEqual(5)

					-- Since we used `prepend` it should be at the front
					expect(newResult.data.todoList.todos[1].text).toEqual("Second mutation.")
					expect(newResult.data.todoList.todos[2].text).toEqual("This one was created with a mutation.")
				end)
				resolve()
			end)
		end)

		itAsync("two mutations, one fails", function(resolve, reject)
			Promise.resolve():andThen(function()
				--[[
						ROBLOX deviation: using custom assertions function to verify nr of assertions called
						original code:
						expect.assertions(10)
					]]
				assertions(10, function()
					local subscriptionHandle: Subscription
					local client = setup(reject, {
						request = { query = mutation },
						error = Error.new("forbidden (test error)"),
						delay = 20,
					}, {
						request = { query = mutation },
						result = mutationResult2,
						-- XXX this test will uncover a flaw in the design of optimistic responses combined with
						-- updateQueries or result reducers if you un-comment the line below. The issue is that
						-- optimistic updates are not commutative but are treated as such. When undoing an
						-- optimistic update, other optimistic updates should be rolled back and re-applied in the
						-- same order as before, otherwise the store can end up in an inconsistent state.
						-- delay: 50,
					}):expect()

					-- we have to actually subscribe to the query to be able to update it
					Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(self, res: any)
								resolve(res)
							end,
						})
					end):expect()

					local updateQueries = {
						todoList = function(_self, prev: any, options: any)
							local mResult = options.mutationResult

							local state = cloneDeep(prev)

							if Boolean.toJSBoolean(mResult.data) then
								table.insert(state.todoList.todos, 1, mResult.data.createTodo)
							end

							return state
						end :: FIX_ANALYZE,
					} :: MutationQueryReducersMap<IMutationResult>
					local promise = client
						:mutate({
							mutation = mutation,
							optimisticResponse = optimisticResponse,
							updateQueries = updateQueries,
						})
						:catch(function(err: any)
							-- it is ok to fail here
							expect(err).toBeInstanceOf(Error)
							expect(err.message).toEqual("forbidden (test error)")
							return nil
						end)

					local promise2 = client:mutate({
						mutation = mutation,
						optimisticResponse = optimisticResponse2,
						updateQueries = updateQueries,
					})

					local dataInStore = (client.cache :: InMemoryCache):extract(true)
					expect(#(dataInStore["TodoList5"] :: any).todos).toEqual(5)
					expect((dataInStore["Todo99"] :: any).text).toEqual("Optimistically generated")
					expect((dataInStore["Todo66"] :: any).text).toEqual("Optimistically generated 2")

					Promise.all({ promise, promise2 }):expect();

					(subscriptionHandle :: any):unsubscribe()
					do
						local dataInStore_ = (client.cache :: InMemoryCache):extract(true)
						expect(#(dataInStore_["TodoList5"] :: any).todos).toEqual(4)
						expect(stripSymbols(dataInStore_)).never.toHaveProperty("Todo99")
						expect(dataInStore_).toHaveProperty("Todo66")
						expect((dataInStore_["TodoList5"] :: any).todos).toContainEqual(makeReference("Todo66"))
						expect((dataInStore_["TodoList5"] :: any).todos).never.toContainEqual(makeReference("Todo99"))
					end
				end)
				-- ROBLOX deviation: move resolve after assertions count check
				resolve()
			end)
		end)

		-- ROBLOX deviation START: no RxJS available
		-- itAsync.skip("will handle dependent updates", function(resolve, reject)
		-- 	-- ROBLOX FIXME
		-- expect:assertions(1)
		-- 	local link = mockSingleLink(
		-- 		{ request = { query = query }, result = result },
		-- 		{ request = { query = mutation }, result = mutationResult, delay = 10 },
		-- 		{ request = { query = mutation }, result = mutationResult2, delay = 20 }
		-- 	):setOnError(reject)
		-- 	local customOptimisticResponse1 = {
		-- 		__typename = "Mutation",
		-- 		createTodo = {
		-- 			__typename = "Todo",
		-- 			id = "optimistic-99",
		-- 			text = "Optimistically generated",
		-- 			completed = true,
		-- 		},
		-- 	}
		-- 	local customOptimisticResponse2 = {
		-- 		__typename = "Mutation",
		-- 		createTodo = {
		-- 			__typename = "Todo",
		-- 			id = "optimistic-66",
		-- 			text = "Optimistically generated 2",
		-- 			completed = true,
		-- 		},
		-- 	}
		-- 	local updateQueries = {
		-- 		todoList = function(prev, options)
		-- 			local mResult = options.mutationResult
		-- 			local state = cloneDeep(prev)
		-- 			if Boolean.toJSBoolean(mResult.data) then
		-- 				table.insert(state.todoList.todos, 1, mResult.data.createTodo)
		-- 			end
		-- 			return state
		-- 		end,
		-- 	} :: MutationQueryReducersMap<IMutationResult>
		-- 	local client = ApolloClient.new({
		-- 		link = link,
		-- 		cache = InMemoryCache.new({
		-- 			dataIdFromObject = function(obj: any)
		-- 				if
		-- 					Boolean.toJSBoolean((function()
		-- 						if Boolean.toJSBoolean(obj.id) then
		-- 							return obj.__typename
		-- 						else
		-- 							return obj.id
		-- 						end
		-- 					end)())
		-- 				then
		-- 					return obj.__typename + obj.id
		-- 				end
		-- 				return nil
		-- 			end,
		-- 		}),
		-- 	})
		-- 	local promise = from((client:watchQuery({ query = query }) :: any) :: ObservableInput<any>)
		-- 		:pipe(
		-- 			map(function(value)
		-- 				return stripSymbols(value.data.todoList.todos)
		-- 			end),
		-- 			take(5),
		-- 			toArray()
		-- 		)
		-- 		:toPromise()
		-- 	Promise.new(function(resolve)
		-- 		return setTimeout(resolve)
		-- 	end):expect()
		-- 	client:mutate({
		-- 		mutation = mutation,
		-- 		optimisticResponse = customOptimisticResponse1,
		-- 		updateQueries = updateQueries,
		-- 	})
		-- 	client:mutate({
		-- 		mutation = mutation,
		-- 		optimisticResponse = customOptimisticResponse2,
		-- 		updateQueries = updateQueries,
		-- 	})
		-- 	local responses = promise:expect()
		-- 	local defaultTodos = stripSymbols(result.data.todoList.todos)
		-- 	expect(responses).toEqual({
		-- 		defaultTodos,
		-- 		Array.concat({}, { customOptimisticResponse1.createTodo }, defaultTodos),
		-- 		Array.concat(
		-- 			{},
		-- 			{ customOptimisticResponse2.createTodo, customOptimisticResponse1.createTodo },
		-- 			defaultTodos
		-- 		),
		-- 		Array.concat(
		-- 			{},
		-- 			{ customOptimisticResponse2.createTodo, mutationResult.data.createTodo },
		-- 			defaultTodos
		-- 		),
		-- 		Array.concat({}, { mutationResult2.data.createTodo, mutationResult.data.createTodo }, defaultTodos),
		-- 	})
		-- 	resolve()
		-- end)
		-- ROBLOX deviation END
	end)

	describe("optimistic updates using `update`", function()
		local mutation = gql([[

      mutation createTodo {
        # skipping arguments in the test since they don't matter
        createTodo {
          id
          text
          completed
          __typename
        }
        __typename
      }
    ]])

		local mutationResult = {
			data = {
				__typename = "Mutation",
				createTodo = {
					id = "99",
					__typename = "Todo",
					text = "This one was created with a mutation.",
					completed = true,
				},
			},
		}

		local optimisticResponse = {
			__typename = "Mutation",
			createTodo = {
				__typename = "Todo",
				id = "99",
				text = "Optimistically generated",
				completed = true,
			},
		}

		local mutationResult2 = {
			data = assign({}, mutationResult.data, {
				createTodo = assign({}, mutationResult.data.createTodo, { id = "66", text = "Second mutation." }),
			}),
		}

		local optimisticResponse2 = {
			__typename = "Mutation",
			createTodo = {
				__typename = "Todo",
				id = "66",
				text = "Optimistically generated 2",
				completed = true,
			},
		}

		itAsync("will insert a single itemAsync to the beginning", function(resolve, reject)
			Promise.resolve():andThen(function()
				--[[
						ROBLOX deviation: using custom assertions function to verify nr of assertions called
						original code:
						expect.assertions(6)
					]]
				assertions(6, function()
					local subscriptionHandle: Subscription
					local client =
						setup(reject, { request = { query = mutation }, delay = 300, result = mutationResult }):expect()

					-- we have to actually subscribe to the query to be able to update it
					Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(self, res: any)
								resolve(res)
							end,
						})
					end):expect()

					local firstTime = true
					local before = DateTime.now().UnixTimestampMillis
					local promise = client:mutate({
						mutation = mutation,
						optimisticResponse = optimisticResponse,
						update = function(_self, proxy: any, mResult: any)
							local after = DateTime.now().UnixTimestampMillis
							local duration = after - before
							if Boolean.toJSBoolean(firstTime) then
								expect(duration < 300).toBe(true)
								firstTime = false
							else
								expect(duration > 300).toBe(true)
							end
							local data = proxy:readQuery({ query = query })

							proxy:writeQuery({
								query = query,
								data = Object.assign({}, data, {
									todoList = Object.assign({}, data.todoList, {
										todos = Array.concat({}, { mResult.data.createTodo }, data.todoList.todos),
									}),
								}),
							})
						end,
					})

					local dataInStore = (client.cache :: InMemoryCache):extract(true)
					expect(#(dataInStore["TodoList5"] :: any).todos).toBe(4)
					expect((dataInStore["Todo99"] :: any).text).toBe("Optimistically generated")
					promise:expect()
					client
						:query({ query = query })
						:andThen(function(newResult: any)
							(subscriptionHandle :: any):unsubscribe()
							-- There should be one more todo item than before
							expect(#newResult.data.todoList.todos).toBe(4)

							-- Since we used `prepend` it should be at the front
							expect(newResult.data.todoList.todos[1].text).toBe("This one was created with a mutation.")
						end)
						:expect()
				end)
				resolve()
			end)
		end)

		itAsync("two array insert like mutations", function(resolve, reject)
			Promise.resolve():andThen(function()
				--[[
						ROBLOX deviation: using custom assertions function to verify nr of assertions called
						original code:
						expect.assertions(9)
					]]
				assertions(9, function()
					local subscriptionHandle: Subscription
					local client = setup(
						reject,
						{ request = { query = mutation }, result = mutationResult },
						{ request = { query = mutation }, result = mutationResult2, delay = 50 }
					):expect()

					-- we have to actually subscribe to the query to be able to update it
					Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(self, res: any)
								resolve(res)
							end,
						})
					end):expect()

					local function update(_self, proxy: any, mResult: any)
						local data: any = proxy:readFragment({
							id = "TodoList5",
							fragment = gql([[

            fragment todoList on TodoList {
              todos {
                id
                text
                completed
                __typename
              }
            }
          ]]),
						})

						proxy:writeFragment({
							data = Object.assign({}, data, {
								todos = Array.concat({}, { mResult.data.createTodo }, data.todos),
							}),
							id = "TodoList5",
							fragment = gql([[

            fragment todoList on TodoList {
              todos {
                id
                text
                completed
                __typename
              }
            }
          ]]),
						})
					end
					local promise = client
						:mutate({
							mutation = mutation,
							optimisticResponse = optimisticResponse,
							update = update,
						})
						:andThen(function(res: any)
							local currentDataInStore = (client.cache :: InMemoryCache):extract(true)
							expect(#(currentDataInStore["TodoList5"] :: any).todos).toBe(5)
							expect((currentDataInStore["Todo99"] :: any).text).toBe(
								"This one was created with a mutation."
							)
							expect((currentDataInStore["Todo66"] :: any).text).toBe("Optimistically generated 2")
							return res
						end)

					local promise2 = client:mutate({
						mutation = mutation,
						optimisticResponse = optimisticResponse2,
						update = update,
					})

					local dataInStore = (client.cache :: InMemoryCache):extract(true)
					expect(#(dataInStore["TodoList5"] :: any).todos).toBe(5)
					expect((dataInStore["Todo99"] :: any).text).toBe("Optimistically generated")
					expect((dataInStore["Todo66"] :: any).text).toBe("Optimistically generated 2")

					Promise.all({ promise, promise2 }):expect()

					local newResult: any = client:query({ query = query }):expect();

					(subscriptionHandle :: any):unsubscribe()
					-- There should be one more todo item than before
					expect(#newResult.data.todoList.todos).toBe(5)

					-- Since we used `prepend` it should be at the front
					expect(newResult.data.todoList.todos[1].text).toBe("Second mutation.")
					expect(newResult.data.todoList.todos[2].text).toBe("This one was created with a mutation.")
				end)

				resolve()
			end)
		end)

		itAsync("two mutations, one fails", function(resolve, reject)
			Promise.resolve():andThen(function()
				--[[
						ROBLOX deviation: using custom assertions function to verify nr of assertions called
						original code:
						expect.assertions(10)
					]]
				assertions(10, function()
					local subscriptionHandle: Subscription
					local client = setup(reject, {
						request = { query = mutation },
						error = Error.new("forbidden (test error)"),
						delay = 20,
					}, {
						request = { query = mutation },
						result = mutationResult2,
						-- XXX this test will uncover a flaw in the design of optimistic responses combined with
						-- updateQueries or result reducers if you un-comment the line below. The issue is that
						-- optimistic updates are not commutative but are treated as such. When undoing an
						-- optimistic update, other optimistic updates should be rolled back and re-applied in the
						-- same order as before, otherwise the store can end up in an inconsistent state.
						-- delay: 50,
					}):expect()

					-- we have to actually subscribe to the query to be able to update it
					Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(self, res: any)
								resolve(res)
							end,
						})
					end):expect()

					local function update(_self, proxy: any, mResult: any)
						local data: any = proxy:readFragment({
							id = "TodoList5",
							fragment = gql([[

            fragment todoList on TodoList {
              todos {
                id
                text
                completed
                __typename
              }
            }
          ]]),
						})

						proxy:writeFragment({
							data = Object.assign({}, data, {
								todos = Array.concat({}, { mResult.data.createTodo }, data.todos),
							}),
							id = "TodoList5",
							fragment = gql([[

            fragment todoList on TodoList {
              todos {
                id
                text
                completed
                __typename
              }
            }
          ]]),
						})
					end
					local promise = client
						:mutate({
							mutation = mutation,
							optimisticResponse = optimisticResponse,
							update = update,
						})
						:catch(function(err: any)
							expect(err).toBeInstanceOf(Error)
							expect(err.message).toBe("forbidden (test error)")
							return nil
						end)

					local promise2 = client:mutate({
						mutation = mutation,
						optimisticResponse = optimisticResponse2,
						update = update,
					})

					local dataInStore = (client.cache :: InMemoryCache):extract(true)
					expect(#(dataInStore["TodoList5"] :: any).todos).toBe(5)
					expect((dataInStore["Todo99"] :: any).text).toBe("Optimistically generated")
					expect((dataInStore["Todo66"] :: any).text).toBe("Optimistically generated 2")

					Promise.all({ promise, promise2 }):expect();

					(subscriptionHandle :: any):unsubscribe()
					do
						local dataInStore_ = (client.cache :: InMemoryCache):extract(true)
						expect(#(dataInStore_["TodoList5"] :: any).todos).toBe(4)
						expect(stripSymbols(dataInStore_)).never.toHaveProperty("Todo99")
						expect(dataInStore_).toHaveProperty("Todo66")
						expect((dataInStore_["TodoList5"] :: any).todos).toContainEqual(makeReference("Todo66"))
						expect((dataInStore_["TodoList5"] :: any).todos).never.toContainEqual(makeReference("Todo99"))
					end
				end)
				-- ROBLOX deviation: move resolve after assertions count check
				resolve()
			end)
		end)

		-- ROBLOX deviation START: no RxJS available and fragments are not supported
		-- 	itAsync.skip("will handle dependent updates", function(resolve, reject)
		-- 		-- ROBLOX FIXME
		-- expect:assertions(1)
		-- 		local link = mockSingleLink(
		-- 			{ request = { query = query }, result = result },
		-- 			{ request = { query = mutation }, result = mutationResult, delay = 10 },
		-- 			{ request = { query = mutation }, result = mutationResult2, delay = 20 }
		-- 		):setOnError(reject)
		-- 		local customOptimisticResponse1 = {
		-- 			__typename = "Mutation",
		-- 			createTodo = {
		-- 				__typename = "Todo",
		-- 				id = "optimistic-99",
		-- 				text = "Optimistically generated",
		-- 				completed = true,
		-- 			},
		-- 		}
		-- 		local customOptimisticResponse2 = {
		-- 			__typename = "Mutation",
		-- 			createTodo = {
		-- 				__typename = "Todo",
		-- 				id = "optimistic-66",
		-- 				text = "Optimistically generated 2",
		-- 				completed = true,
		-- 			},
		-- 		}
		-- 		local function update(proxy: any, mResult: any)
		-- 			local data: any = proxy:readFragment({
		-- 				id = "TodoList5",
		-- 				fragment = gql([[

		--     fragment todoList on TodoList {
		--       todos {
		--         id
		--         text
		--         completed
		--         __typename
		--       }
		--     }
		--   ]]),
		-- 			})
		-- 			proxy:writeFragment({
		-- 				data = Object.assign({}, data, {
		-- 					todos = Array.concat({}, { mResult.data.createTodo }, data.todos),
		-- 				}),
		-- 				id = "TodoList5",
		-- 				fragment = gql([[

		--     fragment todoList on TodoList {
		--       todos {
		--         id
		--         text
		--         completed
		--         __typename
		--       }
		--     }
		--   ]]),
		-- 			})
		-- 		end
		-- 		local client = ApolloClient.new({
		-- 			link = link,
		-- 			cache = InMemoryCache.new({
		-- 				dataIdFromObject = function(obj: any)
		-- 					if
		-- 						Boolean.toJSBoolean((function()
		-- 							if Boolean.toJSBoolean(obj.id) then
		-- 								return obj.__typename
		-- 							else
		-- 								return obj.id
		-- 							end
		-- 						end)())
		-- 					then
		-- 						return obj.__typename + obj.id
		-- 					end
		-- 					return nil
		-- 				end,
		-- 			}),
		-- 		})
		-- 		local promise = from((client:watchQuery({ query = query }) :: any) :: ObservableInput<any>)
		-- 			:pipe(
		-- 				map(function(value)
		-- 					return stripSymbols(value.data.todoList.todos)
		-- 				end),
		-- 				take(5),
		-- 				toArray()
		-- 			)
		-- 			:toPromise()
		-- 		Promise.new(function(resolve)
		-- 			return setTimeout(resolve)
		-- 		end):expect()
		-- 		client:mutate({
		-- 			mutation = mutation,
		-- 			optimisticResponse = customOptimisticResponse1,
		-- 			update = update,
		-- 		})
		-- 		client:mutate({
		-- 			mutation = mutation,
		-- 			optimisticResponse = customOptimisticResponse2,
		-- 			update = update,
		-- 		})
		-- 		local responses = promise:expect()
		-- 		local defaultTodos = stripSymbols(result.data.todoList.todos)
		-- 		expect(responses).toEqual({
		-- 			defaultTodos,
		-- 			Array.concat({}, { customOptimisticResponse1.createTodo }, defaultTodos),
		-- 			Array.concat(
		-- 				{},
		-- 				{ customOptimisticResponse2.createTodo, customOptimisticResponse1.createTodo },
		-- 				defaultTodos
		-- 			),
		-- 			Array.concat(
		-- 				{},
		-- 				{ customOptimisticResponse2.createTodo, mutationResult.data.createTodo },
		-- 				defaultTodos
		-- 			),
		-- 			Array.concat({}, { mutationResult2.data.createTodo, mutationResult.data.createTodo }, defaultTodos),
		-- 		})
		-- 		resolve()
		-- 	end)
		-- ROBLOX deviation END

		itAsync("final update ignores optimistic data", function(resolve, reject)
			local cache = InMemoryCache.new()
			local client = ApolloClient.new({
				cache = cache,
				link = ApolloLink.new(function(_self, operation)
					return Observable.new(function(observer)
						observer:next({ data = { addItem = operation.variables.item } })
						observer:complete()
					end)
				end),
			})

			local query = gql("query { items { text }}")

			local itemCount = 0
			local function makeItem(source: string)
				itemCount += 1
				return {
					__typename = "Item",
					text = ("%s %d"):format(source, itemCount),
				}
			end

			type Item = ReturnType<typeof(makeItem)>
			type Data = { items: Array<Item> }

			local function append(cache: ApolloCache<any>, item: Item)
				local data = cache:readQuery({ query = query })
				cache:writeQuery({
					query = query,
					data = Object.assign({}, data, {
						items = Array.concat({}, (function()
							local ref = if Boolean.toJSBoolean(data) and data ~= nil then data.items else data
							return Boolean.toJSBoolean(ref) and ref
						end)() or {}, { item }),
					}),
				})
				return item
			end
			local cancelFns: Array<() -> ...any> = {}
			local optimisticDiffs: Array<Cache_DiffResult<Data>> = {}
			local realisticDiffs: Array<Cache_DiffResult<Data>> = {}

			table.insert(
				cancelFns,
				cache:watch({
					query = query,
					optimistic = true,
					callback = function(_self, diff)
						table.insert(optimisticDiffs, diff)
					end,
				})
			)

			table.insert(
				cancelFns,
				cache:watch({
					query = query,
					optimistic = false,
					callback = function(self, diff)
						table.insert(realisticDiffs, diff)
					end,
				})
			)

			local manualItem1 = makeItem("manual")
			local manualItem2 = makeItem("manual")
			local manualItems = { manualItem1, manualItem2 }

			expect(optimisticDiffs).toEqual({})
			expect(realisticDiffs).toEqual({})

			-- So that we can have more control over the optimistic data in the
			-- cache, we add two items manually using the underlying cache API.
			cache:recordOptimisticTransaction(function(cache)
				append(cache :: ApolloCache<any>, manualItem1)
				append(cache :: ApolloCache<any>, manualItem2)
			end, "manual")

			expect(cache:extract(false)).toEqual({})
			expect(cache:extract(true)).toEqual({
				ROOT_QUERY = { __typename = "Query", items = manualItems },
			})

			expect(optimisticDiffs).toEqual({
				{
					complete = true,
					fromOptimisticTransaction = true,
					result = { items = manualItems },
				},
			})

			expect(realisticDiffs).toEqual({
				{ complete = false, missing = { expect.anything() }, result = {} },
			})

			local mutation = gql([[

        mutation AddItem($item: Item!) {
          addItem(item: $item) {
            text
          }
        }
      ]])
			local updateCount = 0
			local optimisticItem = makeItem("optimistic")
			local mutationItem = makeItem("mutation")

			-- ROBLOX deviation: need to type single TArg instead of TArgs
			local function wrapReject<TArg, TResult>(fn: (self: any, ...TArg) -> ...TResult): (self: any, ...TArg) -> ...TResult
				return function(self, ...)
					local arguments = { ... }
					local ok, result = pcall(function()
						return fn(self, table.unpack(arguments))
					end)
					if not ok then
						reject(result)
						return
					end
					return result
				end
			end

			return client
				:mutate({
					mutation = mutation,
					optimisticResponse = { addItem = optimisticItem },
					variables = { item = mutationItem },
					update = wrapReject(function(_self, cache, mutationResult)
						updateCount += 1
						if updateCount == 1 then
							expect(mutationResult).toEqual({ data = { addItem = optimisticItem } })

							append(cache, optimisticItem)

							local expected = {
								ROOT_QUERY = {
									__typename = "Query",
									items = { manualItem1, manualItem2, optimisticItem },
								},
								ROOT_MUTATION = {
									__typename = "Mutation",
									-- Although ROOT_MUTATION field data gets removed immediately
									-- after the mutation finishes, it is still temporarily visible
									-- to the update function.
									['addItem({"item":{"__typename":"Item","text":"mutation 4"}})'] = {
										__typename = "Item",
										text = "optimistic 3",
									},
								},
							}

							-- Since we're in an optimistic update function, reading
							-- non-optimistically still returns optimistic data.
							expect(cache:extract(false)).toEqual(expected)
							expect(cache:extract(true)).toEqual(expected)
						elseif updateCount == 2 then
							expect(mutationResult).toEqual({ data = { addItem = mutationItem } })

							append(cache, mutationItem)

							local expected = {
								ROOT_QUERY = { __typename = "Query", items = { mutationItem } },
								ROOT_MUTATION = {
									__typename = "Mutation",
									['addItem({"item":{"__typename":"Item","text":"mutation 4"}})'] = {
										__typename = "Item",
										text = "mutation 4",
									},
								},
							}

							-- Since we're in the final (non-optimistic) update function,
							-- optimistic data is invisible, even if we try to read
							-- optimistically.
							expect(cache:extract(false)).toEqual(expected)
							expect(cache:extract(true)).toEqual(expected)
						else
							error(Error.new("too many updates"))
						end
					end),
				})
				:andThen(function(result)
					expect(result).toEqual({ data = { addItem = mutationItem } })

					-- Only the final update function ever touched non-optimistic
					-- cache data.
					expect(cache:extract(false)).toEqual({
						ROOT_QUERY = { __typename = "Query", items = { mutationItem } },
						ROOT_MUTATION = { __typename = "Mutation" },
					})

					-- Now that the mutation is finished, reading optimistically from
					-- the cache should return the manually added items again.
					expect(cache:extract(true)).toEqual({
						ROOT_QUERY = {
							__typename = "Query",
							items = {
								-- If we wanted to keep optimistic data as up-to-date as
								-- possible, we could rerun all optimistic transactions
								-- after writing to the root (non-optimistic) layer of the
								-- cache, which would result in mutationItem appearing in
								-- this list along with manualItem1 and manualItem2
								-- (presumably in that order). However, rerunning those
								-- optimistic transactions would trigger additional
								-- broadcasts for optimistic query watches, with
								-- intermediate results that (re)combine optimistic and
								-- non-optimistic data. Since rerendering the UI tends to be
								-- expensive, we should prioritize broadcasting states that
								-- matter most, and in this case that means broadcasting the
								-- initial optimistic state (for perceived performance),
								-- followed by the final, authoritative, non-optimistic
								-- state. Other intermediate states are a distraction, as
								-- they will probably soon be superseded by another (more
								-- authoritative) update. This particular state is visible
								-- only because we haven't rolled back this manual Layer
								-- just yet (see cache.removeOptimistic below).
								manualItem1,
								manualItem2,
							},
						},
						ROOT_MUTATION = {
							__typename = "Mutation",
						},
					})

					cache:removeOptimistic("manual")

					-- After removing the manual optimistic layer, only the
					-- non-optimistic data remains.
					expect(cache:extract(true)).toEqual({
						ROOT_QUERY = { __typename = "Query", items = { mutationItem } },
						ROOT_MUTATION = { __typename = "Mutation" },
					})
				end)
				:andThen(function()
					Array.forEach(cancelFns, function(cancel)
						return cancel()
					end)

					expect(optimisticDiffs).toEqual({
						{
							complete = true,
							fromOptimisticTransaction = true,
							result = { items = manualItems },
						} :: FIX_ANALYZE,
						{
							complete = true,
							fromOptimisticTransaction = true,
							result = {
								items = Array.concat({}, manualItems, { optimisticItem }),
							},
						},
						{ complete = true, result = { items = manualItems } },
						{ complete = true, result = { items = { mutationItem } } },
					})

					expect(realisticDiffs).toEqual({
						{ complete = false, missing = { expect.anything() }, result = {} } :: FIX_ANALYZE,
						{ complete = true, result = { items = { mutationItem } } },
					})
				end)
				:andThen(resolve, reject)
		end)
	end)
end)

describe("optimistic mutation - githunt comments", function()
	local query = gql([[

    query Comment($repoName: String!) {
      entry(repoFullName: $repoName) {
        comments {
          postedBy {
            login
            html_url
          }
        }
      }
    }
  ]])
	local queryWithFragment = gql([[

    query Comment($repoName: String!) {
      entry(repoFullName: $repoName) {
        comments {
          ...authorFields
        }
      }
    }

    fragment authorFields on User {
      postedBy {
        login
        html_url
      }
    }
  ]])
	local variables = { repoName = "org/repo" }
	local userDoc = {
		__typename = "User",
		login = "stubailo",
		html_url = "http://avatar.com/stubailo.png",
	}

	local result = {
		data = {
			__typename = "Query",
			entry = {
				__typename = "Entry",
				comments = { { __typename = "Comment", postedBy = userDoc } },
			},
		},
	}

	local function setup(reject: (reason: any) -> any, ...: any)
		local mockedResponses = { ... }

		return Promise:resolve():andThen(function()
			local link = mockSingleLink({
				request = { query = addTypenameToDocument(query), variables = variables },
				result = result,
			}, {
				request = {
					query = addTypenameToDocument(queryWithFragment),
					variables = variables,
				},
				result = result,
			}, table.unpack(mockedResponses)):setOnError(reject)

			local client = ApolloClient.new({
				link = link,
				cache = InMemoryCache.new({
					dataIdFromObject = function(_self, obj: any)
						if Boolean.toJSBoolean(obj.id) and Boolean.toJSBoolean(obj.__typename) then
							return obj.__typename .. obj.id
						end
						return nil
					end,
				}),
			})

			local obsHandle = client:watchQuery({ query = query, variables = variables })

			obsHandle:result():expect()

			return client
		end)
	end

	local mutation = gql([[

    mutation submitComment($repoFullName: String!, $commentContent: String!) {
      submitComment(
        repoFullName: $repoFullName
        commentContent: $commentContent
      ) {
        postedBy {
          login
          html_url
        }
      }
    }
  ]])

	type IMutationResult = {
		__typename: string,
		submitComment: {
			__typename: string,
			postedBy: { __typename: string, login: string, html_url: string },
		},
	}
	local mutationResult = {
		data = {
			__typename = "Mutation",
			submitComment = { __typename = "Comment", postedBy = userDoc },
		},
	}
	local updateQueries = {
		Comment = function(_self, prev, ref)
			local mutationResultArg = ref.mutationResult
			if Boolean.toJSBoolean(mutationResultArg.data) then
				local newComment = mutationResultArg.data.submitComment
				local state = cloneDeep(prev)
				table.insert(state.entry.comments, 1, newComment)
				return state
			end
			return prev
		end :: FIX_ANALYZE,
	} :: MutationQueryReducersMap<IMutationResult>
	local optimisticResponse = {
		__typename = "Mutation",
		submitComment = { __typename = "Comment", postedBy = userDoc },
	}

	itAsync("can post a new comment", function(resolve, reject)
		Promise.resolve():andThen(function()
			--[[
					ROBLOX deviation: using custom assertions function to verify nr of assertions called
					original code:
					expect.assertions(1)
				]]
			assertions(1, function()
				local mutationVariables = { repoFullName = "org/repo", commentContent = "New Comment" }

				local subscriptionHandle: Subscription
				local client = setup(reject, {
					request = { query = addTypenameToDocument(mutation), variables = mutationVariables },
					result = mutationResult,
				}):expect()

				-- we have to actually subscribe to the query to be able to update it
				Promise.new(function(resolve)
					local handle = client:watchQuery({ query = query, variables = variables })
					subscriptionHandle = handle:subscribe({
						next = function(self, res: any)
							resolve(res)
						end,
					})
				end):expect()

				client
					:mutate({
						mutation = mutation,
						optimisticResponse = optimisticResponse,
						variables = mutationVariables,
						updateQueries = updateQueries,
					})
					:expect()

				local newResult: any = client:query({ query = query, variables = variables }):expect();

				(subscriptionHandle :: any):unsubscribe()
				expect(#newResult.data.entry.comments).toBe(2)
			end)

			resolve()
		end)
	end)
end)

return {}
