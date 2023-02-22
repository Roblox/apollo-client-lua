-- ROBLOX upstream: https://github.com/benjamn/wryware/blob/%40wry/trie%400.3.1/packages/trie/src/tests.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Set = LuauPolyfill.Set
local Array = LuauPolyfill.Array
local Symbol = LuauPolyfill.Symbol
local instanceof = LuauPolyfill.instanceof
local RegExp = require(rootWorkspace.LuauRegExp)

type Array<T> = LuauPolyfill.Array<T>

local Trie = require(script.Parent.Parent.trie).Trie

describe("Trie", function()
	it("can be imported", function()
		-- ROBLOX deviation: constructor function is available under Trie.new
		expect(typeof(Trie.new)).toEqual("function")
	end)

	it("can hold objects weakly", function()
		local trie = Trie.new(true)
		expect((trie :: any).weakness).toEqual(true)
		local obj1 = {}
		expect(trie:lookup(obj1, 2, 3)).toEqual(trie:lookup(obj1, 2, 3))
		local obj2 = {}
		expect(trie:lookup(1, obj2)).never.toBe(trie:lookup(1, obj2, 3))
		-- ROBLOX deviation START: use lua table instead of map
		expect((trie :: any).weak[obj1]).toBeDefined()
		-- expect((trie :: any).strong:has(obj1)).toEqual(false)
		-- ROBLOX deviation: WeakMap doesn't have `has` method
		expect((trie :: any).weak[1].weak[obj2]).toBeDefined()
		expect((trie :: any).weak[1].weak[obj2].weak[3]).toBeDefined()
		-- ROBLOX deviation END
	end)

	it("can disable WeakMap", function()
		local trie = Trie.new(false)
		expect((trie :: any).weakness).toEqual(false)
		local obj1 = {}
		expect(trie:lookup(obj1, 2, 3)).toEqual(trie:lookup(obj1, 2, 3))
		local obj2 = {}
		expect(trie:lookup(1, obj2)).never.toBe(trie:lookup(1, obj2, 3))
		expect(typeof((trie :: any).weak)).toEqual("nil")
		-- ROBLOX deviation START: use lua table instead of map
		expect((trie :: any).strong[obj1]).toBeDefined()
		expect((trie :: any).strong[1]).toBeDefined()
		expect((trie :: any).strong[1].strong[obj2]).toBeDefined()
		expect((trie :: any).strong[1].strong[obj2].strong[3]).toBeDefined()
		-- ROBLOX deviation END
	end)

	it("can produce data types other than Object", function()
		local symbolTrie = Trie.new(true, function(args)
			return Symbol.for_(Array.join(args, "."))
		end)
		local s123 = symbolTrie:lookup(1, 2, 3)
		expect(tostring(s123)).toEqual("Symbol(1.2.3)")
		expect(s123).toEqual(symbolTrie:lookup(1, 2, 3))
		expect(s123).toEqual(symbolTrie:lookupArray({ 1, 2, 3 }))
		local sNull = symbolTrie:lookup()
		expect(tostring(sNull)).toEqual("Symbol()")
		local regExpTrie = Trie.new(true, function(args)
			return RegExp("^(" .. Array.join(args, "|") .. ")$")
		end)
		local rXYZ = regExpTrie:lookup("x", "y", "z")
		expect(rXYZ:test("w")).toEqual(false)
		expect(rXYZ:test("x")).toEqual(true)
		expect(rXYZ:test("y")).toEqual(true)
		expect(rXYZ:test("z")).toEqual(true)
		expect(tostring(rXYZ)).toEqual("/^(x|y|z)$/")

		local Data = {}
		Data.__index = Data

		type Data = {}

		function Data.new(args: Array<any>): Data
			local self = setmetatable({}, Data)
			self.args = args
			return (self :: any) :: Data
		end
		local dataTrie = Trie.new(true, function(args)
			return Data.new(args)
		end)
		local function checkData(...)
			local args: Array<any> = { ... }
			local data = dataTrie:lookupArray(args)
			expect(instanceof(data, Data)).toEqual(true)
			expect(data.args).never.toBe(args)
			expect(data.args).toEqual(args) -- assert:deepStrictEqual(data.args, args)
			expect(data).toEqual(dataTrie:lookup(table.unpack(args)))
			-- ROBLOX deviation: 'arguments' is not available in Lua
			expect(data).toEqual(dataTrie:lookupArray(args))
			return data
		end
		local datas = {
			checkData(),
			checkData(1),
			checkData(1, 2),
			checkData(2),
			checkData(2, 3),
			checkData(true, "a"),
			checkData(RegExp("asdf", "i"), "b", function() end),
		}
		-- Verify that all Data objects are distinct.
		expect(Set.new(datas).size).toEqual(#datas)
	end)
end)

return {}
