-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/__tests__/mutationResults.ts
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local describe = JestGlobals.describe

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
local Object = LuauPolyfill.Object
local setTimeout = LuauPolyfill.setTimeout
type Promise<T> = LuauPolyfill.Promise<T>
local Promise = require(rootWorkspace.Promise)

-- ROBLOX FIXME: remove if better solution is found
type FIX_ANALYZE = any

local cloneDeep = require(srcWorkspace.utilities.common.cloneDeep).cloneDeep
local gql = require(rootWorkspace.GraphQLTag).default
local GraphQLError = require(rootWorkspace.GraphQL).GraphQLError

local ApolloClient = require(script.Parent.Parent.core).ApolloClient
local InMemoryCache = require(script.Parent.Parent.cache).InMemoryCache
local ApolloLink = require(script.Parent.Parent.link.core).ApolloLink
local utilitiesModule = require(script.Parent.Parent.utilities)
local Observable = utilitiesModule.Observable
type Subscription = utilitiesModule.ObservableSubscription
local testingModule = require(script.Parent.Parent.testing)
local itAsync = testingModule.itAsync
local subscribeAndCount = testingModule.subscribeAndCount
local mockSingleLink = testingModule.mockSingleLink
local withErrorSpy = testingModule.withErrorSpy

describe("mutation results", function()
	local query = gql([[

    query todoList {
      todoList(id: 5) {
        id
        todos {
          id
          text
          completed
        }
        filteredTodos: todos(completed: true) {
          id
          text
          completed
        }
      }
      noIdList: todoList(id: 6) {
        id
        todos {
          text
          completed
        }
      }
    }
  ]])

	local queryWithTypename = gql([[

    query todoList {
      todoList(id: 5) {
        id
        todos {
          id
          text
          completed
          __typename
        }
        filteredTodos: todos(completed: true) {
          id
          text
          completed
          __typename
        }
        __typename
      }
      noIdList: todoList(id: 6) {
        id
        todos {
          text
          completed
          __typename
        }
        __typename
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
					{
						__typename = "Todo",
						id = "3",
						text = "Hello world",
						completed = false,
					},
					{
						__typename = "Todo",
						id = "6",
						text = "Second task",
						completed = false,
					},
					{
						__typename = "Todo",
						id = "12",
						text = "Do other stuff",
						completed = false,
					},
				},
				filteredTodos = {},
			},
			noIdList = {
				__typename = "TodoList",
				id = "7",
				todos = {
					{
						__typename = "Todo",
						text = "Hello world",
						completed = false,
					},
					{
						__typename = "Todo",
						text = "Second task",
						completed = false,
					},
					{
						__typename = "Todo",
						text = "Do other stuff",
						completed = false,
					},
				},
			},
		},
	}
	local function setupObsQuery(reject: (reason: any) -> any, ...: any)
		local client = ApolloClient.new({
			link = mockSingleLink({
				request = { query = queryWithTypename } :: any,
				result = result,
			}, ...),
			cache = InMemoryCache.new({
				dataIdFromObject = function(_self, obj: any)
					if Boolean.toJSBoolean(obj.id) and Boolean.toJSBoolean(obj.__typename) then
						return obj.__typename .. obj.id
					end
					return nil
				end,
				-- Passing an empty map enables warnings about missing fields:
				possibleTypes = {},
			}),
		})

		return {
			client = client,
			obsQuery = client:watchQuery({
				query = query,
				notifyOnNetworkStatusChange = false,
			}),
		}
	end

	local function setupDelayObsQuery(reject: (reason: any) -> any, delay: number, ...: any)
		local client = ApolloClient.new({
			link = mockSingleLink({
				request = { query = queryWithTypename } :: any,
				result = result,
				delay = delay,
			}, ...):setOnError(reject),
			cache = InMemoryCache.new({
				dataIdFromObject = function(_self, obj: any)
					if Boolean.toJSBoolean(obj.id) and Boolean.toJSBoolean(obj.__typename) then
						return obj.__typename .. obj.id
					end
					return nil
				end,
				-- Passing an empty map enables warnings about missing fields:
				possibleTypes = {},
			}),
		})
		return {
			client = client,
			obsQuery = client:watchQuery({
				query = query,
				notifyOnNetworkStatusChange = false,
			}),
		}
	end

	itAsync("correctly primes cache for tests", function(resolve, reject)
		local ref = setupObsQuery(reject)
		local client, obsQuery = ref.client, ref.obsQuery
		return obsQuery
			:result()
			:andThen(function()
				return client:query({ query = query })
			end)
			:andThen(resolve, reject)
	end)

	itAsync("correctly integrates field changes by default", function(resolve, reject)
		local mutation = gql([[

      mutation setCompleted {
        setCompleted(todoId: "3") {
          id
          completed
          __typename
        }
        __typename
      }
    ]])

		local mutationResult = {
			data = {
				__typename = "Mutation",
				setCompleted = {
					__typename = "Todo",
					id = "3",
					completed = true,
				},
			},
		}

		local ref = setupObsQuery(reject, { request = { query = mutation }, result = mutationResult })
		local client, obsQuery = ref.client, ref.obsQuery

		return obsQuery
			:result()
			:andThen(function()
				return client:mutate({ mutation = mutation }) :: Promise<any>
			end)
			:andThen(function()
				return client:query({ query = query })
			end)
			:andThen(function(newResult: any)
				expect(newResult.data.todoList.todos[1].completed).toBe(true)
			end)
			:andThen(resolve, reject)
	end)

	itAsync("correctly integrates field changes by default with variables", function(resolve, reject)
		local query = gql([[

      query getMini($id: ID!) {
        mini(id: $id) {
          id
          cover(maxWidth: 600, maxHeight: 400)
          __typename
        }
      }
    ]])
		local mutation = gql([[

      mutation upload($signature: String!) {
        mini: submitMiniCoverS3DirectUpload(signature: $signature) {
          id
          cover(maxWidth: 600, maxHeight: 400)
          __typename
        }
      }
    ]])

		local link = mockSingleLink({
			request = {
				query = query,
				variables = { id = 1 },
			} :: any,
			delay = 100,
			result = {
				data = { mini = { id = 1, cover = "image", __typename = "Mini" } },
			},
		}, {
			request = {
				query = mutation,
				variables = { signature = "1234" },
			} :: any,
			delay = 150,
			result = {
				data = { mini = { id = 1, cover = "image2", __typename = "Mini" } },
			},
		}):setOnError(reject)

		type Data = {
			mini: { id: number, cover: string, __typename: string },
		}
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

		local obs = client:watchQuery({
			query = query,
			variables = { id = 1 },
			notifyOnNetworkStatusChange = false,
		})

		local count = 0
		obs:subscribe({
			next = function(_self, result)
				if count == 0 then
					client:mutate({ mutation = mutation, variables = { signature = "1234" } })
					expect((result.data :: any).mini.cover).toBe("image")

					setTimeout(function()
						if count == 0 then
							reject(Error.new("mutate did not re-call observable with next value"))
						end
					end, 250)
				end
				if count == 1 then
					expect((result.data :: any).mini.cover).toBe("image2")
					resolve()
				end
				count += 1
			end,
			error = reject,
		})
	end)

	itAsync("should write results to cache according to errorPolicy", function(resolve, reject)
		return Promise.resolve():andThen(function()
			local expectedFakeError = GraphQLError.new("expected/fake error")

			local client = ApolloClient.new({
				cache = InMemoryCache.new({
					typePolicies = {
						Person = {
							keyFields = { "name" },
						},
					},
				} :: FIX_ANALYZE),
				link = ApolloLink.new(function(_self, operation)
					return Observable.new(function(observer)
						observer:next({
							errors = { expectedFakeError },
							data = {
								newPerson = {
									__typename = "Person",
									name = operation.variables.newName,
								},
							},
						})
						observer:complete()
					end)
				end):setOnError(reject),
			})

			local mutation = gql([[

      mutation AddNewPerson($newName: String!) {
        newPerson(name: $newName) {
          name
        }
      }
    ]])

			client
				:mutate({
					mutation = mutation,
					variables = {
						newName = "Hugh Willson",
					},
				})
				:andThen(function()
					reject("should have thrown for default errorPolicy")
				end, function(error_)
					expect(error_.message).toBe(expectedFakeError.message)
				end)
				:expect()

			expect(client.cache:extract()).toMatchSnapshot()

			local ignoreErrorsResult = client
				:mutate({
					mutation = mutation,
					errorPolicy = "ignore",
					variables = {
						newName = "Jenn Creighton",
					},
				})
				:expect()

			expect(ignoreErrorsResult).toEqual({
				data = {
					newPerson = {
						__typename = "Person",
						name = "Jenn Creighton",
					},
				},
			})

			expect(client.cache:extract()).toMatchSnapshot()

			local allErrorsResult = client
				:mutate({
					mutation = mutation,
					errorPolicy = "all",
					variables = {
						newName = "Ellen Shapiro",
					},
				})
				:expect()

			expect(allErrorsResult).toEqual({
				data = {
					newPerson = {
						__typename = "Person",
						name = "Ellen Shapiro",
					},
				},
				errors = {
					expectedFakeError,
				},
			})

			expect(client.cache:extract()).toMatchSnapshot()

			resolve()
		end)
	end)

	-- ROBLOX FIXME: test leaks into the next test
	withErrorSpy(
		itAsync.skip,
		"should warn when the result fields don't match the query fields",
		function(resolve, reject)
			local handle: any
			local subscriptionHandle: Subscription

			local queryTodos = gql([[
	
		  query todos {
			todos {
			  id
			  name
			  description
			  __typename
			}
		  }
		]])

			local queryTodosResult = {
				data = {
					todos = {
						{
							id = "1",
							name = "Todo 1",
							description = "Description 1",
							__typename = "todos",
						},
					},
				},
			}

			local mutationTodo = gql([[
	
		  mutation createTodo {
			createTodo {
			  id
			  name
			  # missing field: description
			  __typename
			}
		  }
		]])

			local mutationTodoResult = {
				data = {
					createTodo = {
						id = "2",
						name = "Todo 2",
						__typename = "createTodo",
					},
				},
			}

			local ref = setupObsQuery(reject, {
				request = { query = queryTodos },
				result = queryTodosResult,
			}, {
				request = { query = mutationTodo },
				result = mutationTodoResult,
			})
			local client, obsQuery = ref.client, ref.obsQuery

			return obsQuery
				:result()
				:andThen(function()
					-- we have to actually subscribe to the query to be able to update it
					return Promise.new(function(resolve)
						handle = client:watchQuery({ query = queryTodos })
						subscriptionHandle = handle:subscribe({
							next = function(_self, res: any)
								resolve(res)
							end,
						})
					end)
				end)
				:andThen(function()
					return client:mutate({
						mutation = mutationTodo,
						updateQueries = {
							todos = function(_self, prev, ref)
								local mutationResult = ref.mutationResult
								local newTodo = (mutationResult :: any).data.createTodo
								local newResults = {
									todos = Array.concat({}, (prev :: any).todos, { newTodo }),
								}
								return newResults
							end,
						},
					}) :: Promise<any>
				end)
				--[[
					ROBLOX deviation START: finally implementation is different than in JS.
					using separate andThen and catch to perform the same logic and not swallow the error
				]]
				:andThen(
					function(result)
						subscriptionHandle:unsubscribe()
						return result
					end
				)
				:catch(function(err)
					subscriptionHandle:unsubscribe()
					error(err)
				end)
				-- ROBLOX deviation END
				:andThen(function(result)
					expect(result).toEqual(mutationTodoResult)
				end)
				:andThen(resolve, reject)
		end
	)

	describe("InMemoryCache type/field policies", function()
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

		it("mutation update function receives result from cache", function()
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
											-- ROBLOX deviation: not Date object in Lua
											ms = DateTime.now().UnixTimestampMillis
										end
										timeReadCount += 1
										-- ROBLOX deviation: not Date object in Lua
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

			return client
				:mutate({
					mutation = mutation,
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
								doSomething = { __typename = "MutationPayload", time = startTime },
							},
						})
					end,
				})
				:andThen(function(ref)
					local __typename, time = ref.data.doSomething.__typename, ref.data.doSomething.time
					expect(__typename).toBe("MutationPayload")
					-- ROBLOX deviation START: not Date object in Lua
					expect(typeof(time)).toBe("DateTime")
					expect(time.UnixTimestampMillis).toBe(startTime)
					-- ROBLOX deviation END
					expect(timeReadCount).toBe(1)
					expect(timeMergeCount).toBe(1)

					-- The contents of the ROOT_MUTATION object exist only briefly, for the
					-- duration of the mutation update, and are removed after the mutation
					-- write is finished.
					expect(client.cache:extract()).toEqual({
						ROOT_MUTATION = {
							__typename = "Mutation",
						},
					})
				end)
		end)

		it("mutations can preserve ROOT_MUTATION cache data with keepRootFields: true", function()
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
											-- ROBLOX deviation: not Date object in Lua
											ms = DateTime.now().UnixTimestampMillis
										end
										timeReadCount += 1
										-- ROBLOX deviation: not Date object in Lua
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

			return client
				:mutate({
					mutation = mutation,
					keepRootFields = true,
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
								doSomething = { __typename = "MutationPayload", time = startTime },
							},
						})
					end,
				})
				:andThen(function(ref)
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
							doSomething = { __typename = "MutationPayload", time = startTime },
						},
					})
				end)
				:expect()
		end)

		it('mutation update function runs even when fetchPolicy is "no-cache"', function()
			return Promise.resolve()
				:andThen(function()
					local timeReadCount = 0
					local timeMergeCount = 0
					local mutationUpdateCount = 0

					local client = ApolloClient.new({
						link = link,
						cache = InMemoryCache.new({
							typePolicies = {
								MutationPayload = {
									fields = {
										time = {
											read = function(_self, ms: number?)
												if ms == nil then
													-- ROBLOX deviation: not Date object in Lua
													ms = DateTime.now().UnixTimestampMillis
												end
												timeReadCount += 1
												-- ROBLOX deviation: not Date object in Lua
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

					return client
						:mutate({
							mutation = mutation,
							fetchPolicy = "no-cache",
							update = function(_self, cache, ref)
								local __typename, time = ref.data.doSomething.__typename, ref.data.doSomething.time
								mutationUpdateCount += 1
								expect(mutationUpdateCount).toBe(1)
								expect(__typename).toBe("MutationPayload")
								-- ROBLOX deviation: not Date object in Lua
								expect(typeof(time)).never.toBe("DateTime")
								expect(time).toBe(startTime)
								expect(timeReadCount).toBe(0)
								expect(timeMergeCount).toBe(0)
								expect(cache:extract()).toEqual({})
							end,
						})
						:andThen(function(ref)
							local __typename, time = ref.data.doSomething.__typename, ref.data.doSomething.time
							expect(__typename).toBe("MutationPayload")
							-- ROBLOX deviation: not Date object in Lua
							expect(typeof(time)).never.toBe("DateTime")
							expect(time).toBe(tonumber(startTime))
							expect(timeReadCount).toBe(0)
							expect(timeMergeCount).toBe(0)
							expect(mutationUpdateCount).toBe(1)
							expect(client.cache:extract()).toEqual({})
						end)
				end)
				:expect()
		end)
	end)

	describe("updateQueries", function()
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

		itAsync("analogous of ARRAY_INSERT", function(resolve, reject)
			local subscriptionHandle: Subscription
			local ref = setupObsQuery(reject, {
				request = { query = mutation },
				result = mutationResult,
			})
			local client, obsQuery = ref.client, ref.obsQuery

			return obsQuery
				:result()
				:andThen(function()
					-- we have to actually subscribe to the query to be able to update it
					return Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(_self, res)
								resolve(res)
							end,
						})
					end)
				end)
				:andThen(function()
					return client:mutate({
						mutation = mutation,
						updateQueries = {
							todoList = function(_self, prev, options)
								local mResult = options.mutationResult :: any
								expect(mResult.data.createTodo.id).toBe("99")
								expect(mResult.data.createTodo.text).toBe("This one was created with a mutation.")
								local state = cloneDeep(prev) :: any
								table.insert(state.todoList.todos, 1, mResult.data.createTodo)
								return state
							end,
						},
					}) :: Promise<any>
				end)
				:andThen(function()
					return client:query({ query = query })
				end)
				:andThen(function(newResult: any)
					subscriptionHandle:unsubscribe()

					-- There should be one more todo item than before
					expect(#newResult.data.todoList.todos).toBe(4)

					-- Since we used `prepend` it should be at the front
					expect(newResult.data.todoList.todos[1].text).toBe("This one was created with a mutation.")
				end)
				:andThen(resolve, reject)
		end)

		itAsync("does not fail if optional query variables are not supplied", function(resolve, reject)
			local subscriptionHandle: Subscription
			local mutationWithVars = gql([[

        mutation createTodo($requiredVar: String!, $optionalVar: String) {
          createTodo(requiredVar: $requiredVar, optionalVar: $optionalVar) {
            id
            text
            completed
            __typename
          }
          __typename
        }
      ]])

			-- the test will pass if optionalVar is uncommented
			local variables = {
				requiredVar = "x",
				-- optionalVar: 'y',
			}
			local ref = setupObsQuery(reject, {
				request = { query = mutationWithVars, variables = variables },
				result = mutationResult,
			})
			local client, obsQuery = ref.client, ref.obsQuery

			return obsQuery
				:result()
				:andThen(function()
					-- we have to actually subscribe to the query to be able to update it
					return Promise.new(function(resolve)
						local handle = client:watchQuery({
							query = query,
							variables = variables,
						})
						subscriptionHandle = handle:subscribe({
							next = function(_self, res)
								resolve(res)
							end,
						})
					end)
				end)
				:andThen(function()
					return client:mutate({
						mutation = mutationWithVars,
						variables = variables,
						updateQueries = {
							todoList = function(_self, prev, options)
								local mResult = options.mutationResult :: any
								expect(mResult.data.createTodo.id).toBe("99")
								expect(mResult.data.createTodo.text).toBe("This one was created with a mutation.")
								local state = cloneDeep(prev) :: any
								table.insert(state.todoList.todos, 1, mResult.data.createTodo)
								return state
							end,
						},
					}) :: Promise<any>
				end)
				:andThen(function()
					return client:query({ query = query })
				end)
				:andThen(function(newResult: any)
					subscriptionHandle:unsubscribe()

					-- There should be one more todo item than before
					expect(#newResult.data.todoList.todos).toBe(4)

					-- Since we used `prepend` it should be at the front
					expect(newResult.data.todoList.todos[1].text).toBe("This one was created with a mutation.")
				end)
				:andThen(resolve, reject)
		end)

		itAsync("does not fail if the query did not complete correctly", function(resolve, reject)
			local ref = setupObsQuery(reject, { request = { query = mutation }, result = mutationResult })
			local client, obsQuery = ref.client, ref.obsQuery
			local subs = obsQuery:subscribe({
				next = function()
					return nil
				end,
			})
			-- Cancel the query right away!
			subs:unsubscribe()
			return client
				:mutate({
					mutation = mutation,
					updateQueries = {
						todoList = function(_self, prev, options)
							local mResult = options.mutationResult :: any
							expect(mResult.data.createTodo.id).toBe("99")
							expect(mResult.data.createTodo.text).toBe("This one was created with a mutation.")

							local state = cloneDeep(prev) :: any
							table.insert(state.todoList.todos, 1, mResult.data.createTodo)
							return state
						end,
					},
				})
				:andThen(resolve, reject)
		end)

		itAsync("does not fail if the query did not finish loading", function(resolve, reject)
			local ref = setupDelayObsQuery(reject, 15, {
				request = { query = mutation },
				result = mutationResult,
			})
			local client, obsQuery = ref.client, ref.obsQuery
			obsQuery:subscribe({
				next = function()
					return nil
				end,
			})
			return client
				:mutate({
					mutation = mutation,
					updateQueries = {
						todoList = function(_self, prev, options)
							local mResult = options.mutationResult :: any
							expect(mResult.data.createTodo.id).toBe("99")
							expect(mResult.data.createTodo.text).toBe("This one was created with a mutation.")

							local state = cloneDeep(prev) :: any
							table.insert(state.todoList.todos, 1, mResult.data.createTodo)
							return state
						end,
					},
				})
				:andThen(resolve, reject)
		end)

		itAsync("does not make next queries fail if a mutation fails", function(resolve, reject)
			local ref = setupObsQuery(function(error_)
				error(error_)
			end, {
				request = { query = mutation },
				result = { errors = { Error.new("mock error") } },
			}, {
				request = { query = queryWithTypename },
				result = result,
			})
			local client, obsQuery = ref.client, ref.obsQuery

			obsQuery:subscribe({
				next = function(_self)
					client
						:mutate({
							mutation = mutation,
							updateQueries = {
								todoList = function(_self, prev, options)
									local mResult = options.mutationResult :: any
									local state = cloneDeep(prev) :: any
										-- It's unfortunate that this function is called at all, but we are removing
										-- the updateQueries API soon so it won't matter.
										-- ROBLOX deviation: if then else expression formatting is broken
										-- stylua: ignore
										table.insert(
											state.todoList.todos,
											1,
											if Boolean.toJSBoolean(mResult.data)
												then mResult.data.createTodo
												else mResult.data
										)
									return state
								end,
							},
						})
						:andThen(function()
							return reject(Error.new("Mutation should have failed"))
						end, function(err)
							return client:mutate({
								mutation = mutation,
								updateQueries = {
									todoList = function(_self, prev, options)
										local mResult = options.mutationResult :: any
										local state = cloneDeep(prev) :: any
										table.insert(state.todoList.todos, 1, mResult.data.createTodo)
										return state
									end,
								},
							})
						end)
						:andThen(function()
							return reject(Error.new("Mutation should have failed"))
						end, function(err)
							return obsQuery:refetch() :: Promise<any>
						end)
						:andThen(resolve, reject)
				end,
			})
		end)

		itAsync("error handling in reducer functions", function(resolve, reject)
			local subscriptionHandle: Subscription
			local ref = setupObsQuery(reject, {
				request = { query = mutation },
				result = mutationResult,
			})
			local client, obsQuery = ref.client, ref.obsQuery

			return obsQuery
				:result()
				:andThen(function()
					-- we have to actually subscribe to the query to be able to update it
					return Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(_self, res)
								resolve(res)
							end,
						})
					end)
				end)
				:andThen(function()
					return client:mutate({
						mutation = mutation,
						updateQueries = {
							todoList = function()
								error(Error.new("Hello... It's me."))
							end,
						},
					}) :: Promise<any>
				end)
				:andThen(function()
					subscriptionHandle:unsubscribe()
					reject("should have thrown")
				end, function(error_)
					subscriptionHandle:unsubscribe()
					expect(error_.message).toBe("Hello... It's me.")
				end)
				:andThen(resolve, reject)
		end)
	end)

	itAsync("does not fail if one of the previous queries did not complete correctly", function(resolve, reject)
		local variableQuery = gql([[

      query Echo($message: String) {
        echo(message: $message)
      }
    ]])

		local variables1 = {
			message = "a",
		}

		local result1 = {
			data = { echo = "a" },
		}

		local variables2 = {
			message = "b",
		}

		local result2 = {
			data = {
				echo = "b",
			},
		}

		local resetMutation = gql([[

      mutation Reset {
        reset {
          echo
        }
      }
    ]])

		local resetMutationResult = {
			data = {
				reset = {
					echo = "0",
				},
			},
		}

		local client = ApolloClient.new({
			link = mockSingleLink({
				request = { query = variableQuery, variables = variables1 } :: any,
				result = result1,
			}, {
				request = { query = variableQuery, variables = variables2 } :: any,
				result = result2,
			}, { request = { query = resetMutation } :: any, result = resetMutationResult }):setOnError(reject),
			cache = InMemoryCache.new({ addTypename = false }),
		})

		local watchedQuery = client:watchQuery({
			query = variableQuery,
			variables = variables1,
		})

		local firstSubs = watchedQuery:subscribe({
			next = function()
				return nil
			end,
			error = reject,
		})

		-- Cancel the query right away!
		firstSubs:unsubscribe()

		subscribeAndCount(reject, watchedQuery, function(count, result)
			if count == 1 then
				expect(result.data).toEqual({ echo = "a" })
			elseif count == 2 then
				expect(result.data).toEqual({ echo = "b" })
				client:mutate({
					mutation = resetMutation,
					updateQueries = {
						Echo = function()
							return { echo = "0" }
						end,
					},
				})
			elseif count == 3 then
				expect(result.data).toEqual({ echo = "0" })
				resolve()
			end
		end)

		watchedQuery:refetch(variables2 :: FIX_ANALYZE)
	end)

	itAsync("allows mutations with optional arguments", function(resolve, reject)
		local count = 0

		local client = ApolloClient.new({
			cache = InMemoryCache.new({ addTypename = false }),
			link = ApolloLink.from({
				function(_self, ref)
					local variables = ref.variables
					return Observable.new(function(observer)
						local condition = count
						count += 1
						if condition == 0 then
							expect(variables).toEqual({ a = 1, b = 2 })
							observer:next({ data = { result = "hello" } })
							observer:complete()
							return
						elseif condition == 1 then
							expect(variables).toEqual({ a = 1, c = 3 })
							observer:next({ data = { result = "world" } })
							observer:complete()
							return
						elseif condition == 2 then
							expect(variables).toEqual({ a = nil, b = 2, c = 3 })
							observer:next({ data = { result = "goodbye" } })
							observer:complete()
							return
						elseif condition == 3 then
							expect(variables).toEqual({})
							observer:next({ data = { result = "moon" } })
							observer:complete()
							return
						else
							observer:error(Error.new("Too many network calls."))
							return
						end
					end)
				end,
			} :: any),
		})

		local mutation = gql([[

      mutation($a: Int!, $b: Int, $c: Int) {
        result(a: $a, b: $b, c: $c)
      }
    ]])

		Promise.all({
			client:mutate({ mutation = mutation, variables = { a = 1, b = 2 } }),
			client:mutate({ mutation = mutation, variables = { a = 1, c = 3 } }),
			client:mutate({ mutation = mutation, variables = { a = nil, b = 2, c = 3 } }),
			client:mutate({ mutation = mutation }),
		})
			:andThen(function(results)
				expect(client.cache:extract()).toEqual({
					ROOT_MUTATION = {
						__typename = "Mutation",
					},
				})
				expect(results).toEqual({
					{ data = { result = "hello" } },
					{ data = { result = "world" } },
					{ data = { result = "goodbye" } },
					{ data = { result = "moon" } },
				})
			end)
			:andThen(resolve, reject)
	end)

	itAsync("allows mutations with default values", function(resolve, reject)
		local count = 0

		local client = ApolloClient.new({
			cache = InMemoryCache.new({ addTypename = false }),
			link = ApolloLink.from({
				function(_self, ref)
					local variables = ref.variables
					return Observable.new(function(observer)
						local condition = count
						count += 1
						if condition == 0 then
							expect(variables).toEqual({
								a = 1,
								b = "water",
							})
							observer:next({ data = { result = "hello" } })
							observer:complete()
							return
						elseif condition == 1 then
							expect(variables).toEqual({
								a = 2,
								b = "cheese",
								c = 3,
							})
							observer:next({ data = { result = "world" } })
							observer:complete()
							return
						elseif condition == 2 then
							expect(variables).toEqual({
								a = 1,
								b = "cheese",
								c = 3,
							})
							observer:next({ data = { result = "goodbye" } })
							observer:complete()
							return
						else
							observer:error(Error.new("Too many network calls."))
							return
						end
					end)
				end,
			} :: any),
		})

		local mutation = gql([[

      mutation($a: Int = 1, $b: String = "cheese", $c: Int) {
        result(a: $a, b: $b, c: $c)
      }
    ]])
		Promise.all({
			client:mutate({
				mutation = mutation,
				variables = { a = 1, b = "water" },
			}),
			client:mutate({
				mutation = mutation,
				variables = { a = 2, c = 3 },
			}),
			client:mutate({
				mutation = mutation,
				variables = { c = 3 },
			}),
		})
			:andThen(function(results)
				expect(client.cache:extract()).toEqual({
					ROOT_MUTATION = {
						__typename = "Mutation",
					},
				})
				expect(results).toEqual({
					{ data = { result = "hello" } },
					{ data = { result = "world" } },
					{ data = { result = "goodbye" } },
				})
			end)
			:andThen(resolve, reject)
	end)

	itAsync("will pass null to the network interface when provided", function(resolve, reject)
		local count = 0

		local client = ApolloClient.new({
			cache = InMemoryCache.new({ addTypename = false }),
			link = ApolloLink.from({
				function(_self, ref)
					local variables = ref.variables
					return Observable.new(function(observer)
						local condition = count
						count += 1
						if condition == 0 then
							expect(variables).toEqual({ a = 1, b = 2, c = nil })
							observer:next({ data = { result = "hello" } })
							observer:complete()
							return
						end
						if condition == 1 then
							expect(variables).toEqual({ a = 1, b = nil, c = 3 })
							observer:next({ data = { result = "world" } })
							observer:complete()
							return
						end
						if condition == 2 then
							expect(variables).toEqual({ a = nil, b = nil, c = nil })
							observer:next({ data = { result = "moon" } })
							observer:complete()
							return
						else
							observer:error(Error.new("Too many network calls."))
							return
						end
					end)
				end,
			} :: any),
		})

		local mutation = gql([[

      mutation($a: Int!, $b: Int, $c: Int) {
        result(a: $a, b: $b, c: $c)
      }
    ]])

		Promise.all({
			client:mutate({ mutation = mutation, variables = { a = 1, b = 2, c = nil } }),
			client:mutate({ mutation = mutation, variables = { a = 1, b = nil, c = 3 } }),
			client:mutate({ mutation = mutation, variables = { a = nil, b = nil, c = nil } }),
		})
			:andThen(function(results)
				expect(client.cache:extract()).toEqual({
					ROOT_MUTATION = {
						__typename = "Mutation",
					},
				})
				expect(results).toEqual({
					{ data = { result = "hello" } },
					{ data = { result = "world" } },
					{ data = { result = "moon" } },
				})
			end)
			:andThen(resolve, reject)
	end)

	describe("store transaction updater", function()
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

		-- ROBLOX TODO: fragments are not supported yet
		itAsync.skip("analogous of ARRAY_INSERT", function(resolve, reject)
			local subscriptionHandle: Subscription
			local ref = setupObsQuery(reject, {
				request = { query = mutation },
				result = mutationResult,
			})
			local client, obsQuery = ref.client, ref.obsQuery

			return obsQuery
				:result()
				:andThen(function()
					-- we have to actually subscribe to the query to be able to update it
					return Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(_self, res)
								resolve(res)
							end,
						})
					end)
				end)
				:andThen(function()
					return client:mutate({
						mutation = mutation,
						update = function(_self, proxy, mResult: any)
							expect(mResult.data.createTodo.id).toBe("99")
							expect(mResult.data.createTodo.text).toBe("This one was created with a mutation.")

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
					}) :: Promise<any>
				end)
				:andThen(function()
					return client:query({ query = query })
				end)
				:andThen(function(newResult: any)
					subscriptionHandle:unsubscribe()

					-- There should be one more todo item than before
					expect(#newResult.data.todoList.todos).toBe(4)

					-- Since we used `prepend` it should be at the front
					expect(newResult.data.todoList.todos[1].text).toBe("This one was created with a mutation.")
				end)
				:andThen(resolve, reject)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itAsync.skip("does not fail if optional query variables are not supplied", function(resolve, reject)
			local subscriptionHandle: Subscription
			local mutationWithVars = gql([[

        mutation createTodo($requiredVar: String!, $optionalVar: String) {
          createTodo(requiredVar: $requiredVar, optionalVar: $optionalVar) {
            id
            text
            completed
            __typename
          }
          __typename
        }
      ]])

			-- the test will pass if optionalVar is uncommented
			local variables = {
				requiredVar = "x",
				-- optionalVar: 'y',
			}

			local ref = setupObsQuery(reject, {
				request = {
					query = mutationWithVars,
					variables = variables,
				},
				result = mutationResult,
			})
			local client, obsQuery = ref.client, ref.obsQuery

			return obsQuery
				:result()
				:andThen(function()
					return Promise.new(function(resolve)
						local handle = client:watchQuery({
							query = query,
							variables = variables,
						})
						subscriptionHandle = handle:subscribe({
							next = function(_self, res)
								resolve(res)
							end,
						})
					end)
				end)
				:andThen(function()
					return client:mutate({
						mutation = mutationWithVars,
						variables = variables,
						update = function(_self, proxy, mResult: any)
							expect(mResult.data.createTodo.id).toBe("99")
							expect(mResult.data.createTodo.text).toBe("This one was created with a mutation.")

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

							local data: any = proxy:readFragment({
								id = id,
								fragment = fragment,
							})

							proxy:writeFragment({
								data = Object.assign({}, data, {
									todos = Array.concat({}, { mResult.data.createTodo }, data.todos),
								}),
								id = id,
								fragment = fragment,
							})
						end,
					}) :: Promise<any>
				end)
				:andThen(function()
					return client:query({ query = query })
				end)
				:andThen(function(newResult: any)
					subscriptionHandle:unsubscribe()

					-- There should be one more todo item than before
					expect(#newResult.data.todoList.todos).toBe(4)

					-- Since we used `prepend` it should be at the front
					expect(newResult.data.todoList.todos[1].text).toBe("This one was created with a mutation.")
				end)
				:andThen(resolve, reject)
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itAsync.skip("does not make next queries fail if a mutation fails", function(resolve, reject)
			local ref = setupObsQuery(function(error_)
				error(error_)
			end, {
				request = { query = mutation },
				result = { errors = { Error.new("mock error") } },
			}, {
				request = { query = queryWithTypename },
				result = result,
			})
			local client, obsQuery = ref.client, ref.obsQuery

			obsQuery:subscribe({
				next = function(_self)
					client
						:mutate({
							mutation = mutation,
							update = function(proxy, mResult: any)
								expect(mResult.data.createTodo.id).toBe("99")
								expect(mResult.data.createTodo.text).toBe("This one was created with a mutation.")

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

								local data: any = proxy:readFragment({
									id = id,
									fragment = fragment,
								})

								proxy:writeFragment({
									data = Object.assign({}, data, {
										todos = Array.concat({}, { mResult.data.createTodo }, data.todos),
									}),
									id = id,
									fragment = fragment,
								})
							end,
						})
						:andThen(function()
							return reject(Error.new("Mutation should have failed"))
						end, function()
							return client:mutate({
								mutation = mutation,
								update = function(proxy, mResult: any)
									expect(mResult.data.createTodo.id).toBe("99")
									expect(mResult.data.createTodo.text).toBe("This one was created with a mutation.")

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

									local data: any = proxy:readFragment({
										id = id,
										fragment = fragment,
									})

									proxy:writeFragment({
										data = Object.assign({}, data, {
											todos = Array.concat({}, { mResult.data.createTodo }, data.todos),
										}),
										id = id,
										fragment = fragment,
									})
								end,
							})
						end)
						:andThen(function()
							return reject(Error.new("Mutation should have failed"))
						end, function()
							return obsQuery:refetch() :: Promise<any>
						end)
						:andThen(resolve, reject)
				end,
			})
		end)

		itAsync("error handling in reducer functions", function(resolve, reject)
			local subscriptionHandle: Subscription
			local ref = setupObsQuery(reject, { request = { query = mutation }, result = mutationResult })
			local client, obsQuery = ref.client, ref.obsQuery

			return obsQuery
				:result()
				:andThen(function()
					-- we have to actually subscribe to the query to be able to update it
					return Promise.new(function(resolve)
						local handle = client:watchQuery({ query = query })
						subscriptionHandle = handle:subscribe({
							next = function(_self, res)
								resolve(res)
							end,
						})
					end)
				end)
				:andThen(function()
					return client:mutate({
						mutation = mutation,
						update = function()
							error(Error.new("Hello... It's me."))
						end,
					}) :: Promise<any>
				end)
				:andThen(function()
					subscriptionHandle:unsubscribe()
					reject("should have thrown")
				end, function(error_)
					subscriptionHandle:unsubscribe()
					expect(error_.message).toBe("Hello... It's me.")
				end)
				:andThen(resolve, reject)
		end)

		itAsync("mutate<MyType>() data should never be `undefined` in case of success", function(resolve, reject)
			local mutation = gql([[

        mutation Foo {
          foo {
            bar
          }
        }
      ]])

			local result1 = {
				data = {
					foo = {
						bar = "a",
					},
				},
			}

			local client = ApolloClient.new({
				link = mockSingleLink({
					request = { query = mutation } :: any,
					result = result1,
				}):setOnError(reject),
				cache = InMemoryCache.new({ addTypename = false }),
			})

			client
				:mutate({
					mutation = mutation,
				})
				:andThen(function(result)
					-- This next line should **not** raise "TS2533: Object is possibly 'null' or 'undefined'.", even without `!` operator
					if Boolean.toJSBoolean((result.data :: any).foo.bar) then
						resolve()
					end
				end, reject)
		end)
	end)
end)

return {}
