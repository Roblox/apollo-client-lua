return function()
	local srcWorkspace = script.Parent.Parent.Parent
	local Packages = srcWorkspace.Parent
	local JestRoblox = require(Packages.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect
	local RegExp = require(Packages.LuauRegExp)
	local equal = require(script.Parent.Parent.equal)
	describe("equal", function()
		it("should return false if types don't match", function()
			jestExpect(equal(1, "1")).toEqual(false)
			jestExpect(equal(1, true)).toEqual(false)
			jestExpect(equal({}, "table")).toEqual(false)
			jestExpect(equal(1, nil)).toEqual(false)
		end)
		it("should return true when compared to itself", function()
			local a = { "foo" }
			local b = 1
			local c = false
			local d = { foo = "foo", bar = "bar" }
			local e = d
			jestExpect(equal(a, a)).toEqual(true)
			jestExpect(equal(b, b)).toEqual(true)
			jestExpect(equal(c, c)).toEqual(true)
			jestExpect(equal(d, d)).toEqual(true)
			jestExpect(equal(d, e)).toEqual(true)
		end)

		it("should compare nested tables", function()
			local a = { foo = "foo", bar = "bar", baz = { fizz = "fizz", fuzz = "fuzz" } }
			local b = { foo = "foo", bar = "bar", baz = { fizz = "fizz", fuzz = "fuzz" } }
			local c = { foo = "foo", bar = "bar", baz = { fizz = "fizz", fuzz = "fail" } }
			local d = { foo = "foo", bar = "bar", baz = { fizz = "fizz", fail = "fuzz" } }
			local e = { foo = "foo", bar = "bar", baz = { fizz = "fizz" } }
			jestExpect(equal(a, b)).toEqual(true)
			jestExpect(equal(a, c)).toEqual(false)
			jestExpect(equal(a, d)).toEqual(false)
			jestExpect(equal(a, e)).toEqual(false)
		end)

		it("should compare array-like tables", function()
			local a = { "foo", "bar", "baz" }
			local b = { "foo", "bar", "baz" }
			local c = { "bar", "foo", "baz" }
			jestExpect(equal(a, b)).toEqual(true)
			jestExpect(equal(a, c)).toEqual(false)
		end)

		it("should fail if type is not supported and using '==' is not enough", function()
			local function a() end
			local b = a
			local function c() end
			jestExpect(equal(a, b)).toEqual(true)
			jestExpect(function()
				equal(a, c)
			end).toThrowError(RegExp("unhandled equality check"))
		end)

		it("should return false table items count differs", function()
			local a = { "foo", "bar" }
			local b = { "foo" }
			local c = { foo = "foo" }
			local d = { foo = "foo", bar = "bar" }
			local e = { foo = "foo", bar = "bar", baz = "baz" }
			jestExpect(equal(a, b)).toEqual(false)
			jestExpect(equal(c, d)).toEqual(false)
			jestExpect(equal(d, e)).toEqual(false)
		end)
	end)
end
