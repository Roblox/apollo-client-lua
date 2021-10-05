-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/policies/pagination.ts
local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object
type Array<T> = LuauPolyfill.Array<T>
type Object = LuauPolyfill.Object
type Record<T, U> = { [T]: U }

-- ROBLOX deviation: tslib package not available.
local function __rest(obj, props)
	local removed = {}
	Array.forEach(props, function(prop)
		removed[prop] = Object.None
	end)
	return Object.assign({}, obj, removed)
end

local cacheModule = require(script.Parent.Parent.Parent.cache)

type FieldPolicy<TExisting, TIncoming, TReadResult> = cacheModule.FieldPolicy<TExisting, TIncoming, TReadResult>
type Reference = cacheModule.Reference

local mergeDeep = require(script.Parent.Parent.common.mergeDeep).mergeDeep
type KeyArgs = typeof((({} :: any) :: FieldPolicy<any, any, any>).keyArgs)

-- ROBLOX TODO: replace when function generics is available
type T_ = any
type TNode_ = any

-- ROBLOX deviation: predefine variables
local getExtras
local makeEmptyData
local notExtras

-- A very basic pagination field policy that always concatenates new
-- results onto the existing array, without examining options.args.
local function concatPagination(keyArgs: KeyArgs?): FieldPolicy<Array<T_>, any, any>
	if keyArgs == nil then
		keyArgs = false
	end
	return {
		keyArgs = keyArgs,
		merge = function(_self, existing, incoming)
			return Boolean.toJSBoolean(existing) and Array.concat({}, existing, incoming) or incoming
		end,
	}
end
exports.concatPagination = concatPagination

-- A basic field policy that uses options.args.{offset,limit} to splice
-- the incoming data into the existing array. If your arguments are called
-- something different (like args.{start,count}), feel free to copy/paste
-- this implementation and make the appropriate changes.
local function offsetLimitPagination(keyArgs: KeyArgs?): FieldPolicy<Array<T_>, any, any>
	if keyArgs == nil then
		keyArgs = false
	end

	return {
		keyArgs = keyArgs,
		merge = function(_self, existing, incoming, ref)
			local args = ref.args
			local merged
			if Boolean.toJSBoolean(existing) then
				merged = Array.slice(existing, 1)
			else
				merged = {}
			end

			if Boolean.toJSBoolean(args) then
				-- Assume an offset of 0 if args.offset omitted.
				local offset
				if args.offset == nil then
					offset = 0
				else
					offset = args.offset
				end

				for i = 1, #incoming, 1 do
					merged[offset + i] = incoming[i]
				end
			else
				-- It's unusual (probably a mistake) for a paginated field not
				-- to receive any arguments, so you might prefer to throw an
				-- exception here, instead of recovering by appending incoming
				-- onto the existing array.
				table.insert(merged, incoming)
			end
			return merged
		end,
	}
end
exports.offsetLimitPagination = offsetLimitPagination

