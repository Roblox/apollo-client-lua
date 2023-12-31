--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/__snapshots__/entityStore.ts.snap

local snapshots = {}

snapshots["EntityStore ignores retainment count for ROOT_QUERY 1"] = [[

Table {
  "Author:Allie Brosh": Table {
    "__typename": "Author",
    "name": "Allie Brosh",
  },
  "Book:1982156945": Table {
    "__typename": "Book",
    "author": Table {
      "__ref": "Author:Allie Brosh",
    },
    "title": "Solutions and Other Problems",
  },
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "book": Table {
      "__ref": "Book:1982156945",
    },
  },
  "__META": Table {
    "extraRootIds": Table {
      "Author:Allie Brosh",
    },
  },
}
]]

snapshots["EntityStore ignores retainment count for ROOT_QUERY 2"] = [[

Table {
  "Author:Allie Brosh": Table {
    "__typename": "Author",
    "name": "Allie Brosh",
  },
  "__META": Table {
    "extraRootIds": Table {
      "Author:Allie Brosh",
    },
  },
}
]]

return snapshots
