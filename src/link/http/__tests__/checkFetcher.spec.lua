-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/link/http/__tests__/checkFetcher.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local checkFetcher = require(script.Parent.Parent.checkFetcher).checkFetcher
	local voidFetchDuringEachTest = require(script.Parent.helpers)({
		beforeEach = beforeEach,
		afterEach = afterEach,
		describe = describe,
		it = it,
	}).voidFetchDuringEachTest

	describe("checkFetcher", function()
		voidFetchDuringEachTest()

		it("throws if no fetch is present", function()
			jestExpect(function()
				return checkFetcher(nil)
			end).toThrow("has not been found globally")
		end)

		it("does not throws if no fetch is present but a fetch is passed", function()
			jestExpect(function()
				return checkFetcher(function() end :: any)
			end).never.toThrow()
		end)
	end)
end
