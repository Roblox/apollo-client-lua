-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/hooks/utils/useBaseQuery.ts
local exports = {}
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local Promise = require(rootWorkspace.Promise)
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean, Object = LuauPolyfill.Boolean, LuauPolyfill.Object

local React = require(rootWorkspace.React)
local useContext = React.useContext
local useEffect = React.useEffect
local useReducer = React.useReducer
local useRef = React.useRef

local GraphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = GraphQLModule.DocumentNode

local typedDocumentNodeModule = require(srcWorkspace.jsutils.typedDocumentNode)
type TypedDocumentNode<Result, Variables> = typedDocumentNodeModule.TypedDocumentNode<Result, Variables>

local typesModule = require(script.Parent.Parent.Parent.types.types)
type QueryHookOptions<TData, TVariables> = typesModule.QueryHookOptions<TData, TVariables>
type QueryDataOptions<TData, TVariables> = typesModule.QueryDataOptions<TData, TVariables>
type QueryTupleAsReturnType<TData, TVariables> = typesModule.QueryTupleAsReturnType<TData, TVariables>
type QueryResult<TData, TVariables> = typesModule.QueryResult<TData, TVariables>
local QueryData = require(script.Parent.Parent.Parent.data).QueryData
local useDeepMemo = require(script.Parent.useDeepMemo).useDeepMemo
local coreModule = require(script.Parent.Parent.Parent.Parent.core)
type OperationVariables = coreModule.OperationVariables
local getApolloContext = require(script.Parent.Parent.Parent.context).getApolloContext

-- ROBLOX deviation: error is triggered because array with nil values has a different count
local NIL = { __value = "nil placeholder" }

-- <TData, TVariables>
local function useBaseQuery(
	query: DocumentNode | TypedDocumentNode<any, any>,
	options: QueryHookOptions<any, any>?,
	lazy: boolean?
)
	if lazy == nil then
		lazy = false
	end
	local context = useContext(getApolloContext())
	local tick, forceUpdate = useReducer(function(x: any)
		return x + 1
	end, 0)
	local updatedOptions = Boolean.toJSBoolean(options) and Object.assign({}, options, { query = query })
		or { query = query }
	local queryDataRef = useRef(nil)
	local queryData
	queryData = Boolean.toJSBoolean(queryDataRef.current) and queryDataRef.current
		or (function()
			queryDataRef.current = QueryData.new({
				options = updatedOptions :: QueryDataOptions<any, any>,
				context = context,
				onNewData = function(_self)
					if not Boolean.toJSBoolean(queryData:ssrInitiated()) then
						-- // When new data is received from the `QueryData` object, we want to
						-- // force a re-render to make sure the new data is displayed. We can't
						-- // force that re-render if we're already rendering however so to be
						-- // safe we'll trigger the re-render in a microtask. In case the
						-- // component gets unmounted before this callback fires, we re-check
						-- // queryDataRef.current.isMounted before calling forceUpdate().
						Promise.delay(0):andThen(function()
							if Boolean.toJSBoolean(queryDataRef.current) and queryDataRef.current.isMounted then
								-- ROBLOX deviation: Roact forces us to provide a value here
								return forceUpdate(nil)
							end
							return
						end)
					else
						-- // If we're rendering on the server side we can force an update at
						-- // any point.
						-- ROBLOX deviation: Roact forces us to provide a value here
						forceUpdate(nil)
					end
				end,
			})
			return queryDataRef.current
		end)()

	queryData:setOptions(updatedOptions)
	queryData.context = context

	-- `onError` and `onCompleted` callback functions will not always have a
	-- stable identity, so we'll exclude them from the memoization key to
	-- prevent `afterExecute` from being triggered un-necessarily.
	local memo = {
		options = Object.assign({}, updatedOptions, { onError = Object.None, onCompleted = Object.None }) :: QueryHookOptions<any, any>,
		context = context,
		tick = tick,
	}

	local result = useDeepMemo(function()
		return (function()
			if Boolean.toJSBoolean(lazy) then
				return queryData:executeLazy()
			else
				return queryData:execute()
			end
		end)()
	end, memo)
	local queryResult = (function()
		if Boolean.toJSBoolean(lazy) then
			return result[2] --result as QueryTuple<TData, TVariables>
		else
			return result :: QueryResult<any, any>
		end
	end)()
	useEffect(function()
		return function()
			return queryData:cleanup()
		end
	end, {})

	useEffect(function()
		return queryData:afterExecute({ lazy = lazy })
	end, {
		queryResult.loading ~= nil and queryResult.loading or NIL,
		queryResult.networkStatus ~= nil and queryResult.networkStatus or NIL,
		queryResult.error ~= nil and queryResult.error or NIL,
		queryResult.data ~= nil and queryResult.data or NIL,
	})
	return result
end
exports.useBaseQuery = useBaseQuery
return exports
