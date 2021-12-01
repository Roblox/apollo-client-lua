-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/__tests__/local-state/resolvers.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Object = LuauPolyfill.Object
	local Set = LuauPolyfill.Set
	local console = LuauPolyfill.console
	local setTimeout = LuauPolyfill.setTimeout

	type Array<T> = LuauPolyfill.Array<T>
	type Error = LuauPolyfill.Error
	-- ROBLOX FIXME: fix in LuauPolyfill
	type Object = { [string]: any }

	local Promise = require(rootWorkspace.Promise)

	local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
	type Promise<T> = PromiseTypeModule.Promise<T>

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local gql = require(rootWorkspace.Dev.GraphQLTag).default
	local graphqlModule = require(rootWorkspace.GraphQL)
	type DocumentNode = graphqlModule.DocumentNode
	type ExecutionResult = graphqlModule.ExecutionResult
	-- ROBLOX deviation: using Object.assign instead of lodash version
	local assign = Object.assign

	local LocalState = require(script.Parent.Parent.Parent.core.LocalState).LocalState

	local coreModule = require(script.Parent.Parent.Parent.core)
	local ApolloClient = coreModule.ApolloClient
	type ApolloQueryResult<T> = coreModule.ApolloQueryResult<T>
	type Resolvers = coreModule.Resolvers
	type WatchQueryOptions__ = coreModule.WatchQueryOptions__

	local InMemoryCache = require(script.Parent.Parent.Parent.cache).InMemoryCache
	local utilitiesModule = require(script.Parent.Parent.Parent.utilities)
	local Observable = utilitiesModule.Observable
	type Observer<T> = utilitiesModule.Observer<T>
	local ApolloLink = require(script.Parent.Parent.Parent.link.core).ApolloLink
	local itAsync = require(script.Parent.Parent.Parent.testing).itAsync
	local mockQueryManager = require(script.Parent.Parent.Parent.utilities.testing.mocking.mockQueryManager).default
	local wrap = require(script.Parent.Parent.Parent.utilities.testing.wrap).default

	-- Helper method that sets up a mockQueryManager and then passes on the
	-- results to an observer.
	local function assertWithObserver(
		ref: {
			reject: (any) -> any,
			resolvers: Resolvers?,
			query: DocumentNode,
			serverQuery: DocumentNode?,
			variables: Object?,
			queryOptions: Object?,
			error: Error?,
			serverResult: ExecutionResult?,
			delay: number?,
			observer: Observer<ApolloQueryResult<any>>,
		}
	)
		local reject, resolvers, query, serverQuery, variables, queryOptions, serverResult, error_, delay, observer =
			ref.reject, ref.resolvers, ref.query, ref.serverQuery, (function()
				return if ref.variables == nil then {} else ref.variables
			end)(), (function()
				return if ref.queryOptions == nil then {} else ref.queryOptions
			end)(), ref.serverResult, ref.error, ref.delay, ref.observer

		local queryManager = mockQueryManager(reject, {
			request = {
				query = serverQuery or query,
				variables = variables,
			},
			result = serverResult,
			error = error_,
			delay = delay,
		})

		if resolvers then
			queryManager:getLocalState():addResolvers(resolvers)
		end

		local finalOptions = assign({ query = query, variables = variables }, queryOptions) :: WatchQueryOptions__
		return queryManager:watchQuery(finalOptions):subscribe({
			next = wrap(reject, observer.next :: any),
			error = observer.error,
		})
	end

	describe("Basic resolver capabilities", function()
		itAsync(it)("should run resolvers for @client queries", function(resolve, reject)
			local query = gql([[

      query Test {
        foo @client {
          bar
        }
      }
    ]])

			local resolvers = {
				Query = {
					foo = function()
						return { bar = true }
					end,
				},
			}

			assertWithObserver({
				reject = reject,
				resolvers = resolvers,
				query = query,
				observer = {
					next = function(_self, ref)
						local data = ref.data
						xpcall(function()
							jestExpect(data).toEqual({ foo = { bar = true } })
						end, function(error_)
							reject(error_)
						end)
						resolve()
					end,
				},
			})
		end)

		itAsync(it)("should handle queries with a mix of @client and server fields", function(resolve, reject)
			local query = gql([[

      query Mixed {
        foo @client {
          bar
        }
        bar {
          baz
        }
      }
    ]])

			local serverQuery = gql([[

      query Mixed {
        bar {
          baz
        }
      }
    ]])

			local resolvers = {
				Query = {
					foo = function()
						return { bar = true }
					end,
				},
			}

			assertWithObserver({
				reject = reject,
				resolvers = resolvers,
				query = query,
				serverQuery = serverQuery,
				serverResult = { data = { bar = { baz = true } } },
				observer = {
					next = function(_self, ref)
						local data = ref.data
						xpcall(function()
							jestExpect(data).toEqual({ foo = { bar = true }, bar = { baz = true } })
						end, function(error_)
							reject(error_)
						end)
						resolve()
					end,
				},
			})
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itAsync(itSKIP)(
			"should handle a mix of @client fields with fragments and server fields",
			function(resolve, reject)
				local query = gql([[

      fragment client on ClientData {
        bar
        __typename
      }

      query Mixed {
        foo @client {
          ...client
        }
        bar {
          baz
        }
      }
    ]])

				local serverQuery = gql([[

      query Mixed {
        bar {
          baz
        }
      }
    ]])

				local resolvers = {
					Query = {
						foo = function()
							return { bar = true, __typename = "ClientData" }
						end,
					},
				}

				assertWithObserver({
					reject = reject,
					resolvers = resolvers,
					query = query,
					serverQuery = serverQuery,
					serverResult = { data = { bar = { baz = true, __typename = "Bar" } } },
					observer = {
						next = function(_self, ref)
							local data = ref.data
							xpcall(function()
								jestExpect(data).toEqual({
									foo = { bar = true, __typename = "ClientData" },
									bar = { baz = true },
								})
							end, function(error_)
								reject(error_)
							end)
							resolve()
						end,
					},
				})
			end
		)

		itAsync(it)("should have access to query variables when running @client resolvers", function(resolve, reject)
			local query = gql([[

      query WithVariables($id: ID!) {
        foo @client {
          bar(id: $id)
        }
      }
    ]])

			local resolvers = {
				Query = {
					foo = function()
						return { __typename = "Foo" }
					end,
				},
				Foo = {
					bar = function(_self, _data: any, ref)
						local id = ref.id
						return id
					end,
				},
			}

			assertWithObserver({
				reject = reject,
				resolvers = resolvers,
				query = query,
				variables = { id = 1 },
				observer = {
					next = function(_self, ref)
						local data = ref.data
						xpcall(function()
							jestExpect(data).toEqual({ foo = { bar = 1 } })
						end, function(error_)
							reject(error_)
						end)
						resolve()
					end,
				},
			})
		end)

		itAsync(it)("should pass context to @client resolvers", function(resolve, reject)
			local query = gql([[

      query WithContext {
        foo @client {
          bar
        }
      }
    ]])

			local resolvers = {
				Query = {
					foo = function()
						return { __typename = "Foo" }
					end,
				},
				Foo = {
					bar = function(_self, _data: any, _args: any, ref)
						local id = ref.id
						return id
					end,
				},
			}

			assertWithObserver({
				reject = reject,
				resolvers = resolvers,
				query = query,
				queryOptions = { context = { id = 1 } },
				observer = {
					next = function(_self, ref)
						local data = ref.data
						xpcall(function()
							jestExpect(data).toEqual({ foo = { bar = 1 } })
						end, function(error_)
							reject(error_)
						end)
						resolve()
					end,
				},
			})
		end)

		itAsync(it)(
			"should combine local @client resolver results with server results, for " .. "the same field",
			function(resolve, reject)
				local query = gql([[

        query author {
          author {
            name
            stats {
              totalPosts
              postsToday @client
            }
          }
        }
      ]])

				local serverQuery = gql([[

        query author {
          author {
            name
            stats {
              totalPosts
            }
          }
        }
      ]])

				local resolvers = {
					Stats = {
						postsToday = function()
							return 10
						end,
					},
				}

				assertWithObserver({
					reject = reject,
					resolvers = resolvers,
					query = query,
					serverQuery = serverQuery,
					serverResult = {
						data = {
							author = {
								name = "John Smith",
								stats = { totalPosts = 100, __typename = "Stats" },
								__typename = "Author",
							},
						},
					},
					observer = {
						next = function(_self, ref)
							local data = ref.data
							xpcall(function()
								jestExpect(data).toEqual({
									author = {
										name = "John Smith",
										stats = { totalPosts = 100, postsToday = 10 },
									},
								})
							end, function(error_)
								reject(error_)
							end)
							resolve()
						end,
					},
				})
			end
		)

		itAsync(it)("should handle resolvers that work with booleans properly", function(resolve, reject)
			local query = gql([[

      query CartDetails {
        isInCart @client
      }
    ]])

			local cache = InMemoryCache.new()
			cache:writeQuery({ query = query, data = { isInCart = true } })

			local client = ApolloClient.new({
				cache = cache,
				resolvers = { Query = {
					isInCart = function()
						return false
					end,
				} },
			})

			return client:query({ query = query, fetchPolicy = "network-only" }):andThen(function(ref)
				local data = ref.data
				jestExpect(Object.assign({}, data)).toMatchObject({ isInCart = false })
				resolve()
			end)
		end)

		it("should handle nested asynchronous @client resolvers (issue #4841)", function()
			local query = gql([[

      query DeveloperTicketComments($id: ID) {
        developer(id: $id) @client {
          id
          handle
          tickets @client {
            id
            comments @client {
              id
            }
          }
        }
      }
    ]])

			local function randomDelay(range: number)
				return Promise.new(function(resolve)
					return setTimeout(resolve, math.round(math.random() * range))
				end)
			end

			-- ROBLOX deviation: using custom uuid function
			local uuid = require(srcWorkspace.utilities.common.makeUniqueId).uuid

			local developerId = uuid()

			local function times<T>(n: number, thunk: () -> T): Promise<Array<T>>
				local result: Array<T> = {}
				for _ = 1, n do
					-- ROBLOX deviation START: Promise.all handles only Promises and not resolved values. Need to check if thunk returns Promise object
					local res = thunk()
					table.insert(result, if Promise.is(res) then res else Promise.resolve(res))
					-- ROBLOX deviation END
				end
				return Promise.all(result)
			end

			local ticketsPerDev = 5
			local commentsPerTicket = 5

			local client = ApolloClient.new({
				cache = InMemoryCache.new(),
				resolvers = {
					Query = {
						developer = function(_self, _, ref)
							return Promise.resolve():andThen(function()
								local id = ref.id
								randomDelay(50):expect()
								jestExpect(id).toBe(developerId)
								return {
									__typename = "Developer",
									id = id,
									handle = "@benjamn",
								}
							end)
						end,
					},
					Developer = {
						tickets = function(_self, developer)
							return Promise.resolve():andThen(function()
								randomDelay(50):expect()
								jestExpect(developer.__typename).toBe("Developer")
								return times(ticketsPerDev, function()
									return {
										__typename = "Ticket",
										id = uuid(),
									}
								end)
							end)
						end,
					},
					Ticket = {
						comments = function(_self, ticket)
							return Promise.resolve():andThen(function()
								randomDelay(50):expect()
								jestExpect(ticket.__typename).toBe("Ticket")
								return times(commentsPerTicket, function()
									return {
										__typename = "Comment",
										id = uuid(),
									}
								end)
							end)
						end,
					},
				},
			})

			local function check(result: ApolloQueryResult<any>)
				return Promise.new(function(resolve)
					jestExpect(result.data.developer.id).toBe(developerId)
					jestExpect(result.data.developer.handle).toBe("@benjamn")
					jestExpect(#result.data.developer.tickets).toBe(ticketsPerDev)
					local commentIds = Set.new()
					Array.forEach(result.data.developer.tickets, function(ticket: any)
						jestExpect(ticket.__typename).toBe("Ticket")
						jestExpect(#ticket.comments).toBe(commentsPerTicket)
						Array.forEach(ticket.comments, function(comment: any)
							jestExpect(comment.__typename).toBe("Comment")
							commentIds:add(comment.id)
						end)
					end)
					jestExpect(commentIds.size).toBe(ticketsPerDev * commentsPerTicket)
					resolve()
				end)
			end

			return Promise.all({
				Promise.new(function(resolve, reject)
					client:watchQuery({ query = query, variables = { id = developerId } }):subscribe({
						next = function(_self, result)
							check(result):andThen(resolve, reject)
						end,
						error = reject,
					})
				end),
				client:query({ query = query, variables = { id = developerId } }):andThen(check),
			}):expect()
		end)
	end)

	describe("Writing cache data from resolvers", function()
		it("should let you write to the cache with a mutation", function()
			local query = gql([[

      {
        field @client
      }
    ]])

			local mutation = gql([[

      mutation start {
        start @client
      }
    ]])

			local client = ApolloClient.new({
				cache = InMemoryCache.new(),
				link = ApolloLink.empty(),
				resolvers = {
					Mutation = {
						start = function(_self, _data, _args, ref)
							local cache = ref.cache
							cache:writeQuery({ query = query, data = { field = 1 } })
							return { start = true }
						end,
					},
				},
			})

			return client
				:mutate({ mutation = mutation })
				:andThen(function()
					return client:query({ query = query })
				end)
				:andThen(function(ref)
					local data = ref.data
					jestExpect(Object.assign({}, data)).toMatchObject({ field = 1 })
				end)
				:expect()
		end)

		it("should let you write to the cache with a mutation using an ID", function()
			local query = gql([[

      {
        obj @client {
          field
        }
      }
    ]])

			local mutation = gql([[

      mutation start {
        start @client
      }
    ]])

			local cache = InMemoryCache.new()

			local client = ApolloClient.new({
				cache = cache,
				link = ApolloLink.empty(),
				resolvers = {
					Mutation = {
						start = function(_self)
							cache:writeQuery({
								query = query,
								data = { obj = { field = 1, id = "uniqueId", __typename = "Object" } },
							})

							cache:modify({
								id = "Object:uniqueId",
								fields = {
									-- ROBLOX FIXME: had to add 3rd param `_` to satisfy a Modifier interface but it shouldn't be necessary
									field = function(_self, value, _)
										jestExpect(value).toBe(1)
										return 2
									end,
								},
							})

							return { start = true }
						end,
					},
				},
			})

			return client
				:mutate({ mutation = mutation })
				:andThen(function()
					return client:query({ query = query })
				end)
				:andThen(function(ref)
					local data = ref.data
					jestExpect(data.obj.field).toEqual(2)
				end)
				:expect()
		end)

		it("should not overwrite __typename when writing to the cache with an id", function()
			local query = gql([[

      {
        obj @client {
          field {
            field2
          }
          id
        }
      }
    ]])

			local mutation = gql([[

      mutation start {
        start @client
      }
    ]])

			local cache = InMemoryCache.new()

			local client = ApolloClient.new({
				cache = cache,
				link = ApolloLink.empty(),
				resolvers = {
					Mutation = {
						start = function(_self)
							cache:writeQuery({
								query = query,
								data = {
									obj = {
										field = { field2 = 1, __typename = "Field" },
										id = "uniqueId",
										__typename = "Object",
									},
								},
							})
							cache:modify({
								id = "Object:uniqueId",
								fields = {
									-- ROBLOX FIXME: had to add 3rd param `_` to satisfy a Modifier interface but it shouldn't be necessary
									field = function(_self, value: { field2: number }, _)
										jestExpect(value.field2).toBe(1)
										return Object.assign({}, value, { field2 = 2 })
									end,
								},
							})
							return { start = true }
						end,
					},
				},
			})

			return client
				:mutate({ mutation = mutation })
				:andThen(function()
					return client:query({ query = query })
				end)
				:andThen(function(ref)
					local data = ref.data
					jestExpect(data.obj.__typename).toEqual("Object")
					jestExpect(data.obj.field.__typename).toEqual("Field")
				end)
				:catch(function(e)
					return console.log(e)
				end)
				:expect()
		end)
	end)

	describe("Resolving field aliases", function()
		itAsync(it)("should run resolvers for missing client queries with aliased field", function(resolve, reject)
			-- expect.assertions(1);
			local query = gql([[

      query Aliased {
        foo @client {
          bar
        }
        baz: bar {
          foo
        }
      }
    ]])

			local link = ApolloLink.new(function()
				-- Each link is responsible for implementing their own aliasing so it
				-- returns baz not bar
				return Observable.of({ data = { baz = { foo = true, __typename = "Baz" } } })
			end)

			local client = ApolloClient.new({
				cache = InMemoryCache.new(),
				link = link,
				resolvers = {
					Query = {
						foo = function()
							return { bar = true, __typename = "Foo" }
						end,
					},
				},
			})

			client:query({ query = query }):andThen(function(ref)
				local data = ref.data
				local ok, result = pcall(function()
					jestExpect(data).toEqual({
						foo = { bar = true, __typename = "Foo" },
						baz = { foo = true, __typename = "Baz" },
					})
				end)
				if not ok then
					reject(result)
					return
				end
				resolve()
			end, reject)
		end)

		itAsync(it)(
			"should run resolvers for client queries when aliases are in use on " .. "the @client-tagged node",
			function(resolve, reject)
				local aliasedQuery = gql([[

        query Test {
          fie: foo @client {
            bar
          }
        }
      ]])

				local client = ApolloClient.new({
					cache = InMemoryCache.new(),
					link = ApolloLink.empty(),
					resolvers = {
						Query = {
							foo = function()
								return { bar = true, __typename = "Foo" }
							end,
							fie = function()
								reject(
									"Called the resolver using the alias' name, instead of "
										.. "the correct resolver name."
								)
							end,
						},
					},
				})

				client:query({ query = aliasedQuery }):andThen(function(ref)
					local data = ref.data
					jestExpect(data).toEqual({ fie = { bar = true, __typename = "Foo" } })
					resolve()
				end, reject)
			end
		)

		itAsync(it)("should respect aliases for *nested fields* on the @client-tagged node", function(resolve, reject)
			local aliasedQuery = gql([[

      query Test {
        fie: foo @client {
          fum: bar
        }
        baz: bar {
          foo
        }
      }
    ]])

			local link = ApolloLink.new(function()
				return Observable.of({ data = { baz = { foo = true, __typename = "Baz" } } })
			end)

			local client = ApolloClient.new({
				cache = InMemoryCache.new(),
				link = link,
				resolvers = {
					Query = {
						foo = function()
							return { bar = true, __typename = "Foo" }
						end,
						fie = function()
							reject(
								"Called the resolver using the alias' name, instead of " .. "the correct resolver name."
							)
						end,
					},
				},
			})

			client:query({ query = aliasedQuery }):andThen(function(ref)
				local data = ref.data
				jestExpect(data).toEqual({
					fie = { fum = true, __typename = "Foo" },
					baz = { foo = true, __typename = "Baz" },
				})
				resolve()
			end, reject)
		end)

		it("should pull initialized values for aliased fields tagged with @client " .. "from the cache", function()
			local query = gql([[

        {
          fie: foo @client {
            bar
          }
        }
      ]])

			local cache = InMemoryCache.new()
			local client = ApolloClient.new({
				cache = cache,
				link = ApolloLink.empty(),
				resolvers = {},
			})

			cache:writeQuery({
				query = gql("{ foo { bar }}"),
				data = { foo = { bar = "yo", __typename = "Foo" } },
			})

			return client
				:query({ query = query })
				:andThen(function(ref)
					local data = ref.data
					jestExpect(Object.assign({}, data)).toMatchObject({
						fie = { bar = "yo", __typename = "Foo" },
					})
				end)
				:expect()
		end)

		-- ROBLOX TODO: fragments are not supported yet
		itSKIP(
			"should resolve @client fields using local resolvers and not have "
				.. "their value overridden when a fragment is loaded",
			function()
				local query = gql([[

        fragment LaunchDetails on Launch {
          id
          __typename
        }
        query Launch {
          launch {
            isInCart @client
            ...LaunchDetails
          }
        }
      ]])

				local link = ApolloLink.new(function()
					return Observable.of({
						data = {
							launch = {
								id = 1,
								__typename = "Launch",
							},
						},
					})
				end)

				local client = ApolloClient.new({
					cache = InMemoryCache.new(),
					link = link,
					resolvers = { Launch = {
						isInCart = function(_self)
							return true
						end,
					} },
				})

				client:writeQuery({
					query = gql("{ launch { isInCart }}"),
					data = {
						launch = {
							isInCart = false,
							__typename = "Launch",
						},
					},
				})
				return client
					:query({ query = query })
					:andThen(function(ref)
						local data = ref.data
						-- `isInCart` resolver is fired, returning `true` (which is then
						-- stored in the cache).
						jestExpect(data.launch.isInCart).toBe(true)
					end)
					:andThen(function()
						client:query({ query = query }):andThen(function(ref)
							local data = ref.data
							-- When the same query fires again, `isInCart` should be pulled from
							-- the cache and have a value of `true`.
							jestExpect(data.launch.isInCart).toBe(true)
						end)
					end)
			end
		)
	end)

	describe("Force local resolvers", function()
		it(
			"should force the running of local resolvers marked with "
				.. "`@client(always: true)` when using `ApolloClient.query`",
			function()
				return Promise.resolve()
					:andThen(function()
						local query = gql([[

        query Author {
          author {
            name
            isLoggedIn @client(always: true)
          }
        }
      ]])

						local cache = InMemoryCache.new()
						local client = ApolloClient.new({
							cache = cache,
							link = ApolloLink.empty(),
							resolvers = {},
						})

						cache:writeQuery({
							query = query,
							data = {
								author = {
									name = "John Smith",
									isLoggedIn = false,
									__typename = "Author",
								},
							},
						})

						-- When the resolver isn't defined, there isn't anything to force, so
						-- make sure the query resolves from the cache properly.
						local data1 = client:query({
							query = query,
						}):expect().data
						jestExpect(data1.author.isLoggedIn).toEqual(false)

						client:addResolvers({
							Author = {
								isLoggedIn = function(_self)
									return true
								end,
							},
						})

						-- A resolver is defined, so make sure it's forced, and the result
						-- resolves properly as a combination of cache and local resolver
						-- data.
						local data2 = client:query({
							query = query,
						}):expect().data
						jestExpect(data2.author.isLoggedIn).toEqual(true)
					end)
					:expect()
			end
		)

		it(
			"should avoid running forced resolvers a second time when "
				.. "loading results over the network (so not from the cache)",
			function()
				return Promise.resolve()
					:andThen(function()
						local query = gql([[

        query Author {
          author {
            name
            isLoggedIn @client(always: true)
          }
        }
      ]])

						local link = ApolloLink.new(function()
							return Observable.of({
								data = {
									author = {
										name = "John Smith",
										__typename = "Author",
									},
								},
							})
						end)

						local count = 0
						local client = ApolloClient.new({
							cache = InMemoryCache.new(),
							link = link,
							resolvers = {
								Author = {
									isLoggedIn = function(_self)
										count += 1
										return true
									end,
								},
							},
						})

						local data = client:query({
							query = query,
						}):expect().data
						jestExpect(data.author.isLoggedIn).toEqual(true)
						jestExpect(count).toEqual(1)
					end)
					:expect()
			end
		)

		it(
			"should only force resolvers for fields marked with " .. "`@client(always: true)`, not all `@client` fields",
			function()
				return Promise.resolve()
					:andThen(function()
						local query = gql([[

        query UserDetails {
          name @client
          isLoggedIn @client(always: true)
        }
      ]])

						local nameCount = 0
						local isLoggedInCount = 0
						local client = ApolloClient.new({
							cache = InMemoryCache.new(),
							resolvers = {
								Query = {
									name = function(_self)
										nameCount += 1
										return "John Smith"
									end,
									isLoggedIn = function(_self)
										isLoggedInCount += 1
										return true
									end,
								},
							},
						})

						client
							:query({
								query = query,
							})
							:expect()
						jestExpect(nameCount).toEqual(1)
						jestExpect(isLoggedInCount).toEqual(1)

						-- On the next request, `name` will be loaded from the cache only,
						-- whereas `isLoggedIn` will be loaded from the cache then overwritten
						-- by running its forced local resolver.
						client
							:query({
								query = query,
							})
							:expect()
						jestExpect(nameCount).toEqual(1)
						jestExpect(isLoggedInCount).toEqual(2)
					end)
					:expect()
			end
		)

		itAsync(it)(
			"should force the running of local resolvers marked with "
				.. "`@client(always: true)` when using `ApolloClient.watchQuery`",
			function(resolve, reject)
				local query = gql([[

        query IsUserLoggedIn {
          isUserLoggedIn @client(always: true)
        }
      ]])

				local queryNoForce = gql([[

        query IsUserLoggedIn {
          isUserLoggedIn @client
        }
      ]])

				local callCount = 0
				local client = ApolloClient.new({
					cache = InMemoryCache.new(),
					resolvers = {
						Query = {
							isUserLoggedIn = function(_self)
								callCount += 1
								return true
							end,
						},
					},
				})

				client:watchQuery({ query = query }):subscribe({
					next = function(_self)
						jestExpect(callCount).toBe(1)

						client:watchQuery({ query = query }):subscribe({
							next = function(_self)
								jestExpect(callCount).toBe(2)

								client:watchQuery({ query = queryNoForce }):subscribe({
									next = function(_self)
										-- Result is loaded from the cache since the resolver
										-- isn't being forced.
										jestExpect(callCount).toBe(2)
										resolve()
									end,
								})
							end,
						})
					end,
				})
			end
		)

		it("should allow client-only virtual resolvers (#4731)", function()
			local query = gql([[

      query UserData {
        userData @client {
          firstName
          lastName
          fullName
        }
      }
    ]])

			local client = ApolloClient.new({
				cache = InMemoryCache.new(),
				resolvers = {
					Query = {
						userData = function(_self)
							return {
								__typename = "User",
								firstName = "Ben",
								lastName = "Newman",
							}
						end,
					},
					User = {
						fullName = function(_self, data: any)
							return data.firstName .. " " .. data.lastName
						end,
					},
				},
			})

			return client
				:query({ query = query })
				:andThen(function(result)
					jestExpect(result.data).toEqual({
						userData = {
							__typename = "User",
							firstName = "Ben",
							lastName = "Newman",
							fullName = "Ben Newman",
						},
					})
				end)
				:expect()
		end)
	end)

	describe("Async resolvers", function()
		itAsync(it)("should support async @client resolvers", function(resolve, reject)
			local query = gql([[

      query Member {
        isLoggedIn @client
      }
    ]])

			local client = ApolloClient.new({
				cache = InMemoryCache.new(),
				resolvers = {
					Query = {
						isLoggedIn = function(_self)
							return Promise.resolve(true)
						end,
					},
				},
			})

			local isLoggedIn = client:query({
				query = query,
			}):expect().data.isLoggedIn
			jestExpect(isLoggedIn).toBe(true)
			return resolve()
		end)

		itAsync(it)(
			"should support async @client resolvers mixed with remotely resolved data",
			function(resolve, reject)
				local query = gql([[

        query Member {
          member {
            name
            sessionCount @client
            isLoggedIn @client
          }
        }
      ]])

				local testMember = {
					name = "John Smithsonian",
					isLoggedIn = true,
					sessionCount = 10,
				}

				local link = ApolloLink.new(function()
					return Observable.of({
						data = {
							member = {
								name = testMember.name,
								__typename = "Member",
							},
						},
					})
				end)

				local client = ApolloClient.new({
					cache = InMemoryCache.new(),
					link = link,
					resolvers = {
						Member = {
							isLoggedIn = function(_self)
								return Promise.resolve(testMember.isLoggedIn)
							end,
							sessionCount = function(_self)
								return testMember.sessionCount
							end,
						},
					},
				})

				local member = client:query({
					query = query,
				}):expect().data.member
				jestExpect(member.name).toBe(testMember.name)
				jestExpect(member.isLoggedIn).toBe(testMember.isLoggedIn)
				jestExpect(member.sessionCount).toBe(testMember.sessionCount)
				return resolve()
			end
		)
	end)

	describe("LocalState helpers", function()
		describe("#shouldForceResolvers", function()
			it(
				"should return true if the document contains any @client directives "
					.. "with an `always` variable of true",
				function()
					local localState = LocalState.new({ cache = InMemoryCache.new() })
					local query = gql([[

          query Author {
            name
            isLoggedIn @client(always: true)
          }
        ]])
					jestExpect(localState:shouldForceResolvers(query)).toBe(true)
				end
			)

			it(
				"should return false if the document contains any @client directives " .. "without an `always` variable",
				function()
					local localState = LocalState.new({ cache = InMemoryCache.new() })
					local query = gql([[

          query Author {
            name
            isLoggedIn @client
          }
        ]])
					jestExpect(localState:shouldForceResolvers(query)).toBe(false)
				end
			)

			it(
				"should return false if the document contains any @client directives "
					.. "with an `always` variable of false",
				function()
					local localState = LocalState.new({ cache = InMemoryCache.new() })
					local query = gql([[

          query Author {
            name
            isLoggedIn @client(always: false)
          }
        ]])
					jestExpect(localState:shouldForceResolvers(query)).toBe(false)
				end
			)
		end)
	end)
end
