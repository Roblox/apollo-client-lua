-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/utils/__tests__/fromPromise.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Error = LuauPolyfill.Error

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local Promise = require(rootWorkspace.Promise)

	local fromPromise = require(script.Parent.Parent.fromPromise).fromPromise
	local toPromise = require(script.Parent.Parent.toPromise).toPromise

	-- ROBLOX deviation: method not available
	local function fail(...)
		jestExpect(false).toBe(true)
	end

	describe("fromPromise", function()
		local data = { data = { hello = "world" } }
		local error_ = Error.new("I always error")

		it("return next call as Promise resolution", function()
			local observable = fromPromise(Promise.resolve(data))
			return toPromise(observable)
				:andThen(function(result)
					return jestExpect(data).toEqual(result)
				end)
				:expect()
		end)

		it("return Promise rejection as error call", function()
			local observable = fromPromise(Promise.reject(error_))
			return toPromise(observable)
				:andThen(fail)
				:catch(function(actualError)
					return jestExpect(error_).toEqual(actualError)
				end)
				:expect()
		end)
	end)
end
