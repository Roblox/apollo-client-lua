-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/cache/inmemory/__tests__/__snapshots__/policies.ts.snap

local snapshots = {}
snapshots["type policies complains about missing key fields 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'title' while writing result {\"theInformationBookData\":{\"subtitle\":\"A History, a Theory, a Flood\",\"author\":{\"name\":\"James Gleick\"},\"title\":\"The Information\",\"isbn\":\"1400096235\",\"__typename\":\"Book\"},\"year\":2011}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]

snapshots["type policies field policies can handle Relay-style pagination without args 1"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "todos": Table {
      "edges": Table {
        Table {
          "__ref": "TodoEdge:edge1",
          "cursor": "YXJyYXljb25uZWN0aW9uOjI=",
        },
      },
      "pageInfo": Table {
        "__typename": "PageInfo",
        "endCursor": "YXJyYXljb25uZWN0aW9uOjI=",
        "hasNextPage": true,
        "hasPreviousPage": false,
        "startCursor": "YXJyYXljb25uZWN0aW9uOjI=",
      },
      "totalCount": 1292,
    },
  },
  "Todo:1": Table {
    "__typename": "Todo",
    "id": "1",
    "title": "Fix the tests",
  },
  "TodoEdge:edge1": Table {
    "__typename": "TodoEdge",
    "id": "edge1",
    "node": Table {
      "__ref": "Todo:1",
    },
  },
}
]]

snapshots["type policies field policies can handle Relay-style pagination without args 2"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "todos": Table {
      "edges": Table {
        Table {
          "__ref": "TodoEdge:edge1",
          "cursor": "YXJyYXljb25uZWN0aW9uOjI=",
        },
      },
      "extraMetaData": "extra",
      "pageInfo": Table {
        "__typename": "PageInfo",
        "endCursor": "YXJyYXljb25uZWN0aW9uOjI=",
        "hasNextPage": true,
        "hasPreviousPage": false,
        "startCursor": "YXJyYXljb25uZWN0aW9uOjI=",
      },
      "totalCount": 1293,
    },
  },
  "Todo:1": Table {
    "__typename": "Todo",
    "id": "1",
    "title": "Fix the tests",
  },
  "TodoEdge:edge1": Table {
    "__typename": "TodoEdge",
    "id": "edge1",
    "node": Table {
      "__ref": "Todo:1",
    },
  },
}
]]

snapshots["type policies field policies read and merge can cooperate through options.storage 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'result' while writing result {\"__typename\":\"Job\",\"name\":\"Job #1\"}",
    },
    Table {
      "Missing field 'result' while writing result {\"__typename\":\"Job\",\"name\":\"Job #2\"}",
    },
    Table {
      "Missing field 'result' while writing result {\"__typename\":\"Job\",\"name\":\"Job #3\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
    Table {
      "type": "return",
    },
    Table {
      "type": "return",
    },
  },
}
]]

snapshots["type policies field policies readField helper function calls custom read functions 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'blockers' while writing result {\"description\":\"grandchild task\",\"__typename\":\"Task\",\"id\":4}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]

snapshots["type policies field policies runs nested merge functions as well as ancestors 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'time' while writing result {\"__typename\":\"Event\",\"id\":123}",
    },
    Table {
      "Missing field 'time' while writing result {\"name\":\"Rooftop dog party\",\"__typename\":\"Event\",\"attendees\":[{\"name\":\"Inspector Beckett\",\"__typename\":\"Attendee\",\"id\":456},{\"__typename\":\"Attendee\",\"id\":234}],\"id\":345}",
    },
    Table {
      "Missing field 'name' while writing result {\"__typename\":\"Attendee\",\"id\":234}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
    Table {
      "type": "return",
    },
    Table {
      "type": "return",
    },
  },
}
]]

return snapshots
