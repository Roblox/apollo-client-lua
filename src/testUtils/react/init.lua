-- ROBLOX upstream: https://github.com/testing-library/react-testing-library/blob/v12.1.2/src/index.js

local cleanup = require(script.pure).cleanup

-- ROBLOX deviation: passing afterEach/teardown as a function parameter
-- if we're running in a test runner that supports afterEach
-- or teardown then we'll automatically run cleanup afterEach test
-- this ensures that tests run in isolation from each other
-- if you don't like this then either import the `pure` module
-- or set the RTL_SKIP_AUTO_CLEANUP env variable to 'true'.
-- if (typeof process === 'undefined' || !process.env?.RTL_SKIP_AUTO_CLEANUP) {
--   // ignore teardown() in code coverage because Jest does not support it
--   /* istanbul ignore else */
--   if (typeof afterEach === 'function') {
--     afterEach(() => {
--       cleanup()
--     })
--   } else if (typeof teardown === 'function') {
--     // Block is guarded by `typeof` check.
--     // eslint does not support `typeof` guards.
--     // eslint-disable-next-line no-undef
--     teardown(() => {
--       cleanup()
--     })
--   }

return function(afterEach)
	if not _G.RTL_SKIP_AUTO_CLEANUP and typeof(afterEach) == "function" then
		afterEach(function()
			cleanup()
		end)
	end
	return require(script.pure)
end
