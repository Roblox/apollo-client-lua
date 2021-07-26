export type WeakMap<T, V> = {
	-- method definitions
	get: (WeakMap<T, V>, T) -> V,
	set: (WeakMap<T, V>, T, V) -> Map<T, V>,
}

local WeakMap = {}
WeakMap.__index = WeakMap

function WeakMap.new(): WeakMap
	local weakMap = setmetatable({}, { __mode = "k" })
	return setmetatable({ _weakMap = weakMap }, WeakMap)
end

function WeakMap:get(key)
	return self._weakMap[key]
end

function WeakMap:set(key, value)
	self._weakMap[key] = value
	return self
end

return WeakMap
