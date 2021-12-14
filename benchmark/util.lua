-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/6f579e/packages/apollo-client/benchmark/util.ts

local rootWorkspace = script.Parent.Parent

local exports = {}

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean

local Promise = require(rootWorkspace.Promise)

type Array<T> = LuauPolyfill.Array<T>
type Promise<T> = LuauPolyfill.Promise<T>

-- ROBLOX deviation: using own implementation for BenchmarkJs
local Benchmark = require(script.Parent.benchmark)

-- This file implements utilities around benchmark.js that make it
-- easier to use for our benchmarking needs.

-- Specifically, it provides `group` and `benchmark`, examples of which
-- can be seen within the benchmarks.The functions allow you to manage scope and async
-- code more easily than benchmark.js typically allows.
--
-- `group` is meant to provide a way to execute code that sets up the scope variables for your
-- benchmark. It is only run once before the benchmark, not on every call of the code to
-- be benchmarked. The `benchmark` function is similar to the `it` function within mocha;
-- it allows you to define a particular block of code to be benchmarked.

Benchmark.options.minSamples = 150
Benchmark.options.maxTime = _G.__MAX_BENCHMARK_TIME__ and tonumber(_G.__MAX_BENCHMARK_TIME__)
local bsuite = Benchmark.Suite.new()
exports.bsuite = bsuite
export type DoneFunction = () -> ()

export type DescriptionObject = {
	name: string,
	[string]: any,
}

export type Nullable<T> = T | nil
export type Description = DescriptionObject | string
export type CycleFunction = (doneFn: DoneFunction) -> ()
export type BenchmarkFunction = (description: Description, cycleFn: CycleFunction) -> ()
export type GroupFunction = (done: DoneFunction, scope: Scope) -> ()
export type AfterEachCallbackFunction = (descr: Description, event: any) -> ()
export type AfterEachFunction = (afterEachFnArg: AfterEachCallbackFunction) -> ()
export type AfterAllCallbackFunction = () -> ()
export type AfterAllFunction = (afterAllFn: AfterAllCallbackFunction) -> ()

-- ROBLOX deviation START: passing scope to a groupFn so no need to set it globally
-- local benchmark: BenchmarkFunction
-- exports.benchmark = benchmark
-- local afterEach: AfterEachFunction
-- exports.afterEach = afterEach
-- local afterAll: AfterAllFunction
-- exports.afterAll = afterAll
-- ROBLOX deviation END

-- Used to log stuff within benchmarks without pissing off tslint.
local function log(logString: string, ...: any)
	if not _G.__CI__ then
		-- tslint:disable-next-line
		print(logString, ...)
	end
end
exports.log = log

-- A reasonable implementation of dataIdFromObject that we use within
-- the benchmarks.
local function dataIdFromObject(_self, object: any)
	if object.__typename and object.id then
		return object.__typename .. "__" .. object.id
	end
	return nil
end
exports.dataIdFromObject = dataIdFromObject

type Scope = {
	benchmark: BenchmarkFunction,
	afterEach: AfterEachFunction,
	afterAll: AfterAllFunction,
}

-- ROBLOX deviation START: passing scope to a groupFn so no need to set it globally
-- -- Internal function that returns the current exposed functions
-- -- benchmark, setup, etc.
-- local function currentScope()
-- 	return {
-- 		benchmark = benchmark,
-- 		afterEach = afterEach,
-- 		afterAll = afterAll,
-- 	}
-- end

-- -- Internal function that lets us set benchmark, setup, afterEach, etc.
-- -- in a reasonable fashion.
-- local function setScope(scope: Scope)
-- 	benchmark = scope.benchmark :: BenchmarkFunction
-- 	afterEach = scope.afterEach :: AfterEachFunction
-- 	afterAll = scope.afterAll :: AfterAllFunction
-- end
-- ROBLOX deviation END

local groupPromises: Array<Promise<nil>> = {}
exports.groupPromises = groupPromises

local function group(groupFn: GroupFunction)
	-- ROBLOX deviation: passing scope to a groupFn so no need to set it globally
	-- local oldScope = currentScope()

	local afterEachFn: Nullable<AfterEachCallbackFunction> = nil
	local afterAllFn: Nullable<AfterAllCallbackFunction> = nil
	local benchmarkPromises: Array<Promise<nil>> = {}

	local scope: Scope = {
		afterEach = function(afterEachFnArg: AfterEachCallbackFunction)
			afterEachFn = afterEachFnArg
		end,
		afterAll = function(afterAllFnArg: AfterAllCallbackFunction)
			afterAllFn = afterAllFnArg
		end,
		benchmark = function(description: string | Description, benchmarkFn: CycleFunction)
			local name = Boolean.toJSBoolean((description :: DescriptionObject).name)
					and (description :: DescriptionObject).name
				or description :: string
			log("Adding benchmark: ", name)

			-- const scopes: Object[] = [];
			local cycleCount = 0
			table.insert(
				benchmarkPromises,
				Promise.new(function(resolve, _)
					bsuite:add(name, {
						defer = true,
						fn = function(deferred: any)
							local function done()
								cycleCount += 1
								deferred:resolve()
							end

							benchmarkFn(done)
						end,
						onComplete = function(event: any)
							if afterEachFn ~= nil then
								afterEachFn(description, event)
							end
							resolve()
						end,
					})
				end)
			)
		end,
	}

	table.insert(
		groupPromises,
		Promise.new(function(resolve, _)
			local function groupDone()
				Promise.all(benchmarkPromises):andThen(function()
					if afterAllFn then
						afterAllFn()
					end
				end)
				resolve()
			end

			-- ROBLOX deviation START: passing scope to a groupFn so no need to set it globally
			-- setScope(scope)
			groupFn(groupDone, scope)
			-- setScope(oldScope)
			-- ROBLOX deviation END
		end)
	)
end
exports.group = group

local function runBenchmarks()
	Promise.all(groupPromises):andThen(function()
		log("Running benchmarks.")
		bsuite
			:on("error", function(error_)
				log("Error: ", error_)
			end)
			:on("cycle", function(event: any)
				log("Mean time in ms: ", event.target.stats.mean * 1000)
				log(tostring(event.target))
				log("")
			end)
			:run({ async = false })
	end)
end
exports.runBenchmarks = runBenchmarks

return exports
