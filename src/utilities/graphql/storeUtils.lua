-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/graphql/storeUtils.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object
local Boolean = LuauPolyfill.Boolean
type Array<T> = LuauPolyfill.Array<T>
type Object = { [string]: any }
local typesModule = require(srcWorkspace.core.types)
type Record<T, U> = typesModule.Record<T, U>

local HttpService = game:GetService("HttpService")

local exports = {}

-- ROBLOX deviation: predeclare functions:
local getStoreKeyName
local stringify

local graphqlModule = require(rootWorkspace.GraphQL)
type DirectiveNode = graphqlModule.DirectiveNode
type FieldNode = graphqlModule.FieldNode
type IntValueNode = graphqlModule.IntValueNode
type FloatValueNode = graphqlModule.FloatValueNode
type StringValueNode = graphqlModule.StringValueNode
type BooleanValueNode = graphqlModule.BooleanValueNode
type ObjectValueNode = graphqlModule.ObjectValueNode
type ListValueNode = graphqlModule.ListValueNode
type EnumValueNode = graphqlModule.EnumValueNode
type NullValueNode = graphqlModule.NullValueNode
type VariableNode = graphqlModule.VariableNode
type InlineFragmentNode = graphqlModule.InlineFragmentNode
type ValueNode = graphqlModule.ValueNode
type SelectionNode = graphqlModule.SelectionNode
type NameNode = graphqlModule.NameNode
type SelectionSetNode = graphqlModule.SelectionSetNode
type DocumentNode = graphqlModule.DocumentNode

local InvariantError = require(srcWorkspace.jsutils.invariant).InvariantError
local isNonNullObject = require(script.Parent.Parent.common.objects).isNonNullObject
-- local fragmentsModule = require(script.Parent.fragments)
-- local FragmentMap = fragmentsModule.FragmentMap
-- local getFragmentFromSelection = fragmentsModule.getFragmentFromSelection

export type Reference = { __ref: string }

local function makeReference(id: string): Reference
	return { __ref = tostring(id) }
end
exports.makeReference = makeReference

local function isReference(obj: any): boolean
	return Boolean.toJSBoolean(obj) and typeof(obj) == "table" and typeof(obj.__ref) == "string"
end
exports.isReference = isReference

export type StoreValue = number | string | Array<string> | Reference | Array<Reference> | nil | Object
export type StoreObject = { __typename: string?, [string]: StoreValue }

local function isDocumentNode(value: any): boolean
	return isNonNullObject(value)
		and (value :: DocumentNode).kind == "Document"
		and Array.isArray((value :: DocumentNode).definitions)
end
exports.isDocumentNode = isDocumentNode

local function isStringValue(value: ValueNode): boolean
	return value.kind == "StringValue"
end

local function isBooleanValue(value: ValueNode): boolean
	return value.kind == "BooleanValue"
end

local function isIntValue(value: ValueNode): boolean
	return value.kind == "IntValue"
end

local function isFloatValue(value: ValueNode): boolean
	return value.kind == "FloatValue"
end

local function isVariable(value: ValueNode): boolean
	return value.kind == "Variable"
end

local function isObjectValue(value: ValueNode): boolean
	return value.kind == "ObjectValue"
end

local function isListValue(value: ValueNode): boolean
	return value.kind == "ListValue"
end

local function isEnumValue(value: ValueNode): boolean
	return value.kind == "EnumValue"
end

local function isNullValue(value: ValueNode): boolean
	return value.kind == "NullValue"
end

local function valueToObjectRepresentation(argObj: any, name: NameNode, value: ValueNode, variables: Object): ()
	if isIntValue(value) or isFloatValue(value) then
		argObj[tostring(name.value)] = tonumber((value :: (IntValueNode | FloatValueNode)).value)
	elseif isBooleanValue(value) or isStringValue(value) then
		argObj[tostring(name.value)] = (value :: (BooleanValueNode | StringValueNode)).value
	elseif isObjectValue(value) then
		local nestedArgObj = {}
		Array.map((value :: ObjectValueNode).fields, function(obj)
			valueToObjectRepresentation(nestedArgObj, obj.name, obj.value, variables)
			return nil
		end)
		argObj[tostring(name.value)] = nestedArgObj
	elseif isVariable(value) then
		local variableValue = (Boolean.toJSBoolean(variables) and variables or ({} :: any))[tostring(
			(value :: VariableNode).name.value
		)]
		argObj[tostring(name.value)] = variableValue
	elseif isListValue(value) then
		argObj[tostring(name.value)] = Array.map((value :: ListValueNode).values, function(listValue)
			local nestedArgArrayObj = {}
			valueToObjectRepresentation(nestedArgArrayObj, name, listValue, variables)
			return (nestedArgArrayObj :: any)[tostring(name.value)]
		end)
	elseif isEnumValue(value) then
		argObj[tostring(name.value)] = (value :: EnumValueNode).value
	elseif isNullValue(value) then
		argObj[tostring(name.value)] = nil
	else
		error(
			InvariantError.new(
				tostring(('The inline argument "%s" of kind "%s"'):format(name.value, (value :: any).kind))
					.. "is not supported. Use variables instead of inline arguments to "
					.. "overcome this limitation."
			)
		)
	end
