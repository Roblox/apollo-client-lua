local srcWorkspace = script.Parent

local invariantModule = require(srcWorkspace.jsutils.invariant)
local invariant = invariantModule.invariant
local DEV = require(script.Parent.utilities).DEV

invariant("boolean" == typeof(DEV), DEV)

return require(script.Parent.utilities.testing)
