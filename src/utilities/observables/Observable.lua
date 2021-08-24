-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/observables/Observable.ts
local exports = {}
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local zenObservableModule = require(rootWorkspace.ZenObservable)
local Observable = zenObservableModule.Observable

-- ROBLOX deviation: rxjs support not required
-- -- require(Packages["symbol-observable"])
-- -- local prototype = Observable.prototype
-- -- local fakeObsSymbol = "@@observable" :: any --[[ ROBLOX TODO: Unhandled node for type: TSTypeOperator ]]
-- -- --[[ keyof typeof prototype ]]
-- -- if not Boolean.toJSBoolean(prototype[tostring(fakeObsSymbol)]) then
-- -- 	prototype[tostring(fakeObsSymbol)] = function()
-- -- 		return error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: ThisExpression ]]
-- -- 		--[[ this ]]
-- -- 	end
-- -- end

exports.Observable = Observable
export type Observable<T> = zenObservableModule.Observable<T>
export type Observer<T> = zenObservableModule.Observer<T>
export type ObservableSubscription<T> = zenObservableModule.Subscription<T>
export type Subscriber<T> = zenObservableModule.Subscriber<T>
return exports
