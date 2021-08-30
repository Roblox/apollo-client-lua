-- ROBLOX upstream: https://github.com/facebook/react/blob/v16.9.0/packages/react-dom/src/test-utils/ReactTestUtilsAct.js

--[[
  Copyright (c) Facebook, Inc. and its affiliates.

  This source code is licensed under the MIT license found in the
  LICENSE file in the root directory of this source tree.

]]

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local console = LuauPolyfill.console

local Promise = require(rootWorkspace.Promise)

local exports = {}

-- ROBLOX deviation: Thenable type comes from Shared in roact-alignment
-- local ReactFiberWorkLoopModule = require(Packages["react-reconciler"].src.ReactFiberWorkLoop)
local Shared = require(rootWorkspace.Shared)
type Thenable<R, U> = Shared.Thenable<R, U>

local warningWithoutStack = require(srcWorkspace.jsutils.warningWithoutStack).default
-- ROBLOX deviation: Not converting all of ReactDOM
-- local ReactDOM = require(Packages["react-dom"]).default
local ReactSharedInternals = Shared.ReactSharedInternals
local enqueueTask = Shared.enqueueTask
local Scheduler = require(rootWorkspace.Dev.Scheduler)

-- ROBLOX deviation: only using 2 pieces of ReactDOM secret internal events
-- flushPassiveEffects and IsThisRendererActing -> from ReactReconciler

-- local getInstanceFromNode, getNodeFromInstance, getFiberCurrentPropsFromNode, injectEventPluginsByName, eventNameDispatchConfigs, accumulateTwoPhaseDispatches, accumulateDirectDispatches, enqueueStateRestore, restoreStateIfNeeded, dispatchEvent, runEventsInBatch, flushPassiveEffects, IsThisRendererActing =
-- 	table.unpack(
-- 		ReactDOM.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED.Events,
-- 		1,
-- 		13
-- 	)
local ReactReconcilerInit = require(rootWorkspace.Dev.ReactReconciler)
local ReactFiberReconciler = ReactReconcilerInit({})
local flushPassiveEffects = ReactFiberReconciler.flushPassiveEffects
local IsThisRendererActing = ReactFiberReconciler.IsThisRendererActing
local batchedUpdates = ReactFiberReconciler.batchedUpdates

local IsSomeRendererActing = ReactSharedInternals.IsSomeRendererActing

-- this implementation should be exactly the same in
-- ReactTestUtilsAct.js, ReactTestRendererAct.js, createReactNoop.js

local isSchedulerMocked = typeof(Scheduler.unstable_flushAllWithoutAsserting) == "function"
-- ROBLOX deviation: not using unstable_flushAllWithoutAsserting
local flushWork = function()
	local didFlushWork = false
	while flushPassiveEffects() do
		didFlushWork = true
	end
	return didFlushWork
end

local function flushWorkAndMicroTasks(onDone: (err: any?) -> ())
	xpcall(function()
		flushWork()
		enqueueTask(function()
			if flushWork() then
				flushWorkAndMicroTasks(onDone)
			else
				onDone()
			end
		end)
	end, function(err)
		onDone(err)
	end)
end

-- we track the 'depth' of the act() calls with this counter,
-- so we can tell if any async act() calls try to run in parallel.

local actingUpdatesScopeDepth = 0
local didWarnAboutUsingActInProd = false

-- ROBLOX deviation: This seems to be a bug in upstream. act-compat doest adhere to the callback typing upstream.
-- Added () -> () to align with how act is used in act-compat.
local function act(callback: (() -> Thenable<any, any>) | () -> ())
	if not Boolean.toJSBoolean(_G.__DEV__) then
		if didWarnAboutUsingActInProd == false then
			didWarnAboutUsingActInProd = true
			console.error("act(...) is not supported in production builds of React, and might not behave as expected.")
		end
	end
	local previousActingUpdatesScopeDepth = actingUpdatesScopeDepth
	local previousIsSomeRendererActing
	local previousIsThisRendererActing
	actingUpdatesScopeDepth += 1

	previousIsSomeRendererActing = IsSomeRendererActing.current
	previousIsThisRendererActing = IsThisRendererActing.current
	IsSomeRendererActing.current = true
	IsThisRendererActing.current = true

	local function onDone()
		actingUpdatesScopeDepth -= 1
		IsSomeRendererActing.current = previousIsSomeRendererActing
		IsThisRendererActing.current = previousIsThisRendererActing
		if Boolean.toJSBoolean(_G.__DEV__) then
			if actingUpdatesScopeDepth > previousActingUpdatesScopeDepth then
				-- if it's _less than_ previousActingUpdatesScopeDepth, then we can assume the 'other' one has warned
				warningWithoutStack(
					nil,
					"You seem to have overlapping act() calls, this is not supported. "
						.. "Be sure to await previous act() calls before making a new one. "
				)
			end
		end
	end
	local result
	xpcall(function()
		result = batchedUpdates(callback)
	end, function(error_)
		onDone()
		error(error_)
	end)
	if result ~= nil and typeof(result) == "table" and typeof(result["then"]) == "function" then
		-- setup a boolean that gets set to true only
		-- once this act() call is await-ed
		local called = false
		if Boolean.toJSBoolean(_G.__DEV__) then
			if typeof(Promise) ~= "nil" then
				Promise.delay(0):andThen(function()
					if called == false then
						warningWithoutStack(
							false,
							"You called act(async () => ...) without await. "
								.. "This could lead to unexpected testing behaviour, interleaving multiple act "
								.. "calls and mixing their scopes. You should - await act(async () => ...);"
						)
					end
				end)
			end
		end

		-- in the async case, the returned thenable runs the callback, flushes
		-- effects and  microtasks in a loop until flushPassiveEffects() === false,
		-- and cleans up
		return {
			andThen = function(self, resolve: () -> (), reject: (any?) -> ())
				called = true
				result:andThen(function()
					if
						actingUpdatesScopeDepth > 1
						or (isSchedulerMocked == true and previousIsSomeRendererActing == true)
					then
						onDone()
						resolve()
						return
					end
					-- we're about to exit the act() scope,
					-- now's the time to flush tasks/effects
					flushWorkAndMicroTasks(function(err)
						onDone()
						if Boolean.toJSBoolean(err) then
							reject(err)
						else
							resolve()
						end
					end)
				end, function(err)
					onDone()
					reject(err)
				end)
			end,
		}
	else
		if Boolean.toJSBoolean(_G.__DEV__) then
			warningWithoutStack(
				result == nil,
				"The callback passed to act(...) function " .. "must return undefined, or a Promise. You returned %s",
				result
			)
		end
		-- flush effects until none remain, and cleanup
		xpcall(function()
			if
				actingUpdatesScopeDepth == 1
				and (isSchedulerMocked == false or previousIsSomeRendererActing == false)
			then
				-- we're about to exit the act() scope,
				-- now's the time to flush effects
				flushWork()
			end
			onDone()
		end, function(err)
			onDone()
			error(err)
		end)

		-- in the sync case, the returned thenable only warns *if* await-ed
		return {
			andThen = function(self, resolve: () -> ())
				if Boolean.toJSBoolean(_G.__DEV__) then
					warningWithoutStack(
						false,
						"Do not await the result of calling act(...) with sync logic, it is not a Promise."
					)
				end
				resolve()
			end,
		}
	end
end

exports.default = act

return exports
