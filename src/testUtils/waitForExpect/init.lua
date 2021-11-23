-- ROBLOX upstream: https://github.com/TheBrainFamily/wait-for-expect/blob/v3.0.0/src/index.ts

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local Promise = require(rootWorkspace.Promise)

local helpersModule = require(script.helpers)
local getSetTimeoutFn = helpersModule.getSetTimeoutFn

local defaults = {
	timeout = 4500,
	interval = 50,
}

local function waitForExpect(expectation: () -> (), _timeout: number?, _interval: number?)
	local timeout = _timeout or defaults.timeout
	local interval = _interval or defaults.interval

	local setTimeout = getSetTimeoutFn()
	if interval < 1 then
		interval = 1
	end

	local maxTries = math.ceil(timeout / interval)
	local tries = 0
	return Promise.new(function(resolve, reject)
		local rejectOrRerun, runExpectation
		function rejectOrRerun(error_)
			if tries > maxTries then
				reject(error_)
				return
			end
			setTimeout(runExpectation, interval)
		end
		function runExpectation()
			tries += 1
			do --[[ ROBLOX COMMENT: try-catch block conversion ]]
				xpcall(function()
					Promise.delay(0)
						:andThen(function()
							return expectation()
						end)
						:andThen(function()
							return Promise.delay(0)
						end)
						:andThen(function()
							return resolve()
						end)
						:catch(rejectOrRerun)
				end, function(error_)
					rejectOrRerun(error_)
				end)
			end
		end
		setTimeout(runExpectation, 0)
	end)
end

return waitForExpect
