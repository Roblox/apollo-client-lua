-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/observables/__tests__/subclassing.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	type Array<T> = LuauPolyfill.Array<T>

	local Promise = require(rootWorkspace.Promise)

	local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
	type Promise<T> = PromiseTypeModule.Promise<T>

	local ObservableModule = require(script.Parent.Parent.Observable)
	local Observable = ObservableModule.Observable
	type Observable<T> = ObservableModule.Observable<T>

	local Concast = require(script.Parent.Parent.Concast).Concast

	-- Roblox deviation: Luau doesn't support function generics. Creating as a placeholder for T
	type T = any
	local function toArrayPromise(observable: Observable<T>): Promise<Array<any>>
		return Promise.new(function(resolve, reject)
			local values: Array<T> = {}
			observable:subscribe({
				next = function(_self, value)
					table.insert(values, value)
				end,
				error = function(_self, e)
					reject(e)
				end,
				complete = function(_self)
					resolve(values)
				end,
			})
		end)
	end

	describe("Observable subclassing", function()
		it("Symbol.species is defined for Concast subclass", function()
			local concast = Concast.new({ Observable.of(1, 2, 3), Observable.of(4, 5) })
			jestExpect(concast).toBeInstanceOf(Concast)

			local mapped = concast:map(function(n)
				return n * 2
			end)
			jestExpect(mapped).toBeInstanceOf(Observable)
			jestExpect(mapped).never.toBeInstanceOf(Concast)

			return toArrayPromise(mapped):andThen(function(doubles)
				jestExpect(doubles).toEqual({ 2, 4, 6, 8, 10 })
			end)
		end)

		it("Inherited Concast.of static method returns a Concast", function()
			local concast = Concast.of("asdf", "qwer", "zxcv")
			jestExpect(concast).toBeInstanceOf(Observable)
			jestExpect(concast).toBeInstanceOf(Concast)
			return toArrayPromise(concast)
				:andThen(function(values)
					jestExpect(values).toEqual({ "asdf", "qwer", "zxcv" })
				end)
				:expect()
		end)
	end)
end
