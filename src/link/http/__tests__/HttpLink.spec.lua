-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/http/__tests__/HttpLink.ts
return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local setTimeout = LuauPolyfill.setTimeout
	local Boolean = LuauPolyfill.Boolean
	local Error = LuauPolyfill.Error
	local console = LuauPolyfill.console
	type Object = LuauPolyfill.Object
	type Error = LuauPolyfill.Error

	local Promise = require(rootWorkspace.Promise)
	local hasOwnProperty = require(srcWorkspace.luaUtils.hasOwnProperty)
	local RegExp = require(rootWorkspace.LuauRegExp)

	type BodyInit = Object
	local waitForCompletion = require(srcWorkspace.testUtils.waitForCompletion)

	type FetchMock = {
		get: (self: FetchMock, url: string, response: any) -> (),
		post: (self: FetchMock, url: string, response: any) -> (),
		lastCall: (self: FetchMock) -> any,
		lastUrl: (self: FetchMock) -> string,
		restore: (self: FetchMock) -> (),
	}

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest

	local HttpService = game:GetService("HttpService")

	-- ROBLOX deviation: keep original fetch to restore it later
	local fetch = _G.fetch

	local gql = require(rootWorkspace.GraphQLTag).default

	-- ROBLOX deviation: using own implementation
	-- local fetchMock = require(rootWorkspace["fetch-mock"]).default
	local fetchMock: FetchMock = (
		setmetatable({
			calls = {},
			lastCall = function(self)
				return self.calls[#self.calls]
			end,
			lastUrl = function(self)
				return self:lastCall()[1]
			end,
			responses = {},
			post = function(self, url_, response)
				local url = string.sub(url_, 8)
				if self.responses[url] == nil then
					self.responses[url] = {}
				end

				self.responses[url].POST = response
			end,
			get = function(self, url_, response)
				local url = string.sub(url_, 8)
				if self.responses[url] == nil then
					self.responses[url] = {}
				end
				self.responses[url].GET = response
			end,
			restore = function(self)
				self.calls = {}
				self.responses = {}
			end,
		}, {
			__call = function(self, url: string, options: Object)
				if string.sub(url, 1, 1) == "/" then
					table.insert(self.calls, { url, options :: any })
				else
					table.insert(self.calls, { "/" .. url, options :: any })
				end
				local res
				if
					Boolean.toJSBoolean(self.responses[url])
					and Boolean.toJSBoolean(self.responses[url][options.method])
				then
					res = self.responses[url][options.method]
				else
					res = { data = {}, errors = {} }
				end

				if res.throws then
					error(res.throws)
				end
				if typeof(res.andThen) == "function" then
					res = res:expect()
				end

				local status = res.status or 200

				return Promise.resolve({
					text = function(_self)
						return Promise.resolve(res and HttpService:JSONEncode(res) or "")
					end,
					headers = {
						["Content-Length"] = tostring(string.len(res and HttpService:JSONEncode(res) or "")),
					},
					status = status,
				})
			end,
		}) :: any
	) :: FetchMock

	local print_ = require(rootWorkspace.GraphQL).print
	local observableModule = require(srcWorkspace.utilities.observables.Observable)
	local Observable = observableModule.Observable
	type Observable<T> = observableModule.Observable<T>
	type Observer<T> = observableModule.Observer<T>
	type Subscriber<T> = observableModule.Subscriber<T>
	local apolloLinkModule = require(script.Parent.Parent.Parent.core.ApolloLink)
	local ApolloLink = apolloLinkModule.ApolloLink
	type ApolloLink = apolloLinkModule.ApolloLink
	local execute = require(script.Parent.Parent.Parent.core.execute).execute
	local HttpLink = require(script.Parent.Parent.HttpLink).HttpLink
	local createHttpLink = require(script.Parent.Parent.createHttpLink).createHttpLink
	local serializeModule = require(script.Parent.Parent.serializeFetchParameter)
	type ClientParseError = serializeModule.ClientParseError
	local parseModule = require(script.Parent.Parent.parseAndCheckHttpResponse)
	type ServerParseError = parseModule.ServerParseError
	local utilsModule = require(script.Parent.Parent.Parent.utils)
	type ServerError = utilsModule.ServerError

	local voidFetchDuringEachTest = require(script.Parent.helpers)({
		beforeEach = beforeEach,
		afterEach = afterEach,
		describe = describe,
		it = it,
	}).voidFetchDuringEachTest

	local sampleQuery = gql([[

query SampleQuery {
    stub {
      id
    }
}
]])

	local sampleMutation = gql([[

mutation SampleMutation {
	stub {
    	id
    }
}
]])

	local function makeCallback(body: (...any) -> ())
		return function(...)
			local args = { ... }
			local ok, res = pcall(function()
				body(table.unpack(args))
			end)
			if not ok then
				jestExpect(res).toBeUndefined()
			end
		end
	end

	local function convertBatchedBody(body: BodyInit | nil)
		return HttpService:JSONDecode((body :: any) :: string)
	end

	local function makePromise(res: any)
		return Promise.new(function(resolve)
			setTimeout(function()
				return resolve(res)
			end)
		end)
	end

	describe("HttpLink", function()
		describe("General", function()
			local data = { data = { hello = "world" } }
			local data2 = { data = { hello = "everyone" } }
			local mockError = { throws = Error.new("mock me") }
			local subscriber: Observer<any>

			beforeEach(function()
				fetchMock:restore()
				fetchMock:post("begin:/data2", makePromise(data2))
				fetchMock:post("begin:/data", makePromise(data))
				fetchMock:post("begin:/error", mockError)
				fetchMock:post("begin:/apollo", makePromise(data))

				fetchMock:get("begin:/data", makePromise(data))
				fetchMock:get("begin:/data2", makePromise(data2))

				-- ROBLOX deviation: need to set global fetch
				_G.fetch = fetchMock

				local next = jest.fn()
				local error_ = jest.fn()
				local complete = jest.fn()
				subscriber = {
					next = next,
					error = error_,
					complete = complete,
				}
			end)

			afterEach(function()
				fetchMock:restore()

				-- ROBLOX deviation: restore global fetch
				_G.fetch = fetch
			end)

			it("does not need any constructor arguments", function()
				jestExpect(function()
					return HttpLink.new()
				end).never.toThrow()
			end)

			it("constructor creates link that can call next and then complete", function()
				local next = jest.fn()
				local link = HttpLink.new({ uri = "/data" })
				local observable = execute(link, { query = sampleQuery })
				waitForCompletion(observable, {
					next = function(_self, value)
						next(value)
					end,
					error = function(_self, _error)
						return jestExpect(false).toBeTruthy()
					end,
					complete = function()
						jestExpect(next).toHaveBeenCalledTimes(1)
					end,
				})
			end)

			it("supports using a GET request", function()
				local variables = { params = "stub" }
				local extensions = { myExtension = "foo" }
				local link = createHttpLink({
					uri = "/data",
					fetchOptions = { method = "GET" },
					includeExtensions = true,
					includeUnusedVariables = true,
				})
				waitForCompletion(
					execute(link, {
						query = sampleQuery,
						variables = variables,
						extensions = extensions,
					}),
					{
						next = function(_self, value)
							makeCallback(function()
								local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
								local method, body = options.method, options.body
								jestExpect(body).toBeUndefined()
								jestExpect(method).toBe("GET")
								jestExpect(uri).toBe(
									"/data?query=query%20SampleQuery%20%7B%0A%20%20stub%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&operationName=SampleQuery&variables=%7B%22params%22%3A%22stub%22%7D&extensions=%7B%22myExtension%22%3A%22foo%22%7D"
								)
							end)(value)
						end,
						error = function(_self, error_)
							return jestExpect(error_).toBeUndefined()
						end,
					}
				)
			end)

			it("supports using a GET request with search", function()
				local variables = { params = "stub" }

				local link = createHttpLink({ uri = "/data?foo=bar", fetchOptions = { method = "GET" } })

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), {
					next = function(_self, value)
						makeCallback(function()
							local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
							local method, body = options.method, options.body
							jestExpect(body).toBeUndefined()
							jestExpect(method).toBe("GET")
							jestExpect(uri).toBe(
								"/data?foo=bar&query=query%20SampleQuery%20%7B%0A%20%20stub%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&operationName=SampleQuery&variables=%7B%7D"
							)
						end)(value)
					end,
					error = function(_self, error_)
						return jestExpect(error_).toBeUndefined()
					end,
				})
			end)

			it("supports using a GET request on the context", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "/data" })

				waitForCompletion(
					execute(
						link,
						{ query = sampleQuery, variables = variables, context = { fetchOptions = { method = "GET" } } }
					),
					function(_self, value)
						makeCallback(function()
							local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
							local method, body = options.method, options.body
							jestExpect(body).toBeUndefined()
							jestExpect(method).toBe("GET")
							jestExpect(uri).toBe(
								"/data?query=query%20SampleQuery%20%7B%0A%20%20stub%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&operationName=SampleQuery&variables=%7B%7D"
							)
						end)(value)
					end
				)
			end)

			it("uses GET with useGETForQueries", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "/data", useGETForQueries = true })
				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
						local method, body = options.method, options.body
						jestExpect(body).toBeUndefined()
						jestExpect(method).toBe("GET")
						jestExpect(uri).toBe(
							"/data?query=query%20SampleQuery%20%7B%0A%20%20stub%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&operationName=SampleQuery&variables=%7B%7D"
						)
					end)(value)
				end)
			end)

			it("uses POST for mutations with useGETForQueries", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "/data", useGETForQueries = true })

				waitForCompletion(
					execute(link, { query = sampleMutation, variables = variables }),
					function(_self, value)
						makeCallback(function()
							local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
							local method, body = options.method, options.body
							jestExpect(body).toBeDefined()
							jestExpect(method).toBe("POST")
							jestExpect(uri).toBe("/data")
						end)(value)
					end
				)
			end)

			it("strips unused variables, respecting nested fragments", function()
				local link = createHttpLink({ uri = "/data" })
				local query = gql([[

        query PEOPLE (
          $declaredAndUsed: String,
          $declaredButUnused: Int,
        ) {
          people(
            surprise: $undeclared,
            noSurprise: $declaredAndUsed,
          ) {
            ... on Doctor {
              specialty(var: $usedByInlineFragment)
            }
            ...LawyerFragment
          }
        }
        fragment LawyerFragment on Lawyer {
          caseCount(var: $usedByNamedFragment)
        }
      ]])

				local variables = {
					unused = "strip",
					declaredButUnused = "strip",
					declaredAndUsed = "keep",
					undeclared = "keep",
					usedByInlineFragment = "keep",
					usedByNamedFragment = "keep",
				}
				waitForCompletion(execute(link, { query = query, variables = variables }), {
					next = function(_self, value)
						makeCallback(function()
							local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
							local method, body = options.method, options.body
							jestExpect(HttpService:JSONDecode(body :: string)).toEqual({
								operationName = "PEOPLE",
								query = print_(query),
								variables = {
									declaredAndUsed = "keep",
									undeclared = "keep",
									usedByInlineFragment = "keep",
									usedByNamedFragment = "keep",
								},
							})
							jestExpect(method).toBe("POST")
							jestExpect(uri).toBe("/data")
						end)
					end,
					error = function(_self, error_)
						return jestExpect(error_).toBeUndefined()
					end,
				})
			end)

			it("should add client awareness settings to request headers", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "/data" })
				local clientAwareness = { name = "Some Client Name", version = "1.0.1" }
				waitForCompletion(
					execute(
						link,
						{ query = sampleQuery, variables = variables, context = { clientAwareness = clientAwareness } }
					),
					function(_self, value)
						makeCallback(function()
							local options = table.unpack(fetchMock:lastCall(), 2, 2)
							local headers = options.headers
							jestExpect(headers["apollographql-client-name"]).toBeDefined()
							jestExpect(headers["apollographql-client-name"]).toEqual(clientAwareness.name)
							jestExpect(headers["apollographql-client-version"]).toBeDefined()
							jestExpect(headers["apollographql-client-version"]).toEqual(clientAwareness.version)
						end)(value)
					end
				)
			end)

			it("should not add empty client awareness settings to request headers", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "/data" })
				local hasOwn = hasOwnProperty
				local clientAwareness = {}
				waitForCompletion(
					execute(
						link,
						{ query = sampleQuery, variables = variables, context = { clientAwareness = clientAwareness } }
					),
					function(_self, value)
						makeCallback(function()
							local options = table.unpack(fetchMock:lastCall(), 2, 2)
							local headers = options.headers
							jestExpect(hasOwn(headers, "apollographql-client-name")).toBe(false)
							jestExpect(hasOwn(headers, "apollographql-client-version")).toBe(false)
						end)(value)
					end
				)
			end)

			it("throws for GET if the variables can't be stringified", function()
				local link = createHttpLink({ uri = "/data", useGETForQueries = true, includeUnusedVariables = true })

				local b
				local a: any = { b = b }
				b = { a = a }
				a.b = b
				local variables = { a = a, b = b }

				waitForCompletion(
					execute(link, { query = sampleQuery, variables = variables }),
					function(_self, _result)
						jestExpect("next should have been thrown from the link").toBeUndefined()
					end,
					function(_self, e)
						makeCallback(function(e: ClientParseError)
							jestExpect(e.message).toMatch(RegExp("Variables map is not serializable"))
							jestExpect(e.parseError.message).toMatch(RegExp("tables cannot be cyclic"))
						end)(e)
					end
				)
			end)

			it("throws for GET if the extensions can't be stringified", function()
				local link = createHttpLink({ uri = "/data", useGETForQueries = true, includeExtensions = true })
				local b
				local a: any = { b = b }
				b = { a = a }
				a.b = b
				local extensions = { a = a, b = b }

				waitForCompletion(
					execute(link, { query = sampleQuery, extensions = extensions }),
					function(_self, _result)
						jestExpect("next should have been thrown from the link").toBeUndefined()
					end,
					function(_self, e)
						makeCallback(function(e: ClientParseError)
							jestExpect(e.message).toMatch(RegExp("Extensions map is not serializable"))
							jestExpect(e.parseError.message).toMatch(RegExp("tables cannot be cyclic"))
						end)(e)
					end
				)
			end)

			it("raises warning if called with concat", function()
				local link = createHttpLink()
				local _warn = console.warn
				console.warn = function(warning: any)
					return jestExpect(warning["message"]).toBeDefined()
				end
				jestExpect(link:concat(function(_self, operation, forward)
					return forward(operation)
				end)).toEqual(link)
				console.warn = _warn
			end)

			it("does not need any constructor arguments_", function()
				jestExpect(function()
					return createHttpLink()
				end).never.toThrow()
			end)

			it("calls next and then complete", function()
				local next = jest.fn()
				local link = createHttpLink({ uri = "data" })
				local observable = execute(link, { query = sampleQuery })
				waitForCompletion(observable, {
					next = next,
					error = function(_self, error_)
						return jestExpect(error_).toBeUndefined()
					end,
					complete = function(_self)
						makeCallback(function()
							jestExpect(next).toHaveBeenCalledTimes(1)
						end)()
					end,
				})
			end)

			it("calls error when fetch fails", function()
				local link = createHttpLink({ uri = "error" })
				local observable = execute(link, { query = sampleQuery })
				waitForCompletion(observable, function(_self, _result)
					return jestExpect("next should not have been called").toBeUndefined()
				end, function(_self, error_)
					makeCallback(function(error_)
						jestExpect(error_).toEqual(mockError.throws)
					end)
				end, function(_self)
					return jestExpect("complete should not have been called").toBeUndefined()
				end)
			end)

			it("calls error when fetch fails_", function()
				local link = createHttpLink({ uri = "error" })
				local observable = execute(link, { query = sampleMutation })
				waitForCompletion(observable, function(_self, result)
					return jestExpect("next should not have been called").toBeUndefined()
				end, function(_self, e)
					makeCallback(function(error_)
						jestExpect(error_).toEqual(mockError.throws)
					end)(e)
				end, function(_self)
					return jestExpect("complete should not have been called").toBeUndefined()
				end)
			end)

			it("unsubscribes without calling subscriber", function()
				local link = createHttpLink({ uri = "data" })
				local observable = execute(link, { query = sampleQuery })
				local subscription = observable:subscribe({
					next = function(_self, _result)
						return jestExpect("next should not have been called").toBeUndefined()
					end,
					error = function(_self, error_)
						return jestExpect(error_).toBeUndefined()
					end,
					complete = function(_self)
						return jestExpect("complete should not have been called").toBeUndefined()
					end,
				})
				subscription:unsubscribe()
				jestExpect(subscription.closed).toBe(true)
				Promise.delay(50 / 1000):expect() -- ROBLOX deviation:  setTimeout(done, 50);
			end)

			local function verifyRequest(link: ApolloLink, after: () -> (), includeExtensions: boolean)
				local next = jest.fn()
				local context = { info = "stub" }
				local variables = { params = "stub" }
				local observable = execute(link, { query = sampleMutation, context = context, variables = variables })
				waitForCompletion(observable, {
					next = next,
					error = function(_self, error_)
						return jestExpect(error_).toBeUndefined()
					end,
					complete = function(_self)
						xpcall(function()
							local body = convertBatchedBody(fetchMock:lastCall()[2].body)
							jestExpect(body.query).toBe(print_(sampleMutation))
							jestExpect(body.variables).toEqual({})
							jestExpect(body.context).never.toBeDefined()
							if includeExtensions then
								jestExpect(body.extensions).toBeDefined()
							else
								jestExpect(body.extensions).never.toBeDefined()
							end
							jestExpect(next).toHaveBeenCalledTimes(1)
							after()
						end, function(e)
							jestExpect(e).toBeUndefined()
						end)
					end,
				})
			end

			it("passes all arguments to multiple fetch body including extensions", function()
				local link = createHttpLink({ uri = "data", includeExtensions = true })

				verifyRequest(link, function()
					return verifyRequest(link, function() end, true)
				end, true)
			end)

			it("passes all arguments to multiple fetch body excluding extensions", function()
				local link = createHttpLink({ uri = "data" })

				verifyRequest(link, function()
					return verifyRequest(link, function() end, false)
				end, false)
			end)

			it("calls multiple subscribers", function()
				local link = createHttpLink({ uri = "data" })
				local context = { info = "stub" }
				local variables = { params = "stub" }
				local observable = execute(link, { query = sampleMutation, context = context, variables = variables })
				observable:subscribe(subscriber)
				observable:subscribe(subscriber)
				Promise.new(function(resolve, reject)
					setTimeout(function()
						jestExpect(subscriber.next).toHaveBeenCalledTimes(2)
						jestExpect(subscriber.complete).toHaveBeenCalledTimes(2)
						jestExpect(subscriber.error).never.toHaveBeenCalled()
						resolve()
					end, 50)
				end):expect()
			end)

			it("calls remaining subscribers after unsubscribe", function()
				local link = createHttpLink({ uri = "data" })
				local context = { info = "stub" }
				local variables = { params = "stub" }

				local observable = execute(link, { query = sampleMutation, context = context, variables = variables })

				observable:subscribe(subscriber)

				setTimeout(function()
					local subscription = observable:subscribe(subscriber)
					subscription:unsubscribe()
				end, 10)

				Promise.delay(50 / 1000):expect() -- ROBLOX deviation:replaces setTimeout
				makeCallback(function()
					jestExpect(subscriber.next).toHaveBeenCalledTimes(1)
					jestExpect(subscriber.complete).toHaveBeenCalledTimes(1)
					jestExpect(subscriber.error).never.toHaveBeenCalled()
				end)()
			end)

			it("allows for dynamic endpoint setting", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "data" })
				waitForCompletion(
					execute(link, { query = sampleQuery, variables = variables, context = { uri = "data2" } }),
					function(_self, result)
						jestExpect(result).toEqual(data2)
					end
				)
			end)

			it("adds headers to the request from the context", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ headers = { authorization = "1234" } })
					return forward(operation):map(function(result)
						local headers
						do
							local ref = operation:getContext()
							headers = ref.headers
						end
						xpcall(function()
							jestExpect(headers).toBeDefined()
						end, function(e)
							jestExpect(e).toBeUndefined()
						end)
						return result
					end) :: any
				end)
				local link = middleware:concat(createHttpLink({ uri = "data" }))

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local headers = fetchMock:lastCall()[2].headers :: any
						jestExpect(headers.authorization).toBe("1234")
						jestExpect(headers["content-type"]).toBe("application/json")
						jestExpect(headers.accept).toBe("*/*")
					end)(value)
				end)
			end)

			it("adds headers to the request from the setup", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "data", headers = { authorization = "1234" } })

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local headers = fetchMock:lastCall()[2].headers :: any
						jestExpect(headers.authorization).toBe("1234")
						jestExpect(headers["content-type"]).toBe("application/json")
						jestExpect(headers.accept).toBe("*/*")
					end)(value)
				end)
			end)

			it("prioritizes context headers over setup headers", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ headers = { authorization = "1234" } })
					return forward(operation)
				end)
				local link =
					middleware:concat(createHttpLink({ uri = "data", headers = { authorization = "no user" } }))

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local headers = fetchMock:lastCall()[2].headers :: any
						jestExpect(headers.authorization).toBe("1234")
						jestExpect(headers["content-type"]).toBe("application/json")
						jestExpect(headers.accept).toBe("*/*")
					end)(value)
				end)
			end)

			it("adds headers to the request from the context on an operation", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "data" })
				local context = { headers = { authorization = "1234" } }

				waitForCompletion(
					execute(link, { query = sampleQuery, variables = variables, context = context }),
					function(_self, value)
						makeCallback(function()
							local headers = fetchMock:lastCall()[2].headers :: any
							jestExpect(headers.authorization).toBe("1234")
							jestExpect(headers["content-type"]).toBe("application/json")
							jestExpect(headers.accept).toBe("*/*")
						end)(value)
					end
				)
			end)

			it("adds creds to the request from the context", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ credentials = "same-team-yo" })
					return forward(operation)
				end)
				local link = middleware:concat(createHttpLink({ uri = "data" }))

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local creds = fetchMock:lastCall()[2].credentials
						jestExpect(creds).toBe("same-team-yo")
					end)(value)
				end)
			end)

			it("adds creds to the request from the setup", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "data", credentials = "same-team-yo" })

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local creds = fetchMock:lastCall()[2].credentials
						jestExpect(creds).toBe("same-team-yo")
					end)(value)
				end)
			end)

			it("prioritizes creds from the context over the setup", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ credentials = "same-team-yo" })
					return forward(operation)
				end)
				local link = middleware:concat(createHttpLink({ uri = "data", credentials = "error" }))

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local creds = fetchMock:lastCall()[2].credentials
						jestExpect(creds).toBe("same-team-yo")
					end)(value)
				end)
			end)

			it("adds uri to the request from the context", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ uri = "data" })
					return forward(operation)
				end)
				local link = middleware:concat(createHttpLink())

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local uri = fetchMock:lastUrl()
						jestExpect(uri).toBe("/data")
					end)(value)
				end)
			end)

			it("adds uri to the request from the setup", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "data" })
				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local uri = fetchMock:lastUrl()
						jestExpect(uri).toBe("/data")
					end)(value)
				end)
			end)

			it("prioritizes context uri over setup uri", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ uri = "apollo" })
					return forward(operation)
				end)
				local link = middleware:concat(createHttpLink({ uri = "data", credentials = "error" }))

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local uri = fetchMock:lastUrl()
						jestExpect(uri).toBe("/apollo")
					end)(value)
				end)
			end)

			it("allows uri to be a function", function()
				local variables = { params = "stub" }
				local function customFetch(uri, options)
					local operationName
					do
						local ref = convertBatchedBody(options.body)
						operationName = ref.operationName
					end
					xpcall(function()
						jestExpect(operationName).toBe("SampleQuery")
					end, function(e)
						jestExpect(false).toBe(true)
					end)

					return _G.fetch("dataFunc", options)
				end

				local link = createHttpLink({ fetch = customFetch })

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						jestExpect(fetchMock:lastUrl()).toBe("/dataFunc")
					end)(value)
				end)
			end)

			it("adds fetchOptions to the request from the setup", function()
				local variables = { params = "stub" }
				local link = createHttpLink({ uri = "data", fetchOptions = { someOption = "foo", mode = "no-cors" } })

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local someOption, mode, headers
						do
							local ref = fetchMock:lastCall()[2] :: any
							someOption, mode, headers = ref.someOption, ref.mode, ref.headers
						end
						jestExpect(someOption).toBe("foo")
						jestExpect(mode).toBe("no-cors")
						jestExpect(headers["content-type"]).toBe("application/json")
					end)(value)
				end)
			end)

			it("adds fetchOptions to the request from the context", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ fetchOptions = { someOption = "foo" } })
					return forward(operation)
				end)
				local link = middleware:concat(createHttpLink({ uri = "data" }))

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local someOption
						do
							local ref = fetchMock:lastCall()[2] :: any
							someOption = ref.someOption
						end
						jestExpect(someOption).toBe("foo")
					end)(value)
				end)
			end)

			it("prioritizes context over setup", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ fetchOptions = { someOption = "foo" } })
					return forward(operation)
				end)
				local link = middleware:concat(createHttpLink({ uri = "data", fetchOptions = { someOption = "bar" } }))

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local someOption
						do
							local ref = fetchMock:lastCall()[2] :: any
							someOption = ref.someOption
						end
						jestExpect(someOption).toBe("foo")
					end)(value)
				end)
			end)

			it("allows for not sending the query with the request", function()
				local variables = { params = "stub" }
				local middleware = ApolloLink.new(function(_self, operation, forward)
					operation:setContext({ http = { includeQuery = false, includeExtensions = true } })
					operation.extensions.persistedQuery = { hash = "1234" }
					return forward(operation)
				end)
				local link = middleware:concat(createHttpLink({ uri = "data" }))

				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, value)
					makeCallback(function()
						local body = convertBatchedBody(fetchMock:lastCall()[2].body)
						jestExpect(body.query).never.toBeDefined()
						jestExpect(body.extensions).toEqual({ persistedQuery = { hash = "1234" } })
					end)(value)
				end)
			end)

			it("sets the raw response on context", function()
				local middleware = ApolloLink.new(function(_self, operation, forward)
					return Observable.new(function(ob: any)
						local op = forward(operation)
						local sub = op:subscribe({
							next = function(_self, value)
								ob.next(ob, value)
							end,
							error = function(_self, e)
								ob.error(ob, e)
							end,
							complete = function(_self)
								makeCallback(function()
									jestExpect(operation:getContext().response.headers).toBeDefined()
									ob:complete()
								end)()
							end,
						})
						return function()
							sub:unsubscribe()
						end
					end :: Subscriber<any>) :: Observable<any>
				end)
				local link = middleware:concat(createHttpLink({ uri = "data", fetch = _G.fetch }))

				waitForCompletion(
					execute(link, { query = sampleQuery }),
					function(_self, result) end,
					function() end,
					function() end
				)
			end)
		end)

		describe("Dev warnings", function()
			voidFetchDuringEachTest()
			it("warns if fetch is undeclared", function()
				xpcall(function()
					createHttpLink({ uri = "data" })
					jestExpect(false).toBe(true)
				end, function(e)
					makeCallback(function()
						return jestExpect(e.message).toMatch(RegExp("has not been found globally"))
					end)()
				end)
			end)

			it("warns if fetch is undefined", function()
				xpcall(function()
					createHttpLink({ uri = "data" })
					jestExpect("warning wasn't called").toBeUndefined()
				end, function(e)
					makeCallback(function()
						return jestExpect(e.message).toMatch(RegExp("has not been found globally"))
					end)()
				end)
			end)

			it("does not warn if fetch is undeclared but a fetch is passed", function()
				jestExpect(function()
					createHttpLink({ uri = "data", fetch = function() end :: any })
				end).never.toThrow()
			end)
		end)

		describe("Error handling", function()
			local responseBody: any
			local text = jest.fn(function()
				local responseBodyText = "{}"
				responseBody = HttpService:JSONDecode(responseBodyText)
				return Promise.resolve(responseBodyText)
			end)
			local textWithData = jest.fn(function()
				responseBody = { data = { stub = { id = 1 } }, errors = { { message = "dangit" } } }
				return Promise.resolve(HttpService:JSONEncode(responseBody))
			end)
			local textWithErrors = jest.fn(function()
				responseBody = { errors = { { message = "dangit" } } }
				return Promise.resolve(HttpService:JSONEncode(responseBody))
			end)
			local fetch = jest.fn(function()
				return Promise.resolve({ text = text })
			end)

			beforeEach(function()
				fetch.mockReset()
			end)

			it("makes it easy to do stuff on a 401", function()
				local middleware = ApolloLink.new(function(_self, operation, forward)
					return Observable.new(function(ob: any)
						fetch.mockReturnValueOnce(Promise.resolve({ status = 401, text = text }))
						local op = forward(operation)
						local sub = op:subscribe({
							next = function(_self, value)
								ob.next(ob, value)
							end,
							error = function(_self, e)
								makeCallback(function(e: ServerError)
									jestExpect(e.message).toMatch(RegExp("Received status code 401"))
									jestExpect(e.statusCode).toEqual(401)
									ob:error(e)
								end)(e)
							end,
							complete = function(_self)
								ob.complete(ob)
							end,
						})
						return function()
							sub:unsubscribe()
						end
					end :: Subscriber<any>) :: Observable<any>
				end)
				local link = middleware:concat(createHttpLink({ uri = "data", fetch = fetch :: any }))

				waitForCompletion(execute(link, { query = sampleQuery }), function(result)
					jestExpect(false).toBe(true)
				end, function() end)
			end)

			it("throws an error if response code is > 300", function()
				fetch.mockReturnValueOnce(Promise.resolve({ status = 400, text = text }))
				local link = createHttpLink({ uri = "data", fetch = fetch :: any })

				waitForCompletion(execute(link, { query = sampleQuery }), function(_self, result)
					jestExpect(false).toBe(true)
				end, function(_self, e)
					makeCallback(function(e: ServerError)
						jestExpect(e.message).toMatch(RegExp("Received status code 400"))
						jestExpect(e.statusCode).toBe(400)
						jestExpect(e.result).toEqual(responseBody)
					end)(e)
				end)
			end)

			it("throws an error if response code is > 300 and returns data", function()
				fetch.mockReturnValueOnce(Promise.resolve({ status = 400, text = textWithData }))
				local link = createHttpLink({ uri = "data", fetch = fetch :: any })
				local called = false

				waitForCompletion(execute(link, { query = sampleQuery }), function(_self, result)
					called = true
					jestExpect(result).toEqual(responseBody)
				end, function(_self, e)
					jestExpect(called).toBe(true)
					jestExpect(e.message).toMatch(RegExp("Received status code 400"))
					jestExpect(e.statusCode).toBe(400)
					jestExpect(e.result).toEqual(responseBody)
				end)
			end)

			it("throws an error if only errors are returned", function()
				fetch.mockReturnValueOnce(Promise.resolve({ status = 400, text = textWithErrors }))
				local link = createHttpLink({ uri = "data", fetch = fetch :: any })

				waitForCompletion(execute(link, { query = sampleQuery }), function(_self, result)
					jestExpect("should not have called result because we have no data").toBeUndefined()
				end, function(_self, e)
					jestExpect(e.message).toMatch(RegExp("Received status code 400"))
					jestExpect(e.statusCode).toBe(400)
					jestExpect(e.result).toEqual(responseBody)
				end)
			end)

			it("throws an error if empty response from the server ", function()
				fetch.mockReturnValueOnce(Promise.resolve({ text = text }))
				text.mockReturnValueOnce(Promise.resolve('{ "body": "boo" }'))
				local link = createHttpLink({ uri = "data", fetch = fetch :: any })

				waitForCompletion(execute(link, { query = sampleQuery }), function(_self, result)
					jestExpect("next should have been thrown from the network").toBeUndefined()
				end, function(_self, e)
					makeCallback(function(e: Error)
						jestExpect(e.message).toMatch(RegExp("Server response was missing for query 'SampleQuery'"))
					end)(e)
				end)
			end)

			it("throws if the body can't be stringified", function()
				fetch.mockReturnValueOnce(Promise.resolve({ data = {}, text = text }))
				local link = createHttpLink({ uri = "data", fetch = fetch :: any, includeUnusedVariables = true })
				local b
				local a: any = { b = b }
				b = { a = a }
				a.b = b
				local variables = { a = a, b = b }
				waitForCompletion(execute(link, { query = sampleQuery, variables = variables }), function(_self, result)
					jestExpect("next should have been thrown from the link").toBeUndefined()
				end, function(_self, e)
					makeCallback(function(e: ClientParseError)
						jestExpect(e.message).toMatch(RegExp("Payload is not serializable"))
						jestExpect(e.parseError.message).toMatch(RegExp("tables cannot be cyclic"))
					end)(e)
				end)
			end)

			it("supports being cancelled and does not throw", function()
				local called = false
				type AbortController = { signal: any, abort: any }
				local AbortController = {}
				AbortController.__index = AbortController
				function AbortController.new()
					local self = setmetatable({ signal = {} }, AbortController)
					return self
				end

				function AbortController:abort()
					called = true
				end

				(_G :: any).AbortController = AbortController
				fetch.mockReturnValueOnce(Promise.resolve({ text = text }))
				text.mockReturnValueOnce(Promise.resolve('{ "data": { "hello": "world" } }'))
				local link = createHttpLink({ uri = "data", fetch = fetch :: any })
				local sub = execute(link, { query = sampleQuery }):subscribe({
					next = function(result)
						jestExpect("result should not have been called").toBeUndefined()
					end,
					["error"] = function(e)
						jestExpect(e).toBeUndefined()
					end,
					complete = function()
						jestExpect("complete should not have been called").toBeUndefined()
					end,
				})
				sub:unsubscribe()
				Promise.delay(150 / 1000):expect()
				makeCallback(function()
					(_G :: any).AbortController = nil
					jestExpect(called).toBe(true)
					fetch.mockReset()
					text.mockReset()
				end)()
			end)

			local body = "{"
			local unparsableJson = jest.fn(function()
				return Promise.resolve(body)
			end)

			it("throws an error if response is unparsable", function()
				fetch.mockReturnValueOnce(Promise.resolve({ status = 400, text = unparsableJson }))
				local link = createHttpLink({ uri = "data", fetch = fetch :: any })
				waitForCompletion(execute(link, { query = sampleQuery }), function(_self, result)
					jestExpect(false).toBe(true)
				end, function(_self, e)
					makeCallback(function(e: ServerParseError)
						jestExpect(e.message).toMatch(RegExp("JSON"))
						jestExpect(e.statusCode).toBe(400)
						jestExpect(e.response).toBeDefined()
						jestExpect(e.bodyText).toBe(body)
					end)(e)
				end)
			end)
		end)
	end)
end
