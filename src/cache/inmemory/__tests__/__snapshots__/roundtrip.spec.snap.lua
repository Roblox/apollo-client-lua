--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
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
