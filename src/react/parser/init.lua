-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/parser/index.ts
local exports = {}
local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array, Boolean = LuauPolyfill.Array, LuauPolyfill.Boolean

local graphqlModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphqlModule.DocumentNode
type DefinitionNode = graphqlModule.DefinitionNode
type VariableDefinitionNode = graphqlModule.VariableDefinitionNode
type OperationDefinitionNode = graphqlModule.OperationDefinitionNode
local invariant = require(srcWorkspace.jsutils.invariant).invariant

local Map = LuauPolyfill.Map
type Map<T, V> = LuauPolyfill.Map<T, V>
type Array<T> = LuauPolyfill.Array<T>

local DocumentType = {
	Query = 1,
	Mutation = 2,
	Subscription = 3,
}
export type DocumentType = number

exports.DocumentType = DocumentType

export type IDocumentDefinition = { type: number, name: string, variables: Array<VariableDefinitionNode> }

local cache = Map.new()
local function operationName(type_: DocumentType)
	local name
	--[[ ROBLOX comment: switch statement conversion ]]
	if type_ == DocumentType.Query then
		name = "Query"
	elseif type_ == DocumentType.Mutation then
		name = "Mutation"
	elseif type_ == DocumentType.Subscription then
		name = "Subscription"
	end
	return name
end
exports.operationName = operationName

--[[
	// This parser is mostly used to saftey check incoming documents.
]]
local function parser(document: DocumentNode): IDocumentDefinition
	local cached = (cache :: any):get(document)
	if Boolean.toJSBoolean(cached) then
		return cached
	end
	local variables, type_, name
	invariant(
		(function()
			if Boolean.toJSBoolean(document) then
				return Boolean.toJSBoolean(document.kind)
			else
				return Boolean.toJSBoolean(document)
			end
		end)(),
		("Argument of %s passed to parser was not a valid GraphQL "):format(tostring(document))
			.. "DocumentNode. You may need to use 'graphql-tag' or another method "
			.. "to convert your operation into a document"
	)
	local fragments = Array.filter(document.definitions, function(x: DefinitionNode)
		return x.kind == "FragmentDefinition"
	end, nil)

	local queries = Array.filter(document.definitions, function(x: DefinitionNode)
		return x.kind == "OperationDefinition" and (x :: OperationDefinitionNode).operation == "query"
	end, nil)

	local mutations = Array.filter(document.definitions, function(x: DefinitionNode)
		return x.kind == "OperationDefinition" and (x :: OperationDefinitionNode).operation == "mutation"
	end, nil)

	local subscriptions = Array.filter(document.definitions, function(x: DefinitionNode)
		return x.kind == "OperationDefinition" and (x :: OperationDefinitionNode).operation == "subscription"
	end, nil)

	invariant(
		not Boolean.toJSBoolean(#fragments) and not Boolean.toJSBoolean(#fragments)
			or Boolean.toJSBoolean(Boolean.toJSBoolean(#queries) and #queries or #mutations) and (Boolean.toJSBoolean(
				#queries
			) and #queries or #mutations)
			or #subscriptions,
		"Passing only a fragment to 'graphql' is not yet supported. "
			.. "You must include a query, subscription or mutation as well"
	)
	invariant(
		#queries + #mutations + #subscriptions <= 1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]],
		"react-apollo only supports a query, subscription, or a mutation per HOC. "
			.. ("%s had %s queries, %s "):format(tostring(document), tostring(#queries), tostring(#subscriptions))
			.. ("subscriptions and %s mutations. "):format(tostring(#mutations))
			.. "You can use 'compose' to join multiple operation types to a component"
	)

	if Boolean.toJSBoolean(#queries) then
		type_ = DocumentType.Query
	else
		type_ = DocumentType.Mutation
	end

	if
		Boolean.toJSBoolean((function()
			if not Boolean.toJSBoolean(#queries) then
				return not Boolean.toJSBoolean(#mutations)
			else
				return not Boolean.toJSBoolean(#queries)
			end
		end)())
	then
		type_ = DocumentType.Subscription
	end

	local definitions = (function()
		if Boolean.toJSBoolean(#queries) then
			return queries
		else
			return (function()
				if Boolean.toJSBoolean(#mutations) then
					return mutations
				else
					return subscriptions
				end
			end)()
		end
	end)()

	invariant(
		#definitions == 1,
		("react-apollo only supports one definition per HOC. %s had "):format(tostring(document))
			.. ("%s definitions. "):format(tostring(#definitions))
			.. "You can use 'compose' to join multiple operation types to a component"
	)

	local definition = definitions[1]
	variables = Boolean.toJSBoolean(definition.variableDefinitions) and definition.variableDefinitions or {}
	if
		Boolean.toJSBoolean((function()
			if Boolean.toJSBoolean(definition.name) then
				return definition.name.kind == "Name"
			else
				return definition.name
			end
		end)())
	then
		name = definition.name.value
	else
		name = "data"
	end

	local payload = { name = name, type = type_, variables = variables };
	(cache :: any):set(document, payload)
	return payload
end

exports.parser = parser

return exports
