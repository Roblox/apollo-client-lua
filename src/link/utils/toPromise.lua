-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/utils/toPromise.ts

local exports = {}
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local Promise = require(rootWorkspace.Promise)

local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
type Promise<T> = PromiseTypeModule.Promise<T>

local invariantModule = require(srcWorkspace.jsutils.invariant)
local invariant = invariantModule.invariant

local utilitiesModule = require(script.Parent.Parent.Parent.utilities)
type Observable<T> = utilitiesModule.Observable<T>

-- ROBLOX TODO:replace when generic in functions are possible
type R_ = any

local function toPromise(observable: Observable<R_>): Promise<R_>
	local completed = false
	return Promise.new(function(resolve, reject)
		observable:subscribe({
			next = function(_self, data)
				if completed then
					invariant.warn("Promise Wrapper does not support multiple results from Observable")
				else
					completed = true
					resolve(data)
				end
			end,
			error = function(_self, e)
				reject(e)
			end,
		})
	end):andThen(
		-- ROBLOX deviation: delaying promise resolution to allow Observable to complete first
		function(result)
			return Promise.delay(0):andThenReturn(result)
		end
	)
end

exports.toPromise = toPromise

return exports
