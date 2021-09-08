-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/graphql/getFromAST.ts
local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array, Boolean = LuauPolyfill.Array, LuauPolyfill.Boolean

local graphqlModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphqlModule.DocumentNode
type OperationDefinitionNode = graphqlModule.OperationDefinitionNode
type FragmentDefinitionNode = graphqlModule.FragmentDefinitionNode
-- ROBLOX TODO: remove underscore when required
local _ValueNode = graphqlModule.ValueNode
local invariantModule = require(srcWorkspace.jsutils.invariant)
-- ROBLOX TODO: remove underscore when required
local _invariant = invariantModule.invariant
local _InvariantError = invariantModule.InvariantError
-- ROBLOX TODO: uncomment when available
-- local valueToObjectRepresentation = require(script.Parent.storeUtils).valueToObjectRepresentation

-- local function checkDocument(doc: DocumentNode)
-- 	invariant(
-- 		(function()
-- 			if Boolean.toJSBoolean(doc) then
-- 				return doc.kind == "Document"
-- 			else
-- 				return doc
-- 			end
-- 		end)(),
-- 		[[Expecting a parsed GraphQL document. Perhaps you need to wrap the query string in a "gql" tag? http://docs.apollostack.com/apollo-client/core.html#gql]]
-- 	)
-- 	local operations = doc.definitions
-- 		:filter(function(d)
-- 			return d.kind ~= "FragmentDefinition"
-- 		end)
-- 		:map(function(definition)
-- 			if definition.kind ~= "OperationDefinition" then
-- 				error(
-- 					InvariantError.new(
-- 						('Schema type definitions not allowed in queries. Found: "%s"'):format(
-- 							definition.kind
-- 						)
-- 					)
-- 				)
-- 			end
-- 			return definition
-- 		end)
-- 	invariant(
-- 		operations.length <= 1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]],
-- 		("Ambiguous GraphQL document: contains %s operations"):format(operations.length)
-- 	)
-- 	return doc
-- end
-- exports.checkDocument = checkDocument
-- local function getOperationDefinition(
-- 	doc: DocumentNode
-- ): any --[[ ROBLOX TODO: Unhandled node for type: TSUnionType ]]
-- 	--[[ OperationDefinitionNode | undefined ]]
-- 	checkDocument(doc)
-- 	return doc.definitions:filter(function(definition)
-- 		return definition.kind == "OperationDefinition"
-- 	end)[1 --[[ ROBLOX adaptation: added 1 to array index ]]] :: OperationDefinitionNode
-- end
-- exports.getOperationDefinition = getOperationDefinition
local function getOperationName(doc: DocumentNode): (string | nil)
	local mapped = Array.map(
		Array.filter(doc.definitions, function(definition)
			if Boolean.toJSBoolean(definition.kind == "OperationDefinition") then
				return definition.name
			else
				return definition.kind == "OperationDefinition"
			end
		end),
		function(x: OperationDefinitionNode)
			return (Boolean.toJSBoolean(x) and Boolean.toJSBoolean(x.name) and (x.name :: any).value or nil)
		end
	)

	return Boolean.toJSBoolean(mapped[1]) and mapped[1] or nil
