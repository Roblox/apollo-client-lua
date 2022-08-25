-- ROBLOX no upstream

local rootWorkspace = script.Parent.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
type Array<T> = { [number]: T }

export type Stats = {
	min: number,
	max: number,
	mean: number,
	variance: number,
	sd: number,
	sem: number,
	df: number,
	critical: number,
	moe: number,
	rme: number,
	size: number,
}

--[[*
* T-Distribution two-tailed critical values for 95% confidence.
* For more info see http://www.itl.nist.gov/div898/handbook/eda/section3/eda3672.htm.
]]
local tTable = {
	["1"] = 12.706,
	["2"] = 4.303,
	["3"] = 3.182,
	["4"] = 2.776,
	["5"] = 2.571,
	["6"] = 2.447,
	["7"] = 2.365,
	["8"] = 2.306,
	["9"] = 2.262,
	["10"] = 2.228,
	["11"] = 2.201,
	["12"] = 2.179,
	["13"] = 2.16,
	["14"] = 2.145,
	["15"] = 2.131,
	["16"] = 2.12,
	["17"] = 2.11,
	["18"] = 2.101,
	["19"] = 2.093,
	["20"] = 2.086,
	["21"] = 2.08,
	["22"] = 2.074,
	["23"] = 2.069,
	["24"] = 2.064,
	["25"] = 2.06,
	["26"] = 2.056,
	["27"] = 2.052,
	["28"] = 2.048,
	["29"] = 2.045,
	["30"] = 2.042,
	["infinity"] = 1.96,
}

local function getMean(data: Array<number>)
	return Array.reduce(data, function(sum: number, a)
		return sum + a
	end, 0) / #data
end

local function getVariance(data: Array<number>, mean: number)
	return Array.reduce(data, function(sum: number, x)
		return sum + math.pow(x - mean, 2)
	end, 0) / (#data - 1)
end

local function calculateStats(data: Array<number>): Stats
	local size = #data
	-- Compute the sample mean (estimate of the population mean).
	local mean = getMean(data)
	-- Compute the sample variance (estimate of the population variance).
	local variance = getVariance(data, mean)
	-- Compute the sample standard deviation (estimate of the population standard deviation).
	local sd = math.sqrt(variance)
	-- Compute the standard error of the mean (a.k.a. the standard deviation of the sampling distribution of the sample mean).
	local sem = sd / math.sqrt(size)
	-- Compute the degrees of freedom.
	local df = size - 1
	-- Compute the critical value.
	local idx = math.round(df)
	local critical = tTable[if Boolean.toJSBoolean(idx) then idx else 1] or tTable.infinity
	-- Compute the margin of error.
	local moe = sem * critical
	-- Compute the relative margin of error.
	local rme_ = (moe / mean) * 100
	local rme = if Boolean.toJSBoolean(rme_) then rme_ else 0

	return {
		min = math.min(math.huge, table.unpack(data)),
		max = math.max(0, table.unpack(data)),
		mean = mean,
		variance = variance,
		sd = sd,
		sem = sem,
		df = df,
		critical = critical,
		moe = moe,
		rme = rme,
		size = size,
	}
end

return calculateStats
