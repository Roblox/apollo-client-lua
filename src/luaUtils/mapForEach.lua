local rootWorkspace = script.Parent.Parent.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
type Map<K, V> = LuauPolyfill.Map<K, V>
-- ROBLOX FIXME: add Map.forEach (and Set.forEach) to polyfill and use it here
function mapForEach<K, V>(map: Map<K, V>, fn: (V, K) -> ...any)
	for _, key in map:keys() do
		fn(map:get(key) :: any, key)
	end
end

return mapForEach
