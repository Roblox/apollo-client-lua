--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/core/__tests__/ApolloLink.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array, Boolean, console, Error, Object =
	LuauPolyfill.Array, LuauPolyfill.Boolean, LuauPolyfill.console, LuauPolyfill.Error, LuauPolyfill.Object

type Array<T> = LuauPolyfill.Array<T>
type Record<T, U> = { [T]: U }

local HttpService = game:GetService("HttpService")

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterAll = JestGlobals.afterAll
local beforeAll = JestGlobals.beforeAll
local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest

local gql = require(rootWorkspace.GraphQLTag).default
local graphQLModule = require(rootWorkspace.GraphQL)
local print_ = graphQLModule.print
local observableModule = require(srcWorkspace.utilities.observables.Observable)
local Observable = observableModule.Observable
type Observable<T> = observableModule.Observable<T>
type Subscriber<T> = observableModule.Subscriber<T>
local typesModule = require(script.Parent.Parent.types)
type FetchResult<TData, C, E> = typesModule.FetchResult<TData, C, E>
type Operation = typesModule.Operation
type NextLink = typesModule.NextLink
type GraphQLRequest = typesModule.GraphQLRequest

--ROBLOX comment: imported to make type checker happy
type RequestHandler = typesModule.RequestHandler

local apolloLinkModule = require(script.Parent.Parent.ApolloLink)
local ApolloLink = apolloLinkModule.ApolloLink
type ApolloLink = apolloLinkModule.ApolloLink
type DocumentNode = graphQLModule.DocumentNode

local SetContextLink = setmetatable({}, { __index = ApolloLink })
SetContextLink.__index = SetContextLink

type SetContextLink = ApolloLink

function SetContextLink.new(
	setContext: ((self: SetContextLink, context: Record<string, any>) -> Record<string, any>)?
): SetContextLink
	if setContext == nil then
		setContext = function(_self, c)
			return c
		end
	end

	local self: any = ApolloLink.new()
	self.setContext = setContext
	return (setmetatable(self, SetContextLink) :: any) :: SetContextLink
end

function SetContextLink:request(operation: Operation, forward: NextLink): Observable<FetchResult<any, any, any>>
	operation:setContext(self:setContext(operation:getContext()))
	return forward(operation)
end

local sampleQuery = gql([[

		query SampleQuery {
			stub {
		  		id
			}
	  	}
	]])

