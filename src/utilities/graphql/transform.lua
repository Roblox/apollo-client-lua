-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/3161e31538c33f3aafb18f955fbee0e6e7a0b0c0/src/utilities/graphql/transform.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object
local Boolean = LuauPolyfill.Boolean
local String = LuauPolyfill.String
type Array<T> = LuauPolyfill.Array<T>
type Record<T, U> = { [T]: U }
type Function = (...any) -> any

type TooComplex = any

local exports = {}

local graphqlModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphqlModule.DocumentNode
type SelectionNode = graphqlModule.SelectionNode
type SelectionSetNode = graphqlModule.SelectionSetNode
type OperationDefinitionNode = graphqlModule.OperationDefinitionNode
type FieldNode = graphqlModule.FieldNode
type DirectiveNode = graphqlModule.DirectiveNode
type FragmentDefinitionNode = graphqlModule.FragmentDefinitionNode
type ArgumentNode = graphqlModule.ArgumentNode
type FragmentSpreadNode = graphqlModule.FragmentSpreadNode
type VariableDefinitionNode = graphqlModule.VariableDefinitionNode
type VariableNode = graphqlModule.VariableNode
type InlineFragmentNode = graphqlModule.InlineFragmentNode
local visit = graphqlModule.visit
-- ROBLOX deviation: we need to use REMOVE token cause there is no way to express `null` in Lua
local REMOVE = graphqlModule.REMOVE
local invariant = require(srcWorkspace.jsutils.invariant).invariant

local getFromASTModule = require(script.Parent.getFromAST)
local checkDocument = getFromASTModule.checkDocument
local getOperationDefinition = getFromASTModule.getOperationDefinition
local getFragmentDefinition = getFromASTModule.getFragmentDefinition
local getFragmentDefinitions = getFromASTModule.getFragmentDefinitions
local getMainDefinition = getFromASTModule.getMainDefinition
local filterInPlace = require(script.Parent.Parent.common.filterInPlace).filterInPlace
local storeUtilsModule = require(script.Parent.storeUtils)
local isField = storeUtilsModule.isField
local isInlineFragment = storeUtilsModule.isInlineFragment
-- local fragmentsModule = require(script.Parent.fragments)
-- local createFragmentMap = fragmentsModule.createFragmentMap
local function createFragmentMap(fragments: Array<any>)
	local symTable = {}
	Array.forEach(fragments, function(fragment)
		symTable[fragment.name.value] = fragment
	end)
	return symTable
end
-- type FragmentMap = fragmentsModule.FragmentMap
type FragmentMap = any

-- ROBLOX deviation: predefine functions
local hasDirectivesInSelection
local removeArgumentsFromDocument
local removeFragmentSpreadFromDocument
local getAllFragmentSpreadsFromSelectionSet

export type RemoveNodeConfig<N> = {
	name: string?,
	test: ((_self: RemoveNodeConfig<N>, node: N) -> boolean)?,
	remove: boolean?,
}

export type GetNodeConfig<N> = { name: string?, test: ((node: N) -> boolean)? }

export type RemoveDirectiveConfig = RemoveNodeConfig<DirectiveNode>
export type GetDirectiveConfig = GetNodeConfig<DirectiveNode>
export type RemoveArgumentsConfig = RemoveNodeConfig<ArgumentNode>
export type GetFragmentSpreadConfig = GetNodeConfig<FragmentSpreadNode>
export type RemoveFragmentSpreadConfig = RemoveNodeConfig<FragmentSpreadNode>
export type RemoveFragmentDefinitionConfig = RemoveNodeConfig<FragmentDefinitionNode>
export type RemoveVariableDefinitionConfig = RemoveNodeConfig<VariableDefinitionNode>

local TYPENAME_FIELD: FieldNode = { kind = "Field", name = { kind = "Name", value = "__typename" } }

local function isEmpty(op: OperationDefinitionNode | FragmentDefinitionNode, fragments: FragmentMap): boolean
	return Array.every(op.selectionSet.selections, function(selection)
		return selection.kind == "FragmentSpread" and isEmpty(fragments[selection.name.value], fragments)
	end, nil)
end

local function nullIfDocIsEmpty(doc: DocumentNode): DocumentNode | nil
	if
		isEmpty(
			(
					Boolean.toJSBoolean(getOperationDefinition(doc :: TooComplex))
					and getOperationDefinition(doc :: TooComplex) :: TooComplex
				) or getFragmentDefinition(doc :: TooComplex),
			createFragmentMap(getFragmentDefinitions(doc :: TooComplex)) :: TooComplex
		)
	then
		return nil
	else
		return doc
	end
end

