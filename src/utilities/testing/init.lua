-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/index.ts
local exports: { [string]: any } = {}
local MockedProviderModule = require(script.mocking.MockedProvider)
exports.MockedProvider = MockedProviderModule.MockedProvider
export type MockedProviderProps<TSerializedCache> = MockedProviderModule.MockedProviderProps<TSerializedCache>
local mockLinkModule = require(script.mocking.mockLink)
exports.MockLink = mockLinkModule.MockLink
export type MockLink = mockLinkModule.MockLink
exports.mockSingleLink = mockLinkModule.mockSingleLink
export type MockedResponse<TData> = mockLinkModule.MockedResponse<TData>
export type ResultFunction<T> = mockLinkModule.ResultFunction<T>
-- local mockSubscriptionLinkModule = require(script.mocking.mockSubscriptionLink)
-- exports.MockSubscriptionLink = mockSubscriptionLinkModule.MockSubscriptionLink
-- exports.mockObservableLink = mockSubscriptionLinkModule.mockObservableLink
-- exports.createMockClient = require(script.mocking.mockClient).createMockClient
exports.stripSymbols = require(script.stripSymbols).stripSymbols
-- exports.subscribeAndCount = require(script.subscribeAndCount).default
exports.itAsync = require(script.itAsync)
exports.withErrorSpy = require(script.withErrorSpy).withErrorSpy
return exports
