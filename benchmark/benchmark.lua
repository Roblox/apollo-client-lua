-- ROBLOX no upstream

--[[
    ROBLOX note:
    custom implementation for BenchmarkJS
    only supporting necessary features
]]

local Suite = {}
Suite.__index = Suite

function Suite.new()
	local self = setmetatable({}, Suite)
	return self
end

function Suite:add(...)
	-- ROBLOX TODO: implement
	return self
end

function Suite:on(...)
	-- ROBLOX TODO: implement
	return self
end

function Suite:run(...)
	-- ROBLOX TODO: implement
	return self
end

local Benchmark = {
	options = {},
	Suite = Suite,
}

return Benchmark
