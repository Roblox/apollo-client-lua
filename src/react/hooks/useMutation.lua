-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/hooks/useMutation.ts

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

local typedDocumentNodeModule = require(srcWorkspace.jsutils.typedDocumentNode)
type TypedDocumentNode<Result, Variables> = typedDocumentNodeModule.TypedDocumentNode<Result, Variables>

local typesModule = require(script.Parent.Parent.types.types)
type MutationHookOptions_<TData, TVariables, TContext> = typesModule.MutationHookOptions_<TData, TVariables, TContext>
-- ROBLOX deviation: can't type tuple
type MutationTuple<TData, TVariables, TContext, TCache> = typesModule.MutationTuple<TData, TVariables, TContext, TCache>
local dataModule = require(script.Parent.Parent.data)
local MutationData = dataModule.MutationData
type MutationData<TData, TVariables, TContext, TCache> = dataModule.MutationData<TData, TVariables, TContext, TCache>
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

	local mutationDataRef = useRef(nil :: any)
	local function getMutationDataRef()
		if not mutationDataRef.current then
			mutationDataRef.current = MutationData.new({
				options = updatedOptions,
				context = context,
				result = result,
				setResult = function(_self, ...: any)
					setResult(...)
					return nil
				end,
			})
		end
		return mutationDataRef.current
	end

	local mutationData = getMutationDataRef() :: MutationData<any, any, any, any>
	mutationData:setOptions(updatedOptions)
	mutationData.context = context

	useEffect(function()
		return mutationData:afterExecute()
	end)

	return mutationData:execute(result)
end
exports.useMutation = useMutation

return exports
