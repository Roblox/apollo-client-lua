-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/hooks/utils/useDeepMemo.ts

local srcWorkspace = script.Parent.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.parent
local LuauPolyfill = require(srcWorkspace.Dev.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean

local React = require(rootWorkspace.Roact)
local useRef = React.useRef
local exports = {}
-- was used for a equal() comparison
-- local equal = require(Packages.@wry.equality).equal

local function useDeepMemo(memoFn: any, key: any): any
	local ref = useRef()
	if
		Boolean.toJSBoolean(
			Boolean.toJSBoolean(not Boolean.toJSBoolean(ref.current)) and not Boolean.toJSBoolean(ref.current)
				or not Boolean.toJSBoolean(key == ref.current.key)
		)
	then
		ref.current = { key = key, value = memoFn() }
	end
	return ref.current.value
end
exports.useDeepMemo = useDeepMemo
return exports
