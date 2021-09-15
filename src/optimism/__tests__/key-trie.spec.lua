-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/key-trie.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

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
			jestExpect(typeof(KeyTrie.new)).toBe("function")
		end)

		it("can hold objects weakly", function()
			local trie = KeyTrie.new(true)
			jestExpect((trie :: any).weakness).toBe(true)
			local obj1 = {}
			jestExpect(trie:lookup(obj1, 2, 3)).toBe(trie:lookup(obj1, 2, 3))
			local obj2 = {}
			jestExpect(trie:lookup(1, obj2)).never.toBe(trie:lookup(1, obj2, 3))
			-- ROBLOX deviation: WeakMap doesn't have `has` method
			jestExpect((trie :: any).weak:get(obj1) ~= nil).toBe(true)
			jestExpect((trie :: any).strong:has(obj1)).toBe(false)
			-- ROBLOX deviation: WeakMap doesn't have `has` method
			jestExpect((trie :: any).strong:get(1).weak:get(obj2) ~= nil).toBe(true)
			jestExpect((trie :: any).strong:get(1).weak:get(obj2).strong:has(3)).toBe(true)
		end)

		it("can disable WeakMap", function()
			local trie = KeyTrie.new(false)
			jestExpect((trie :: any).weakness).toBe(false)
			local obj1 = {}
			jestExpect(trie:lookup(obj1, 2, 3)).toBe(trie:lookup(obj1, 2, 3))
			local obj2 = {}
			jestExpect(trie:lookup(1, obj2)).never.toBe(trie:lookup(1, obj2, 3))
			jestExpect(typeof((trie :: any).weak)).toBe("nil")
			jestExpect((trie :: any).strong:has(obj1)).toBe(true)
			jestExpect((trie :: any).strong:has(1)).toBe(true)
			jestExpect((trie :: any).strong:get(1).strong:has(obj2)).toBe(true)
			jestExpect((trie :: any).strong:get(1).strong:get(obj2).strong:has(3)).toBe(true)
		end)

		it("can produce data types other than Object", function()
			local symbolTrie = KeyTrie.new(true, function(args)
				return Symbol.for_(Array.join(args, "."))
			end)
			local s123 = symbolTrie:lookup(1, 2, 3)
			jestExpect(tostring(s123)).toBe("Symbol(1.2.3)")
			jestExpect(s123).toBe(symbolTrie:lookup(1, 2, 3))
			jestExpect(s123).toBe(symbolTrie:lookupArray({ 1, 2, 3 }))
			local sNull = symbolTrie:lookup()
			jestExpect(tostring(sNull)).toBe("Symbol()")
			local regExpTrie = KeyTrie.new(true, function(args)
				return RegExp("^(" .. Array.join(args, "|") .. ")$")
			end)
			local rXYZ = regExpTrie:lookup("x", "y", "z")
			jestExpect(rXYZ:test("w")).toBe(false)
			jestExpect(rXYZ:test("x")).toBe(true)
			jestExpect(rXYZ:test("y")).toBe(true)
			jestExpect(rXYZ:test("z")).toBe(true)
			jestExpect(tostring(rXYZ)).toBe("/^(x|y|z)$/")

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
				jestExpect(instanceof(data, Data)).toBe(true)
				jestExpect(data.args).never.toBe(args)
				jestExpect(data.args).toEqual(args)
				jestExpect(data).toBe(dataTrie:lookup(table.unpack(args)))
				-- ROBLOX deviation: there is no implicit arguments param available in Lua
				local arguments = { ... }
				jestExpect(data).toBe(dataTrie:lookupArray(arguments))
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
			jestExpect(Set.new(datas).size).toBe(#datas)
		end)
	end)
end
