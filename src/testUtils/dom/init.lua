-- ROBLOX upstream: https://github.com/testing-library/dom-testing-library/blob/v6.11.0/src/index.js

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

local exports: { [string]: any } = {}

-- import {getQueriesForElement} from './get-queries-for-element'
-- import * as queries from './queries'
-- import * as queryHelpers from './query-helpers'

-- export * from './queries'

local waitModule = require(script.wait)
Object.assign(exports, waitModule)

-- export * from './wait-for-element'
-- export * from './wait-for-element-to-be-removed'
-- export * from './wait-for-dom-change'
-- export {getDefaultNormalizer} from './matches'
-- export * from './get-node-text'
-- export * from './events'
-- export * from './get-queries-for-element'
-- export * from './screen'
-- export * from './query-helpers'
-- export {getRoles, logRoles, isInaccessible} from './role-helpers'
-- export * from './pretty-dom'
exports.configure = require(script.config).configure

-- export {
--   // The original name of bindElementToQueries was weird
--   // The new name is better. Remove this in the next major version bump.
--   getQueriesForElement as bindElementToQueries,
--   getQueriesForElement as within,
--   // export query utils under a namespace for convenience:
--   queries,
--   queryHelpers,
-- }

return exports :: typeof(exports) & typeof(waitModule)
