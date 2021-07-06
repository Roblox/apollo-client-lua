-- Roblox deviation: has no upstream

local function invariant(condition: any, message: string | nil)
	if not condition then
		error(message or "Unexpected invariant triggered.")
	end
end

return {
	invariant = invariant,
}
