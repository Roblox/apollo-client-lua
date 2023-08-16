--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/utils/__tests__/fromPromise.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Error = LuauPolyfill.Error

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Promise = require(rootWorkspace.Promise)

local fromPromise = require(script.Parent.Parent.fromPromise).fromPromise
local toPromise = require(script.Parent.Parent.toPromise).toPromise

-- ROBLOX deviation: method not available
local function fail(...)
	expect(false).toBe(true)
end

describe("fromPromise", function()
	local data = { data = { hello = "world" } }
	local error_ = Error.new("I always error")

	it("return next call as Promise resolution", function()
		local observable = fromPromise(Promise.resolve(data))
		return toPromise(observable)
			:andThen(function(result)
				return expect(data).toEqual(result)
			end)
			:expect()
	end)

	it("return Promise rejection as error call", function()
		local observable = fromPromise(Promise.reject(error_))
		return toPromise(observable)
			:andThen(fail)
			:catch(function(actualError)
				return expect(error_).toEqual(actualError)
			end)
			:expect()
	end)
end)

return {}
