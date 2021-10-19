-- ROBLOX upstream: https://github.com/testing-library/react-testing-library/blob/v9.4.1/src/pure.js

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

local Shared = require(rootWorkspace.Shared)
type ReactElement = Shared.ReactElement

local React = require(rootWorkspace.React)
local ReactRoblox = require(rootWorkspace.ReactRoblox)

-- ROBLOX deviation: not converting react-dom
-- local ReactDOM = require(Packages["react-dom"]).default

-- ROBLOX deviation: not converting these parts of dom testing lib
-- local domModule = require(Packages["@testing-library"].dom)
-- local getQueriesForElement = domModule.getQueriesForElement
-- local prettyDOM = domModule.prettyDOM
-- local dtlFireEvent = domModule.fireEvent
-- local configureDTL = domModule.configure

local actCompatModule = require(script.Parent["act-compat"])
local act = actCompatModule.default

-- ROBLOX deviation: asyncAct is only used with configureDTL, not being used
-- local asyncAct = actCompatModule.asyncAct

local exports = {}

type GenericObject = { [string]: any }

-- ROBLOX deviation: not using configureDTL
-- configureDTL({
-- 	asyncWrapper = function(cb)
-- 		local result
-- 		error("not implemented")		--[[ await asyncAct(async () => {
--       result = await cb();
--     }) ]]
--  --[[ ROBLOX TODO: Unhandled node for type: AwaitExpression ]]
-- 		return result
-- 	end,
-- })

-- ROBLOX deviation: instead of importing getQueriesForElement, we are defining it here
local function getQueriesForElement(rootInstance: Instance)
	return {
		getByText = function(text): any
			local descendants = rootInstance:GetDescendants()
			for index, descendant in ipairs(descendants) do
				if descendant.Text == text then
					return descendant
				end
			end
			return nil
		end,
		getFirstChild = function()
			return rootInstance:GetChildren()[1]
		end,
	}
end

-- ROBLOX deviation: using a table instead of Set
-- local mountedContainers = Set.new()
local mountedContainers = {}

type Container = any

type RenderOptions = {
	-- RenderOptions properties
	container: Container?,
	baseElement: GenericObject?,
	queries: any?,
	hydrate: boolean?,
	wrapper: GenericObject?,
}

local rootInstance: Instance?

local function render(ui: any, renderOptions: RenderOptions?)
	local assertedRenderOptions = (renderOptions :: RenderOptions)
	local container = assertedRenderOptions and assertedRenderOptions.container
	-- ROBLOX deviation: we aren't using baseElement for querying yet
	-- local baseElement = assertedRenderOptions.baseElement or container
	-- ROBLOX deviation: we arent using queries
	-- local queries = assertedRenderOptions.queries
	-- ROBLOX deviation: we aren't using hydrate
	-- local hydrate = assertedRenderOptions and assertedRenderOptions.hydrate or false
	local WrapperComponent = assertedRenderOptions and assertedRenderOptions.wrapper

	--[[
    if (!baseElement) {
      // default to document.body instead of documentElement to avoid output of potentially-large
      // head elements (such as JSS style blocks) in debug output
      baseElement = document.body
    }
  ]]

	if not container then
		rootInstance = Instance.new("Folder") :: Folder;
		(rootInstance :: Folder).Name = "GuiRoot"
		container = ReactRoblox.createLegacyRoot(rootInstance :: Instance)
	else
		rootInstance = container and container._internalRoot and container._internalRoot.containerInfo
	end

	table.insert(mountedContainers, container)

	local wrapUiIfNeeded = function(innerElement)
		if WrapperComponent then
			return React.createElement(WrapperComponent, nil, innerElement)
		else
			return innerElement
		end
	end

	-- ROBLOX deviation: not using hydrate, not fully supported in ReactRoblox
	act(function()
		if container.render ~= nil then
			container:render(wrapUiIfNeeded(ui))
		end
	end)

	return Object.assign(
		{
			container = container,
			-- ROBLOX deviation: we aren't using baseElement for querying
			-- baseElement = baseElement,
			-- ROBLOX deviation: not including debug function, havent converted prettyDOM
			-- debug = function(el)
			-- 	if el == nil then
			-- 		el = baseElement
			-- 	end
			-- 	return (function()
			-- 		if Boolean.toJSBoolean(Array:isArray(el)) then
			-- 			return el:forEach(function(e)
			-- 				return console:log(prettyDOM(e))
			-- 			end)
			-- 		else
			-- 			return console:log(prettyDOM(el))
			-- 		end
			-- 	end)()
			-- end,
			-- ROBLOX deviation: using ReactRoblox's root's unmount function
			unmount = function()
				container:unmount()
			end,
			rerender = function(rerenderUi)
				render(wrapUiIfNeeded(rerenderUi), { container = container })
				-- Intentionally do not return anything to avoid unnecessarily complicating the API.
				-- folks can use all the same utilities we return in the first place that are bound to the container
			end,
			-- ROBLOX deviation: not using asFragment
			-- asFragment = function()
			-- 	if typeof(document.createRange) == "function" then
			-- 		return document:createRange():createContextualFragment(container.innerHTML)
			-- 	end
			-- 	local template = document:createElement("template")
			-- 	template.innerHTML = container.innerHTML
			-- 	return template.content
			-- end,
		},
		-- ROBLOX deviation: using rootInstance for querying
		getQueriesForElement(rootInstance :: Instance)
	)