end
exports.valueToObjectRepresentation = valueToObjectRepresentation

local function storeKeyNameFromField(field: FieldNode, variables: Object): string
	local directivesObj: any = nil
	if Boolean.toJSBoolean(field.directives) then
		directivesObj = {}
		-- ROBLOX deviation: using Array.map instead of forEach
		Array.map(((field.directives :: any) :: Array<DirectiveNode>), function(directive)
			directivesObj[directive.name.value] = {}

			if Boolean.toJSBoolean(directive.arguments) then
				-- ROBLOX deviation: using Array.map instead of forEach
				Array.map(directive.arguments, function(ref)
					local name, value = ref.name, ref.value
					valueToObjectRepresentation(directivesObj[directive.name.value], name, value, variables)
					return nil
				end)
			end
			return nil
		end)
	end

	local argObj: any = nil
	if Boolean.toJSBoolean(field.arguments) and Boolean.toJSBoolean(#field.arguments :: Array<any>) then
		argObj = {}
		-- ROBLOX deviation: using Array.map instead of forEach
		Array.map(field.arguments :: Array<any>, function(ref)
			local name, value = ref.name, ref.value
			valueToObjectRepresentation(argObj, name, value, variables)
			return nil
		end)
	end

	return getStoreKeyName(field.name.value, argObj, directivesObj)
end
exports.storeKeyNameFromField = storeKeyNameFromField

export type Directives = { --[[ ROBLOX TODO: Unhandled node for type: TSIndexSignature ]]
	[string]: { -- ROBLOX note [directiveName: string]
		[string]: any, -- note ROBLOX [argName: string]
	},
}

local KNOWN_DIRECTIVES: Array<string> = {
	"connection",
	"include",
	"skip",
	"client",
	"rest",
	"export",
}

-- ROBLOX deviation: function in Lua can't have additional properties. Using callable table instead
getStoreKeyName = Object.assign(
	setmetatable({}, {
		__call = function(_self, fieldName: string, args: (Record<string, any> | nil)?, directives: Directives?): string
			if
				Boolean.toJSBoolean(args)
				and Boolean.toJSBoolean(directives)
				and Boolean.toJSBoolean((directives :: Directives)["connection"])
				and Boolean.toJSBoolean((directives :: Directives)["connection"]["key"])
			then
				if
					Boolean.toJSBoolean((directives :: Directives)["connection"]["filter"])
					and #((directives :: Directives)["connection"]["filter"] :: Array<string>) > 0
				then
					local filterKeys
					if Boolean.toJSBoolean((directives :: Directives)["connection"]["filter"]) then
						filterKeys = (directives :: Directives)["connection"]["filter"] :: Array<string>
					else
						filterKeys = {}
					end
					Array.sort(filterKeys, nil)

					local filteredArgs = {} :: { [string]: any }
					-- ROBLOX deviation: using Array.map instead of forEach
					Array.map(filterKeys, function(key)
						filteredArgs[key] = (args :: Record<string, any>)[key]
						return nil
					end)

					return ("%s(%s)"):format((directives :: Directives)["connection"]["key"], stringify(filteredArgs))
				else
					return (directives :: Directives)["connection"]["key"]
				end
			end

			local completeFieldName: string = fieldName

			if Boolean.toJSBoolean(args) then
				-- We can't use `JSON.stringify` here since it's non-deterministic,
				-- and can lead to different store key names being created even though
				-- the `args` object used during creation has the same properties/values.
				local stringifiedArgs: string = stringify(args :: Record<string, any>)
				completeFieldName ..= ("(%s)"):format(stringifiedArgs)
			end

			if Boolean.toJSBoolean(directives) then
				-- ROBLOX deviation: using Array.map instead of forEach
				Array.map(Object.keys(directives), function(key)
					if Array.indexOf(KNOWN_DIRECTIVES, key) ~= -1 then
						return
					end
					if
						Boolean.toJSBoolean((directives :: Directives)[key])
						and Boolean.toJSBoolean(#Object.keys((directives :: Directives)[key]))
					then
						completeFieldName ..= ("@%s(%s)"):format(key, stringify((directives :: Directives)[key]))
					else
						completeFieldName ..= ("@%s"):format(key)
					end
					return nil
				end)
			end

			return completeFieldName
		end,
	}),
	{
		setStringify = function(self, s: typeof(stringify))
			local previous = stringify
			stringify = s
			return previous
		end,
	}
)
exports.getStoreKeyName = getStoreKeyName

-- Default stable JSON.stringify implementation. Can be updated/replaced with
-- something better by calling getStoreKeyName.setStringify.
function stringify(value: any): string
	--[[
		ROBLOX deviation:
		HttpService:JSONEncode doesn't take second 'replacer' param
		Stringifying manually with key sorting
		original code:
		return JSON.stringify(value, stringifyReplacer)
	]]
	if not isNonNullObject(value) then
		return HttpService:JSONEncode(value)
	end
	local entries = Array.map(Array.sort(Object.keys(value)), function(key)
		return { key, stringify(value[key]) }
	end)

	if Array.isArray(value) then
		return ([=[[%s]]=]):format(Array.join(
			Array.map(entries, function(entry)
				return entry[2]
			end),
			","
		))
	end
	return ([[{%s}]]):format(Array.join(
		Array.map(entries, function(entry)
			return ([["%s":%s]]):format(entry[1], entry[2])
		end),
		","
	))

	-- Array.join(Array.map(Array.sort(Object.keys(value)), function(key)
	-- 	return ([["%s":%s]]):format(key, stringify(value[key]))
	-- end), ","))
end

-- local function _stringifyReplacer(_key: string, value: any): any
-- 	if isNonNullObject(value) and not Array.isArray(value) then
-- 		value = Array.reduce(Array.sort(Object.keys(value)), function(copy, key)
-- 			copy[key] = value[key]
-- 			return copy
-- 		end, {} :: Record<string, any>)
-- 	end
-- 	return value
-- end

local function argumentsObjectFromField(field: FieldNode | DirectiveNode, variables: Record<string, any>): Object | nil
	if Boolean.toJSBoolean(field.arguments) and Boolean.toJSBoolean(#(field.arguments :: Array<any>)) then
		local argObj: Object = {}
		-- ROBLOX deviation: using Array.map instead of forEach
		Array.map((field.arguments :: Array<any>), function(ref)
			local name, value = ref.name, ref.value
			valueToObjectRepresentation(argObj, name, value, variables)
			return nil
		end)
		return argObj
	end
	return nil
end
exports.argumentsObjectFromField = argumentsObjectFromField

local function resultKeyNameFromField(field: FieldNode): string
	if Boolean.toJSBoolean(field.alias) then
		return field.alias.value
	else
		return field.name.value
	end
end
exports.resultKeyNameFromField = resultKeyNameFromField

-- ROBLOX deviation: not supporting fragments
-- local function getTypenameFromResult(
-- 	result: Record<string, any>,
-- 	selectionSet: SelectionSetNode,
-- 	fragmentMap: FragmentMap
-- ): string | nil
-- 	if typeof(result.__typename) == "string" then
-- 		return result.__typename
-- 	end

-- 	error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: ForOfStatement ]]
-- 	--[[ for (const selection of selectionSet.selections) {
--     if (isField(selection)) {
--       if (selection.name.value === '__typename') {
--         return result[resultKeyNameFromField(selection)];
--       }
--     } else {
--       const typename = getTypenameFromResult(result, getFragmentFromSelection(selection, fragmentMap)!.selectionSet, fragmentMap);

--       if (typeof typename === 'string') {
--         return typename;
--       }
--     }
--   } ]]
-- end
-- exports.getTypenameFromResult = getTypenameFromResult

local function isField(selection: SelectionNode): boolean
	return selection.kind == "Field"
end
exports.isField = isField

local function isInlineFragment(selection: SelectionNode): boolean
	return selection.kind == "InlineFragment"
end
exports.isInlineFragment = isInlineFragment

export type VariableValue = (node: VariableNode) -> any

return exports
