-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/writeToStore.ts

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
type Array<T> = LuauPolyfill.Array<T>
type Map<T, V> = LuauPolyfill.Map<T, V>
type Set<T> = LuauPolyfill.Set<T>

--[[
  ROBLOX deviation: no generic params for functions are supported.
  T_ is placeholder for generic T param
]]
type T_ = any

local graphQLModule = require(rootWorkspace.GraphQL)
type SelectionSetNode = graphQLModule.SelectionSetNode
type FieldNode = graphQLModule.FieldNode
type SelectionNode = graphQLModule.SelectionNode

local utilitiesModule = require(srcWorkspace.utilities)
type FragmentMap = utilitiesModule.FragmentMap
type StoreObject = utilitiesModule.StoreObject

local typesModule = require(script.Parent.types)
type ReadMergeModifyContext = typesModule.ReadMergeModifyContext
type MergeTree = typesModule.MergeTree

export type WriteContext = ReadMergeModifyContext & {
	written: { [string]: Array<SelectionSetNode> },
	fragmentMap: FragmentMap?,
	-- General-purpose deep-merge function for use during writes.
	merge: (existing: T_, incoming: T_) -> T_,
	-- General-purpose deep-merge function for use during writes.
	overwrite: boolean,
	incomingById: Map<string, { fields: StoreObject, mergeTree: MergeTree, selections: Set<SelectionNode> }>,
	clientOnly: boolean,
}

return {}
