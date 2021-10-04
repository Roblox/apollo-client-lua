-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/utils/__tests__/toPromise.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Error = LuauPolyfill.Error
	local console = LuauPolyfill.console

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect
	local jest = JestRoblox.Globals.jest

	local Observable = require(srcWorkspace.utilities.observables.Observable).Observable

	local toPromise = require(script.Parent.Parent.toPromise).toPromise
	local fromError = require(script.Parent.Parent.fromError).fromError

	-- ROBLOX deviation: method not available
	local function fail(...)
		jestExpect(false).toBe(true)
	end

	describe("toPromise", function()
		local data = { data = { hello = "world" } }
		local error_ = Error.new("I always error")

		it("return next call as Promise resolution", function()
			toPromise(Observable.of(data))
				:andThen(function(result)
					return jestExpect(data).toEqual(result)
				end)
				:expect()
		end)

		it("return error call as Promise rejection", function()
			toPromise(fromError(error_))
				:andThen(fail)
				:catch(function(actualError)
					return jestExpect(error_).toEqual(actualError)
				end)
				:expect()
		end)

		describe("warnings", function()
			local spy = jest.fn()
			local _warn: (message: any?, ...any) -> ()

			beforeEach(function()
				_warn = console.warn
				console.warn = spy
			end)

			afterEach(function()
				console.warn = _warn
			end)

			it("return error call as Promise rejection", function()
				local obs = Observable.of(data, data)
				toPromise(obs)
					:andThen(function(result)
						jestExpect(data).toEqual(result)
						jestExpect(spy).toHaveBeenCalled()
					end)
					:expect()
			end)
		end)
	end)
end