-- Whether TRelayEdge<TNode> is a normalized Reference or a non-normalized
-- object, it needs a .cursor property where the relayStylePagination
-- merge function can store cursor strings taken from pageInfo. Storing an
-- extra reference.cursor property should be safe, and is easier than
-- attempting to update the cursor field of the normalized StoreObject
-- that the reference refers to, or managing edge wrapper objects
-- (something I attempted in #7023, but abandoned because of #7088).
export type TRelayEdge<TNode> = { cursor: string?, node: TNode } | (Reference & {
	cursor: string?,
})

export type TRelayPageInfo = {
	hasPreviousPage: boolean,
	hasNextPage: boolean,
	startCursor: string,
	endCursor: string,
}
export type TExistingRelay<TNode> = {
	edges: Array<TRelayEdge<TNode>>,
	pageInfo: TRelayPageInfo,
}

export type TIncomingRelay<TNode> = {
	edges: Array<TRelayEdge<TNode>>?,
	pageInfo: TRelayPageInfo?,
}

export type RelayFieldPolicy<TNode> = FieldPolicy<TExistingRelay<TNode>, TIncomingRelay<TNode>, TIncomingRelay<TNode>>

-- As proof of the flexibility of field policies, this function generates
-- one that handles Relay-style pagination, without Apollo Client knowing
-- anything about connections, edges, cursors, or pageInfo objects.
local function relayStylePagination(keyArgs: KeyArgs?): RelayFieldPolicy<TNode_>
	if keyArgs == nil then
		keyArgs = false
	end

	return {
		keyArgs = keyArgs,
		read = function(_self, existing, ref)
			local canRead, readField = ref.canRead, ref.readField
			if not Boolean.toJSBoolean(existing) then
				return
			end

			local edges: Array<TRelayEdge<TNode_>> = {}
			local firstEdgeCursor = ""
			local lastEdgeCursor = ""

			Array.forEach(existing.edges, function(edge)
				-- Edges themselves could be Reference objects, so it's important
				-- to use readField to access the edge.edge.node property.
				if canRead(readField("node", edge)) then
					table.insert(edges, edge)
					if Boolean.toJSBoolean(edge.cursor) then
						if Boolean.toJSBoolean(firstEdgeCursor) then
							firstEdgeCursor = firstEdgeCursor
						elseif Boolean.toJSBoolean(edge.cursor) then
							firstEdgeCursor = edge.cursor :: string
						else
							firstEdgeCursor = ""
						end

						lastEdgeCursor = Boolean.toJSBoolean(edge.cursor) and (edge.cursor :: string) or lastEdgeCursor
					end
				end
			end)

			local startCursor, endCursor
			do
				local ref_ = Boolean.toJSBoolean(existing.pageInfo) and existing.pageInfo or {}
				startCursor, endCursor = ref_.startCursor, ref_.endCursor
			end

			return Object.assign(
				{},
				-- Some implementations return additional Connection fields, such
				-- as existing.totalCount. These fields are saved by the merge
				-- function, so the read function should also preserve them.
				getExtras(existing),
				{
					edges = edges,
					pageInfo = Object.assign(
						{},
						existing.pageInfo,
						-- If existing.pageInfo.{start,end}Cursor are undefined or "", default
						-- to firstEdgeCursor and/or lastEdgeCursor.
						{
							startCursor = Boolean.toJSBoolean(startCursor) and startCursor or firstEdgeCursor,
							endCursor = Boolean.toJSBoolean(endCursor) and endCursor or lastEdgeCursor,
						}
					),
				}
			)
		end,

		merge = function(_self, existing, incoming, ref)
			if existing == nil then
				existing = makeEmptyData()
			end
			local args, isReference, readField = ref.args, ref.isReference, ref.readField

			local incomingEdges
			if Boolean.toJSBoolean(incoming.edges) then
				incomingEdges = Array.map(incoming.edges, function(edge)
					edge = Object.assign({}, edge)
					if isReference(edge) then
						edge.cursor = readField("cursor", edge)
					end
					return edge
				end)
			else
				incomingEdges = {}
			end

			if Boolean.toJSBoolean(incoming.pageInfo) then
				local pageInfo = incoming.pageInfo
				local startCursor, endCursor = pageInfo.startCursor, pageInfo.endCursor
				local firstEdge = incomingEdges[1]
				local lastEdge = incomingEdges[#incomingEdges]

				-- In case we did not request the cursor field for edges in this
				-- query, we can still infer cursors from pageInfo.
				if Boolean.toJSBoolean(firstEdge) and Boolean.toJSBoolean(startCursor) then
					firstEdge.cursor = startCursor
				end
				if Boolean.toJSBoolean(lastEdge) and Boolean.toJSBoolean(endCursor) then
					lastEdge.cursor = endCursor
				end

				-- Cursors can also come from edges, so we default
				-- pageInfo.{start,end}Cursor to {first,last}Edge.cursor.
				local firstCursor
				if Boolean.toJSBoolean(firstEdge) then
					firstCursor = firstEdge.cursor
				else
					firstCursor = firstEdge
				end

				if Boolean.toJSBoolean(firstCursor) and not Boolean.toJSBoolean(startCursor) then
					incoming = mergeDeep(incoming, { pageInfo = { startCursor = firstCursor } })
				end

				local lastCursor
				if Boolean.toJSBoolean(lastEdge) then
					lastCursor = lastEdge.cursor
				else
					lastCursor = lastEdge
				end

				if Boolean.toJSBoolean(lastCursor) and not Boolean.toJSBoolean(endCursor) then
					incoming = mergeDeep(incoming, { pageInfo = { endCursor = lastCursor } })
				end
			end

			local prefix = existing.edges
			local suffix: typeof(prefix) = {}

			if Boolean.toJSBoolean(args) and Boolean.toJSBoolean(args.after) then
				-- This comparison does not need to use readField("cursor", edge),
				-- because we stored the cursor field of any Reference edges as an
				-- extra property of the Reference object.
				local index = Array.findIndex(prefix, function(edge)
					return edge.cursor == args.after
				end)

				if
					index >= 1 --ROBLOX deviation: index starts at 1
				then
					prefix = Array.slice(prefix, 1, index + 1)
					-- suffix = []; // already true
				end
			elseif Boolean.toJSBoolean(args) and Boolean.toJSBoolean(args.before) then
				local index = Array.findIndex(prefix, function(edge)
					return edge.cursor == args.before
				end)
				if index < 0 then
					suffix = prefix
				else
					suffix = Array.slice(prefix, index)
				end
				prefix = {}
			elseif Boolean.toJSBoolean(incoming.edges) then
				-- If we have neither args.after nor args.before, the incoming
				-- edges cannot be spliced into the existing edges, so they must
				-- replace the existing edges. See #6592 for a motivating example.
				prefix = {}
			end

			local edges = Array.concat({}, prefix, incomingEdges, suffix)

			local pageInfo: TRelayPageInfo = Object.assign(
				{},
				-- The ordering of these two ...spreads may be surprising, but it
				-- makes sense because we want to combine PageInfo properties with a
				-- preference for existing values, *unless* the existing values are
				-- overridden by the logic below, which is permitted only when the
				-- incoming page falls at the beginning or end of the data.
				incoming.pageInfo,
				existing.pageInfo
			)

			if Boolean.toJSBoolean(incoming.pageInfo) then
				local hasPreviousPage, hasNextPage, startCursor, endCursor, extras
				do
					local ref_ = incoming.pageInfo
					hasPreviousPage, hasNextPage, startCursor, endCursor, extras =
						ref_.hasPreviousPage,
						ref_.hasNextPage,
						ref_.startCursor,
						ref_.endCursor,
						Object.assign({}, ref_, {
							hasPreviousPage = Object.None,
							hasNextPage = Object.None,
							startCursor = Object.None,
							endCursor = Object.None,
						})
				end

				-- If incoming.pageInfo had any extra non-standard properties,
				-- assume they should take precedence over any existing properties
				-- of the same name, regardless of where this page falls with
				-- respect to the existing data.
				Object.assign(pageInfo, extras)

				-- Keep existing.pageInfo.has{Previous,Next}Page unless the
				-- placement of the incoming edges means incoming.hasPreviousPage
				-- or incoming.hasNextPage should become the new values for those
				-- properties in existing.pageInfo. Note that these updates are
				-- only permitted when the beginning or end of the incoming page
				-- coincides with the beginning or end of the existing data, as
				-- determined using prefix.length and suffix.length.
				if not Boolean.toJSBoolean(#prefix) then
					if nil ~= hasPreviousPage then
						pageInfo.hasPreviousPage = hasPreviousPage
					end
					if nil ~= startCursor then
						pageInfo.startCursor = startCursor
					end
				end

				if not Boolean.toJSBoolean(#suffix) then
					if nil ~= hasNextPage then
						pageInfo.hasNextPage = hasNextPage
					end
					if nil ~= endCursor then
						pageInfo.endCursor = endCursor
					end
				end
			end

			return Object.assign({}, getExtras(existing), getExtras(incoming), { edges = edges, pageInfo = pageInfo })
		end,
	}
end
exports.relayStylePagination = relayStylePagination

-- Returns any unrecognized properties of the given object.
function getExtras(obj: Record<string, any>): Object
	return __rest(obj, notExtras)
end
notExtras = { "edges", "pageInfo" }

function makeEmptyData(): TExistingRelay<any>
	return {
		edges = {},
		pageInfo = { hasPreviousPage = false, hasNextPage = true, startCursor = "", endCursor = "" },
	}
end

return exports
