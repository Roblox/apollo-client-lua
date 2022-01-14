-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/testing/index.ts

local srcWorkspace = script.Parent

local invariant = require(srcWorkspace.jsutils.invariant).invariant
local DEV = require(script.Parent.utilities).DEV

invariant("boolean" == typeof(DEV), DEV)

return require(script.Parent.utilities.testing)
