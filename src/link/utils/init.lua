-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/link/utils/index.ts
local exports = {}
-- ROBLOX TODO: uncomment when available
exports.fromError = require(script.fromError).fromError
exports.toPromise = require(script.toPromise).toPromise
exports.fromPromise = require(script.fromPromise).fromPromise
-- local throwServerErrorModule = require(script.throwServerError)
-- exports.ServerError = throwServerErrorModule.ServerError
-- exports.throwServerError = throwServerErrorModule.throwServerError
exports.validateOperation = require(script.validateOperation).validateOperation
exports.createOperation = require(script.createOperation).createOperation
exports.transformOperation = require(script.transformOperation).transformOperation
return exports
