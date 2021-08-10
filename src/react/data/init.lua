-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/data/index.ts
local exports = {}
-- exports.SubscriptionData = require(script.SubscriptionData).SubscriptionData
exports.OperationData = require(script.OperationData).OperationData
exports.MutationData = require(script.MutationData).MutationData
-- exports.QueryData = require(script.QueryData).QueryData
return exports
