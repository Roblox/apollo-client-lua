-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/hooks/utils/useDeepMemo.ts
local exports = {}

local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean

local React = require(rootWorkspace.React)
local useRef = React.useRef
local equal = require(srcWorkspace.jsutils.equal)

--[[
	/**
 * Memoize a result using deep equality. This hook has two advantages over
 * React.useMemo: it uses deep equality to compare memo keys, and it guarantees
 * that the memo function will only be called if the keys are unequal.
 * React.useMemo cannot be relied on to do this, since it is only a performance
 * optimization (see https://reactjs.org/docs/hooks-reference.html#usememo).
 */
]]
local function useDeepMemo(memoFn: (() -> any), key: any): any
	local ref = useRef(nil)
	if not Boolean.toJSBoolean(ref.current) or not equal(key, ref.current.key) then
		ref.current = { key = key, value = memoFn() }
	end
	return ref.current.value
end
exports.useDeepMemo = useDeepMemo
return exports