local function getDirectiveMatcher(directives: Array<RemoveDirectiveConfig | GetDirectiveConfig>)
	return function(directive: DirectiveNode)
		return Array.some(directives, function(dir)
			return (Boolean.toJSBoolean(dir.name) and dir.name == directive.name.value)
				or (Boolean.toJSBoolean(dir.test) and dir:test(directive))
		end)
	end
end

local function removeDirectivesFromDocument(
	directives: Array<RemoveDirectiveConfig>,
	doc: DocumentNode
): DocumentNode | typeof(REMOVE)
	local variablesInUse: Record<string, boolean> = {}
	local variablesToRemove: Array<RemoveArgumentsConfig> = {}

	local fragmentSpreadsInUse: Record<string, boolean> = {}
	local fragmentSpreadsToRemove: Array<RemoveFragmentSpreadConfig> = {}

	local modifiedDoc = nullIfDocIsEmpty(visit(doc, {
		Variable = {
			enter = function(_self: any, node: VariableNode, _key: any, parent: any)
				-- Store each variable that's referenced as part of an argument
				-- (excluding operation definition variables), so we know which
				-- variables are being used. If we later want to remove a variable
				-- we'll first check to see if it's being used, before continuing with
				-- the removal.
				if (parent :: VariableDefinitionNode).kind ~= "VariableDefinition" then
					variablesInUse[node.name.value] = true
				end
				return nil
			end,
		},
		Field = {
			enter = function(_self: any, node: FieldNode)
				if Boolean.toJSBoolean(directives) and Boolean.toJSBoolean(node.directives) then
					-- If `remove` is set to true for a directive, and a directive match
					-- is found for a field, remove the field as well.
					local shouldRemoveField = Array.some(directives, function(directive)
						return directive.remove
					end)

					if
						Boolean.toJSBoolean(shouldRemoveField)
						and Boolean.toJSBoolean(node.directives)
						and Array.some(node.directives :: Array<DirectiveNode>, getDirectiveMatcher(directives))
					then
						if Boolean.toJSBoolean(node.arguments) then
							-- Store field argument variables so they can be removed
							-- from the operation definition.
							Array.forEach(node.arguments :: Array<ArgumentNode>, function(arg)
								if arg.value.kind == "Variable" then
									table.insert(variablesToRemove, {
										name = (arg.value :: VariableNode).name.value,
									})
								end
							end)
						end

						if Boolean.toJSBoolean(node.selectionSet) then
							-- Store fragment spread names so they can be removed from the
							-- document.
							Array.forEach(
								getAllFragmentSpreadsFromSelectionSet(node.selectionSet :: SelectionSetNode),
								function(frag)
									table.insert(fragmentSpreadsToRemove, { name = frag.name.value })
								end
							)
						end

						-- ROBLOX deviation: return REMOVE token cause there is no way to express `null` in Lua
						-- Remove the field.
						return REMOVE
					end
				end
				return nil
			end,
		},
		FragmentSpread = {
			enter = function(_self: any, node: FragmentSpreadNode)
				-- Keep track of referenced fragment spreads. This is used to
				-- determine if top level fragment definitions should be removed.
				fragmentSpreadsInUse[node.name.value] = true
			end,
		},
		Directive = {
			enter = function(_self: any, node: DirectiveNode)
				-- If a matching directive is found, remove it.
				if Boolean.toJSBoolean(getDirectiveMatcher(directives)(node)) then
					-- ROBLOX deviation: return REMOVE token cause there is no way to express `null` in Lua
					return REMOVE
				end
				return nil
			end,
		},
	}))

	-- If we've removed fields with arguments, make sure the associated
	-- variables are also removed from the rest of the document, as long as they
	-- aren't being used elsewhere.
	if
		Boolean.toJSBoolean(modifiedDoc)
		and Boolean.toJSBoolean(#filterInPlace(variablesToRemove, function(v)
			return not not Boolean.toJSBoolean(v.name) and not variablesInUse[v.name]
		end))
	then
		modifiedDoc = removeArgumentsFromDocument(variablesToRemove, modifiedDoc :: DocumentNode)
	end

	-- If we've removed selection sets with fragment spreads, make sure the
	-- associated fragment definitions are also removed from the rest of the
	-- document, as long as they aren't being used elsewhere.
	if
		Boolean.toJSBoolean(modifiedDoc)
		and Boolean.toJSBoolean(#filterInPlace(fragmentSpreadsToRemove, function(fs)
			return not not Boolean.toJSBoolean(fs.name) and not fragmentSpreadsInUse[fs.name]
		end))
	then
		modifiedDoc = removeFragmentSpreadFromDocument(fragmentSpreadsToRemove, modifiedDoc :: DocumentNode)
	end

	return modifiedDoc
end
exports.removeDirectivesFromDocument = removeDirectivesFromDocument

