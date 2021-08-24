-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/utils/createOperation.ts
local exports = {}
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

local coreModule = require(script.Parent.Parent.core)
type GraphQLRequest = coreModule.GraphQLRequest
type Operation = coreModule.Operation

local function createOperation(starting: any, operation_: GraphQLRequest): Operation
	local operation = operation_ :: any
	local context = Object.assign({}, starting)
	local function setContext(next: any)
		if typeof(next) == "function" then
			context = Object.assign({}, context, next(context))
		else
			context = Object.assign({}, context, next)
		end
	end

	local function getContext()
		return Object.assign({}, context)
	end

	operation.setContext = setContext
	operation.getContext = getContext

	return operation :: Operation
end

exports.createOperation = createOperation

return exports
