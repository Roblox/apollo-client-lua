-- ROBLOX no upstream

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

	local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
	local jestExpect = JestRoblox.Globals.expect
	local jest = JestRoblox.Globals.jest

	local reactiveVarsModule = require(script.Parent.Parent.reactiveVars)
	local makeVar = reactiveVarsModule.makeVar

	describe("reactiveVars", function()
		it("should expose functions", function()
			jestExpect(typeof(reactiveVarsModule.cacheSlot)).toBe("table")
			jestExpect(typeof(reactiveVarsModule.forgetCache)).toBe("function")
			jestExpect(typeof(reactiveVarsModule.makeVar)).toBe("function")
			jestExpect(typeof(reactiveVarsModule.recallCache)).toBe("function")
		end)

		it("should return a reactive var from makeVar", function()
			local rv = makeVar("initial value")

			jestExpect(typeof(getmetatable(rv).__call)).toBe("function")
			jestExpect(typeof(rv.onNextChange)).toBe("function")
			jestExpect(typeof(rv.attachCache)).toBe("function")
			jestExpect(typeof(rv.forgetCache)).toBe("function")
		end)

		it("should return a reactive var with initial value", function()
			local rv = makeVar("initial value")

			jestExpect(rv()).toBe("initial value")
		end)

		it("should call a listener when value changes", function()
			local rv = makeVar("initial value")
			local listener = jest.fn()

			rv:onNextChange(listener)
			jestExpect(rv("another value")).toBe("another value")
			jestExpect(listener).toHaveBeenCalledTimes(1)
			jestExpect(listener).toHaveBeenCalledWith("another value")

			listener.mockClear()
			rv:onNextChange(listener)
			jestExpect(rv("yet another value")).toBe("yet another value")
			jestExpect(listener).toHaveBeenCalledTimes(1)
			jestExpect(listener).toHaveBeenCalledWith("yet another value")

			listener.mockClear()
			rv:onNextChange(listener)
			jestExpect(rv("yet another value")).toBe("yet another value")
			jestExpect(listener).toHaveBeenCalledTimes(0)
		end)
	end)
end
