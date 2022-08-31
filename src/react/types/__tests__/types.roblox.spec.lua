-- ROBLOX no upstream

local rootWorkspace = script.Parent.Parent.Parent.Parent.Parent

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect
local describe = JestGlobals.describe
local it = JestGlobals.it

local _typesModule = require(script.Parent.Parent.types)

describe("types module", function()
	it("empty test", function()
		-- just to verify the types file is executing properly
		expect("").toEqual("")
	end)
end)

return {}
