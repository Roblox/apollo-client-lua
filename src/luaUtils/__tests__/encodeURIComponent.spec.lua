return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect

	local encodeURIComponent = require(script.Parent.Parent.encodeURIComponent)

	describe("encodeURIComponent", function()
		it("should encode strings properly", function()
			local set1 = ";,/?:@&=+$" -- Reserved Characters
			local set2 = "-_.!~*'()" -- Unescaped Characters
			local set3 = "#" -- Number Sign
			local set4 = "ABC abc 123" -- Alphanumeric Characters + Space
			local set5 = "#$&+,/:;=?@" -- Custom set

			jestExpect(encodeURIComponent(set1)).toEqual("%3B%2C%2F%3F%3A%40%26%3D%2B%24")
			jestExpect(encodeURIComponent(set2)).toEqual("-_.!~*'()")
			jestExpect(encodeURIComponent(set3)).toEqual("%23")
			jestExpect(encodeURIComponent(set4)).toEqual("ABC%20abc%20123") -- the space gets encoded as %20
			jestExpect(encodeURIComponent(set5)).toEqual("%23%24%26%2B%2C%2F%3A%3B%3D%3F%40")
		end)
	end)
end
