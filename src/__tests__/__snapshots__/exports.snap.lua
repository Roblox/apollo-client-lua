-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/__tests__/__snapshots__/exports.ts.snap
local snapshots = {}

-- ROBLOX deviation:
-- Exports added: NULL, Object.None
-- Exports removed: Cache (namespace exported as types)
snapshots["exports of public entry points @apollo/client 1"] = [[

Table {
  "ApolloCache",
  "ApolloClient",
  "ApolloConsumer",
  "ApolloError",
  "ApolloLink",
  "ApolloProvider",
  "DocumentType",
  "HttpLink",
  "InMemoryCache",
  "MissingFieldError",
  "NULL",
  "NetworkStatus",
  "Object",
  "Observable",
  "ObservableQuery",
  "applyNextFetchPolicy",
  "checkFetcher",
  "concat",
  "createHttpLink",
  "createSignalIfSupported",
  "defaultDataIdFromObject",
  "disableExperimentalFragmentVariables",
  "disableFragmentWarnings",
  "empty",
  "enableExperimentalFragmentVariables",
  "execute",
  "fallbackHttpConfig",
  "from",
  "fromError",
  "fromPromise",
  "getApolloContext",
  "gql",
  "isApolloError",
  "isReference",
  "makeReference",
  "makeVar",
  "mergeOptions",
  "operationName",
  "parseAndCheckHttpResponse",
  "parser",
  "resetApolloContext",
  "resetCaches",
  "rewriteURIForGET",
  "selectHttpOptionsAndBody",
  "selectURI",
  "serializeFetchParameter",
  "setLogVerbosity",
  "split",
  "throwServerError",
  "toPromise",
  "useApolloClient",
  "useLazyQuery",
  "useMutation",
  "useQuery",
  "useReactiveVar",
  "useSubscription",
}
]]

-- ROBLOX deviation:
-- Exports removed: Object.None
-- Exports removed: Cache (namespace exported as types)
snapshots["exports of public entry points @apollo/client/cache 1"] = [[

Table {
  "ApolloCache",
  "EntityStore",
  "InMemoryCache",
  "MissingFieldError",
  "Object",
  "Policies",
  "cacheSlot",
  "canonicalStringify",
  "defaultDataIdFromObject",
  "fieldNameFromStoreName",
  "isReference",
  "makeReference",
  "makeVar",
}
]]

-- ROBLOX deviation:
-- Exports added: NULL, Object.None
-- Exports removed: Cache (namespace exported as types)
snapshots["exports of public entry points @apollo/client/core 1"] = [[

Table {
  "ApolloCache",
  "ApolloClient",
  "ApolloError",
  "ApolloLink",
  "HttpLink",
  "InMemoryCache",
  "MissingFieldError",
  "NULL",
  "NetworkStatus",
  "Object",
  "Observable",
  "ObservableQuery",
  "applyNextFetchPolicy",
  "checkFetcher",
  "concat",
  "createHttpLink",
  "createSignalIfSupported",
  "defaultDataIdFromObject",
  "disableExperimentalFragmentVariables",
  "disableFragmentWarnings",
  "empty",
  "enableExperimentalFragmentVariables",
  "execute",
  "fallbackHttpConfig",
  "from",
  "fromError",
  "fromPromise",
  "gql",
  "isApolloError",
  "isReference",
  "makeReference",
  "makeVar",
  "mergeOptions",
  "parseAndCheckHttpResponse",
  "resetCaches",
  "rewriteURIForGET",
  "selectHttpOptionsAndBody",
  "selectURI",
  "serializeFetchParameter",
  "setLogVerbosity",
  "split",
  "throwServerError",
  "toPromise",
}
]]

snapshots["exports of public entry points @apollo/client/errors 1"] = [[

Table {
  "ApolloError",
  "isApolloError",
}
]]

snapshots["exports of public entry points @apollo/client/link/batch 1"] = [[

Table {
  "BatchLink",
  "OperationBatcher",
}
]]

snapshots["exports of public entry points @apollo/client/link/batch-http 1"] = [[

Table {
  "BatchHttpLink",
}
]]

snapshots["exports of public entry points @apollo/client/link/context 1"] = [[

Table {
  "setContext",
}
]]

snapshots["exports of public entry points @apollo/client/link/core 1"] = [[

Table {
  "ApolloLink",
  "concat",
  "empty",
  "execute",
  "from",
  "split",
}
]]

snapshots["exports of public entry points @apollo/client/link/error 1"] = [[

Table {
  "ErrorLink",
  "onError",
}
]]

snapshots["exports of public entry points @apollo/client/link/http 1"] = [[

Table {
  "HttpLink",
  "checkFetcher",
  "createHttpLink",
  "createSignalIfSupported",
  "fallbackHttpConfig",
  "parseAndCheckHttpResponse",
  "rewriteURIForGET",
  "selectHttpOptionsAndBody",
  "selectURI",
  "serializeFetchParameter",
}
]]

