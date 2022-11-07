-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/__snapshots__/roundtrip.ts.snap

local snapshots = {}

-- ROBLOX deviation START: convert Object and Array to Table
snapshots["roundtrip fragments should throw an error on two of the same inline fragment types 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'rank' while writing result {\"name\":\"Luke Skywalker\",\"side\":\"bright\",\"__typename\":\"Jedi\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]

snapshots["roundtrip fragments should throw on error on two of the same spread fragment types 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'rank' while writing result {\"name\":\"Luke Skywalker\",\"side\":\"bright\",\"__typename\":\"Jedi\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]
-- ROBLOX deviation END

return snapshots
