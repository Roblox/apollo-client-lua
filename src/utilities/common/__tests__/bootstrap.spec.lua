return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent
	local PackagesWorkspace = rootWorkspace.Parent

	local JestGlobals = require(PackagesWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LuauPolyfill = require(PackagesWorkspace.LuauPolyfill)
	local Array = LuauPolyfill.Array

	local React = require(PackagesWorkspace.React)
	local useState = React.useState
	local bootstrap = require(script.Parent.Parent.bootstrap)

	local DivElement = function()
		local textLabelCount = useState(11)
		return React.createElement(
			"Folder",
			{ Name = "Div" },
			(function()
				local textLabels = {}
				for i = 1, textLabelCount do
					table.insert(
						textLabels,
						React.createElement("TextLabel", { Text = string.format("TextLabel #%s", tostring(i)) })
					)
				end
				return textLabels
			end)()
		)
	end

	describe("bootstrap utility", function()
		local rootInstance
		local stop

		beforeEach(function()
			rootInstance = Instance.new("Folder")
			rootInstance.Name = "GuiRoot"

			stop = bootstrap(rootInstance, DivElement)
		end)

		afterEach(function()
			stop()
		end)

		it("DivElement should not be nil", function()
			jestExpect(DivElement).never.toBe(nil)
		end)

		it("should render 11 TextLabels", function()
			local descendants = rootInstance:GetDescendants()
			local count = #Array.filter(descendants, function(item)
				return item.ClassName == "TextLabel"
			end, nil)
			jestExpect(count).toBe(11)
		end)
	end)
end
