-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/index.ts
local exports: { [string]: any } = {}
local srcWorkspace = script.Parent
local Packages = srcWorkspace.Parent
local invariant = require(srcWorkspace.jsutils.invariant).invariant
-- local DEV = require(srcWorkspace.utilities).DEV
-- invariant("boolean" == typeof(DEV), DEV)
-- local invariant = require(Packages["ts-invariant"]).invariant
local DEV = require(script.globals).DEV
invariant("boolean" == typeof(DEV), tostring(DEV))
exports.DEV = DEV
-- ROBLOX deviation: add polyfills for JS Primitives
local LuauPolyfill = require(Packages.LuauPolyfill)
local Object = LuauPolyfill.Object
-- local directivesModule = require(script.graphql.directives)
-- exports.DirectiveInfo = directivesModule.DirectiveInfo
-- exports.InclusionDirectives = directivesModule.InclusionDirectives
-- exports.shouldInclude = directivesModule.shouldInclude
-- exports.hasDirectives = directivesModule.hasDirectives
-- exports.hasClientExports = directivesModule.hasClientExports
-- exports.getDirectiveNames = directivesModule.getDirectiveNames
-- exports.getInclusionDirectives = directivesModule.getInclusionDirectives
-- local fragmentsModule = require(script.graphql.fragments)
-- exports.FragmentMap = fragmentsModule.FragmentMap
-- exports.createFragmentMap = fragmentsModule.createFragmentMap
-- exports.getFragmentQueryDocument = fragmentsModule.getFragmentQueryDocument
-- exports.getFragmentFromSelection = fragmentsModule.getFragmentFromSelection
-- local getFromASTModule = require(script.graphql.getFromAST)
-- exports.checkDocument = getFromASTModule.checkDocument
-- exports.getOperationDefinition = getFromASTModule.getOperationDefinition
-- exports.getOperationName = getFromASTModule.getOperationName
-- exports.getFragmentDefinitions = getFromASTModule.getFragmentDefinitions
-- exports.getQueryDefinition = getFromASTModule.getQueryDefinition
-- exports.getFragmentDefinition = getFromASTModule.getFragmentDefinition
-- exports.getMainDefinition = getFromASTModule.getMainDefinition
-- exports.getDefaultValues = getFromASTModule.getDefaultValues
-- local storeUtilsModule = require(script.graphql.storeUtils)
-- exports.StoreObject = storeUtilsModule.StoreObject
-- exports.Reference = storeUtilsModule.Reference
-- exports.StoreValue = storeUtilsModule.StoreValue
-- exports.Directives = storeUtilsModule.Directives
-- exports.VariableValue = storeUtilsModule.VariableValue
-- exports.makeReference = storeUtilsModule.makeReference
-- exports.isDocumentNode = storeUtilsModule.isDocumentNode
-- exports.isReference = storeUtilsModule.isReference
-- exports.isField = storeUtilsModule.isField
-- exports.isInlineFragment = storeUtilsModule.isInlineFragment
-- exports.valueToObjectRepresentation = storeUtilsModule.valueToObjectRepresentation
-- exports.storeKeyNameFromField = storeUtilsModule.storeKeyNameFromField
-- exports.argumentsObjectFromField = storeUtilsModule.argumentsObjectFromField
-- exports.resultKeyNameFromField = storeUtilsModule.resultKeyNameFromField
-- exports.getStoreKeyName = storeUtilsModule.getStoreKeyName
-- exports.getTypenameFromResult = storeUtilsModule.getTypenameFromResult
-- local transformModule = require(script.graphql.transform)
-- exports.RemoveNodeConfig = transformModule.RemoveNodeConfig
-- exports.GetNodeConfig = transformModule.GetNodeConfig
-- exports.RemoveDirectiveConfig = transformModule.RemoveDirectiveConfig
-- exports.GetDirectiveConfig = transformModule.GetDirectiveConfig
-- exports.RemoveArgumentsConfig = transformModule.RemoveArgumentsConfig
-- exports.GetFragmentSpreadConfig = transformModule.GetFragmentSpreadConfig
-- exports.RemoveFragmentSpreadConfig = transformModule.RemoveFragmentSpreadConfig
-- exports.RemoveFragmentDefinitionConfig = transformModule.RemoveFragmentDefinitionConfig
-- exports.RemoveVariableDefinitionConfig = transformModule.RemoveVariableDefinitionConfig
-- exports.addTypenameToDocument = transformModule.addTypenameToDocument
-- exports.buildQueryFromSelectionSet = transformModule.buildQueryFromSelectionSet
-- exports.removeDirectivesFromDocument = transformModule.removeDirectivesFromDocument
-- exports.removeConnectionDirectiveFromDocument =
-- 	transformModule.removeConnectionDirectiveFromDocument
-- exports.removeArgumentsFromDocument = transformModule.removeArgumentsFromDocument
-- exports.removeFragmentSpreadFromDocument = transformModule.removeFragmentSpreadFromDocument
-- exports.removeClientSetsFromDocument = transformModule.removeClientSetsFromDocument
-- local paginationModule = require(script.policies.pagination)
-- exports.concatPagination = paginationModule.concatPagination
-- exports.offsetLimitPagination = paginationModule.offsetLimitPagination
-- exports.relayStylePagination = paginationModule.relayStylePagination
-- local ObservableModule = require(script.observables.Observable)
-- exports.Observable = ObservableModule.Observable
-- exports.Observer = ObservableModule.Observer
-- exports.ObservableSubscription = ObservableModule.ObservableSubscription
-- Object.assign(exports, require(script.common.mergeDeep))
-- Object.assign(exports, require(script.common.cloneDeep))
-- Object.assign(exports, require(script.common.maybeDeepFreeze))
-- Object.assign(exports, require(script.observables.iteration))
-- Object.assign(exports, require(script.observables.asyncMap))
-- Object.assign(exports, require(script.observables.Concast))
-- Object.assign(exports, require(script.observables.subclassing))
Object.assign(exports, require(script.common.arrays))
-- Object.assign(exports, require(script.common.objects))
-- Object.assign(exports, require(script.common.errorHandling))
Object.assign(exports, require(script.common.canUse))
Object.assign(exports, require(script.common.compact))
Object.assign(exports, require(script.common.makeUniqueId))
-- Object.assign(exports, require(script.types.IsStrictlyAny))
return exports
