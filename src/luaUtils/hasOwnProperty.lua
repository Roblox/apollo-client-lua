local function hasOwnProperty(obj, prop): boolean
	return obj[prop] ~= nil
end

return hasOwnProperty
