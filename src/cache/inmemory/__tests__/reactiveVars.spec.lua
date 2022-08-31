-- ROBLOX no upstream
local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest

local reactiveVarsModule = require(script.Parent.Parent.reactiveVars)
local makeVar = reactiveVarsModule.makeVar

describe("reactiveVars", function()
	it("should expose functions", function()
		expect(typeof(reactiveVarsModule.cacheSlot)).toBe("table")
		expect(typeof(reactiveVarsModule.forgetCache)).toBe("function")
		expect(typeof(reactiveVarsModule.makeVar)).toBe("function")
		expect(typeof(reactiveVarsModule.recallCache)).toBe("function")
	end)

	it("should return a reactive var from makeVar", function()
		local rv = makeVar("initial value")

		expect(typeof(getmetatable(rv).__call)).toBe("function")
		expect(typeof(rv.onNextChange)).toBe("function")
		expect(typeof(rv.attachCache)).toBe("function")
		expect(typeof(rv.forgetCache)).toBe("function")
	end)

	it("should return a reactive var with initial value", function()
		local rv = makeVar("initial value")

		expect(rv()).toBe("initial value")
	end)

	it("should call a listener when value changes", function()
		local rv = makeVar("initial value")
		local listener = jest.fn()

		rv:onNextChange(listener)
		expect(rv("another value")).toBe("another value")
		expect(listener).toHaveBeenCalledTimes(1)
		expect(listener).toHaveBeenCalledWith("another value")

		listener.mockClear()
		rv:onNextChange(listener)
		expect(rv("yet another value")).toBe("yet another value")
		expect(listener).toHaveBeenCalledTimes(1)
		expect(listener).toHaveBeenCalledWith("yet another value")

		listener.mockClear()
		rv:onNextChange(listener)
		expect(rv("yet another value")).toBe("yet another value")
		expect(listener).toHaveBeenCalledTimes(0)
	end)
end)

return {}
