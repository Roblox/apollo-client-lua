-- ROBLOX upstream: https://github.com/testing-library/react-testing-library/blob/v9.4.1/src/act-compat.js

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local console = LuauPolyfill.console

local Promise = require(rootWorkspace.Promise)
local PromiseTypeModule = require(srcWorkspace.luaUtils.Promise)
type Promise<T> = PromiseTypeModule.Promise<T>

local Shared = require(rootWorkspace.Shared)
type Thenable<R> = Shared.Thenable<R>

-- ROBLOX deviation: not using React
-- local React = require(rootWorkspace.React)

-- ROBLOX deviation: not converting all of ReactDOM, just testUtils
-- local ReactDOM = require(rootWorkspace["react-dom"]).default

local exports = {}

local testUtils = require(srcWorkspace.testUtils["react-dom"]["test-utils"])
local reactAct = testUtils.act
local actSupported = reactAct ~= nil

-- ROBLOX deviation: we dont have ReactDOM
-- -- act is supported react-dom@16.8.0
-- -- so for versions that don't have act from test utils
-- -- we do this little polyfill. No warnings, but it's
-- -- better than nothing.
-- local function actPolyfill(cb)
-- 	ReactDOM:unstable_batchedUpdates(cb)
-- 	ReactDOM:render(React.createElement("div", nil), document:createElement("div"))
-- end

-- ROBLOX deviation: reactAct exists, we dont need actPolyfill
local act = reactAct

local youHaveBeenWarned = false
local isAsyncActSupported = nil

local function asyncAct(cb)
	if actSupported == true then
		if isAsyncActSupported == nil then
			return Promise.new(function(resolve, reject)
				-- patch console.error here
				local originalConsoleError = console.error
				console.error = function(...)
					local args = table.pack(...)
					--[[ if console.error fired *with that specific message* ]]
					local firstArgIsString = typeof(args[1]) == "string"
					if
						firstArgIsString
						and string.find(args[1], "Warning: Do not await the result of calling ReactTestUtils.act")
							== 1
					then
						-- v16.8.6
						isAsyncActSupported = false
					elseif
						firstArgIsString
						and string.find(
								args[1],
								"Warning: The callback passed to ReactTestUtils.act(...) function must not return anything"
							)
							== 1
					then
						-- no-op
					else
						originalConsoleError(table.unpack(args))
					end
				end

				local cbReturn, result
				local _ok, hasReturned = xpcall(function()
					result = reactAct(function()
						cbReturn = cb()
						return cbReturn :: Thenable<any>
					end)
					return false
				end, function(err)
					console.error = originalConsoleError
					reject(err)
					return true
				end)
				if hasReturned then
					return
				end

				result:andThen(function()
					console.error = originalConsoleError
					-- if it got here, it means async act is supported
					isAsyncActSupported = true
					resolve()
				end, function(err)
					console.error = originalConsoleError
					isAsyncActSupported = true
					reject(err)
				end)
				-- 16.8.6's act().then() doesn't call a resolve handler, so we need to manually flush here, sigh
				if isAsyncActSupported == false then
					console.error = originalConsoleError
					if not youHaveBeenWarned then
						-- if act is supported and async act isn't and they're trying to use async
						-- act, then they need to upgrade from 16.8 to 16.9.
						-- This is a seemless upgrade, so we'll add a warning
						console.error(
							'It looks like you\'re using a version of react-dom that supports the "act" function, but not an awaitable version of "act" which you will need. Please upgrade to at least react-dom@16.9.0 to remove this warning.'
						)
						youHaveBeenWarned = true
					end
					cbReturn:andThen(function()
						-- a faux-version.
						-- todo - copy https://github.com/facebook/react/blob/master/packages/shared/enqueueTask.js
						Promise.resolve():andThen(function()
							-- use sync act to flush effects
							act(function() end :: () -> ())
							resolve()
						end)
					end, reject)
				end
			end)
		elseif isAsyncActSupported == false then
			-- ROBLOX TODO: use the polyfill directly
			local result: Promise<any>
			act(function()
				result = (cb() :: any) :: Promise<any>
			end :: () -> ())
			return result:andThen(function()
				return Promise.resolve():andThen(function()
					-- use sync act to flush effects
					act(function() end :: () -> ())
				end)
			end)
		end
		-- all good! regular act
		return act(cb)
	end
	-- ROBLOX TODO: use the polyfill directly
	local result: Promise<any>
	act(function()
		result = (cb() :: any) :: Promise<any>
	end)

	return result:andThen(function()
		return Promise.resolve():andThen(function()
			-- use sync act to flush effects
			act(function() end)
		end)
	end)
end

exports.default = act
exports.asyncAct = asyncAct

return exports
