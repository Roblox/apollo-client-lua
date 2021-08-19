-- ROBLOX upstream: https://github.com/testing-library/react-testing-library/blob/v9.4.1/src/__tests__/cleanup.js

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local JestRoblox = require(rootWorkspace.Dev.JestRoblox)
local jestExpect = JestRoblox.Globals.expect
local jest = JestRoblox.Globals.jest

local React = require(rootWorkspace.React)

local ParentModule = require(script.Parent.Parent)
local render = ParentModule.render
local cleanup = ParentModule.cleanup

return function()
	describe("cleanup", function()
		it("cleans up the document", function()
			local spy = jest.fn()
			local divId = "my-div"
			local getFirstChild

			local Test = React.Component:extend("Test")

			function Test:componentWillUnmount()
				jestExpect(getFirstChild()).toBeDefined()
				spy()
			end

			function Test:render()
				return React.createElement("Folder", { Name = divId })
			end

			local renderTable = render(React.createElement(Test, nil))
			getFirstChild = renderTable.getFirstChild
			cleanup()
			jestExpect(getFirstChild()).toBeUndefined()
			jestExpect(spy).toHaveBeenCalledTimes(1)
		end)

		it("cleanup does not error when an element is not a child", function()
			render(React.createElement("TextLabel"), { container = React.createElement("Folder") })
			cleanup()
		end)
	end)
end
