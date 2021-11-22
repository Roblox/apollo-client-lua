local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local graphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = graphQLModule.DocumentNode
-- ROBLOX deviation: we're implementing TypedDocumentNode inline instead of importing it from a library
-- original: export { TypedDocumentNode } from '@graphql-typed-document-node/core';
-- ROBLOX TODO: a workaround to mimic the default generic type params. Remove when default generic types are supported
export type TypedDocumentNode_<Result> = TypedDocumentNode<Result, { [string]: any }>
export type TypedDocumentNode<Result, Variables> = DocumentNode & { __apiType: ((Variables) -> Result)? }

return {}
