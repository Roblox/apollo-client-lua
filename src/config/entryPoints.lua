-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/config/entryPoints.js
local rootWorkspace = script.Parent.Parent.Parent
local exports = {}

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array

local entryPoints = {
	{ dirs = {}, bundleName = "main" } :: any,
	{ dirs = { "cache" } },
	{ dirs = { "core" } },
	{ dirs = { "errors" } },
	{ dirs = { "link", "batch" } },
	{ dirs = { "link", "batch-http" } },
	{ dirs = { "link", "context" } },
	{ dirs = { "link", "core" } },
	{ dirs = { "link", "error" } },
	{ dirs = { "link", "http" } },
	{ dirs = { "link", "persisted-queries" } },
	{ dirs = { "link", "retry" } },
	{ dirs = { "link", "schema" } },
	{ dirs = { "link", "utils" } },
	{ dirs = { "link", "ws" } },
	{ dirs = { "react" } },
	{ dirs = { "react", "components" } },
	{ dirs = { "react", "context" } },
	{ dirs = { "react", "data" } },
	{ dirs = { "react", "hoc" } },
	{ dirs = { "react", "hooks" } },
	{ dirs = { "react", "parser" } },
	{ dirs = { "react", "ssr" } },
	{ dirs = { "utilities" }, sideEffects = { "./globals/**" } } :: any,
	{ dirs = { "testing" }, extensions = { ".js", ".jsx" } } :: any,
}

local lookupTrie = {} :: any

Array.forEach(entryPoints, function(info)
	local node = lookupTrie
	Array.forEach(info.dirs, function(dir)
		node.dirs = node.dirs or {}
		local dirs = node.dirs
		dirs[dir] = dirs[dir] or { isEntry = false }
		node = dirs[dir]
	end)
	node.isEntry = true
end)

local function forEach(callback, context)
	Array.forEach(entryPoints, callback, context)
end
exports.forEach = forEach

local function map(callback, context)
	return Array.map(entryPoints, callback, context)
end
exports.map = map

-- ROBLOX TODO: the rest of this file is not required ATM.
-- local path = require("path").posix

-- -- ROBLOX deviation: predefine variables
-- local partsAfterDist, lengthOfLongestEntryPoint, arraysEqualUpTo

-- exports.check = function(id, parentId)
-- 	local resolved = path:resolve(path:dirname(parentId), id)
-- 	local importedParts = partsAfterDist(resolved)

--     if Boolean.toJSBoolean(importedParts) then
-- 		local entryPointIndex = lengthOfLongestEntryPoint(importedParts)
-- 		if entryPointIndex == #importedParts then
-- 			return true
-- 		end
-- 		if
-- 			entryPointIndex
-- 			>= 1 -- ROBLOX deviation: added 1 to min index
-- 		then
-- 			local parentParts = partsAfterDist(parentId)
-- 			local parentEntryPointIndex = lengthOfLongestEntryPoint(parentParts)
-- 			local sameEntryPoint = (function()
-- 				if Boolean.toJSBoolean(entryPointIndex == parentEntryPointIndex) then
-- 					return arraysEqualUpTo(importedParts, parentParts, entryPointIndex)
-- 				else
-- 					return entryPointIndex == parentEntryPointIndex
-- 				end
-- 			end)()

--             -- If the imported ID and the parent ID have the same longest entry
--       -- point prefix, then this import is safely confined within that
--       -- entry point. Returning false lets Rollup know this import is not
--       -- external, and can be bundled into the CJS bundle that we build
--       -- for this shared entry point.
-- 			if sameEntryPoint then
-- 				return false
-- 			end

-- 			console.warn(
-- 				("Risky cross-entry-point nested import of %s in %s"):format(
-- 					id,
-- 					partsAfterDist(parentId):join("/")
-- 				)
-- 			)
-- 		end
-- 	end
-- 	return false
-- end

-- function partsAfterDist(id:string)
-- 	local parts = String.split(id, path.sep)
-- 	local distIndex = Array.lastIndexOf(parts, "dist")
-- 	if
-- 		distIndex
-- 		>= 1 -- ROBLOX deviation: index start at 1
-- 	then
-- 		return Array.slice(parts, distIndex + 1)
-- 	end
-- end

-- -- function lengthOfLongestEntryPoint(parts)
-- -- 	local node = lookupTrie
-- -- 	local longest = -1
-- -- 	local i = 0
-- -- 	while
-- -- 		(function()
-- -- 			if Boolean.toJSBoolean(node) then
-- -- 				return i < #parts
-- -- 			else
-- -- 				return node
-- -- 			end
-- -- 		end)()
-- -- 	do
-- -- 		if Boolean.toJSBoolean(node.isEntry) then
-- -- 			longest = i
-- -- 		end
-- -- 		node = (function()
-- -- 			if Boolean.toJSBoolean(node.dirs) then
-- -- 				return node.dirs[tostring(parts[tostring(i)])]
-- -- 			else
-- -- 				return node.dirs
-- -- 			end
-- -- 		end)();
-- -- 		(function()
-- -- 			i += 1
-- -- 			return i
-- -- 		end)()
-- -- 	end
-- -- 	if
-- -- 		Boolean.toJSBoolean((function()
-- -- 			if Boolean.toJSBoolean(node) then
-- -- 				return node.isEntry
-- -- 			else
-- -- 				return node
-- -- 			end
-- -- 		end)())
-- -- 	then
-- -- 		return #parts
-- -- 	end
-- -- 	return longest
-- -- end

-- function arraysEqualUpTo(a, b, end_)
-- 	local i = 1
-- 	while
-- 		i
-- 		<= end_
-- 	do
-- 		if a[i] ~= b[i] then
-- 			return false
-- 		end

-- 		i += 1
-- 	end
-- 	return true
-- end

return exports