end
exports.getOperationName = getOperationName
-- local function getFragmentDefinitions(
-- 	doc: DocumentNode
-- ): any --[[ ROBLOX TODO: Unhandled node for type: TSArrayType ]]
-- 	--[[ FragmentDefinitionNode[] ]]
-- 	return doc.definitions:filter(function(definition)
-- 		return definition.kind == "FragmentDefinition"
-- 	end) :: any --[[ ROBLOX TODO: Unhandled node for type: TSArrayType ]]
-- 	--[[ FragmentDefinitionNode[] ]]
-- end
-- exports.getFragmentDefinitions = getFragmentDefinitions
-- local function getQueryDefinition(doc: DocumentNode): OperationDefinitionNode
-- 	local queryDef = getOperationDefinition(doc) :: OperationDefinitionNode
-- 	invariant(
-- 		(function()
-- 			if Boolean.toJSBoolean(queryDef) then
-- 				return queryDef.operation == "query"
-- 			else
-- 				return queryDef
-- 			end
-- 		end)(),
-- 		"Must contain a query definition."
-- 	)
-- 	return queryDef
-- end
-- exports.getQueryDefinition = getQueryDefinition
-- local function getFragmentDefinition(doc: DocumentNode): FragmentDefinitionNode
-- 	invariant(
-- 		doc.kind == "Document",
-- 		[[Expecting a parsed GraphQL document. Perhaps you need to wrap the query string in a "gql" tag? http://docs.apollostack.com/apollo-client/core.html#gql]]
-- 	)
-- 	invariant(
-- 		doc.definitions.length <= 1 --[[ ROBLOX CHECK: operator '<=' works only if either both arguments are strings or both are a number ]],
-- 		"Fragment must have exactly one definition."
-- 	)
-- 	local fragmentDef =
-- 		doc.definitions[1 --[[ ROBLOX adaptation: added 1 to array index ]]] :: FragmentDefinitionNode
-- 	invariant(fragmentDef.kind == "FragmentDefinition", "Must be a fragment definition.")
-- 	return fragmentDef :: FragmentDefinitionNode
-- end
-- exports.getFragmentDefinition = getFragmentDefinition
-- local function getMainDefinition(
-- 	queryDoc: DocumentNode
-- ): any --[[ ROBLOX TODO: Unhandled node for type: TSUnionType ]]
-- 	--[[ OperationDefinitionNode | FragmentDefinitionNode ]]
-- 	checkDocument(queryDoc)
-- 	local fragmentDefinition
-- 	error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: ForOfStatement ]]
-- 	--[[ for (let definition of queryDoc.definitions) {
--     if (definition.kind === 'OperationDefinition') {
--       const operation = (definition as OperationDefinitionNode).operation;

--       if (operation === 'query' || operation === 'mutation' || operation === 'subscription') {
--         return (definition as OperationDefinitionNode);
--       }
--     }

--     if (definition.kind === 'FragmentDefinition' && !fragmentDefinition) {
--       // we do this because we want to allow multiple fragment definitions
--       // to precede an operation definition.
--       fragmentDefinition = (definition as FragmentDefinitionNode);
--     }
--   } ]]
-- 	if Boolean.toJSBoolean(fragmentDefinition) then
-- 		return fragmentDefinition
-- 	end
-- 	error(
-- 		InvariantError.new(
-- 			"Expected a parsed GraphQL query with a query, mutation, subscription, or a fragment."
-- 		)
-- 	)
-- end
-- exports.getMainDefinition = getMainDefinition
-- local function getDefaultValues(
-- 	definition: any --[[ ROBLOX TODO: Unhandled node for type: TSUnionType ]]--[[ OperationDefinitionNode | undefined ]]

-- ): Record<string, any>
-- 	local defaultValues = Object:create(nil)
-- 	local defs = (function()
-- 		if Boolean.toJSBoolean(definition) then
-- 			return definition.variableDefinitions
-- 		else
-- 			return definition
-- 		end
-- 	end)()
-- 	if
-- 		Boolean.toJSBoolean((function()
-- 			if Boolean.toJSBoolean(defs) then
-- 				return defs.length
-- 			else
-- 				return defs
-- 			end
-- 		end)())
-- 	then
-- 		defs:forEach(function(def)
-- 			if Boolean.toJSBoolean(def.defaultValue) then
-- 				valueToObjectRepresentation(
-- 					defaultValues,
-- 					def.variable.name,
-- 					def.defaultValue :: ValueNode
-- 				)
-- 			end
-- 		end)
-- 	end
-- 	return defaultValues
-- end
-- exports.getDefaultValues = getDefaultValues
return exports