end
exports.render = render

-- ROBLOX deviation: customizing cleanup functionality for ReactRobloxRoot
-- local function cleanup()
-- 	mountedContainers:forEach(cleanupAtContainer)
-- end

-- local function cleanupAtContainer(container)
-- 	ReactDOM:unmountComponentAtNode(container)
-- 	if container.parentNode == document.body then
-- 		document.body:removeChild(container)
-- 	end
-- 	mountedContainers:delete(container)
-- end

local function cleanup()
	for _, container in ipairs(mountedContainers) do
		if container.unmount ~= nil then
			container:unmount()
		end
	end
	if rootInstance then
		(rootInstance :: Folder).Parent = nil
	end
end
exports.cleanup = cleanup

-- ROBLOX deviation: not using the event functionality
-- local function fireEvent(
-- 	__unhandledIdentifier__ --[[ ROBLOX TODO: Unhandled node for type: RestElement ]]--[[ ...args ]]

-- )
-- 	local returnValue
-- 	ac
-- 	t(function()
-- 		returnValue = dtlFireEvent(
-- 			error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: SpreadElement ]]
-- 			--[[ ...args ]]
-- 		)
-- 	end)
-- 	return returnValue
-- end

-- Object.keys(dtlFireEvent):forEach(function(key)
-- 	fireEvent[tostring(key)] = function(
-- 		__unhandledIdentifier__ --[[ ROBLOX TODO: Unhandled node for type: RestElement ]]	--[[ ...args ]]

-- 	)
-- 		local returnValue
-- 		act(function()
-- 			returnValue = dtlFireEvent[tostring(key)](
-- 				dtlFireEvent,
-- 				error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: SpreadElement ]]
-- 				--[[ ...args ]]
-- 			)
-- 		end)
-- 		return returnValue
-- 	end
-- end)

-- local mouseEnter = fireEvent.mouseEnter
-- local mouseLeave = fireEvent.mouseLeave
-- fireEvent.mouseEnter = function(
-- 	__unhandledIdentifier__ --[[ ROBLOX TODO: Unhandled node for type: RestElement ]]--[[ ...args ]]

-- )
-- 	mouseEnter(
-- 		error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: SpreadElement ]]
-- 		--[[ ...args ]]
-- 	)
-- 	return fireEvent:mouseOver(
-- 		error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: SpreadElement ]]
-- 		--[[ ...args ]]
-- 	)
-- end
-- fireEvent.mouseLeave = function(
-- 	__unhandledIdentifier__ --[[ ROBLOX TODO: Unhandled node for type: RestElement ]]--[[ ...args ]]

-- )
-- 	mouseLeave(
-- 		error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: SpreadElement ]]
-- 		--[[ ...args ]]
-- 	)
-- 	return fireEvent:mouseOut(
-- 		error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: SpreadElement ]]
-- 		--[[ ...args ]]
-- 	)
-- end

-- local select = fireEvent.select
-- fireEvent.select = function(node, init)
-- 	select(node, init)
-- 	node:focus()
-- 	fireEvent:keyUp(node, init)
-- end

Object.assign(exports, require(srcWorkspace.testUtils.dom))

-- ROBLOX deviation: not converting fireEvent
-- exports.fireEvent = fireEvent
exports.act = act

return exports
