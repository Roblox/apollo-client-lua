-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/cache.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array
	local Boolean = LuauPolyfill.Boolean

	type Array<T> = LuauPolyfill.Array<T>

	-- ROBLOX TODO: include in LuauPolyfill
	local function reverse(arr: Array<any>): Array<any>
		local reversed = {}
		for i = #arr, 1, -1 do
			table.insert(reversed, arr[i])
		end
		for i = 1, #arr do
			arr[i] = reversed[i]
		end
		return reversed
	end

	local Cache = require(script.Parent.Parent.cache).Cache
	describe("least-recently-used cache", function()
		it("can hold lots of elements", function()
			local cache = Cache.new()
			local count = 1000000
			for i = 0, count - 1 do
				cache:set(i, tostring(i))
			end

			cache:clean()

			jestExpect((cache :: any).map.size).toBe(count)
			jestExpect(cache:has(0)).toBeTruthy()
			jestExpect(cache:has(count - 1)).toBeTruthy()
			jestExpect(cache:get(43)).toBe("43")
		end)

		it("evicts excess old elements", function()
			local max = 10
			local evicted = {}
			local cache = Cache.new(max, function(value, key)
				jestExpect(tostring(key)).toBe(value)
				table.insert(evicted, key)
			end)

			local count = 100
			local keys = {}
			for i = 0, count - 1 do
				cache:set(i, tostring(i))
				table.insert(keys, i)
			end

			cache:clean()

			jestExpect((cache :: any).map.size).toBe(max)
			jestExpect(#evicted).toBe(count - max)

			for i = count - max, count - 1 do
				jestExpect(cache:has(i)).toBeTruthy()
			end
		end)

		it("can cope with small max values", function()
			local cache = Cache.new(2)
			local function check(...: number)
				local sequence: Array<number> = { ... }

				cache:clean()

				local entry = (cache :: any).newest
				local forwards = {}
				while Boolean.toJSBoolean(entry) do
					table.insert(forwards, entry.key)
					entry = entry.older
				end
				jestExpect(forwards).toEqual(sequence)

				local backwards = {}
				entry = (cache :: any).oldest
				while Boolean.toJSBoolean(entry) do
					table.insert(backwards, entry.key)
					entry = entry.newer
				end
				reverse(backwards)
				jestExpect(backwards).toEqual(sequence)

				Array.map(sequence, function(n)
					jestExpect((cache :: any).map:get(n).value).toBe(n + 1)
				end)

				if #sequence > 0 then
					jestExpect((cache :: any).newest.key).toBe(sequence[1])
					jestExpect((cache :: any).oldest.key).toBe(sequence[#sequence])
				end
			end

			cache:set(1, 2)
			check(1)

			cache:set(2, 3)
			check(2, 1)

			cache:set(3, 4)
			check(3, 2)

			cache:get(2)
			check(2, 3)

			cache:set(4, 5)
			check(4, 2)

			jestExpect(cache:has(1)).toBe(false)
			jestExpect(cache:get(2)).toBe(3)
			jestExpect(cache:has(3)).toBe(false)
			jestExpect(cache:get(4)).toBe(5)

			cache:delete(2)
			check(4)
			cache:delete(4)
			check()

			jestExpect((cache :: any).newest).toBe(nil)
			jestExpect((cache :: any).oldest).toBe(nil)
		end)
	end)
end
