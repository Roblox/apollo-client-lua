-- ROBLOX no upstream

--[[
    ROBLOX note:
    custom implementation for BenchmarkJS
    only supporting necessary features
]]
local rootWorkspace = script.Parent.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

type Array<T> = LuauPolyfill.Array<T>
-- ROBLOX FIXME: fix in LuauPolyfill
type Object = { [string]: any }
type Promise<T> = LuauPolyfill.Promise<T>

local Promise = require(rootWorkspace.Promise)

local calculateStats = require(script.Parent.calculateStats)

type Stats = calculateStats.Stats

-- ROBLOX NOTE: maximum relative margin of error
local MAX_RME: number = 5
if _G.__MAX_RME__ then
	local parsedNum = tonumber(_G.__MAX_RME__)
	if typeof(parsedNum) == "number" and parsedNum == parsedNum then
		MAX_RME = parsedNum
	end
end

local function secToMs(sec: number): number
	return sec * 1000
end

local function printStats(benchmarkName: string, data: Array<number>)
	local stats = calculateStats(data)
	local hz = 1 / stats.mean
	print(("%s x %4.4f ops/sec ±%3.2f%% (%d runs sampled)"):format(benchmarkName, hz, stats.rme, stats.size))
end

local function notifyHandlers(target: any, eventName: string, event: Event)
	local ok, err_ = pcall(function()
		local options = target.options

		local eventHandlerProp = "on" .. string.upper(string.sub(eventName, 1, 1)) .. string.sub(eventName, 2)

		if typeof(options) == "table" and typeof(options[eventHandlerProp]) == "function" then
			local ok, err_ = pcall(options[eventHandlerProp], event)

			if not ok then
				warn(("error when calling %s handler: "):format(eventHandlerProp), err_)
			end
		end

		if typeof(target.handlers) == "table" and target.handlers[eventName] then
			for _, handler in ipairs(target.handlers[eventName]) do
				local ok, err_ = pcall(handler, event)

				if not ok then
					warn(("error when calling %s handler: "):format(eventName), err_)
				end
			end
		end
	end)

	if not ok then
		warn(err_)
	end
end

type Event = {
	type: string,
	target: any,
	timestamp: number,
} & Object

type BenchmarkOptions = Object

local Benchmark = {}

type Suite = {
	add: (self: Suite, name: string, options: BenchmarkOptions) -> Suite,
	on: (self: Suite, eventName: string, handler: (event: Event) -> ...any) -> Suite,
	run: (self: Suite, ...any) -> Promise<nil>,
}

local Suite = {}
Suite.__index = Suite

function Suite.new(): Suite
	local self = setmetatable({}, Suite)

	self.benchmarks = {}
	self.handlers = {}

	return (self :: any) :: Suite
end

function Suite:add(name, options)
	table.insert(self.benchmarks, {
		name = name,
		options = Object.assign({}, Benchmark.defaultOptions, Benchmark.options, options),
	})

	return self
end

function Suite:on(eventName, handler: (event: Event) -> ...any)
	self.handlers[eventName] = self.handlers[eventName] or {}
	table.insert(self.handlers[eventName], handler)
	return self
end

local function isSignificant(stats: Stats): boolean
	return stats.rme < MAX_RME
end

function Suite:run(...)
	return Promise.new(function(resolve)
		for i = 1, #self.benchmarks do
			local benchmark = Object.assign({}, self.benchmarks[i])
			local data = {}
			local name, options = benchmark.name, benchmark.options
			local maxTime = secToMs(options.maxTime)
			local startTime = secToMs(os.clock())
			while
				secToMs(os.clock()) - startTime < maxTime
				and (#data < options.minSamples or not isSignificant(benchmark.stats))
			do
				local cycleStartTime
				local cycleEndTime
				local ok, error_ = Promise.new(function(resolve)
					cycleStartTime = os.clock()
					options.fn({
						resolve = function(...)
							cycleEndTime = os.clock()
							resolve(...)
						end,
					})
				end):await()

				if not ok then
					notifyHandlers(benchmark, "error", {
						type = "error",
						target = benchmark,
						timestamp = secToMs(os.clock()),
						error = error_,
					})
					break
				end

				table.insert(data, cycleEndTime - cycleStartTime)

				benchmark.stats = calculateStats(data)

				local cycleEvent = {
					type = "cycle",
					target = benchmark,
					timestamp = secToMs(cycleEndTime),
				}
				notifyHandlers(benchmark, "cycle", cycleEvent)
				notifyHandlers(self, "cycle", cycleEvent)

				task.wait(options.delay)
			end
			notifyHandlers(benchmark, "complete", {
				type = "complete",
				target = benchmark,
				timestamp = secToMs(os.clock()),
			})

			printStats(name, data)
		end

		notifyHandlers(self, "complete", {
			type = "complete",
			target = self,
			timestamp = secToMs(os.clock()),
		})

		resolve()
	end):expect()
end

Benchmark.options = {} :: BenchmarkOptions
Benchmark.Suite = Suite
Benchmark.defaultOptions = {
	async = false,
	defer = false,
	delay = 0.005,
	id = nil,
	initCount = 1,
	maxTime = 5,
	minSamples = 5,
	minTime = 0,
	name = nil,
	onAbort = nil,
	onComplete = nil,
	onCycle = nil,
	onError = nil,
	onReset = nil,
	onStart = nil,
}

return Benchmark
