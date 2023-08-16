--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/3161e31538c33f3aafb18f955fbee0e6e7a0b0c0/src/utilities/observables/__tests__/asyncMap.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local setTimeout = LuauPolyfill.setTimeout
local Error = LuauPolyfill.Error

type Array<T> = LuauPolyfill.Array<T>
type Promise<T> = LuauPolyfill.Promise<T>
type PromiseLike<T> = LuauPolyfill.PromiseLike<T>

local Promise = require(rootWorkspace.Promise)

type Function = () -> any

--[[
		ROBLOX deviation: no generic params for functions are supported.
		Ret_ is placeholder for generic Ret param
	]]
type Ret_ = any?

local itAsync = require(script.Parent.Parent.Parent.testing).itAsync
local observableModule = require(script.Parent.Parent.Observable)
local Observable = observableModule.Observable
type Observable<T> = observableModule.Observable<T>
local asyncMap = require(script.Parent.Parent.asyncMap).asyncMap

local function wait_(delayMs: number)
	return Promise.new(function(resolve)
		setTimeout(resolve, delayMs)
	end)
end

local function make1234Observable(): Observable<number>
	return Observable.new(function(observer)
		observer:next(1)
		observer:next(2)
		setTimeout(function()
			observer:next(3)
			setTimeout(function()
				observer:next(4)
				observer:complete()
			end, 10)
		end, 10)
	end)
end

local function rejectExceptions(reject: (reason: any) -> ...any, fn: (...any) -> ...Ret_)
	return function(_self: any, ...)
		local arguments = { ... }
		local ok, result = pcall(function()
			return fn(table.unpack(arguments))
		end)
		if ok then
			return result
		else
			reject(result)
		end
		return
	end :: typeof(fn)
end

describe("asyncMap", function()
	itAsync("keeps normal results in order", function(resolve, reject)
		local values: Array<number> = {}
		local mapped: Array<number> = {}
		asyncMap(make1234Observable(), function(value: number)
			table.insert(values, value)
			local delay = 100 - value * 10
			return wait_(delay):andThen(function()
				return value * 2
			end)
		end):subscribe({
			next = function(_self, mappedValue)
				table.insert(mapped, mappedValue)
			end,
			error = reject,
			complete = rejectExceptions(reject, function()
				expect(values).toEqual({ 1, 2, 3, 4 })
				expect(mapped).toEqual({ 2, 4, 6, 8 })
				resolve()
			end),
		})
	end)

	itAsync("handles exceptions from mapping functions", function(resolve, reject)
		local triples: Array<number> = {}
		asyncMap(make1234Observable(), function(num: number)
			if num == 3 then
				error(Error.new("expected"))
			end
			return num * 3
		end):subscribe({
			next = rejectExceptions(reject, function(triple)
				expect(triple).toBeLessThan(9)
				table.insert(triples, triple)
			end),
			error = rejectExceptions(reject, function(error_)
				expect(error_.message).toBe("expected")
				expect(triples).toEqual({ 3, 6 })
				resolve()
			end),
		})
	end)

	itAsync("handles rejected promises from mapping functions", function(resolve, reject)
		local triples: Array<number> = {}
		asyncMap(make1234Observable(), function(num: number)
			if num == 3 then
				return Promise.reject(Error.new("expected"))
			end
			return num * 3
		end):subscribe({
			next = rejectExceptions(reject, function(triple)
				expect(triple).toBeLessThan(9)
				table.insert(triples, triple)
			end),
			error = rejectExceptions(reject, function(error_)
				expect(error_.message).toBe("expected")
				expect(triples).toEqual({ 3, 6 })
				resolve()
			end),
		})
	end)

	itAsync("handles async exceptions from mapping functions", function(resolve, reject)
		local triples: Array<number> = {}
		asyncMap(make1234Observable(), function(num: number)
			return wait_(10):andThen(function()
				if num == 3 then
					error(Error.new("expected"))
				end
				return num * 3
			end)
		end):subscribe({
			next = rejectExceptions(reject, function(triple)
				expect(triple).toBeLessThan(9)
				table.insert(triples, triple)
			end),
			error = rejectExceptions(reject, function(error_)
				expect(error_.message).toBe("expected")
				expect(triples).toEqual({ 3, 6 })
				resolve()
			end),
		})
	end)

	itAsync("handles exceptions from next functions", function(resolve, reject)
		local triples: Array<number> = {}
		asyncMap(make1234Observable(), function(num: number)
			return num * 3
		end):subscribe({
			next = function(self, triple)
				table.insert(triples, triple)
				-- Unfortunately this exception won't be caught by asyncMap, because
				-- the Observable implementation wraps this next function with its own
				-- try-catch. Uncomment the remaining lines to make this test more
				-- meaningful, in the event that this behavior ever changes.
				-- if triple == 9 then
				-- 	error(Error.new("expected"))
				-- end
			end,
			-- error = rejectExceptions(reject, function(error_)
			-- 	expect(error_.message).toBe("expected")
			-- 	expect(triples).toEqual({ 3, 6, 9 })
			-- 	resolve()
			-- end),
			complete = rejectExceptions(reject, function()
				expect(triples).toEqual({ 3, 6, 9, 12 })
				resolve()
			end),
		})
	end)
end)

return {}
