-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/hooks/useQuery.ts
local exports: { [string]: any } = {}
local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local GraphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = GraphQLModule.DocumentNode

local typedDocumentNodesModule = require(srcWorkspace.jsutils.typedDocumentNode)
type TypedDocumentNode<Result, Variables> = typedDocumentNodesModule.TypedDocumentNode<Result, Variables>

local typesModule = require(script.Parent.Parent.types.types)
type QueryHookOptions<TData, TVariables> = typesModule.QueryHookOptions<TData, TVariables>
type QueryResult<TData, TVariables> = typesModule.QueryResult<TData, TVariables>

local useBaseQuery = require(script.Parent.utils.useBaseQuery).useBaseQuery

local coreModule = require(srcWorkspace.core)
type OperationVariables = coreModule.OperationVariables

local function useQuery(query: DocumentNode | TypedDocumentNode<any, any>, options: QueryHookOptions<any, any>?)
	return useBaseQuery(query, options, false) :: QueryResult<any, any>
end

exports.useQuery = useQuery

return exports
