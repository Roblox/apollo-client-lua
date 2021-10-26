-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/__tests__/__snapshots__/readFromStore.ts.snap

local snapshots = {}

snapshots["reading from the store propagates eviction signals to parent queries 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'children' while writing result {
  \"__typename\": \"Deity\",
  \"name\": \"Zeus\"
}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
      "value": undefined,
    },
  },
}
]]

snapshots["reading from the store returns === results for different queries 1"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": Table {
      "a",
      "y",
      "y",
    },
    "b": Table {
      "c": "C",
      "d": "D",
    },
  },
}
]]

return snapshots