local addTypenameToDocument = Object.assign(
	setmetatable({}, {
		__call = function(_self, doc: DocumentNode): DocumentNode
			return visit(checkDocument(doc :: TooComplex), {
				SelectionSet = {
					enter = function(_self, node, _key, parent)
						-- Don't add __typename to OperationDefinitions.
						if
							Boolean.toJSBoolean(parent)
							and (parent :: OperationDefinitionNode).kind == "OperationDefinition"
						then
							return
						end

						-- No changes if no selections.
						local selections = node.selections
						if not Boolean.toJSBoolean(selections) then
							return
						end

						-- If selections already have a __typename, or are part of an
						-- introspection query, do nothing.
						local skip = Array.some(selections, function(selection)
							return isField(selection)
								and (
									((selection :: TooComplex) :: FieldNode).name.value == "__typename"
									or String.lastIndexOf(
											((selection :: TooComplex) :: FieldNode).name.value,
											"__",
											1
										)
										== 1
								)
						end)
						if skip then
							return
						end

						-- If this SelectionSet is @export-ed as an input variable, it should
						-- not have a __typename field (see issue #4691).
						local field = parent :: FieldNode
						if
							isField(field :: TooComplex)
							and Boolean.toJSBoolean(field.directives)
							and Boolean.toJSBoolean(Array.some((field.directives :: Array<DirectiveNode>), function(d)
								return d.name.value == "export"
							end))
						then
							return
						end

						-- Create and return a new SelectionSet with a __typename Field.
						return Object.assign(
							{},
							node,
							{ selections = Array.concat({}, selections, { TYPENAME_FIELD }) }
						)
					end,
				},
			})
		end,
	}) :: any,
	{
		added = function(_self, field: FieldNode): boolean
			return field == TYPENAME_FIELD
		end,
	}
)
exports.addTypenameToDocument = addTypenameToDocument

local connectionRemoveConfig: RemoveDirectiveConfig = {
	test = function(_self: RemoveDirectiveConfig, directive: DirectiveNode)
		local willRemove = directive.name.value == "connection"
		if willRemove then
			if
				not Boolean.toJSBoolean(directive.arguments)
				or Array.some(directive.arguments :: Array<ArgumentNode>, function(arg)
					return arg.name.value == "key"
				end)
			then
				invariant.warn(
					"Removing an @connection directive even though it does not have a key. "
						.. "You may want to use the key parameter to specify a store key."
				)
			end
		end

		return willRemove
	end,
}

local function removeConnectionDirectiveFromDocument(doc: DocumentNode)
	return removeDirectivesFromDocument({ connectionRemoveConfig }, checkDocument(doc :: TooComplex) :: TooComplex)
end
exports.removeConnectionDirectiveFromDocument = removeConnectionDirectiveFromDocument

local function hasDirectivesInSelectionSet(
	directives: Array<GetDirectiveConfig>,
	selectionSet: SelectionSetNode | nil,
	nestedCheck: boolean?
): boolean
	if nestedCheck == nil then
		nestedCheck = true
	end

	return not not Boolean.toJSBoolean(selectionSet)
		and Boolean.toJSBoolean((selectionSet :: SelectionSetNode).selections)
		and Array.some((selectionSet :: SelectionSetNode).selections, function(selection)
			return hasDirectivesInSelection(directives, selection, nestedCheck)
		end)
end

function hasDirectivesInSelection(
	directives: Array<GetDirectiveConfig>,
	selection: SelectionNode,
	nestedCheck: boolean?
): boolean
	if nestedCheck == nil then
		nestedCheck = true
	end

	if not isField(selection :: TooComplex) then
		return true
	end

	if not Boolean.toJSBoolean(selection.directives) then
		return false
	end

	return Array.some(selection.directives :: Array<any>, getDirectiveMatcher(directives))
		or (nestedCheck and hasDirectivesInSelectionSet(directives, (selection :: any).selectionSet, nestedCheck))
end

local function getArgumentMatcher(config: Array<RemoveArgumentsConfig>)
	return function(argument: ArgumentNode)
		return Array.some(config, function(aConfig: RemoveArgumentsConfig)
			return Boolean.toJSBoolean(argument.value)
				and argument.value.kind == "Variable"
				and Boolean.toJSBoolean((argument.value :: VariableNode).name)
				and (
					aConfig.name == (argument.value :: VariableNode).name.value
					or (Boolean.toJSBoolean(aConfig.test) and (aConfig :: any):test(argument))
				)
		end)
	end
end

function removeArgumentsFromDocument(config: Array<RemoveArgumentsConfig>, doc: DocumentNode): DocumentNode | nil
	local argMatcher = getArgumentMatcher(config)

	return nullIfDocIsEmpty(visit(doc, {
		OperationDefinition = {
			enter = function(_self, node)
				return Object.assign({}, node, {
					-- Remove matching top level variables definitions.
					variableDefinitions = Boolean.toJSBoolean(node.variableDefinitions) and Array.filter(
						node.variableDefinitions,
						function(varDef)
							return not Array.some(config, function(arg)
								return arg.name == varDef.variable.name.value
							end)
						end
					) or {},
				})
			end,
		},

		Field = {
			enter = function(_self, node)
				-- If `remove` is set to true for an argument, and an argument match
				-- is found for a field, remove the field as well.
				local shouldRemoveField = Array.some(config, function(argConfig)
					return argConfig.remove
				end)

				if shouldRemoveField then
					local argMatchCount = 0
					if Boolean.toJSBoolean(node.arguments) then
						Array.forEach(node.arguments, function(arg)
							if Boolean.toJSBoolean(argMatcher(arg)) then
								argMatchCount += 1
							end
						end)
					end

					if argMatchCount == 1 then
						return REMOVE
					end
				end
				return nil
			end,
		},

		Argument = {
			enter = function(_self, node)
				-- Remove all matching arguments.
				if Boolean.toJSBoolean(argMatcher(node)) then
					return REMOVE
				end
				return nil
			end,
		},
	}))
end
exports.removeArgumentsFromDocument = removeArgumentsFromDocument

function removeFragmentSpreadFromDocument(
	config: Array<RemoveFragmentSpreadConfig>,
	doc: DocumentNode
): DocumentNode | nil
	local function enter(_self, node: FragmentSpreadNode | FragmentDefinitionNode): typeof(REMOVE) | nil
		if Array.some(config, function(def)
			return def.name == node.name.value
		end) then
			return REMOVE
		end
		return nil
	end

	return nullIfDocIsEmpty(visit(doc, { FragmentSpread = { enter = enter }, FragmentDefinition = { enter = enter } }))
end
exports.removeFragmentSpreadFromDocument = removeFragmentSpreadFromDocument

function getAllFragmentSpreadsFromSelectionSet(selectionSet: SelectionSetNode): Array<FragmentSpreadNode>
	local allFragments: Array<FragmentSpreadNode> = {}
	Array.forEach(selectionSet.selections, function(selection)
		if
			(isField(selection) or isInlineFragment(selection))
			and Boolean.toJSBoolean(((selection :: TooComplex) :: FieldNode | InlineFragmentNode).selectionSet)
		then
			Array.forEach(getAllFragmentSpreadsFromSelectionSet((selection :: any).selectionSet), function(frag)
				table.insert(allFragments, frag)
			end)
		elseif selection.kind == "FragmentSpread" then
			table.insert(allFragments, selection :: FragmentSpreadNode)
		end
	end)
	return allFragments
end

-- If the incoming document is a query, return it as is. Otherwise, build a
-- new document containing a query operation based on the selection set
-- of the previous main operation.
local function buildQueryFromSelectionSet(document: DocumentNode): DocumentNode
	local definition = getMainDefinition(document :: TooComplex)
	local definitionOperation = ((definition :: TooComplex) :: OperationDefinitionNode).operation

	if definitionOperation == "query" then
		-- Already a query, so return the existing document.
		return document
	end

	-- Build a new query using the selection set of the main operation.
	local modifiedDoc = visit(document, {
		OperationDefinition = {
			enter = function(_self, node)
				return Object.assign({}, node, { operation = "query" })
			end,
		},
	})
	return modifiedDoc
end
exports.buildQueryFromSelectionSet = buildQueryFromSelectionSet

-- Remove fields / selection sets that include an @client directive.
local function removeClientSetsFromDocument(document: DocumentNode): DocumentNode | typeof(REMOVE)
	checkDocument(document :: TooComplex)

	local modifiedDoc = removeDirectivesFromDocument({
		{
			test = function(_self: RemoveDirectiveConfig, directive: DirectiveNode)
				return directive.name.value == "client"
			end,
			remove = true,
		},
	}, document)

	--After a fragment definition has had its @client related document
	--sets removed, if the only field it has left is a __typename field,
	--remove the entire fragment operation to prevent it from being fired
	--on the server.
	if Boolean.toJSBoolean(modifiedDoc) then
		modifiedDoc = visit(modifiedDoc, {
			FragmentDefinition = {
				enter = function(_self: any, node: FragmentDefinitionNode)
					if Boolean.toJSBoolean(node.selectionSet) then
						local isTypenameOnly = Array.every(node.selectionSet.selections, function(selection)
							return isField(selection)
								and ((selection :: TooComplex) :: FieldNode).name.value == "__typename"
						end, nil)
						if Boolean.toJSBoolean(isTypenameOnly) then
							return REMOVE
						end
					end
					return nil
				end,
			},
		})
	end

	return modifiedDoc
end
exports.removeClientSetsFromDocument = removeClientSetsFromDocument

return exports
