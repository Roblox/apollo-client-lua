-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/http/__tests__/HttpLink.ts

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

type FetchMock = {
	get: (self: FetchMock, url: string, response: any) -> (),
	post: (self: FetchMock, url: string, response: any) -> (),
	lastCall: (self: FetchMock) -> any,
	lastUrl: (self: FetchMock) -> string,
	restore: (self: FetchMock) -> (),
}

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest
type DoneFn = ((string | Error)?) -> ()

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

local voidFetchDuringEachTest = require(script.Parent.helpers).voidFetchDuringEachTest

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

local function makeCallback(done: any, body: (...any) -> ())
	return function(...)
		local args = { ... }
		local ok, res = pcall(function()
			body(table.unpack(args))
			done()
		end)
		if not ok then
			-- ROBLOX deviation START: using done(error) instead of done.fail(error)
			done(res)
			-- ROBLOX deviation END
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
			expect(function()
				return HttpLink.new()
			end).never.toThrow()
		end)

		it("constructor creates link that can call next and then complete", function(_, done)
			local next = jest.fn()
			local link = HttpLink.new({ uri = "/data" })
			local observable = execute(link, { query = sampleQuery })
			observable:subscribe({
				next = function(_self, value)
					next(value)
				end,
				error = function(_self, _error)
					return expect(false).toBeTruthy()
				end,
				complete = function()
					expect(next).toHaveBeenCalledTimes(1)
					done()
				end,
			})
		end)

		it("supports using a GET request", function(_, done)
			local variables = { params = "stub" }
			local extensions = { myExtension = "foo" }
			local link = createHttpLink({
				uri = "/data",
				fetchOptions = { method = "GET" },
				includeExtensions = true,
				includeUnusedVariables = true,
			})
			execute(link, {
				query = sampleQuery,
				variables = variables,
				extensions = extensions,
			}):subscribe({
				next = function(_self, value)
					makeCallback(done, function()
						local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
						local method, body = options.method, options.body
						expect(body).toBeUndefined()
						expect(method).toBe("GET")
						expect(uri).toBe(
							"/data?query=query%20SampleQuery%20%7B%0A%20%20stub%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&operationName=SampleQuery&variables=%7B%22params%22%3A%22stub%22%7D&extensions=%7B%22myExtension%22%3A%22foo%22%7D"
						)
					end)(value)
				end,
				error = function(_self, error_)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					return done(error_)
					-- ROBLOX deviation END
				end,
			})
		end)

		it("supports using a GET request with search", function(_, done)
			local variables = { params = "stub" }

			local link = createHttpLink({ uri = "/data?foo=bar", fetchOptions = { method = "GET" } })

			execute(link, { query = sampleQuery, variables = variables }):subscribe({
				next = function(_self, value)
					makeCallback(done, function()
						local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
						local method, body = options.method, options.body
						expect(body).toBeUndefined()
						expect(method).toBe("GET")
						expect(uri).toBe(
							"/data?foo=bar&query=query%20SampleQuery%20%7B%0A%20%20stub%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&operationName=SampleQuery&variables=%7B%7D"
						)
					end)(value)
				end,
				error = function(_self, error_)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					return done(error_)
					-- ROBLOX deviation END
				end,
			})
		end)

		it("supports using a GET request on the context", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "/data" })

			execute(
				link,
				{ query = sampleQuery, variables = variables, context = { fetchOptions = { method = "GET" } } }
			):subscribe(function(_self, value)
				makeCallback(done, function()
					local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
					local method, body = options.method, options.body
					expect(body).toBeUndefined()
					expect(method).toBe("GET")
					expect(uri).toBe(
						"/data?query=query%20SampleQuery%20%7B%0A%20%20stub%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&operationName=SampleQuery&variables=%7B%7D"
					)
				end)(value)
			end)
		end)

		it("uses GET with useGETForQueries", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "/data", useGETForQueries = true })
			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
					local method, body = options.method, options.body
					expect(body).toBeUndefined()
					expect(method).toBe("GET")
					expect(uri).toBe(
						"/data?query=query%20SampleQuery%20%7B%0A%20%20stub%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&operationName=SampleQuery&variables=%7B%7D"
					)
				end)(value)
			end)
		end)

		it("uses POST for mutations with useGETForQueries", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "/data", useGETForQueries = true })

			execute(link, { query = sampleMutation, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
					local method, body = options.method, options.body
					expect(body).toBeDefined()
					expect(method).toBe("POST")
					expect(uri).toBe("/data")
				end)(value)
			end)
		end)

		it("strips unused variables, respecting nested fragments", function(_, done)
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
			execute(link, { query = query, variables = variables }):subscribe({
				next = function(_self, value)
					makeCallback(done, function()
						local uri, options = table.unpack(fetchMock:lastCall(), 1, 2)
						local method, body = options.method, options.body
						expect(HttpService:JSONDecode(body :: string)).toEqual({
							operationName = "PEOPLE",
							query = print_(query),
							variables = {
								declaredAndUsed = "keep",
								undeclared = "keep",
								usedByInlineFragment = "keep",
								usedByNamedFragment = "keep",
							},
						})
						expect(method).toBe("POST")
						expect(uri).toBe("/data")
					end)(value)
				end,
				error = function(_self, error_)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					return done(error_)
					-- ROBLOX deviation END
				end,
			})
		end)

		it("should add client awareness settings to request headers", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "/data" })
			local clientAwareness = { name = "Some Client Name", version = "1.0.1" }

			execute(
				link,
				{ query = sampleQuery, variables = variables, context = { clientAwareness = clientAwareness } }
			):subscribe(function(_self, value)
				makeCallback(done, function()
					local options = table.unpack(fetchMock:lastCall(), 2, 2)
					local headers = options.headers
					expect(headers["apollographql-client-name"]).toBeDefined()
					expect(headers["apollographql-client-name"]).toEqual(clientAwareness.name)
					expect(headers["apollographql-client-version"]).toBeDefined()
					expect(headers["apollographql-client-version"]).toEqual(clientAwareness.version)
				end)(value)
			end)
		end)

		it("should not add empty client awareness settings to request headers", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "/data" })
			local hasOwn = hasOwnProperty
			local clientAwareness = {}

			execute(
				link,
				{ query = sampleQuery, variables = variables, context = { clientAwareness = clientAwareness } }
			):subscribe(function(_self, value)
				makeCallback(done, function()
					local options = table.unpack(fetchMock:lastCall(), 2, 2)
					local headers = options.headers
					expect(hasOwn(headers, "apollographql-client-name")).toBe(false)
					expect(hasOwn(headers, "apollographql-client-version")).toBe(false)
				end)(value)
			end)
		end)

		it("throws for GET if the variables can't be stringified", function(_, done)
			local link = createHttpLink({ uri = "/data", useGETForQueries = true, includeUnusedVariables = true })

			local b
			local a: any = { b = b }
			b = { a = a }
			a.b = b
			local variables = { a = a, b = b }

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, _result)
				expect("next should have been thrown from the link").toBeUndefined()
			end :: (...any) -> (), function(_self, e)
				makeCallback(done, function(e: ClientParseError)
					expect(e.message).toMatch(RegExp("Variables map is not serializable"))
					expect(e.parseError.message).toMatch(RegExp("tables cannot be cyclic"))
				end)(e)
			end)
		end)

		it("throws for GET if the extensions can't be stringified", function(_, done)
			local link = createHttpLink({ uri = "/data", useGETForQueries = true, includeExtensions = true })
			local b
			local a: any = { b = b }
			b = { a = a }
			a.b = b
			local extensions = { a = a, b = b }

			execute(link, { query = sampleQuery, extensions = extensions }):subscribe(function(_self, _result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("next should have been thrown from the link")
				-- ROBLOX deviation END
			end :: (...any) -> (), function(_self, e)
				makeCallback(done, function(e: ClientParseError)
					expect(e.message).toMatch(RegExp("Extensions map is not serializable"))
					expect(e.parseError.message).toMatch(RegExp("tables cannot be cyclic"))
				end)(e)
			end)
		end)

		it("raises warning if called with concat", function()
			local link = createHttpLink()
			local _warn = console.warn
			console.warn = function(warning: any)
				return expect(warning["message"]).toBeDefined()
			end
			expect(link:concat(function(_self, operation, forward)
				return forward(operation)
			end)).toEqual(link)
			console.warn = _warn
		end)

		it("does not need any constructor arguments_", function()
			expect(function()
				return createHttpLink()
			end).never.toThrow()
		end)

		it("calls next and then complete", function(_, done: DoneFn)
			local next = jest.fn()
			local link = createHttpLink({ uri = "data" })
			local observable = execute(link, { query = sampleQuery })
			observable:subscribe({
				next = next,
				error = function(_self, error_)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					return done(error_)
					-- ROBLOX deviation END
				end,
				complete = function(_self)
					makeCallback(done, function()
						expect(next).toHaveBeenCalledTimes(1)
					end)()
				end,
			})
		end)

		it("calls error when fetch fails", function(_, done)
			local link = createHttpLink({ uri = "error" })
			local observable = execute(link, { query = sampleQuery })
			observable:subscribe(function(_self, _result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				return done("next should not have been called")
				-- ROBLOX deviation END
			end :: (...any) -> (), function(_self, e)
				makeCallback(done, function(error_)
					expect(error_).toEqual(mockError.throws)
				end)(e)
			end, function(_self: any)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				return done("complete should not have been called")
				-- ROBLOX deviation END
			end)
		end)

		it("calls error when fetch fails_", function(_, done)
			local link = createHttpLink({ uri = "error" })
			local observable = execute(link, { query = sampleMutation })
			observable:subscribe(function(_self, result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				return done("next should not have been called")
				-- ROBLOX deviation END
			end :: (...any) -> (), function(_self, e)
				makeCallback(done, function(error_)
					expect(error_).toEqual(mockError.throws)
				end)(e)
			end, function(_self: any)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				return done("complete should not have been called")
				-- ROBLOX deviation END
			end)
		end)

		it("unsubscribes without calling subscriber", function(_, done)
			local link = createHttpLink({ uri = "data" })
			local observable = execute(link, { query = sampleQuery })
			local subscription = observable:subscribe({
				next = function(_self, _result)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					return done("next should not have been called")
					-- ROBLOX deviation END
				end,
				error = function(_self, error_)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					return done(error_)
					-- ROBLOX deviation END
				end,
				complete = function(_self)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					return done("complete should not have been called")
					-- ROBLOX deviation END
				end,
			})
			subscription:unsubscribe()
			expect(subscription.closed).toBe(true)
			setTimeout(done, 50)
		end)

		local function verifyRequest(link: ApolloLink, after: () -> (), includeExtensions: boolean, done: any)
			local next = jest.fn()
			local context = { info = "stub" }
			local variables = { params = "stub" }

			local observable = execute(link, { query = sampleMutation, context = context, variables = variables })
			observable:subscribe({
				next = next,
				error = function(_self, error_)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					return done(error_)
					-- ROBLOX deviation END
				end,
				complete = function(_self)
					xpcall(function()
						local body = convertBatchedBody(fetchMock:lastCall()[2].body)
						expect(body.query).toBe(print_(sampleMutation))
						expect(body.variables).toEqual({})
						expect(body.context).never.toBeDefined()
						if includeExtensions then
							expect(body.extensions).toBeDefined()
						else
							expect(body.extensions).never.toBeDefined()
						end
						expect(next).toHaveBeenCalledTimes(1)
						after()
					end, function(e)
						-- ROBLOX deviation START: using done(error) instead of done.fail(error)
						done(e)
						-- ROBLOX deviation END
					end)
				end,
			})
		end

		it("passes all arguments to multiple fetch body including extensions", function(_, done)
			local link = createHttpLink({ uri = "data", includeExtensions = true })

			verifyRequest(link, function()
				return verifyRequest(link, done, true, done)
			end, true, done)
		end)

		it("passes all arguments to multiple fetch body excluding extensions", function(_, done)
			local link = createHttpLink({ uri = "data" })

			verifyRequest(link, function()
				return verifyRequest(link, done, false, done)
			end, false, done)
		end)

		it("calls multiple subscribers", function(_, done)
			local link = createHttpLink({ uri = "data" })
			local context = { info = "stub" }
			local variables = { params = "stub" }
			local observable = execute(link, { query = sampleMutation, context = context, variables = variables })
			observable:subscribe(subscriber)
			observable:subscribe(subscriber)

			setTimeout(function()
				expect(subscriber.next).toHaveBeenCalledTimes(2)
				expect(subscriber.complete).toHaveBeenCalledTimes(2)
				expect(subscriber.error).never.toHaveBeenCalled()
				done()
			end, 50)
		end)

		it("calls remaining subscribers after unsubscribe", function(_, done)
			local link = createHttpLink({ uri = "data" })
			local context = { info = "stub" }
			local variables = { params = "stub" }

			local observable = execute(link, { query = sampleMutation, context = context, variables = variables })

			observable:subscribe(subscriber)

			setTimeout(function()
				local subscription = observable:subscribe(subscriber)
				subscription:unsubscribe()
			end, 10)

			setTimeout(
				makeCallback(done, function()
					expect(subscriber.next).toHaveBeenCalledTimes(1)
					expect(subscriber.complete).toHaveBeenCalledTimes(1)
					expect(subscriber.error).never.toHaveBeenCalled()
					-- done()
				end),
				50
			)
		end)

		it("allows for dynamic endpoint setting", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "data" })

			execute(link, { query = sampleQuery, variables = variables, context = { uri = "data2" } }):subscribe(
				function(_self, result)
					expect(result).toEqual(data2)
					done()
				end
			)
		end)

		it("adds headers to the request from the context", function(_, done: DoneFn)
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
						expect(headers).toBeDefined()
					end, function(e)
						-- ROBLOX deviation START: using done(error) instead of done.fail(error)
						done(e)
						-- ROBLOX deviation END
					end)
					return result
				end) :: any
			end)
			local link = middleware:concat(createHttpLink({ uri = "data" }))

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local headers = fetchMock:lastCall()[2].headers :: any
					expect(headers.authorization).toBe("1234")
					expect(headers["content-type"]).toBe("application/json")
					expect(headers.accept).toBe("*/*")
				end)(value)
			end)
		end)

		it("adds headers to the request from the setup", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "data", headers = { authorization = "1234" } })

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local headers = fetchMock:lastCall()[2].headers :: any
					expect(headers.authorization).toBe("1234")
					expect(headers["content-type"]).toBe("application/json")
					expect(headers.accept).toBe("*/*")
				end)(value)
			end)
		end)

		it("prioritizes context headers over setup headers", function(_, done)
			local variables = { params = "stub" }
			local middleware = ApolloLink.new(function(_self, operation, forward)
				operation:setContext({ headers = { authorization = "1234" } })
				return forward(operation)
			end)
			local link = middleware:concat(createHttpLink({ uri = "data", headers = { authorization = "no user" } }))

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local headers = fetchMock:lastCall()[2].headers :: any
					expect(headers.authorization).toBe("1234")
					expect(headers["content-type"]).toBe("application/json")
					expect(headers.accept).toBe("*/*")
				end)(value)
			end)
		end)

		it("adds headers to the request from the context on an operation", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "data" })
			local context = { headers = { authorization = "1234" } }

			execute(link, { query = sampleQuery, variables = variables, context = context }):subscribe(
				function(_self, value)
					makeCallback(done, function()
						local headers = fetchMock:lastCall()[2].headers :: any
						expect(headers.authorization).toBe("1234")
						expect(headers["content-type"]).toBe("application/json")
						expect(headers.accept).toBe("*/*")
					end)(value)
				end
			)
		end)

		it("adds creds to the request from the context", function(_, done)
			local variables = { params = "stub" }
			local middleware = ApolloLink.new(function(_self, operation, forward)
				operation:setContext({ credentials = "same-team-yo" })
				return forward(operation)
			end)
			local link = middleware:concat(createHttpLink({ uri = "data" }))

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local creds = fetchMock:lastCall()[2].credentials
					expect(creds).toBe("same-team-yo")
				end)(value)
			end)
		end)

		it("adds creds to the request from the setup", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "data", credentials = "same-team-yo" })

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local creds = fetchMock:lastCall()[2].credentials
					expect(creds).toBe("same-team-yo")
				end)(value)
			end)
		end)

		it("prioritizes creds from the context over the setup", function(_, done)
			local variables = { params = "stub" }
			local middleware = ApolloLink.new(function(_self, operation, forward)
				operation:setContext({ credentials = "same-team-yo" })
				return forward(operation)
			end)
			local link = middleware:concat(createHttpLink({ uri = "data", credentials = "error" }))

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local creds = fetchMock:lastCall()[2].credentials
					expect(creds).toBe("same-team-yo")
				end)(value)
			end)
		end)

		it("adds uri to the request from the context", function(_, done)
			local variables = { params = "stub" }
			local middleware = ApolloLink.new(function(_self, operation, forward)
				operation:setContext({ uri = "data" })
				return forward(operation)
			end)
			local link = middleware:concat(createHttpLink())

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local uri = fetchMock:lastUrl()
					expect(uri).toBe("/data")
				end)(value)
			end)
		end)

		it("adds uri to the request from the setup", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "data" })
			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local uri = fetchMock:lastUrl()
					expect(uri).toBe("/data")
				end)(value)
			end)
		end)

		it("prioritizes context uri over setup uri", function(_, done)
			local variables = { params = "stub" }
			local middleware = ApolloLink.new(function(_self, operation, forward)
				operation:setContext({ uri = "apollo" })
				return forward(operation)
			end)
			local link = middleware:concat(createHttpLink({ uri = "data", credentials = "error" }))

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local uri = fetchMock:lastUrl()
					expect(uri).toBe("/apollo")
				end)(value)
			end)
		end)

		it("allows uri to be a function", function(_, done: DoneFn)
			local variables = { params = "stub" }
			local function customFetch(uri, options)
				local operationName = convertBatchedBody(options.body).operationName
				xpcall(function()
					expect(operationName).toBe("SampleQuery")
				end, function(e)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					done(e)
					-- ROBLOX deviation END
				end)

				return _G.fetch("dataFunc", options)
			end

			local link = createHttpLink({ fetch = customFetch })

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					expect(fetchMock:lastUrl()).toBe("/dataFunc")
				end)(value)
			end)
		end)

		it("adds fetchOptions to the request from the setup", function(_, done)
			local variables = { params = "stub" }
			local link = createHttpLink({ uri = "data", fetchOptions = { someOption = "foo", mode = "no-cors" } })

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local someOption, mode, headers
					do
						local ref = fetchMock:lastCall()[2] :: any
						someOption, mode, headers = ref.someOption, ref.mode, ref.headers
					end
					expect(someOption).toBe("foo")
					expect(mode).toBe("no-cors")
					expect(headers["content-type"]).toBe("application/json")
				end)(value)
			end)
		end)

		it("adds fetchOptions to the request from the context", function(_, done)
			local variables = { params = "stub" }
			local middleware = ApolloLink.new(function(_self, operation, forward)
				operation:setContext({ fetchOptions = { someOption = "foo" } })
				return forward(operation)
			end)
			local link = middleware:concat(createHttpLink({ uri = "data" }))

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local someOption = (fetchMock:lastCall()[2] :: any).someOption
					expect(someOption).toBe("foo")
					-- done()
				end)(value)
			end)
		end)

		it("prioritizes context over setup", function(_, done)
			local variables = { params = "stub" }
			local middleware = ApolloLink.new(function(_self, operation, forward)
				operation:setContext({ fetchOptions = { someOption = "foo" } })
				return forward(operation)
			end)
			local link = middleware:concat(createHttpLink({ uri = "data", fetchOptions = { someOption = "bar" } }))

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local someOption
					do
						local ref = fetchMock:lastCall()[2] :: any
						someOption = ref.someOption
					end
					expect(someOption).toBe("foo")
				end)(value)
			end)
		end)

		it("allows for not sending the query with the request", function(_, done)
			local variables = { params = "stub" }
			local middleware = ApolloLink.new(function(_self, operation, forward)
				operation:setContext({ http = { includeQuery = false, includeExtensions = true } })
				operation.extensions.persistedQuery = { hash = "1234" }
				return forward(operation)
			end)
			local link = middleware:concat(createHttpLink({ uri = "data" }))

			execute(link, { query = sampleQuery, variables = variables }):subscribe(function(_self, value)
				makeCallback(done, function()
					local body = convertBatchedBody(fetchMock:lastCall()[2].body)
					expect(body.query).never.toBeDefined()
					expect(body.extensions).toEqual({ persistedQuery = { hash = "1234" } })
					-- done()
				end)(value)
			end)
		end)

		it("sets the raw response on context", function(_, done)
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
							makeCallback(done, function()
								expect(operation:getContext().response.headers).toBeDefined()
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

			execute(link, { query = sampleQuery }):subscribe(function(_self: any, result: any)
				-- ROBLOX deviation START: seems to be an error upstream, expectation in makeCallback is not properly defined, skipping done() otherwise is called twice
				-- done()
				-- ROBLOX deviation END
			end, function() end)
		end)
	end)

	describe("Dev warnings", function()
		voidFetchDuringEachTest()

		it("warns if fetch is undeclared", function(_, done)
			xpcall(function()
				createHttpLink({ uri = "data" })
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("warning wasn't called")
				-- ROBLOX deviation END
			end, function(e)
				makeCallback(done, function()
					return expect(e.message).toMatch(RegExp("has not been found globally"))
				end)()
			end)
		end)

		it("warns if fetch is undefined", function(_, done)
			xpcall(function()
				createHttpLink({ uri = "data" })
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("warning wasn't called")
				-- ROBLOX deviation END
			end, function(e)
				makeCallback(done, function()
					return expect(e.message).toMatch(RegExp("has not been found globally"))
				end)()
			end)
		end)

		it("does not warn if fetch is undeclared but a fetch is passed", function()
			expect(function()
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

		it("makes it easy to do stuff on a 401", function(_, done)
			local middleware = ApolloLink.new(function(_self, operation, forward)
				return Observable.new(function(ob: any)
					fetch.mockReturnValueOnce(Promise.resolve({ status = 401, text = text }))
					local op = forward(operation)
					local sub = op:subscribe({
						next = function(_self, value)
							ob.next(ob, value)
						end,
						error = function(_self, e)
							makeCallback(done, function(e: ServerError)
								expect(e.message).toMatch(RegExp("Received status code 401"))
								expect(e.statusCode).toEqual(401)
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

			execute(link, { query = sampleQuery }):subscribe(function(result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("next should have been thrown from the network")
				-- ROBLOX deviation END
			end, function() end)
		end)

		it("throws an error if response code is > 300", function(_, done)
			fetch.mockReturnValueOnce(Promise.resolve({ status = 400, text = text }))
			local link = createHttpLink({ uri = "data", fetch = fetch :: any })

			execute(link, { query = sampleQuery } :: any):subscribe(function(_self, result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("next should have been thrown from the network")
				-- ROBLOX deviation END
			end :: (...any) -> (), function(_self, e)
				makeCallback(done, function(e: ServerError)
					expect(e.message).toMatch(RegExp("Received status code 400"))
					expect(e.statusCode).toBe(400)
					expect(e.result).toEqual(responseBody)
				end)(e)
			end)
		end)

		it("throws an error if response code is > 300 and returns data", function(_, done)
			fetch.mockReturnValueOnce(Promise.resolve({ status = 400, text = textWithData }))
			local link = createHttpLink({ uri = "data", fetch = fetch :: any })
			local called = false

			execute(link, { query = sampleQuery }):subscribe(function(_self, result)
				called = true
				expect(result).toEqual(responseBody)
			end, function(_self: any, e: any)
				expect(called).toBe(true)
				expect(e.message).toMatch(RegExp("Received status code 400"))
				expect(e.statusCode).toBe(400)
				expect(e.result).toEqual(responseBody)
				done()
			end)
		end)

		it("throws an error if only errors are returned", function(_, done: DoneFn)
			fetch.mockReturnValueOnce(Promise.resolve({ status = 400, text = textWithErrors }))
			local link = createHttpLink({ uri = "data", fetch = fetch :: any })

			execute(link, { query = sampleQuery }):subscribe(function(_self, result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("should not have called result because we have no data")
				-- ROBLOX deviation END
			end :: (...any) -> (), function(_self, e)
				expect(e.message).toMatch(RegExp("Received status code 400"))
				expect(e.statusCode).toBe(400)
				expect(e.result).toEqual(responseBody)
				done()
			end :: (...any) -> ())
		end)

		it("throws an error if empty response from the server ", function(_, done)
			fetch.mockReturnValueOnce(Promise.resolve({ text = text }))
			text.mockReturnValueOnce(Promise.resolve('{ "body": "boo" }'))
			local link = createHttpLink({ uri = "data", fetch = fetch :: any })

			execute(link, { query = sampleQuery }):subscribe(function(_self, result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("next should have been thrown from the network")
				-- ROBLOX deviation END
			end :: (...any) -> (), function(_self, e)
				makeCallback(done, function(e: Error)
					expect(e.message).toMatch(RegExp("Server response was missing for query 'SampleQuery'"))
				end)(e)
			end)
		end)

		it("throws if the body can't be stringified", function(_, done: any)
			fetch.mockReturnValueOnce(Promise.resolve({ data = {}, text = text }))
			local link = createHttpLink({ uri = "data", fetch = fetch :: any, includeUnusedVariables = true })
			local b
			local a: any = { b = b }
			b = { a = a }
			a.b = b
			local variables = { a = a, b = b }
			execute(link, { query = sampleQuery, variables = variables } :: any):subscribe(function(_self, result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("next should have been thrown from the link")
				-- ROBLOX deviation END
			end :: (...any) -> (), function(_self, e)
				makeCallback(done, function(e: ClientParseError)
					expect(e.message).toMatch(RegExp("Payload is not serializable"))
					expect(e.parseError.message).toMatch(RegExp("tables cannot be cyclic"))
				end)(e)
			end)
		end)

		it("supports being cancelled and does not throw", function(_, done)
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
			local sub = execute(link, { query = sampleQuery } :: any):subscribe({
				next = function(_self, _result)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					done("result should not have been called")
					-- ROBLOX deviation END
				end,
				error = function(_self, e)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					done(e)
					-- ROBLOX deviation END
				end,
				complete = function(_self)
					-- ROBLOX deviation START: using done(error) instead of done.fail(error)
					done("complete should not have been called")
					-- ROBLOX deviation END
				end,
			})
			sub:unsubscribe()
			setTimeout(
				makeCallback(done, function()
					(_G :: any).AbortController = nil
					expect(called).toBe(true)
					fetch.mockReset()
					text.mockReset()
				end),
				150
			)
		end)

		local body = "{"
		local unparsableJson = jest.fn(function()
			return Promise.resolve(body)
		end)

		it("throws an error if response is unparsable", function(_, done: any)
			fetch.mockReturnValueOnce(Promise.resolve({ status = 400, text = unparsableJson }))
			local link = createHttpLink({ uri = "data", fetch = fetch :: any })
			execute(link, { query = sampleQuery }):subscribe(function(_self, result)
				-- ROBLOX deviation START: using done(error) instead of done.fail(error)
				done("next should have been thrown from the network")
				-- ROBLOX deviation END
			end :: (...any) -> (), function(_self, e)
				makeCallback(done, function(e: ServerParseError)
					expect(e.message).toMatch(RegExp("JSON"))
					expect(e.statusCode).toBe(400)
					expect(e.response).toBeDefined()
					expect(e.bodyText).toBe(body)
				end)(e)
			end)
		end)
	end)
end)

return {}
