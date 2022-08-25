-- ROBLOX upstream: https://github.com/testing-library/react-testing-library/blob/v9.4.1/src/__tests__/render.js
return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	-- ROBLOX FIXME: remove if better solution is found
	type FIX_ANALYZE = any

	local React = require(rootWorkspace.React)

	local ReactRoblox = require(rootWorkspace.ReactRoblox)

	local RoactCompat = require(rootWorkspace.Dev.RoactCompat)
	local Portal = RoactCompat.Portal

	local reactTestUtilsModule = require(srcWorkspace.testUtils.react)(afterEach)
	local render = reactTestUtilsModule.render

	describe("render", function()
		it("renders TextLabel", function()
			local ref = React.createRef()
			local getFirstChild = render(React.createElement("TextLabel", { ref = ref })).getFirstChild
			jestExpect(getFirstChild()).toBe(ref.current)
		end)

		it("works great with react portals", function()
			type GreetProps = { greeting: string, subject: string }
			local function Greet(props: GreetProps)
				local greeting = props.greeting
				local subject = props.subject
				return React.createElement("TextLabel", { Text = greeting .. " " .. subject })
			end

			local rootInstance = Instance.new("Folder") :: Folder
			rootInstance.Name = "GuiRoot"

			-- MyPortal class definition
			local MyPortal = React.Component:extend("MyPortal")

			function MyPortal:init()
				self.portalNode = React.createElement("div")
				-- ROBLOX deviation: cant assign properties to a Roblox Instance
				-- self.portalNode.dataset.testid = "my-portal"
			end

			-- ROBLOX deviation: not converting componentDidMount and componentWillUnmount, no document.body

			function MyPortal:render()
				return React.createElement(
					Portal,
					{ target = rootInstance } :: any,
					React.createElement(Greet, { greeting = "Hello", subject = "World" })
				)
			end
			-- end MyPortal class definition

			local renderReturnTable =
				render(React.createElement(MyPortal), { container = ReactRoblox.createLegacyRoot(rootInstance) })
			-- ROBLOX deviation: not converting getByTestId functions
			-- const {getByTestId} = render(<MyPortal />)
			local getByText = renderReturnTable.getByText

			jestExpect(getByText("Hello World")).toBeDefined()
			-- ROBLOX deviation: not testing for presence of portalNode
			--[[
        const portalNode = getByTestId('my-portal')
        expect(portalNode).toBeInTheDocument()
        unmount()
        expect(portalNode).not.toBeInTheDocument()
        ]]
		end)

		-- ROBLOX deviation not supporting baseElement for querying, no document.body
		--[[
      test('returns baseElement which defaults to document.body', () => {
        const {baseElement} = render(<div />)
        expect(baseElement).toBe(document.body)
      })
    ]]

		-- ROBLOX deviation: not supporting asFragment in render conversion
		--[[
			test('supports fragments', () => {
				class Test extends React.Component {
				render() {
					return (
					<div>
						<code>DocumentFragment</code> is pretty cool!
					</div>
					)
				}
				}

				const {asFragment} = render(<Test />)
				expect(asFragment()).toMatchSnapshot()
			})
		]]

		it("renders options.wrapper around node", function()
			local function WrapperComponent(ref)
				local children = ref.children
				-- ROBLOX deviation: can't pass datatest-id to TextLabel
				return React.createElement("Folder", nil, children)
			end
			local getFirstChild
			do
				local ref = render(
					-- ROBLOX deviation: can't pass datatest-id to TextLabel
					React.createElement("TextLabel", { Text = "Inner" }),
					{ wrapper = WrapperComponent :: FIX_ANALYZE }
				)
				getFirstChild = ref.getFirstChild
			end
			local firstChild = getFirstChild()
			-- ROBLOX deviation: checking the structure manually instead of using snapshot comparison
			jestExpect(firstChild.ClassName).toBe("Folder")
			local wrapperChildren = firstChild:GetChildren()
			jestExpect(#wrapperChildren).toBe(1)
			jestExpect(wrapperChildren[1].ClassName).toBe("TextLabel")
			jestExpect((wrapperChildren[1] :: TextLabel).Text).toBe("Inner")
		end)
	end)
end
