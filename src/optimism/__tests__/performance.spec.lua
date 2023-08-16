--[[
 * Copyright (c) 2016 Ben Newman
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/performance.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local afterEach = JestGlobals.afterEach
local beforeAll = JestGlobals.beforeAll
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local itFIXME = function(description: string, ...: any)
	it.todo(description)
end

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array

type Array<T> = LuauPolyfill.Array<T>
type Object = { [string]: any }

local optimismModule = require(script.Parent.Parent)
local wrap = optimismModule.wrap
local dep = optimismModule.dep
local KeyTrie = optimismModule.KeyTrie

describe("performance", function()
	-- ROBLOX deviation: simulating tests timeout
	local startTime
	local timeout = 30000

	local function checkIfTimedOut()
		if DateTime.now().UnixTimestampMillis - startTime > timeout then
			error("timeout")
		end
	end
	beforeAll(function()
		startTime = DateTime.now().UnixTimestampMillis
	end)

	beforeEach(checkIfTimedOut)
	afterEach(checkIfTimedOut)

	-- ROBLOX FIXME: this test runs more than the timeout
	itFIXME("should be able to tolerate lots of Entry objects", function()
		local counter = 0
		local child = wrap(function(a: any, b: any)
			local result = counter
			counter += 1
			return result
		end) :: any
		local parent = wrap(function(obj1: Object, num: number, obj2: Object)
			child(obj1, counter)
			child(counter, obj2)
			local result = counter
			counter += 1
			return result
		end) :: any
		for i = 1, 100000 do
			parent({}, i, {})
		end
	end)

	local keys = {}
	for i = 1, 100000 do
		table.insert(keys, i)
	end

	it("should be able to tolerate lots of deps", function()
		local d = dep()
		local parent = wrap(function(id: number)
			Array.forEach(keys, function(...)
				d(...)
			end)
			return id
		end)
		parent(1)
		parent(2)
		parent(3)
		Array.forEach(keys, function(key)
			d:dirty(key)
		end)
	end)

	it("can speed up sorting with O(array.length) cache lookup", function()
		local counter = 0
		local trie = KeyTrie.new(false)
		local sort = wrap(function(array: Array<number>)
			counter += 1
			return Array.sort(Array.slice(array, 1))
		end, {
			makeCacheKey = function(_self, array)
				return trie:lookupArray(array)
			end,
		})

		expect(sort({ 2, 1, 5, 4 })).toEqual({ 1, 2, 4, 5 })
		expect(counter).toBe(1)
		expect(sort({ 2, 1, 5, 4 })).toBe(sort({ 2, 1, 5, 4 }))
		expect(counter).toBe(1)

		expect(sort({ 3, 2, 1 })).toEqual({ 1, 2, 3 })
		expect(counter).toBe(2)

		local bigArray: Array<number> = {}
		for i = 1, 100000 do
			table.insert(bigArray, math.round(math.random() * 100))
		end

		local bigArrayCopy = Array.slice(bigArray, 1)
		local rawSortStartTime = DateTime.now().UnixTimestampMillis
		Array.sort(bigArrayCopy)
		local rawSortTime = DateTime.now().UnixTimestampMillis - rawSortStartTime

		expect(sort(bigArray)).toEqual(bigArrayCopy)

		local cachedSortStartTime = DateTime.now().UnixTimestampMillis
		local cached = sort(bigArray)
		local cachedSortTime = DateTime.now().UnixTimestampMillis - cachedSortStartTime

		expect(cached).toEqual(bigArrayCopy)
		-- ROBLOX deviation: using toBeLessThanOrEqual matcher to get more meaningful error message
		expect(cachedSortTime).toBeLessThanOrEqual(rawSortTime)
		expect(counter).toBe(3)
	end)
end)

return {}
