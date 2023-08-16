--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/testing/index.ts
local exports = {}

local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Object = LuauPolyfill.Object

local MockedProviderModule = require(script.mocking.MockedProvider)
exports.MockedProvider = MockedProviderModule.MockedProvider
export type MockedProviderProps<TSerializedCache> = MockedProviderModule.MockedProviderProps<TSerializedCache>
local mockLinkModule = require(script.mocking.mockLink)
exports.MockLink = mockLinkModule.MockLink
export type MockLink = mockLinkModule.MockLink
exports.mockSingleLink = mockLinkModule.mockSingleLink
export type MockedResponse<TData> = mockLinkModule.MockedResponse<TData>
export type ResultFunction<T> = mockLinkModule.ResultFunction<T>
local mockSubscriptionLinkModule = require(script.mocking.mockSubscriptionLink)
exports.MockSubscriptionLink = mockSubscriptionLinkModule.MockSubscriptionLink
export type MockSubscriptionLink = mockSubscriptionLinkModule.MockSubscriptionLink
exports.mockObservableLink = mockSubscriptionLinkModule.mockObservableLink
-- exports.createMockClient = require(script.mocking.mockClient).createMockClient
exports.stripSymbols = require(script.stripSymbols).stripSymbols
exports.subscribeAndCount = require(script.subscribeAndCount).default
exports.itAsync = require(script.itAsync).itAsync
local withConsoleSpyModule = require(script.withConsoleSpy)
Object.assign(exports, withConsoleSpyModule)
return exports :: typeof(exports) & typeof(withConsoleSpyModule)
