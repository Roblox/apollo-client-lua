-- ROBLOX upstream: https://github.com/benjamn/optimism/blob/v0.16.1/src/tests/context.ts

return function()
	local rootWorkspace = script.Parent.Parent.Parent.Parent

	local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
	local jestExpect = JestGlobals.expect

	local ParentModule = require(script.Parent.Parent)
	local wrap = ParentModule.wrap
	-- local setTimeout = ParentModule.setTimeout
	-- local asyncFromGen = ParentModule.asyncFromGen
	local noContext = ParentModule.noContext

	-- ROBLOX deviation: Luau doesn't support generators
	xdescribe("asyncFromGen", function()
		it("is importable", function()
			-- jestExpect(typeof(asyncFromGen)).toBe("function")
		end)

		-- it(
		-- 	"works like an async function",
		-- 	asyncFromGen(function()
		-- 		local sum = 0
		-- 		local limit = error("not implemented")
		-- 		--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
		-- 		--[[ yield new Promise(resolve => {
		-- 			setTimeout(() => resolve(10), 10);
		-- 		}) ]]
		-- 		error("not implemented")
		-- 		--[[ ROBLOX TODO: Unhandled node for type: ForStatement ]]
		-- 		--[[ for (let i = 0; i < limit; ++i) {
		-- 			sum += yield i + 1;
		-- 		} ]]
		-- 		jestExpect(sum).toBe(55)
		-- 		return Promise:resolve("ok")
		-- 	end)
		-- )

		it("properly handles exceptions", function()
			-- local fn = asyncFromGen(function(
			-- 	throwee: any --[[ ROBLOX TODO: Unhandled node for type: TSObjectKeyword ]] --[[ object ]]

			-- )
			-- 	local result = error("not implemented")
			-- 	--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
			-- 	--[[ yield Promise.resolve("ok") ]]
			-- 	if Boolean.toJSBoolean(throwee) then
			-- 		error(
			-- 			error("not implemented")
			-- 			--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
			-- 			--[[ yield throwee ]]
			-- 		)
			-- 	end
			-- 	return result
			-- end)
			-- local okPromise = fn()
			-- local expected = {}
			-- local koPromise = fn(expected)
			-- jestExpect(okPromise:expect()).toBe("ok")
			-- do --[[ ROBLOX COMMENT: try-catch block conversion ]]
			-- 	xpcall(function()
			-- 		koPromise:expect()
			-- 		error(Error.new("not reached"))
			-- 	end, function(error_)
			-- 		jestExpect(error_).toBe(expected)
			-- 	end)
			-- end
			-- do --[[ ROBLOX COMMENT: try-catch block conversion ]]
			-- 	xpcall(function()
			-- 		fn(Promise.resolve("oyez")):expect()
			-- 		error(Error.new("not reached"))
			-- 	end, function(thrown)
			-- 		jestExpect(thrown).toBe("oyez")
			-- 	end)
			-- end
			-- local catcher = asyncFromGen(function()
			-- 	do --[[ ROBLOX COMMENT: try-catch block conversion ]]
			-- 		xpcall(function()
			-- 			error("not implemented")
			-- 			--[[ yield Promise.reject(new Error("expected")) ]]
			-- 			--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
			-- 			error(Error.new("not reached"))
			-- 		end, function(error_)
			-- 			jestExpect(error_.message).toBe("expected")
			-- 		end)
			-- 	end
			-- 	return "ok"
			-- end)
			-- return catcher():then_(function(result)
			-- 	jestExpect(result).toBe("ok")
			-- end)
		end)

		it("can be cached", function()
			-- local parentCounter = 0
			-- local parent = wrap(asyncFromGen(function(x: number)
			-- 	(function()
			-- 		parentCounter += 1
			-- 		return parentCounter
			-- 	end)()
			-- 	local a = error("not implemented")
			-- 	--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
			-- 	--[[ yield new Promise<number>(resolve => setTimeout(() => {
			-- 		resolve(child(x));
			-- 	}, 10)) ]]
			-- 	local b = error("not implemented")
			-- 	--[[ ROBLOX TODO: Unhandled node for type: YieldExpression ]]
			-- 	--[[ yield new Promise<number>(resolve => setTimeout(() => {
			-- 		resolve(child(x + 1));
			-- 	}, 20)) ]]
			-- 	return a * b
			-- end))
			-- local childCounter = 0
			-- local child = wrap(function(x: number)
			-- 	return (function()
			-- 		childCounter += 1
			-- 		return childCounter
			-- 	end)()
			-- end)
			-- jestExpect(parentCounter).toBe(0)
			-- jestExpect(childCounter).toBe(0)
			-- local parentPromise = parent(123)
			-- jestExpect(parentCounter).toBe(1)
			-- jestExpect(parentPromise:expect()).toBe(2)
			-- jestExpect(childCounter).toBe(2)
			-- jestExpect(parent(123)).toBe(parentPromise)
			-- jestExpect(parentCounter).toBe(1)
			-- jestExpect(childCounter).toBe(2)
			-- child:dirty(123)
			-- jestExpect(parent(123):expect()).toBe(3 * 2)
			-- jestExpect(parentCounter).toBe(2)
			-- jestExpect(childCounter).toBe(3)
			-- jestExpect(parent(456):expect()).toBe(4 * 5)
			-- jestExpect(parentCounter).toBe(3)
			-- jestExpect(childCounter).toBe(5)
			-- jestExpect(parent(666)).toBe(parent(666))
			-- jestExpect(parent(666):expect()).toBe(parent(666):expect())
			-- jestExpect(parentCounter).toBe(4)
			-- jestExpect(childCounter).toBe(7)
			-- child:dirty(667)
			-- jestExpect(parent(667):expect()).toBe(8 * 9)
			-- jestExpect(parent(667):expect()).toBe(8 * 9)
			-- jestExpect(parentCounter).toBe(5)
			-- jestExpect(childCounter).toBe(9)
			-- jestExpect(parent(123):expect()).toBe(3 * 2)
			-- jestExpect(parentCounter).toBe(5)
			-- jestExpect(childCounter).toBe(9)
		end)
	end)

	describe("noContext", function()
		it("prevents registering dependencies", function()
			local child

			local parentCounter = 0
			local parent = wrap(function()
				parentCounter += 1
				return { parentCounter, noContext(child) }
			end)

			local childCounter = 0
			child = wrap(function()
				childCounter += 1
				return childCounter
			end)

			jestExpect(parent()).toEqual({ 1, 1 })
			jestExpect(parent()).toEqual({ 1, 1 })
			parent:dirty()
			jestExpect(parent()).toEqual({ 2, 1 })
			child:dirty()
			jestExpect(parent()).toEqual({ 2, 1 })
			parent:dirty()
			jestExpect(parent()).toEqual({ 3, 2 })
			jestExpect(parent()).toEqual({ 3, 2 })
			parent:dirty()
			jestExpect(parent()).toEqual({ 4, 2 })
		end)
	end)
end
