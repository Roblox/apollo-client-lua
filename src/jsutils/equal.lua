local srcWorkspace = script.Parent.Parent
local Packages = srcWorkspace.Parent
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array, Object = LuauPolyfill.Array, LuauPolyfill.Object

local function equal(a: any, b: any): boolean
	if typeof(a) ~= typeof(b) then
		return false
	end
	if a == b then
		return true
	end
	if typeof(a) == "table" then
		if Array.isArray(a) and not Array.isArray(b) then
			return false
		end
		if #a ~= #b or #Object.keys(a) ~= #Object.keys(b) then
			return false
		end
		if Array.isArray(a) then
			for k, v in ipairs(a) do
				if not equal(a[k], b[k]) then
					return false
				end
			end
		else
			for k in pairs(a) do
				if not equal(a[tostring(k)], b[tostring(k)]) then
					return false
				end
			end
		end
		return true
	elseif typeof(a) == "string" or typeof(a) == "number" or typeof(a) == "boolean" then
		return a == b
	elseif typeof(a) == "function" then
		error("unhandled equality check for type 'function'")
	elseif typeof(a) == "thread" then
		error("unhandled equality check for type 'thread'")
	elseif typeof(a) == "userdata" then
		error("unhandled equality check for type 'userdata'")
	end
	error("unhandled equality check for type " .. typeof(a))
end

return equal
