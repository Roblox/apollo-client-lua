--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/react/components/__tests__/client/__snapshots__/Query.test.tsx.snap

local snapshots = {}

snapshots["Query component Partial refetching should attempt a refetch when the query result was marked as being partial, the returned data was reset to an empty Object by the Apollo Client QueryManager (due to a cache miss), and the `partialRefetch` prop is `true` 1"] =
	[[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'allPeople' while writing result []",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]

snapshots["Query component calls the children prop: result in render prop 1"] = [[

Table {
  "called": true,
  "data": Table {
    "allPeople": Table {
      "people": Table {
        Table {
          "name": "Luke Skywalker",
        },
      },
    },
  },
  "fetchMore": [Function],
  "loading": false,
  "networkStatus": 7,
  "refetch": [Function],
  "startPolling": [Function],
  "stopPolling": [Function],
  "subscribeToMore": [Function],
  "updateQuery": [Function],
  "variables": Table {},
}
]]

snapshots["Query component calls the children prop: result in render prop while loading 1"] = [[

Table {
  "called": true,
  "fetchMore": [Function],
  "loading": true,
  "networkStatus": 1,
  "refetch": [Function],
  "startPolling": [Function],
  "stopPolling": [Function],
  "subscribeToMore": [Function],
  "updateQuery": [Function],
  "variables": Table {},
}
]]

return snapshots
