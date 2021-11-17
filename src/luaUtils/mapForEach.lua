-- ROBLOX FIXME: add Map.forEach (and Set.forEach) to polyfill and use it here
function mapForEach(map, fn)
	for _, key in ipairs(map:keys()) do
		fn(map:get(key), key)
	end
end

return mapForEach
