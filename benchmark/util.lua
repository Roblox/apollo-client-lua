-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/6f579e/packages/apollo-client/benchmark/util.ts

local rootWorkspace = script.Parent.Parent

local getters = {}

local exports = setmetatable({}, {
    __index = function(t, k)
        if getters[k] then
            return getters[k]()
        end
        return rawget(t,k)
    end
})

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local console = LuauPolyfill.console

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
export type GroupFunction = (done: DoneFunction) -> ()
export type AfterEachCallbackFunction = (descr: Description, event: any) -> ()
export type AfterEachFunction = (afterEachFnArg: AfterEachCallbackFunction) -> ()
export type AfterAllCallbackFunction = () -> ()
export type AfterAllFunction = (afterAllFn: AfterAllCallbackFunction) -> ()

-- ROBLOX deviation START: using getter to simulate upstream behavior
local benchmark: BenchmarkFunction
getters.benchmark = function(): BenchmarkFunction
    return benchmark
end
exports.benchmark = benchmark
local afterEach: AfterEachFunction
getters.afterEach = function(): BenchmarkFunction
    return afterEach
end
exports.afterEach = afterEach
local afterAll: AfterAllFunction
getters.afterAll = function(): BenchmarkFunction
    return afterAll
end
exports.afterAll = afterAll
-- ROBLOX deviation END
-- Used to log stuff within benchmarks without pissing off tslint.
local function log(logString: string, ...: any)
	-- tslint:disable-next-line
	console.log(logString, ...)
end
exports.log = log

-- A reasonable implementation of dataIdFromObject that we use within
-- the benchmarks.
local function dataIdFromObject(object: any)
	if object.__typename and object.id then
		return object.__typename .. "__" .. object.id
	end
	return nil
end
exports.dataIdFromObject = dataIdFromObject

type Scope = {
	benchmark: BenchmarkFunction?,
	afterEach: AfterEachFunction?,
	afterAll: AfterAllFunction?,
}

-- Internal function that returns the current exposed functions
-- benchmark, setup, etc.
local function currentScope()
	return {
		benchmark = benchmark,
		afterEach = afterEach,
		afterAll = afterAll,
	}
end

-- Internal function that lets us set benchmark, setup, afterEach, etc.
-- in a reasonable fashion.
local function setScope(scope: Scope)
	benchmark = scope.benchmark :: BenchmarkFunction
	afterEach = scope.afterEach :: AfterEachFunction
	afterAll = scope.afterAll :: AfterAllFunction
end

local groupPromises: Array<Promise<nil>> = {}
exports.groupPromises = groupPromises

local function group(groupFn: GroupFunction)
	local oldScope = currentScope()
	local scope: { benchmark: BenchmarkFunction?, afterEach: AfterEachFunction?, afterAll: AfterAllFunction? } = {}

	local afterEachFn: Nullable<AfterEachCallbackFunction> = nil
	scope.afterEach = function(afterEachFnArg: AfterEachCallbackFunction)
		afterEachFn = afterEachFnArg
	end

	local afterAllFn: Nullable<AfterAllCallbackFunction> = nil
	scope.afterAll = function(afterAllFnArg: AfterAllCallbackFunction)
		afterAllFn = afterAllFnArg
	end

	local benchmarkPromises: Array<Promise<nil>> = {}

	scope.benchmark = function(description: string | Description, benchmarkFn: CycleFunction)
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
						if Boolean.toJSBoolean(afterEachFn) then
							afterEachFn(description, event)
						end
						resolve()
					end,
				})
			end)
		)
	end

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

			setScope(scope)
			groupFn(groupDone)
			setScope(oldScope)
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
