--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/testing/wrap.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local console = LuauPolyfill.console
local RegExp = require(rootWorkspace.LuauRegExp)
type RegExp = RegExp.RegExp

type Function = (...any) -> ...any

--[[
  ROBLOX deviation: no generic params for functions are supported.
  TResult_, TArgs_
  are a placeholders for generic TResult, TArgs params
]]
type TResult_ = any
type TArgs_ = any

local exports = {}

exports.default = function(reject: (reason: any) -> any, cb: (...TArgs_) -> ...TResult_)
	return function(...: TArgs_)
		local args = { ... }
		local ok, result = pcall(function()
			return cb(table.unpack(args))
		end)
		if not ok then
			local e = result
			reject(e)
		end
		return result
	end
end

local function withError(func: Function, regex: RegExp)
	local message: string = nil :: any
	local oldError = console.error

	console.error = function(m: string)
		message = m
		return message
	end

	local ok, result = pcall(function()
		local result = func()
		expect(message).toMatch(regex)
		return result
	end)
	console.error = oldError
	if not ok then
		error(result)
	end
	return result
end
exports.withError = withError

return exports
