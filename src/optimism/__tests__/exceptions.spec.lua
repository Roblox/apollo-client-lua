-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/exceptions.ts

local rootWorkspace = script.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Error = LuauPolyfill.Error

local wrap = require(script.Parent.Parent).wrap

describe("exceptions", function()
	it("should be cached", function()
		local error_ = Error.new("expected")
		local threw = false
		local function throwOnce()
			if not threw then
				threw = true
				error(error_)
			end
			return "already threw"
		end

		local wrapper = wrap(throwOnce) :: any

		xpcall(function()
			wrapper()
			error(Error.new("unreached"))
		end, function(e)
			expect(e).toBe(error_)
		end)

		xpcall(function()
			wrapper()
			error(Error.new("unreached"))
		end, function(e)
			expect(e).toBe(error_)
		end)

		wrapper:dirty()
		expect(wrapper()).toBe("already threw")
		expect(wrapper()).toBe("already threw")
		wrapper:dirty()
		expect(wrapper()).toBe("already threw")
	end)

	it("should memoize a throwing fibonacci function", function()
		local fib: any
		fib = wrap(function(n: number)
			if n < 2 then
				-- ROBLOX deviation: we can't throw bare-bone number. We need to at least wrap them in an Array
				error({ n })
			end
			local ok, minusOne: any = pcall(function()
				fib(n - 1)
				return nil
			end)
			if not ok then
				local ok2, minusTwo: any = pcall(function()
					fib(n - 2)
					return nil
				end)
				if not ok2 then
					-- ROBLOX deviation: we can't throw bare-bone number. We need to at least wrap them in an Array
					error({ minusOne[1] + minusTwo[1] })
				end
			end
			error(Error.new("unreached"))
			return nil
		end) :: any

		local function check(n: number, expected: number)
			local ok, result: any = pcall(function()
				fib(n)
				error(Error.new("unreached"))
				return nil
			end)
			if not ok then
				-- ROBLOX deviation: we can't throw bare-bone number. We need to at least wrap them in an Array
				expect(result[1]).toBe(expected)
			end
		end

		-- ROBLOX deviation: we can't calculate more than fib(48) because of Stack Oveflow 🤯
		-- check(78, 8944394323791464)
		-- check(68, 72723460248141)
		-- check(58, 591286729879)
		check(48, 4807526976)
		fib:dirty(28)
		check(38, 39088169)
		check(28, 317811)
		check(18, 2584)
		check(8, 21)
		fib:dirty(20)
		-- check(78, 8944394323791464)
		check(10, 55)
	end)
end)

return {}
