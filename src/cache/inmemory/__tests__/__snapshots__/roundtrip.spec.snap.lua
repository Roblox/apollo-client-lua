-- Jest Roblox Snapshot v1, http://roblox.github.io/jest-roblox/snapshot-testing
local exports = {}
exports[ [=[roundtrip fragments should throw an error on two of the same inline fragment types 1]=] ] = [=[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'rank' while writing result {\"__typename\":\"Jedi\",\"name\":\"Luke Skywalker\",\"side\":\"bright\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]=]

exports[ [=[roundtrip fragments should throw on error on two of the same spread fragment types 1]=] ] = [=[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'rank' while writing result {\"__typename\":\"Jedi\",\"name\":\"Luke Skywalker\",\"side\":\"bright\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]=]

return exports
