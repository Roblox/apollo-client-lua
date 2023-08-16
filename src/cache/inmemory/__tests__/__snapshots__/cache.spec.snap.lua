--[[
 * Copyright (c) 2021 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.)
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]
-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/__snapshots__/cache.ts.snap

local snapshots = {}
snapshots["Cache cache.restore replaces cache.{store{Reader,Writer},maybeBroadcastWatch} 1"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": "ay",
    "b": "bee",
    "c": "see",
  },
}
]]

snapshots["InMemoryCache#modify should allow invalidation using details.INVALIDATE 1"] = [[

Table {
  "Author:{\"name\":\"Maria Dahvana Headley\"}": Table {
    "__typename": "Author",
    "name": "Maria Dahvana Headley",
  },
  "Book:{\"isbn\":\"0374110034\"}": Table {
    "__typename": "Book",
    "author": Table {
      "__ref": "Author:{\"name\":\"Maria Dahvana Headley\"}",
    },
    "isbn": "0374110034",
    "title": "Beowulf: A New Translation",
  },
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "currentlyReading": Table {
      "__ref": "Book:{\"isbn\":\"0374110034\"}",
    },
  },
}
]]

snapshots["TypedDocumentNode<Data, Variables> should determine Data and Variables types of {write,read}{Query,Fragment} 1"] =
	[[

Table {
  "Author:{\"name\":\"John C. Mitchell\"}": Table {
    "__typename": "Author",
    "name": "John C. Mitchell",
  },
  "Book:{\"isbn\":\"0262133210\"}": Table {
    "__typename": "Book",
    "author": Table {
      "__ref": "Author:{\"name\":\"John C. Mitchell\"}",
    },
    "isbn": "0262133210",
    "title": "Foundations for Programming Languages",
  },
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "book({\"isbn\":\"0262133210\"})": Table {
      "__ref": "Book:{\"isbn\":\"0262133210\"}",
    },
  },
}
]]

-- ROBLOX deviation START: convert Object and Array to Table
snapshots[ [=[TypedDocumentNode<Data, Variables> should determine Data and Variables types of {write,read}{Query,Fragment} 2]=] ] =
	[=[

Table {
  "Author:{\"name\":\"Harold Abelson\"}": Table {
    "__typename": "Author",
    "name": "Harold Abelson",
  },
  "Author:{\"name\":\"John C. Mitchell\"}": Table {
    "__typename": "Author",
    "name": "John C. Mitchell",
  },
  "Book:{\"isbn\":\"0262133210\"}": Table {
    "__typename": "Book",
    "author": Table {
      "__ref": "Author:{\"name\":\"John C. Mitchell\"}",
    },
    "isbn": "0262133210",
    "title": "Foundations for Programming Languages",
  },
  "Book:{\"isbn\":\"0262510871\"}": Table {
    "__typename": "Book",
    "author": Table {
      "__ref": "Author:{\"name\":\"Harold Abelson\"}",
    },
    "isbn": "0262510871",
    "title": "Structure and Interpretation of Computer Programs",
  },
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "book({\"isbn\":\"0262133210\"})": Table {
      "__ref": "Book:{\"isbn\":\"0262133210\"}",
    },
  },
  "__META": Table {
    "extraRootIds": Table {
      "Book:{\"isbn\":\"0262510871\"}",
    },
  },
}
]=]
-- ROBLOX deviation END

return snapshots
