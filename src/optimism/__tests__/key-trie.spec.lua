-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/key-trie.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local instanceof = LuauPolyfill.instanceof
local Symbol = LuauPolyfill.Symbol
local Set = LuauPolyfill.Set
local RegExp = require(rootWorkspace.LuauRegExp)

type Array<T> = LuauPolyfill.Array<T>

local KeyTrie = require(script.Parent.Parent).KeyTrie

describe("KeyTrie", function()
	it("can be imported", function()
		expect(typeof(KeyTrie.new)).toBe("function")
	end)

	it("can hold objects weakly", function()
		local trie = KeyTrie.new(true)
		expect((trie :: any).weakness).toBe(true)
		local obj1 = {}
		expect(trie:lookup(obj1, 2, 3)).toBe(trie:lookup(obj1, 2, 3))
		local obj2 = {}
		expect(trie:lookup(1, obj2)).never.toBe(trie:lookup(1, obj2, 3))
		-- ROBLOX deviation START: use lua table instead of map
		expect((trie :: any).weak[obj1]).toBeDefined()
		-- expect((trie :: any).strong:has(obj1)).toBe(false)
		expect((trie :: any).weak[1].weak[obj2]).toBeDefined()
		expect((trie :: any).weak[1].weak[obj2].weak[3]).toBeDefined()
		-- ROBLOX deviation END
	end)

	it("can disable WeakMap", function()
		local trie = KeyTrie.new(false)
		expect((trie :: any).weakness).toBe(false)
		local obj1 = {}
		expect(trie:lookup(obj1, 2, 3)).toBe(trie:lookup(obj1, 2, 3))
		local obj2 = {}
		expect(trie:lookup(1, obj2)).never.toBe(trie:lookup(1, obj2, 3))
		expect(typeof((trie :: any).weak)).toBe("nil")
		-- ROBLOX deviation START: use lua table instead of map
		expect((trie :: any).strong[obj1]).toBeDefined()
		expect((trie :: any).strong[1]).toBeDefined()
		expect((trie :: any).strong[1].strong[obj2]).toBeDefined()
		expect((trie :: any).strong[1].strong[obj2].strong[3]).toBeDefined()
		-- ROBLOX deviation END
	end)

	it("can produce data types other than Object", function()
		local symbolTrie = KeyTrie.new(true, function(args)
			return Symbol.for_(Array.join(args, "."))
		end)
		local s123 = symbolTrie:lookup(1, 2, 3)
		expect(tostring(s123)).toBe("Symbol(1.2.3)")
		expect(s123).toBe(symbolTrie:lookup(1, 2, 3))
		expect(s123).toBe(symbolTrie:lookupArray({ 1, 2, 3 }))
		local sNull = symbolTrie:lookup()
		expect(tostring(sNull)).toBe("Symbol()")
		local regExpTrie = KeyTrie.new(true, function(args)
			return RegExp("^(" .. Array.join(args, "|") .. ")$")
		end)
		local rXYZ = regExpTrie:lookup("x", "y", "z")
		expect(rXYZ:test("w")).toBe(false)
		expect(rXYZ:test("x")).toBe(true)
		expect(rXYZ:test("y")).toBe(true)
		expect(rXYZ:test("z")).toBe(true)
		expect(tostring(rXYZ)).toBe("/^(x|y|z)$/")

		type Data = { args: Array<any> }

		local Data = {}
		Data.__index = Data

		function Data.new(args: Array<any>): Data
			local self = setmetatable({}, Data)
			self.args = args
			return (self :: any) :: Data
		end

		local dataTrie = KeyTrie.new(true, function(args)
			return Data.new(args)
		end)
		local function checkData(...)
			local args = { ... }
			local data = dataTrie:lookupArray(args)
			expect(instanceof(data, Data)).toBe(true)
			expect(data.args).never.toBe(args)
			expect(data.args).toEqual(args)
			expect(data).toBe(dataTrie:lookup(table.unpack(args)))
			-- ROBLOX deviation: there is no implicit arguments param available in Lua
			local arguments = { ... }
			expect(data).toBe(dataTrie:lookupArray(arguments))
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
		expect(Set.new(datas).size).toBe(#datas)
	end)
end)

return {}
