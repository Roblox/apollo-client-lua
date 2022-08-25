-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/hooks/__tests__/useReactiveVar.test.tsx
return function()
	local srcWorkspace = script.Parent.Parent.Parent.Parent
	local rootWorkspace = srcWorkspace.Parent
	local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
	local Array, console, setTimeout = LuauPolyfill.Array, LuauPolyfill.console, LuauPolyfill.setTimeout

	type Array<T> = LuauPolyfill.Array<T>

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect
	local jest = JestGlobals.jest

	-- ROBLOX deviation: setTimeout currently operates at minimum 30Hz rate. Any lower number seems to be treated as 0
	local TICK = 1000 / 30

	local Promise = require(rootWorkspace.Promise)

	local React = require(rootWorkspace.React)
	local StrictMode = React.StrictMode
	local useEffect = React.useEffect

	local testingLibraryModule = require(srcWorkspace.testUtils.react)(afterEach)
	local render = testingLibraryModule.render
	local wait_ = testingLibraryModule.wait
	local act = testingLibraryModule.act

	local itAsync = require(srcWorkspace.testing).itAsync

	-- ROBLOX deviation: import from cache instead of core
	local makeVar = require(srcWorkspace.cache).makeVar

	local useReactiveVar = require(script.Parent.Parent.useReactiveVar).useReactiveVar

	describe("useReactiveVar Hook", function()
		itAsync(it)("works with one component", function(resolve, reject)
			Promise.resolve():andThen(function()
				local counterVar = makeVar(0)
				local renderCount = 0

				local function Component()
					local count = useReactiveVar(counterVar)

					useEffect(function()
						renderCount += 1
						local condition_ = renderCount
						if condition_ == 1 then
							jestExpect(count).toBe(0)
							counterVar(count + 1)
						elseif condition_ == 2 then
							jestExpect(count).toBe(1)
							counterVar(counterVar() + 2)
						elseif condition_ == 3 then
							jestExpect(count).toBe(3)
						else
							reject(("too many (%s) renders"):format(tostring(renderCount)))
						end
					end)
					return nil
				end

				render(React.createElement(Component, nil))

				return wait_(function()
					jestExpect(renderCount).toBe(3)
					jestExpect(counterVar()).toBe(3)
				end):andThen(resolve, reject)
			end)
		end)

		itAsync(it)("works when two components share a variable", function(resolve, reject)
			Promise.resolve():andThen(function()
				-- ROBLOX deviation: predefine variable
				local Child

				local counterVar = makeVar(0)

				local parentRenderCount = 0

				local function Parent()
					local count = useReactiveVar(counterVar)
					parentRenderCount += 1
					local condition_ = parentRenderCount
					if condition_ == 1 then
						jestExpect(count).toBe(0)
					elseif condition_ == 2 then
						jestExpect(count).toBe(1)
					elseif condition_ == 3 then
						jestExpect(count).toBe(11)
					else
						reject(("too many (%s) parent renders"):format(tostring(parentRenderCount)))
					end
					return React.createElement(Child, nil)
				end

				local childRenderCount = 0

				function Child()
					local count = useReactiveVar(counterVar)

					childRenderCount += 1
					local condition_ = childRenderCount
					if condition_ == 1 then
						jestExpect(count).toBe(0)
					elseif condition_ == 2 then
						jestExpect(count).toBe(1)
					elseif condition_ == 3 then
						jestExpect(count).toBe(11)
					else
						reject(("too many (%s) child renders"):format(tostring(childRenderCount)))
					end

					return nil
				end

				render(React.createElement(Parent, nil))

				wait_(function()
					jestExpect(parentRenderCount).toBe(1)
					jestExpect(childRenderCount).toBe(1)
				end):expect()

				jestExpect(counterVar()).toBe(0)
				act(function()
					counterVar(1)
				end)

				wait_(function()
					jestExpect(parentRenderCount).toBe(2)
					jestExpect(childRenderCount).toBe(2)
				end):expect()

				jestExpect(counterVar()).toBe(1)
				act(function()
					counterVar(counterVar() + 10)
				end)

				wait_(function()
					jestExpect(parentRenderCount).toBe(3)
					jestExpect(childRenderCount).toBe(3)
				end):expect()

				jestExpect(counterVar()).toBe(11)

				resolve()
			end)
		end)

		itAsync(it)("does not update if component has been unmounted", function(resolve, reject)
			Promise.resolve():andThen(function()
				local counterVar = makeVar(0)
				local renderCount = 0
				local attemptedUpdateAfterUnmount = false
				local unmount

				local function Component()
					-- ROBLOX deviation: predefine variable

					local count = useReactiveVar(counterVar)

					useEffect(function()
						if count < 3 then
							jestExpect(count).toBe((function()
								local result = renderCount
								renderCount += 1
								return result
							end)())
							counterVar(count + 1)
						end

						if count == 3 then
							jestExpect(count).toBe(3)
							setTimeout(function()
								unmount()
								setTimeout(
									function()
										counterVar(counterVar() * 2)
										attemptedUpdateAfterUnmount = true
									end,
									-- ROBLOX deviation: use min interval
									10 * TICK
								)
								-- ROBLOX deviation: use min interval
							end, 10 * TICK)
						end
					end)

					return nil
				end

				-- To detect updates of unmounted components, we have to monkey-patch
				-- the console.error method.
				local consoleErrorArgs: Array<Array<any>> = {}

				local error_ = console.error
				console.error = function(...)
					local args = { ... }
					Array.forEach(args, function(arg)
						table.insert(consoleErrorArgs, arg)
					end)
					return error_(args)
				end

				unmount = render(React.createElement(Component, nil)).unmount

				return wait_(function()
						jestExpect(attemptedUpdateAfterUnmount).toBe(true)
					end)
					:andThen(function()
						jestExpect(renderCount).toBe(3)
						jestExpect(counterVar()).toBe(6)
						jestExpect(consoleErrorArgs).toEqual({})
					end) -- ROBLOX deviation: finally works different in Lua, replacing with then catch blocks
					:andThen(function()
						console.error = error_
					end)
					:catch(function(err)
						console.error = error_
						error(err)
					end)
					:andThen(resolve, reject)
			end)
		end)

		describe("useEffect", function()
			itAsync(it)("works if updated higher in the component tree", function(resolve, reject)
				Promise.resolve():andThen(function()
					local counterVar = makeVar(0)

					local function ComponentOne()
						local count = useReactiveVar(counterVar)

						useEffect(function()
							counterVar(1)
						end, {})

						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = count })
					end

					local function ComponentTwo()
						local count = useReactiveVar(counterVar)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = count })
					end

					local getAllByText = render(
						React.createElement(
							React.Fragment,
							nil,
							React.createElement(ComponentOne, nil),
							React.createElement(ComponentTwo, nil)
						)
					).getAllByText

					wait_(function()
						jestExpect(getAllByText("1")).toHaveLength(2)
					end):expect()

					resolve()
				end)
			end)

			itAsync(it)("works if updated lower in the component tree", function(resolve, reject)
				Promise.resolve():andThen(function()
					local counterVar = makeVar(0)

					local function ComponentOne()
						local count = useReactiveVar(counterVar)

						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = count })
					end

					local function ComponentTwo()
						local count = useReactiveVar(counterVar)

						useEffect(function()
							counterVar(1)
						end, {})

						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = count })
					end

					local getAllByText = render(
						React.createElement(
							React.Fragment,
							nil,
							React.createElement(ComponentOne, nil),
							React.createElement(ComponentTwo, nil)
						)
					).getAllByText

					wait_(function()
						jestExpect(getAllByText("1")).toHaveLength(2)
					end):expect()

					resolve()
				end)
			end)

			itAsync(it)("works with strict mode", function(resolve, reject)
				Promise.resolve():andThen(function()
					local counterVar = makeVar(0)

					local mock = jest.fn()

					local function Component()
						local count = useReactiveVar(counterVar)
						useEffect(function()
							mock(count)
						end, { count })

						useEffect(function()
							Promise.resolve():andThen(function()
								counterVar(counterVar() + 1)
							end)
						end, {})

						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = "" })
					end

					render(React.createElement(StrictMode, nil, React.createElement(Component, nil)))

					wait_(function()
						jestExpect(mock).toHaveBeenCalledWith(1)
					end):expect()

					resolve()
				end)
			end)

			itAsync(it)("works with multiple synchronous calls", function(resolve, reject)
				Promise.resolve():andThen(function()
					local counterVar = makeVar(0)

					local function Component()
						local count = useReactiveVar(counterVar)
						-- ROBLOX deviation: using text element instead of div
						return React.createElement("TextLabel", { Text = count })
					end

					local getAllByText = render(React.createElement(Component, nil)).getAllByText

					Promise.resolve():andThen(function()
						counterVar(1)
						counterVar(2)
						counterVar(3)
						counterVar(4)
						counterVar(5)
						counterVar(6)
						counterVar(7)
						counterVar(8)
						counterVar(9)
						counterVar(10)
					end)

					wait_(function()
						jestExpect(getAllByText("10")).toHaveLength(1)
					end):expect()

					resolve()
				end)
			end)
		end)
	end)
end
