-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/index.ts

local exports = {}
local srcWorkspace = script.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

local invariant = require(srcWorkspace.jsutils.invariant).invariant
local DEV = require(srcWorkspace.utilities).DEV
invariant("boolean" == typeof(DEV), tostring(DEV))

local contextModule = require(script.context)
exports.ApolloProvider = contextModule.ApolloProvider
exports.ApolloConsumer = contextModule.ApolloConsumer
exports.getApolloContext = contextModule.getApolloContext
exports.resetApolloContext = contextModule.resetApolloContext
exports.ApolloContextValue = contextModule.ApolloContextValue

Object.assign(exports, require(script.hooks))

local parserModule = require(script.parser)
export type DocumentType = parserModule.DocumentType
export type IDocumentDefinition = parserModule.IDocumentDefinition
exports.operationName = parserModule.operationName
exports.parser = parserModule.parser

local typesModule = require(script.types.types)
Object.assign(exports, typesModule)
-- ROBLOX TODO: export more types as required
export type QueryFunctionOptions<TData, TVariables> = typesModule.QueryFunctionOptions<TData, TVariables>

return exports
