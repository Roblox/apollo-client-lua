-- ROBLOX upstream: https://github.com/testing-library/react-testing-library/blob/v9.4.1/src/__tests__/act.js
return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest

	local React = require(rootWorkspace.React)

	local testUtilsModule = require(srcWorkspace.testUtils.react)(afterEach)
	local render = testUtilsModule.render

	-- ROBLOX deviation: not using fireEvent, screen
	-- local fireEvent = testUtilsModule.fireEvent
	-- local screen = testUtilsModule.screen

	describe("act", function()
		it("render calls useEffect immediately", function()
			local effectCb = jest.fn()
			local function MyUselessComponent()
				React.useEffect(effectCb, nil)
				return nil
			end
			render(React.createElement(MyUselessComponent, nil))
			jestExpect(effectCb).toHaveBeenCalledTimes(1)
		end)

		-- ROBLOX deviation: there aren't ID's in Roblox environment
		-- it("findByTestId returns the element", function()
		-- 	local ref = React.createRef()
		-- 	local findByTestId
		-- 	do
		-- 		local ref = render(React.createElement("div", { ref = ref, ["data-testid"] = "foo" }))
		-- 		findByTestId = ref.findByTestId
		-- 	end
		-- 	expect(
		-- 		error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: AwaitExpression ]]
		-- 		--[[ await findByTestId('foo') ]]
		-- 	).toBe(ref.current)
		-- end)

		-- ROBLOX deviation: not using fireEvent
		-- it("fireEvent triggers useEffect calls", function()
		-- 	local effectCb = jest.fn()
		-- 	local function Counter()
		-- 		React.useEffect(effectCb)
		-- 		local count, setCount = table.unpack(React.useState(0), 1, 2)
		-- 		return React.createElement("button", {
		-- 			onClick = function()
		-- 				return setCount(count + 1)
		-- 			end,
		-- 		}, count)
		-- 	end
		-- 	local buttonNode
		-- 	do
		-- 		local ref = render(React.createElement(Counter, nil))
		-- 		buttonNode = ref.container.firstChild
		-- 	end
		-- 	effectCb:mockClear()
		-- 	fireEvent:click(buttonNode)
		-- 	expect(buttonNode).toHaveTextContent("1")
		-- 	expect(effectCb).toHaveBeenCalledTimes(1)
		-- end)

		-- ROBLOX deviation: hydration isn't supported in RobloxRenderer
		-- it("calls to hydrate will run useEffects", function()
		-- 	local effectCb = jest.fn()
		-- 	local function MyUselessComponent()
		-- 		React.useEffect(effectCb, nil)
		-- 		return nil
		-- 	end
		-- 	render(React.createElement(MyUselessComponent, nil), { hydrate = true })
		-- 	jestExpect(effectCb).toHaveBeenCalledTimes(1)
		-- end)
	end)
end
