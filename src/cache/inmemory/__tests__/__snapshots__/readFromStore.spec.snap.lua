-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/__snapshots__/readFromStore.ts.snap

local snapshots = {}

-- ROBLOX deviation: this test is skipping the parts where it uses fragments
-- Snapshot has been edited to reflect what would happen upstream.
snapshots["reading from the store propagates eviction signals to parent queries 1"] = [=[
[MockFunction]]=]

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
