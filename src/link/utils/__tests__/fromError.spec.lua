-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/utils/__tests__/fromError.ts

return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Error = LuauPolyfill.Error

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local toPromise = require(script.Parent.Parent.toPromise).toPromise
	local fromError = require(script.Parent.Parent.fromError).fromError

	-- ROBLOX deviation: method not available
	local function fail(...)
		jestExpect(false).toBe(true)
	end

	describe("fromError", function()
		it("acts as error call", function()
			local error_ = Error.new("I always error")
			local observable = fromError(error_)
			return toPromise(observable)
				:andThen(fail)
				:catch(function(actualError)
					return jestExpect(error_).toEqual(actualError)
				end)
				:expect()
		end)
	end)
end
