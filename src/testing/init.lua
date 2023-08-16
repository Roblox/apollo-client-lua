--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/testing/index.ts

local srcWorkspace = script.Parent

local invariant = require(srcWorkspace.jsutils.invariant).invariant
local DEV = require(script.Parent.utilities).DEV

invariant("boolean" == typeof(DEV), DEV)

local testingModule = require(script.Parent.utilities.testing)
export type MockedProviderProps<TSerializedCache> = testingModule.MockedProviderProps<TSerializedCache>
export type MockLink = testingModule.MockLink
export type MockedResponse<TData> = testingModule.MockedResponse<TData>
export type ResultFunction<T> = testingModule.ResultFunction<T>
export type MockSubscriptionLink = testingModule.MockSubscriptionLink

return testingModule
