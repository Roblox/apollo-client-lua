-- ROBLOX upstream: https://github.com/benjamn/wryware/blob/%40wry/trie%400.3.1/packages/trie/src/tests.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
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
			jestExpect(typeof(Trie.new)).toEqual("function")
		end)

		it("can hold objects weakly", function()
			local trie = Trie.new(true)
			jestExpect((trie :: any).weakness).toEqual(true)
			local obj1 = {}
			jestExpect(trie:lookup(obj1, 2, 3)).toEqual(trie:lookup(obj1, 2, 3))
			local obj2 = {}
			jestExpect(trie:lookup(1, obj2)).never.toBe(trie:lookup(1, obj2, 3))
			-- ROBLOX deviation: WeakMap doesn't have `has` method
			jestExpect((trie :: any).weak:get(obj1) ~= nil).toEqual(true)
			jestExpect((trie :: any).strong:has(obj1)).toEqual(false)
			-- ROBLOX deviation: WeakMap doesn't have `has` method
			jestExpect((trie :: any).strong:get(1).weak:get(obj2) ~= nil).toEqual(true)
			jestExpect((trie :: any).strong:get(1).weak:get(obj2).strong:has(3)).toEqual(true)
		end)

		it("can disable WeakMap", function()
			local trie = Trie.new(false)
			jestExpect((trie :: any).weakness).toEqual(false)
			local obj1 = {}
			jestExpect(trie:lookup(obj1, 2, 3)).toEqual(trie:lookup(obj1, 2, 3))
			local obj2 = {}
			jestExpect(trie:lookup(1, obj2)).never.toBe(trie:lookup(1, obj2, 3))
			jestExpect(typeof((trie :: any).weak)).toEqual("nil")
			jestExpect((trie :: any).strong:has(obj1)).toEqual(true)
			jestExpect((trie :: any).strong:has(1)).toEqual(true)
			jestExpect((trie :: any).strong:get(1).strong:has(obj2)).toEqual(true)
			jestExpect((trie :: any).strong:get(1).strong:get(obj2).strong:has(3)).toEqual(true)
		end)

		it("can produce data types other than Object", function()
			local symbolTrie = Trie.new(true, function(args)
				return Symbol.for_(Array.join(args, "."))
			end)
			local s123 = symbolTrie:lookup(1, 2, 3)
			jestExpect(tostring(s123)).toEqual("Symbol(1.2.3)")
			jestExpect(s123).toEqual(symbolTrie:lookup(1, 2, 3))
			jestExpect(s123).toEqual(symbolTrie:lookupArray({ 1, 2, 3 }))
			local sNull = symbolTrie:lookup()
			jestExpect(tostring(sNull)).toEqual("Symbol()")
			local regExpTrie = Trie.new(true, function(args)
				return RegExp("^(" .. Array.join(args, "|") .. ")$")
			end)
			local rXYZ = regExpTrie:lookup("x", "y", "z")
			jestExpect(rXYZ:test("w")).toEqual(false)
			jestExpect(rXYZ:test("x")).toEqual(true)
			jestExpect(rXYZ:test("y")).toEqual(true)
			jestExpect(rXYZ:test("z")).toEqual(true)
			jestExpect(tostring(rXYZ)).toEqual("/^(x|y|z)$/")

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
				jestExpect(instanceof(data, Data)).toEqual(true)
				jestExpect(data.args).never.toBe(args)
				jestExpect(data.args).toEqual(args) -- assert:deepStrictEqual(data.args, args)
				jestExpect(data).toEqual(dataTrie:lookup(table.unpack(args)))
				-- ROBLOX deviation: 'arguments' is not available in Lua
				jestExpect(data).toEqual(dataTrie:lookupArray(args))
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
			jestExpect(Set.new(datas).size).toEqual(#datas)
		end)
	end)
end
