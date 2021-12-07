-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/6f579e/packages/apollo-client/benchmark/github-reporter.ts

local exports = {}

local rootWorkspace = script.Parent.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Object = LuauPolyfill.Object
local console = LuauPolyfill.console

local Promise = require(rootWorkspace.Promise)

-- ROBLOX deviation: not using GitHub API
-- local GithubAPI = require(Packages["@octokit"].rest).default
local utilModule = require(script.Parent.util)
local bsuite = utilModule.bsuite
local groupPromises = utilModule.groupPromises
local log = utilModule.log
local thresholds = require(script.Parent.thresholds).thresholds

local function collectAndReportBenchmarks(uploadToGithub: boolean)
	-- ROBLOX deviation START: not using GitHub API
	-- local github = eval('new require("@octokit/rest")()') :: GithubAPI
	-- local commitSHA = (function()
	-- 	local ref = Boolean.toJSBoolean(process.env.TRAVIS_PULL_REQUEST_SHA)
	-- 			and process.env.TRAVIS_PULL_REQUEST_SHA
	-- 		or process.env.TRAVIS_COMMIT
	-- 	return Boolean.toJSBoolean(ref) and ref
	-- end)() or ""
	-- ROBLOX deviation END:
	if uploadToGithub then
		-- ROBLOX deviation START: not uploading to GitHub
		-- github:authenticate({
		-- 	type = "oauth",
		-- 	token = Boolean.toJSBoolean(process.env.DANGER_GITHUB_API_TOKEN)
		-- 			and process.env.DANGER_GITHUB_API_TOKEN
		-- 		or "",
		-- })
		-- github.repos:createStatus({
		-- 	owner = "apollographql",
		-- 	repo = "apollo-client",
		-- 	sha = commitSHA,
		-- 	context = "Benchmark",
		-- 	description = "Evaluation is in progress!",
		-- 	state = "pending",
		-- })
		warn("not uploading to GitHub")
		-- ROBLOX deviation END
	end

	Promise.all(groupPromises)
		:andThen(function()
			log("Running benchmarks.")
			return Promise.new(function(resolve)
				local retMap: { [string]: {
					mean: number,
					moe: number,
				} } = {}

				bsuite
					:on("error", function(error_)
						log("Error: ", error_)
					end)
					:on("cycle", function(event: any)
						retMap[event.target.name] = {
							mean = event.target.stats.mean * 1000,
							moe = event.target.stats.moe * 1000,
						}
						log("Mean time in ms: ", event.target.stats.mean * 1000)
						log(tostring(event.target))
						log("")
					end)
					:on("complete", function(_: any)
						resolve(retMap)
					end)
					:run({ async = false })
			end)
		end)
		:andThen(function(res)
			local message = ""
			local _pass = false
			Array.forEach(Object.keys(res), function(element: string)
				if element ~= "baseline" then
					if not Boolean.toJSBoolean(thresholds[element]) then
						console.error(('Threshold not defined for "%s"'):format(element))
						if message == "" then
							message = ('Threshold not defined for "%s"'):format(element)
							_pass = false
						end
					else
						local normalizedMean = res[element].mean / res["baseline"].mean
						if normalizedMean > thresholds[element] then
							local perfDropMessage =
								(
									'Performance drop detected for benchmark: "%s", %s / %s = %s > %s'
								):format(
									element,
									res[element].mean,
									res["baseline"].mean,
									normalizedMean,
									thresholds[element]
								)
							console.error(perfDropMessage)
							if message == "" then
								message = ('Performance drop detected for benchmark: "%s"'):format(element)
								_pass = false
							end
						else
							console.log(
								('No performance drop detected for benchmark: "%s", %s / %s = %s <= %s'):format(
									element,
									res[element].mean,
									res["baseline"].mean,
									normalizedMean,
									thresholds[element]
								)
							)
						end
					end
				end
			end)

			if message == "" then
				message = "All benchmarks are under the defined thresholds!"
				_pass = true
			end

			console.log("Reporting benchmarks to GitHub status...")

			if uploadToGithub then
				-- ROBLOX deviation START: not uploading to GitHub
				-- return github.repos
				-- 	:createStatus({
				-- 		owner = "apollographql",
				-- 		repo = "apollo-client",
				-- 		sha = commitSHA,
				-- 		context = "Benchmark",
				-- 		description = message,
				-- 		state = _pass and "success" or "error",
				-- 	})
				-- 	:andThen(function()
				-- 		console.log("Published benchmark results to GitHub status")
				-- 	end)
				warn("not uploading to GitHub")
				return
				-- ROBLOX deviation END
			else
				return
			end
		end)
end
exports.collectAndReportBenchmarks = collectAndReportBenchmarks

return exports
