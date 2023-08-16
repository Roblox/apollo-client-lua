--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/utils/__tests__/toPromise.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Error = LuauPolyfill.Error
local console = LuauPolyfill.console

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest

-- ROBLOX deviation START: global not available
local fail = function(...)
	expect("Global fail called").toBeUndefined()
end
-- ROBLOX deviation END

local Observable = require(srcWorkspace.utilities.observables.Observable).Observable

local toPromise = require(script.Parent.Parent.toPromise).toPromise
local fromError = require(script.Parent.Parent.fromError).fromError

describe("toPromise", function()
	local data = { data = { hello = "world" } }
	local error_ = Error.new("I always error")

	it("return next call as Promise resolution", function()
		toPromise(Observable.of(data))
			:andThen(function(result)
				return expect(data).toEqual(result)
			end)
			:expect()
	end)

	it("return error call as Promise rejection", function()
		toPromise(fromError(error_))
			:andThen(fail)
			:catch(function(actualError)
				return expect(error_).toEqual(actualError)
			end)
			:expect()
	end)

	describe("warnings", function()
		local spy = jest.fn()
		local _warn: (message: any?, ...any) -> ()

		beforeEach(function()
			_warn = console.warn
			console.warn = spy
		end)

		afterEach(function()
			console.warn = _warn
		end)

		it("return error call as Promise rejection", function(_, done)
			local obs = Observable.of(data, data)
			toPromise(obs):andThen(function(result)
				expect(data).toEqual(result)
				expect(spy).toHaveBeenCalled()
				done()
			end)
		end)
	end)
end)

return {}
