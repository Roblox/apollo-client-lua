-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/hooks/useMutation.ts

local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Object = LuauPolyfill.Object

local reactModule = require(rootWorkspace.React)
local useContext = reactModule.useContext
local useState = reactModule.useState
local useRef = reactModule.useRef
local useEffect = reactModule.useEffect
local graphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphQLModule.DocumentNode
--[[
	ROBLOX deviation: we're implementing TypedDocumentNode inline instead of importing it from a library
	original: export { TypedDocumentNode } from '@graphql-typed-document-node/core';
]]
type TypedDocumentNode<Result, Variables> = DocumentNode & { __apiType: ((Variables) -> Result)? }

local typesModule = require(script.Parent.Parent.types.types)
type MutationHookOptions_<TData, TVariables, TContext> = typesModule.MutationHookOptions_<TData, TVariables, TContext>
-- ROBLOX deviation: can't type tuple
type MutationTuple<TData, TVariables, TContext, TCache> = typesModule.MutationTuple<TData, TVariables, TContext, TCache>
local MutationData = require(script.Parent.Parent.data).MutationData
local getApolloContext = require(script.Parent.Parent.context).getApolloContext

local function useMutation<TData, TVariables, TContext, TCache>(
	mutation: DocumentNode | TypedDocumentNode<TData, TContext>,
	options: MutationHookOptions_<TData, TVariables, TContext>?
): MutationTuple<TData, TVariables, TContext, TCache>
	local context = useContext(getApolloContext())
	local result, setResult = useState({ called = false, loading = false })
	local updatedOptions = if Boolean.toJSBoolean(options)
		then Object.assign({}, options, { mutation = mutation })
		else { mutation = mutation }

	local mutationDataRef = useRef(nil)
	local function getMutationDataRef()
		if not Boolean.toJSBoolean(mutationDataRef.current) then
			mutationDataRef.current = MutationData.new({
				options = updatedOptions,
				context = context,
				result = result,
				setResult = function(_self, ...)
					setResult(...)
					return nil
				end,
			})
		end
		return mutationDataRef.current
	end

	local mutationData = getMutationDataRef()
	mutationData:setOptions(updatedOptions)
	mutationData.context = context

	useEffect(function()
		return mutationData:afterExecute()
	end)

	return mutationData:execute(result)
end
exports.useMutation = useMutation

return exports
