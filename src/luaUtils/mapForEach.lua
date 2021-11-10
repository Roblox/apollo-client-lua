function mapForEach(map, fn)
	for _, key in ipairs(map:keys()) do
		fn(map:get(key), key)
	end
end

return mapForEach
