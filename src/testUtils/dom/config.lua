-- ROBLOX upstream: https://github.com/testing-library/dom-testing-library/blob/v6.11.0/src/config.js

local exports = {}

local rootWorkspace = script.Parent.Parent.Parent.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

type GenericFunction = (...any) -> any?

-- It would be cleaner for this to live inside './queries', but
-- other parts of the code assume that all exports from
-- './queries' are query functions.
local config = {
	testIdAttribute = "data-testid",
	asyncUtilTimeout = 4500,
	-- this is to support React's async `act` function.
	-- forcing react-testing-library to wrap all async functions would've been
	-- a total nightmare (consider wrapping every findBy* query and then also
	-- updating `within` so those would be wrapped too. Total nightmare).
	-- so we have this config option that's really only intended for
	-- react-testing-library to use. For that reason, this feature will remain
	-- undocumented.
	asyncWrapper = function(cb: GenericFunction)
		return cb()
	end,
	-- default value for the `hidden` option in `ByRole` queries
	defaultHidden = false,
}

local function configure(newConfig)
	if typeof(newConfig) == "function" then
		-- Pass the existing config out to the provided function
		-- and accept a delta in return
		newConfig = newConfig(config)
	end

	-- Merge the incoming config delta
	config = Object.assign({}, config, newConfig)
end
exports.configure = configure

local function getConfig()
	return config
end
exports.getConfig = getConfig

return exports
