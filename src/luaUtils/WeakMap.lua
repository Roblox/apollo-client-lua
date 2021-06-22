export type WeakMap<T, V> = {
	-- method definitions
	get: (WeakMap<T, V>, T) -> V,
	set: (WeakMap<T, V>, T, V) -> Map<T, V>,
}

local WeakMap = {}

function WeakMap.new(): WeakMap
	local weakMap = {}
	return setmetatable({ _weakMap = weakMap }, { __mode = "v", __index = WeakMap })
end

function WeakMap:get(key)
	return self._weakMap[key]
end

function WeakMap:set(key, value)
	self._weakMap[key] = value
	return self
end

return WeakMap
