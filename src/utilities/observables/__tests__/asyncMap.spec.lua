-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/3161e31538c33f3aafb18f955fbee0e6e7a0b0c0/src/utilities/observables/__tests__/asyncMap.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local setTimeout = LuauPolyfill.setTimeout
	local Error = LuauPolyfill.Error

	type Array<T> = LuauPolyfill.Array<T>

	local Promise = require(rootWorkspace.Promise)

	local PromiseModule = require(srcWorkspace.luaUtils.Promise)
	type Promise<T> = PromiseModule.Promise<T>
	type PromiseLike<T> = PromiseModule.PromiseLike<T>
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

	local function wait(delayMs: number)
		return Promise.new(function(resolve)
			return setTimeout(resolve, delayMs)
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

	local function rejectExceptions(reject: (reason: any) -> any, fn: (...any) -> Ret_)
		return function(_self: any, ...): ()
			local arguments = { ... }
			local _ok, result, hasReturned = xpcall(function()
				return fn(table.unpack(arguments)), true
			end, function(error_)
				reject(error_)
			end)
			if hasReturned then
				return result
			end
		end :: typeof(fn)
	end

	describe("asyncMap", function()
		itAsync(it)("keeps normal results in order", function(resolve, reject)
			local values: Array<number> = {}
			local mapped: Array<number> = {}
			asyncMap(make1234Observable(), function(value: number)
				table.insert(values, value)
				local delay = 100 - value * 10
				return wait(delay):andThen(function()
					return value * 2
				end)
			end):subscribe({
				next = function(_self, mappedValue)
					table.insert(mapped, mappedValue)
				end,
				error = reject,
				complete = rejectExceptions(reject, function()
					jestExpect(values).toEqual({ 1, 2, 3, 4 })
					jestExpect(mapped).toEqual({ 2, 4, 6, 8 })
					resolve()
				end),
			})
		end)

		itAsync(it)("handles exceptions from mapping functions", function(resolve, reject)
			local triples: Array<number> = {}
			asyncMap(make1234Observable(), function(num: number)
				if num == 3 then
					error(Error.new("expected"))
				end
				return num * 3
			end):subscribe({
				next = rejectExceptions(reject, function(triple)
					jestExpect(triple).toBeLessThan(9)
					table.insert(triples, triple)
				end),
				error = rejectExceptions(reject, function(error_)
					jestExpect(error_.message).toBe("expected")
					jestExpect(triples).toEqual({ 3, 6 })
					resolve()
				end),
			})
		end)

		itAsync(it)("handles rejected promises from mapping functions", function(resolve, reject)
			local triples: Array<number> = {}
			asyncMap(make1234Observable(), function(num: number)
				if num == 3 then
					return Promise.reject(Error.new("expected"))
				end
				return num * 3
			end):subscribe({
				next = rejectExceptions(reject, function(triple)
					jestExpect(triple).toBeLessThan(9)
					table.insert(triples, triple)
				end),
				error = rejectExceptions(reject, function(error_)
					jestExpect(error_.message).toBe("expected")
					jestExpect(triples).toEqual({ 3, 6 })
					resolve()
				end),
			})
		end)

		itAsync(it)("handles async exceptions from mapping functions", function(resolve, reject)
			local triples: Array<number> = {}
			asyncMap(make1234Observable(), function(num: number)
				return wait(10):andThen(function()
					if num == 3 then
						error(Error.new("expected"))
					end
					return num * 3
				end)
			end):subscribe({
				next = rejectExceptions(reject, function(triple)
					jestExpect(triple).toBeLessThan(9)
					table.insert(triples, triple)
				end),
				error = rejectExceptions(reject, function(error_)
					jestExpect(error_.message).toBe("expected")
					jestExpect(triples).toEqual({ 3, 6 })
					resolve()
				end),
			})
		end)

		itAsync(it)("handles exceptions from next functions", function(resolve, reject)
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
				-- 	jestExpect(error_.message).toBe("expected")
				-- 	jestExpect(triples).toEqual({ 3, 6, 9 })
				-- 	resolve()
				-- end),
				complete = rejectExceptions(reject, function()
					jestExpect(triples).toEqual({ 3, 6, 9, 12 })
					resolve()
				end),
			})
		end)
	end)
end
