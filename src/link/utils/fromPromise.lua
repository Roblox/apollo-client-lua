-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/utils/fromPromise.ts

local exports = {}
local srcWorkspace = script.Parent.Parent.Parent

local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
type Promise<T> = PromiseTypeModule.Promise<T>

local utilitiesModule = require(script.Parent.Parent.Parent.utilities)
type Observable<T> = utilitiesModule.Observable<T>

local Observable = utilitiesModule.Observable

-- ROBLOX TODO:replace when generic in functions are possible
type T_ = any

local function fromPromise(promise: Promise<T_>): Observable<T_>
	return Observable.new(function(observer)
		promise
			:andThen(function(value: T_)
				observer:next(value)
				observer:complete()
			end)
			:catch(function(e)
				observer.error(observer, e)
			end)
	end)
end

exports.fromPromise = fromPromise

return exports