snapshots["exports of public entry points @apollo/client/link/persisted-queries 1"] = [[

Table {
  "VERSION",
  "createPersistedQueryLink",
}
]]

snapshots["exports of public entry points @apollo/client/link/retry 1"] = [[

Table {
  "RetryLink",
}
]]

snapshots["exports of public entry points @apollo/client/link/schema 1"] = [[

Table {
  "SchemaLink",
}
]]

snapshots["exports of public entry points @apollo/client/link/utils 1"] = [[

Table {
  "createOperation",
  "fromError",
  "fromPromise",
  "throwServerError",
  "toPromise",
  "transformOperation",
  "validateOperation",
}
]]

snapshots["exports of public entry points @apollo/client/link/ws 1"] = [[

Table {
  "WebSocketLink",
}
]]

snapshots["exports of public entry points @apollo/client/react 1"] = [[

Table {
  "ApolloConsumer",
  "ApolloProvider",
  "DocumentType",
  "getApolloContext",
  "operationName",
  "parser",
  "resetApolloContext",
  "useApolloClient",
  "useLazyQuery",
  "useMutation",
  "useQuery",
  "useReactiveVar",
  "useSubscription",
}
]]

snapshots["exports of public entry points @apollo/client/react/components 1"] = [[

Table {
  "Mutation",
  "Query",
  "Subscription",
}
]]

snapshots["exports of public entry points @apollo/client/react/context 1"] = [[

Table {
  "ApolloConsumer",
  "ApolloProvider",
  "getApolloContext",
  "resetApolloContext",
}
]]

snapshots["exports of public entry points @apollo/client/react/data 1"] = [[

Table {
  "MutationData",
  "OperationData",
  "QueryData",
  "SubscriptionData",
}
]]

snapshots["exports of public entry points @apollo/client/react/hoc 1"] = [[

Table {
  "graphql",
  "withApollo",
  "withMutation",
  "withQuery",
  "withSubscription",
}
]]

snapshots["exports of public entry points @apollo/client/react/hooks 1"] = [[

Table {
  "useApolloClient",
  "useLazyQuery",
  "useMutation",
  "useQuery",
  "useReactiveVar",
  "useSubscription",
}
]]

snapshots["exports of public entry points @apollo/client/react/parser 1"] = [[

Table {
  "DocumentType",
  "operationName",
  "parser",
}
]]

snapshots["exports of public entry points @apollo/client/react/ssr 1"] = [[

Table {
  "RenderPromises",
  "getDataFromTree",
  "getMarkupFromTree",
  "renderToStringWithData",
}
]]

snapshots["exports of public entry points @apollo/client/testing 1"] = [[

Table {
  "MockLink",
  "MockSubscriptionLink",
  "MockedProvider",
  "createMockClient",
  "itAsync",
  "mockObservableLink",
  "mockSingleLink",
  "stripSymbols",
  "subscribeAndCount",
  "withErrorSpy",
  "withLogSpy",
  "withWarningSpy",
}
]]

-- ROBLOX deviation:
-- Exports added: NULL, uuid
snapshots["exports of public entry points @apollo/client/utilities 1"] = [[

Table {
  "Concast",
  "DEV",
  "DeepMerger",
  "NULL",
  "Observable",
  "addTypenameToDocument",
  "argumentsObjectFromField",
  "asyncMap",
  "buildQueryFromSelectionSet",
  "canUseWeakMap",
  "canUseWeakSet",
  "checkDocument",
  "cloneDeep",
  "compact",
  "concatPagination",
  "createFragmentMap",
  "fixObservableSubclass",
  "getDefaultValues",
  "getDirectiveNames",
  "getFragmentDefinition",
  "getFragmentDefinitions",
  "getFragmentFromSelection",
  "getFragmentQueryDocument",
  "getInclusionDirectives",
  "getMainDefinition",
  "getOperationDefinition",
  "getOperationName",
  "getQueryDefinition",
  "getStoreKeyName",
  "getTypenameFromResult",
  "graphQLResultHasError",
  "hasClientExports",
  "hasDirectives",
  "isDocumentNode",
  "isField",
  "isInlineFragment",
  "isNonEmptyArray",
  "isNonNullObject",
  "isReference",
  "iterateObserversSafely",
  "makeReference",
  "makeUniqueId",
  "maybeDeepFreeze",
  "mergeDeep",
  "mergeDeepArray",
  "offsetLimitPagination",
  "relayStylePagination",
  "removeArgumentsFromDocument",
  "removeClientSetsFromDocument",
  "removeConnectionDirectiveFromDocument",
  "removeDirectivesFromDocument",
  "removeFragmentSpreadFromDocument",
  "resultKeyNameFromField",
  "shouldInclude",
  "storeKeyNameFromField",
  "stringifyForDisplay",
  "uuid",
  "valueToObjectRepresentation",
}
]]

return snapshots