local function checkCalls(calls: Array<any>, results: Array<any>)
	if calls == nil then
		calls = {}
	end
	expect(#calls).toBe(#results)
	Array.map(calls, function(call: any, i: number)
		return expect(call.data).toEqual(results[i])
	end)
end

type TestResultType = {
	link: ApolloLink,
	results: Array<any>?,
	query: DocumentNode?,
	done: (() -> ())?,
	context: any?,
	variables: any?,
}

local function testLinkResults(params: TestResultType)
	local link, context, variables = params.link, params.context, params.variables
	local results: Array<any> = (Boolean.toJSBoolean(params.results) and params.results or {}) :: any
	local query = (if Boolean.toJSBoolean(params.query) then params.query else sampleQuery) :: DocumentNode
	local done = (
		if Boolean.toJSBoolean(params.done)
			then params.done
			else function()
				return nil
			end
	) :: (...any) -> ()

	local spy = jest.fn()
	ApolloLink.execute(link, { query = query, context = context, variables = variables }):subscribe({
		next = function(_self, v)
			spy(v)
		end,
		error = function(_self, error_)
			local result = table.remove(results, #results)
			expect(error_).toEqual(result)
			checkCalls(spy.mock.calls[1], results)
			if done then
				done()
			end
		end,
		complete = function(_self)
			checkCalls(spy.mock.calls[1], results)
			if done then
				done()
			end
		end,
	})
end

local function setContext()
	return { add = 1 }
end

describe("ApolloClient", function()
	describe("context", function()
		it("should merge context when using a function", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local mock = ApolloLink.new(function(self: any, op: Operation, forward: NextLink)
				op:setContext(function(context_: Record<string, any>): Record<string, any>
					local context = context_ :: { add: number }
					return { add = context.add + 2 }
				end)
				op:setContext(function()
					return { substract = 1 }
				end)
				return forward(op)
			end)
			local link = (returnOne:concat(mock)):concat(function(self, op)
				expect(op:getContext()).toEqual({ add = 3, substract = 1 })
				return Observable.of({ data = op:getContext().add })
			end)
			testLinkResults({ link = link, results = { 3 }, done = done })
		end)

		it("should merge context when not using a function", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local mock = ApolloLink.new(function(self, op: Operation, forward: NextLink)
				op:setContext({ add = 3 })
				op:setContext({ substract = 1 } :: any)
				return forward(op)
			end)
			local link = returnOne:concat(mock):concat(function(self, op)
				expect(op:getContext()).toEqual({ add = 3, substract = 1 })
				return Observable.of({ data = op:getContext().add })
			end)
			testLinkResults({ link = link, results = { 3 }, done = done })
		end)
	end)

	describe("concat", function()
		it("should concat a function", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local link = returnOne:concat(function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = { count = operation:getContext().add } })
			end)
			testLinkResults({ link = link, results = { { count = 1 } }, done = done })
		end)

		it("should concat a Link", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local mock = ApolloLink.new(function(_self, op: Operation)
				return Observable.of({ data = op:getContext().add })
			end)
			local link = returnOne:concat(mock)
			testLinkResults({ link = link, results = { 1 }, done = done })
		end)

		it("should pass error to observable's error", function(_, done)
			local error_ = Error.new("thrown")
			local returnOne = SetContextLink.new(setContext)
			local mock = ApolloLink.new(function(_self, op: Operation)
				return Observable.new(function(observer)
					observer:next({ data = op:getContext().add })
					observer:error(error_)
				end) :: Observable<any>
			end)
			local link = returnOne:concat(mock)
			-- ROBLOX FIXME: Luau needs to stop insisting that mixed arrays can't exist
			testLinkResults({ link = link, results = { 1, error_ :: any }, done = done })
		end)

		it("should concat a Link and function", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local mock = ApolloLink.new(function(_self, op: Operation, forward: NextLink)
				op:setContext(function(context_: Record<string, any>): Record<string, any>
					local context = context_ :: { add: number }
					return { add = context.add + 2 }
				end)
				return forward(op)
			end)
			local link = returnOne:concat(mock):concat(function(_self, op: Operation)
				return Observable.of({ data = op:getContext().add })
			end)
			testLinkResults({ link = link, results = { 3 }, done = done })
		end)

		it("should concat a function and Link", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local mock = ApolloLink.new(function(_self, op: Operation, forward: NextLink)
				return Observable.of({ data = op:getContext().add })
			end)
			local link = returnOne
				:concat(function(_self, operation: Operation, forward: NextLink)
					operation:setContext({ add = (operation:getContext().add :: number) + 2 })
					return forward(operation)
				end)
				:concat(mock)
			testLinkResults({ link = link, results = { 3 }, done = done })
		end)

		it("should concat two functions", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local link = returnOne
				:concat(function(_self, operation: Operation, forward: NextLink)
					operation:setContext({ add = (operation:getContext().add :: number) + 2 })
					return forward(operation)
				end)
				:concat(function(_self, op: Operation, forward: NextLink)
					return Observable.of({ data = op:getContext().add })
				end)
			testLinkResults({ link = link, results = { 3 }, done = done })
		end)

		it("should concat two Links", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local mock1 = ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
				operation:setContext({ add = (operation:getContext().add :: number) + 2 })
				return forward(operation)
			end)
			local mock2 = ApolloLink.new(function(_self, op: Operation, forward: NextLink)
				return Observable.of({ data = op:getContext().add })
			end)
			local link = returnOne:concat(mock1):concat(mock2)
			testLinkResults({ link = link, results = { 3 }, done = done })
		end)

		it("should return an link that can be concat'd multiple times", function(_, done)
			local returnOne = SetContextLink.new(setContext)
			local mock1 = ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
				operation:setContext({ add = (operation:getContext().add :: number) + 2 })
				return forward(operation)
			end)
			local mock2 = ApolloLink.new(function(_self, op: Operation, forward: NextLink)
				return Observable.of({ data = (op:getContext().add :: number) + 2 })
			end)
			local mock3 = ApolloLink.new(function(_self, op: Operation, forward: NextLink)
				return Observable.of({ data = (op:getContext().add :: number) + 3 })
			end)
			local link = returnOne:concat(mock1)
			testLinkResults({ link = link:concat(mock2), results = { 5 } })
			testLinkResults({ link = link:concat(mock3), results = { 6 }, done = done })
		end)
	end)

	describe("empty", function()
		it("should returns an immediately completed Observable", function(_, done)
			testLinkResults({ link = ApolloLink.empty(), done = done })
		end)
	end)

	describe("execute", function()
		it("transforms an opearation with context into something serlizable", function(_, done)
			local query = gql([[

					{
				  		id
					}
				]])

			local link = ApolloLink.new(function(_self, operation)
				local str = HttpService:JSONEncode(Object.assign({}, operation, { query = print_(operation.query) }))
				expect(str).toBe(HttpService:JSONEncode({
					variables = { id = 1 },
					extensions = { cache = true },
					query = print_(operation.query),
				}))
				return Observable.of()
			end)
			local function noop(...: any): () end
			ApolloLink.execute(link, { query = query, variables = { id = 1 }, extensions = { cache = true } })
				:subscribe(noop, noop, function(_self)
					done()
				end :: (...any) -> ())
		end)

		describe("execute", function()
			local _warn: ((message: any?, ...any) -> ())
			beforeEach(function()
				_warn = console.warn
				console.warn = jest.fn(function(warning)
					expect(warning).toBe("query should either be a string or GraphQL AST")
				end)
			end)

			afterEach(function()
				console.warn = _warn
			end)

			it("should return an empty observable when a link returns null", function(_, done)
				local link = ApolloLink.new()
				link.request = function(_self)
					return nil
				end
				testLinkResults({ link = link, results = {}, done = done })
			end)

			it("should return an empty observable when a link is empty", function(_, done)
				testLinkResults({ link = ApolloLink.empty(), results = {}, done = done })
			end)

			it("should return an empty observable when a concat'd link returns null", function(_, done)
				local link = ApolloLink.new(function(_self, operation, forward)
					return forward(operation)
				end):concat(function(_self)
					return nil
				end)
				testLinkResults({ link = link, results = {}, done = done })
			end)

			it("should return an empty observable when a split link returns null", function(_, done)
				local context = { test = true }
				local link = SetContextLink.new(function(_self)
					return context
				end):split(function(op: Operation)
					return op:getContext().test
				end, function(_self)
					return Observable.of()
				end, function(_self)
					return nil
				end)
				testLinkResults({ link = link, results = {} })
				context.test = false
				testLinkResults({ link = link, results = {}, done = done })
			end)

			it("should set a default context, variable, and query on a copy of operation", function(_, done)
				local operation = {
					query = gql([[

							{
							  id
							}
						]]),
				}
				local link = ApolloLink.new(function(self, op: Operation)
					expect((operation :: any)["operationName"]).toBeUndefined()
					expect((operation :: any)["variables"]).toBeUndefined()
					expect((operation :: any)["context"]).toBeUndefined()
					expect((operation :: any)["extensions"]).toBeUndefined()
					expect(op["variables"]).toBeDefined()
					expect((op :: any)["context"]).toBeUndefined()
					expect(op["extensions"]).toBeDefined()
					return Observable.of()
				end)

				ApolloLink.execute(link, operation):subscribe({
					complete = function(_self)
						done()
					end,
				})
			end)
		end)
	end)

	describe("from", function()
		local uniqueOperation: GraphQLRequest = {
			query = sampleQuery,
			context = { name = "uniqueName" },
			operationName = "SampleQuery",
			extensions = {},
		}

		it("should create an observable that completes when passed an empty array", function(_, done)
			local observable = ApolloLink.execute(ApolloLink.from({}), { query = sampleQuery })
			observable:subscribe(function()
				return expect(false)
			end, function()
				return expect(false)
			end, function()
				done()
			end)
		end)

		it("can create chain of one", function()
			expect(function()
				return ApolloLink.from({ ApolloLink.new() })
			end).never.toThrow()
		end)

		it("can create chain of two", function()
			expect(function()
				return ApolloLink.from({
					ApolloLink.new(function(self, operation, forward)
						return forward(operation)
					end),
					ApolloLink.new(),
				})
			end).never.toThrow()
		end)

		it("should receive result of one link", function(_, done)
			local data: FetchResult<any, any, any> = { data = { hello = "world" } }
			local chain = ApolloLink.from({
				ApolloLink.new(function(self)
					return Observable.of(data)
				end),
			})
			-- Smoke tests execute as a static method
			local observable = ApolloLink.execute(chain, uniqueOperation)
			observable:subscribe({
				next = function(self, actualData)
					expect(data).toEqual(actualData)
				end,
				error = function(self, e)
					error(Error.new(nil))
				end,
				complete = function()
					done()
				end,
			})
		end)

		it("should accept AST query and pass AST to link", function()
			local astOperation = Object.assign({}, uniqueOperation, { query = sampleQuery })
			local stub = jest.fn()
			local chain = ApolloLink.from({ ApolloLink.new(function(self, op)
				return stub(op)
			end) })
			ApolloLink.execute(chain, astOperation)
			expect(stub).toBeCalledWith({
				query = sampleQuery,
				operationName = "SampleQuery",
				variables = {},
				extensions = {},
			})
		end)

		it("should pass operation from one link to next with modifications", function(_, done)
			local chain = ApolloLink.from({
				ApolloLink.new(function(self, op, forward)
					return forward(Object.assign({}, op, { query = sampleQuery }))
				end),
				ApolloLink.new(function(self, op)
					expect({
						extensions = {},
						operationName = "SampleQuery",
						query = sampleQuery,
						variables = {},
					}).toEqual(op)
					return done()
				end),
			})
			ApolloLink.execute(chain, uniqueOperation)
		end)

		it("should pass result of one link to another with forward", function(_, done)
			local data: FetchResult<any, any, any> = { data = { hello = "world" } }

			local chain = ApolloLink.from({
				ApolloLink.new(function(_self, op: Operation, forward: NextLink)
					local observable = forward(op)

					observable:subscribe({
						next = function(self, actualData)
							expect(data).toEqual(actualData)
						end,
						error = function(self, e)
							error(Error.new(nil))
						end,
						complete = function(_self)
							done()
						end,
					})

					return observable
				end),
				ApolloLink.new(function(self)
					return Observable.of(data)
				end),
			})
			ApolloLink.execute(chain, uniqueOperation)
		end)

		it("should receive final result of two link chain", function(_, done)
			local data: FetchResult<any, any, any> = { data = { hello = "world" } }

			local chain = ApolloLink.from({
				ApolloLink.new(function(_self, op: Operation, forward: NextLink)
					local observable = forward(op)

					return Observable.new(function(observer: any)
						observable:subscribe({
							next = function(self, actualData)
								expect(data).toEqual(actualData)
								observer:next({
									data = Object.assign({}, actualData.data, { modification = "unique" }),
								})
							end,
							error = function(self, error_)
								return observer:error_(error_)
							end,
							complete = function(self)
								return observer:complete()
							end,
						})
					end :: Subscriber<any>) :: Observable<any>
				end),
				ApolloLink.new(function(_self)
					return Observable.of(data)
				end),
			})

			local result = ApolloLink.execute(chain, uniqueOperation)

			result:subscribe({
				next = function(_self, modifiedData)
					expect({ data = Object.assign({}, data.data, { modification = "unique" }) }).toEqual(modifiedData)
				end,
				error = function(_self, e)
					error(Error.new(nil))
				end,
				complete = function(_self)
					done()
				end,
			})
		end)

		it("should chain together a function with links", function(_, done)
			local add1 = ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
				operation:setContext(function(context_: Record<string, any>)
					local context = context_ :: { num: number }
					return { num = (context.num :: number) + 1 }
				end)
				return forward(operation)
			end)
			local add1Link = ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
				operation:setContext(function(context_: Record<string, any>)
					local context = context_ :: { num: number }
					return { num = (context.num :: number) + 1 }
				end)
				return forward(operation)
			end)
			local link = ApolloLink.from({
				add1,
				add1,
				add1Link,
				add1,
				add1Link,
				ApolloLink.new(function(self, operation)
					return Observable.of({ data = operation:getContext() })
				end),
			})
			testLinkResults({ link = link, results = { { num = 5 } }, context = { num = 0 }, done = done })
		end)
	end)

	describe("split", function()
		it("should split two functions", function(_, done)
			local context = { add = 1 }
			local returnOne = SetContextLink.new(function(self)
				return context
			end)
			local link1 = returnOne:concat(function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = (operation:getContext().add :: number) + 1 })
			end)
			local link2 = returnOne:concat(function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = (operation:getContext().add :: number) + 2 })
			end)
			local link = returnOne:split(function(operation: Operation)
				return operation:getContext().add == 1
			end, link1, link2)
			testLinkResults({ link = link, results = { 2 } })
			context.add = 2
			testLinkResults({ link = link, results = { 4 }, done = done })
		end)

		it("should split two Links", function(_, done)
			local context = { add = 1 }
			local returnOne = SetContextLink.new(function(self)
				return context
			end)
			local link1 = returnOne:concat(ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = (operation:getContext().add :: number) + 1 })
			end))
			local link2 = returnOne:concat(ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = (operation:getContext().add :: number) + 2 })
			end))
			local link = returnOne:split(function(operation: Operation)
				return operation:getContext().add == 1
			end, link1, link2)
			testLinkResults({ link = link, results = { 2 } })
			context.add = 2
			testLinkResults({ link = link, results = { 4 }, done = done })
		end)

		it("should split a link and a function", function(_, done)
			local context = { add = 1 }
			local returnOne = SetContextLink.new(function(_self)
				return context
			end)
			local link1 = returnOne:concat(function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = (operation:getContext().add :: number) + 1 })
			end)
			local link2 = returnOne:concat(ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = (operation:getContext().add :: number) + 2 })
			end))
			local link = returnOne:split(function(operation: Operation)
				return operation:getContext().add == 1
			end, link1, link2)
			testLinkResults({ link = link, results = { 2 } })
			context.add = 2
			testLinkResults({ link = link, results = { 4 }, done = done })
		end)

		it("should allow concat after split to be join", function(_, done)
			local context = { test = true, add = 1 }
			local start = SetContextLink.new(function(_self)
				return Object.assign({}, context)
			end)
			local link = start
				:split(function(operation: Operation)
					return operation:getContext().test
				end, function(_self, operation: Operation, forward: NextLink)
					operation:setContext(function(context_: Record<string, any>): Record<string, any>
						local context = context_ :: { add: number }
						return { add = context.add + 1 }
					end)
					return forward(operation)
				end, function(_self, operation: Operation, forward: NextLink)
					operation:setContext(function(context_: Record<string, any>): Record<string, any>
						local context = context_ :: { add: number }
						return { add = context.add + 2 }
					end)
					return forward(operation)
				end)
				:concat(function(_self, operation: Operation)
					return Observable.of({ data = operation:getContext().add })
				end)
			testLinkResults({ link = link, context = context, results = { 2 } })
			context.test = false
			testLinkResults({ link = link, context = context, results = { 3 }, done = done })
		end)

		it("should allow default right to be empty or passthrough when forward available", function(_, done)
			local context = { test = true }
			local start = SetContextLink.new(function(_self)
				return context
			end)
			local link = start:split(function(operation: Operation)
				return operation:getContext().test
			end, function(_self, operation: Operation)
				return Observable.of({ data = { count = 1 } })
			end)
			local concat = link:concat(function(_self, operation: Operation)
				return Observable.of({ data = { count = 2 } })
			end)
			testLinkResults({ link = link, results = { { count = 1 } } })
			context.test = false
			testLinkResults({ link = link, results = {} })
			testLinkResults({ link = concat, results = { { count = 2 } }, done = done })
		end)

		it("should create filter when single link passed in", function(_, done)
			local link = ApolloLink.split_(function(operation: Operation)
				return operation:getContext().test
			end, function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = { count = 1 } })
			end)
			local context = { test = true }
			testLinkResults({ link = link, results = { { count = 1 } }, context = context })
			context.test = false
			testLinkResults({ link = link, results = {}, context = context, done = done })
		end)

		it("should split two functions_", function(_, done)
			local link = ApolloLink.split_(function(operation: Operation)
				return operation:getContext().test
			end, function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = { count = 1 } })
			end, function(_self, operation: Operation, forward: NextLink)
				return Observable.of({ data = { count = 2 } })
			end)
			local context = { test = true }
			testLinkResults({ link = link, results = { { count = 1 } }, context = context })
			context.test = false
			testLinkResults({ link = link, results = { { count = 2 } }, context = context, done = done })
		end)

		it("should split two Links_", function(_, done)
			local link = ApolloLink.split_(
				function(operation: Operation)
					return operation:getContext().test
				end,
				function(self, operation: Operation, forward: NextLink)
					return Observable.of({ data = { count = 1 } })
				end,
				ApolloLink.new(function(self, operation: Operation, forward: NextLink)
					return Observable.of({ data = { count = 2 } })
				end)
			)
			local context = { test = true }
			testLinkResults({ link = link, results = { { count = 1 } }, context = context })
			context.test = false
			testLinkResults({ link = link, results = { { count = 2 } }, context = context, done = done })
		end)

		it("should split a link and a function_", function(_, done)
			local link = ApolloLink.split_(
				function(operation: Operation)
					return operation:getContext().test
				end,
				function(_self, operation: Operation, forward: NextLink)
					return Observable.of({ data = { count = 1 } })
				end,
				ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
					return Observable.of({ data = { count = 2 } })
				end)
			)
			local context = { test = true }
			testLinkResults({ link = link, results = { { count = 1 } }, context = context })
			context.test = false
			testLinkResults({ link = link, results = { { count = 2 } }, context = context, done = done })
		end)

		it("should allow concat after split to be join_", function(_, done)
			local context = { test = true }
			local link = ApolloLink.split_(function(operation: Operation)
				return operation:getContext().test
			end, function(_self, operation: Operation, forward: NextLink)
				return forward(operation):map(function(data)
					return {
						data = {
							count = data.data.count :: number + 1,
						},
					}
				end) :: any
			end):concat(function(_self)
				return Observable.of({ data = { count = 1 } })
			end)
			testLinkResults({ link = link, context = context, results = { { count = 2 } } })
			context.test = false
			testLinkResults({
				link = link,
				context = context,
				results = { { count = 1 } },
				done = done,
			})
		end)

		it("should allow default right to be passthrough", function(_, done)
			local context = { test = true }
			local link = ApolloLink.split_(function(operation: Operation)
				return operation:getContext().test
			end, function(_self, operation: Operation)
				return Observable.of({ data = { count = 2 } })
			end):concat(function(_self, operation: Operation)
				return Observable.of({ data = { count = 1 } })
			end)
			testLinkResults({ link = link, context = context, results = { { count = 2 } } })
			context.test = false
			testLinkResults({
				link = link,
				context = context,
				results = { { count = 1 } },
				done = done,
			})
		end)
	end)

	describe("Terminating links", function()
		local _warn = console.warn

		local warningStub = jest.fn(function(warning)
			expect(warning.message).toBe("You are calling concat on a terminating link, which will have no effect")
		end)

		local data = { stub = "data" }

		beforeAll(function()
			console.warn = warningStub
		end)

		beforeEach(function()
			warningStub:mockClear()
		end)

		afterAll(function()
			console.warn = _warn
		end)

		describe("split", function()
			it("should not warn if attempting to split a terminating and non-terminating Link", function()
				local split = ApolloLink.split_(function()
					return true
				end, function(self, operation)
					return Observable.of({ data = data })
				end, function(self, operation, forward)
					return forward(operation)
				end)
				split:concat(function(self, operation, forward)
					return forward(operation)
				end)
				expect(warningStub).never.toBeCalled()
			end)

			it("should warn if attempting to concat to split two terminating links", function()
				local split = ApolloLink.split_(function()
					return true
				end, function(operation)
					return Observable.of({ data = data })
				end, function(operation)
					return Observable.of({ data = data })
				end)
				expect(split:concat(function(self, operation, forward)
					return forward(operation)
				end)).toEqual(split)
				expect(warningStub).toHaveBeenCalledTimes(1)
			end)

			it("should warn if attempting to split to split two terminating links", function()
				local split = ApolloLink.split_(function()
					return true
				end, function(_operation)
					return Observable.of({ data = data })
				end, function(_operation)
					return Observable.of({ data = data })
				end)
				expect(split:split(function()
					return true
				end, function(_self, operation: Operation, forward: NextLink)
					return forward(operation)
				end, function(_self, operation: Operation, forward: NextLink)
					return forward(operation)
				end)).toEqual(split)
				expect(warningStub).toHaveBeenCalledTimes(1)
			end)
		end)

		describe("from", function()
			it("should not warn if attempting to form a terminating then non-terminating Link", function()
				ApolloLink.from({
					function(_self, operation: Operation, forward: NextLink)
						return forward(operation)
					end,
					function(_self, operation: Operation)
						return Observable.of({ data = data })
					end,
				})
				expect(warningStub).never.toBeCalled()
			end)

			it("should warn if attempting to add link after termination", function()
				ApolloLink.from({
					function(_self, operation: Operation, forward: NextLink)
						return forward(operation)
					end,
					function(_self, operation: Operation)
						return Observable.of({ data = data })
					end,
					function(_self, operation: Operation, forward: NextLink)
						return forward(operation)
					end,
				})
				expect(warningStub).toHaveBeenCalledTimes(1)
			end)

			it("should warn if attempting to add link after termination_", function()
				ApolloLink.from({
					ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
						return forward(operation)
					end),
					ApolloLink.new(function(_self, operation: Operation)
						return Observable.of({ data = data })
					end),
					ApolloLink.new(function(_self, operation: Operation, forward: NextLink)
						return forward(operation)
					end),
				})
				expect(warningStub).toHaveBeenCalledTimes(1)
			end)
		end)

		describe("concat", function()
			it("should warn if attempting to concat to a terminating Link from function", function()
				local link = ApolloLink.new(function(self, operation)
					return Observable.of({ data = data })
				end)
				expect(ApolloLink.concat_(link, function(self, operation, forward)
					return forward(operation)
				end)).toEqual(link)
				expect(warningStub).toHaveBeenCalledTimes(1)
				expect(warningStub.mock.calls[1][1].link).toEqual(link)
			end)

			it("should warn if attempting to concat to a terminating Link", function()
				local link = ApolloLink.new(function(self, operation)
					return Observable.of()
				end)
				expect(link:concat(function(self, operation, forward)
					return forward(operation)
				end)).toEqual(link)
				expect(warningStub).toHaveBeenCalledTimes(1)
				expect(warningStub.mock.calls[1][1].link).toEqual(link)
			end)

			it("should not warn if attempting concat a terminating Link at end", function()
				local link = ApolloLink.new(function(self, operation, forward)
					return forward(operation)
				end)
				link:concat(function(self, operation)
					return Observable.of()
				end)
				expect(warningStub).never.toBeCalled()
			end)
		end)

		describe("warning", function()
			it("should include link that terminates", function()
				local terminatingLink = ApolloLink.new(function(self, operation)
					return Observable.of({ data = data })
				end)
				ApolloLink.from({
					ApolloLink.new(function(self, operation, forward)
						return forward(operation)
					end),
					ApolloLink.new(function(self, operation, forward)
						return forward(operation)
					end),
					terminatingLink,
					ApolloLink.new(function(self, operation, forward)
						return forward(operation)
					end),
					ApolloLink.new(function(self, operation, forward)
						return forward(operation)
					end),
					ApolloLink.new(function(self, operation)
						return Observable.of({ data = data })
					end),
					ApolloLink.new(function(self, operation, forward)
						return forward(operation)
					end),
				})
				expect(warningStub).toHaveBeenCalledTimes(4)
			end)
		end)
	end)
end)

return {}
