-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/observables/iteration.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
type Array<T> = LuauPolyfill.Array<T>
type Set<T> = LuauPolyfill.Set<T>

local exports = {}

local ObservableModule = require(script.Parent.Observable)
type Observer<T> = ObservableModule.Observer<T>

-- ROBLOX deviation: generic function parameters aren't supported in Luau
-- E and A are placeholders for the generic function parameters for iterateObserversSafely
type E = any
type A = any
local function iterateObserversSafely(
	observers: Set<Observer<E>>,
	-- ROBLOX TODO: create keyof Observer<E> type for method for safety
	method: string,
	argument: A?
)
	-- In case observers is modified during iteration, we need to commit to the
	-- original elements, which also provides an opportunity to filter them down
	-- to just the observers with the given method.
	local observersWithMethod: Array<Observer<E>> = {}

	for _, obs in observers:ipairs() do
		if obs[method] ~= nil then
			table.insert(observersWithMethod, obs)
		end
	end

	-- ROBLOX deviation: using map because forEach doesn't exist in LuauPolyfill.Array
	Array.forEach(observersWithMethod, function(obs)
		obs[method](argument)
	end)
end

exports.iterateObserversSafely = iterateObserversSafely

return exports