--[[ ROBLOX: no upstream]]
--[[
    Wait until an observable completes or errors
]]
local srcWorkspace = script.Parent.Parent
type Function = (...any) -> ...any

local observableModule = require(srcWorkspace.utilities.observables.Observable)
type Observable<T> = observableModule.Observable<T>

local function waitForCompletion(
	obs: Observable<any>,
	nextCallback: Function?,
	errorCallback: Function?,
	completeCallback: Function?
)
	local bindable = Instance.new("BindableEvent")

	obs:subscribe({
		next = function(self, v)
			if typeof(nextCallback) == "function" then
				nextCallback(self, v)
			end
		end :: any,
		["error"] = function(self, e)
			if typeof(errorCallback) == "function" then
				errorCallback(self, e)
			end
			bindable:Fire()
		end :: any,
		complete = function(self)
			if typeof(completeCallback) == "function" then
				completeCallback(self)
			end
			bindable:Fire()
		end :: any,
	})
	bindable.Event:Wait()
	bindable:Destroy()
end

return waitForCompletion
