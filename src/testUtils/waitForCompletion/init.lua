--[[ ROBLOX: no upstream]]
--[[
    Wait until an observable completes or errors
]]
local srcWorkspace = script.Parent.Parent
local isCallable = require(srcWorkspace.luaUtils.isCallable)

type Function = (...any) -> ...any

local observableModule = require(srcWorkspace.utilities.observables.Observable)
type Observable<T> = observableModule.Observable<T>

local function waitForCompletion(
	obs: Observable<any>,
	nextCallback: (Function | { next: Function?, error: Function?, complete: Function? })?,
	errorCallback: Function?,
	completeCallback: Function?
)
	local bindable = Instance.new("BindableEvent")

	obs:subscribe({
		next = function(self, v)
			if isCallable(nextCallback) then
				(nextCallback :: Function)(self, v)
			elseif typeof(nextCallback) == "table" and isCallable(nextCallback.next) then
				(nextCallback.next :: Function)(self, v)
			end
		end,
		error = function(self, e)
			if isCallable(errorCallback) then
				(errorCallback :: Function)(self, e)
			elseif typeof(nextCallback) == "table" and isCallable(nextCallback.error) then
				(nextCallback.error :: Function)(self, e)
			end
			bindable:Fire()
		end,
		complete = function(self)
			if isCallable(completeCallback) then
				(completeCallback :: Function)(self)
			elseif typeof(nextCallback) == "table" and isCallable(nextCallback.complete) then
				(nextCallback.complete :: Function)(self)
			end
			bindable:Fire()
		end,
	})
	bindable.Event:Wait()
	bindable:Destroy()
end

return waitForCompletion
