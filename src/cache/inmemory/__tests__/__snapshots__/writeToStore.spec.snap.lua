-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/cache/inmemory/__tests__/__snapshots__/writeToStore.ts.snap

local snapshots = {}

snapshots['writing to the store "Cache data maybe lost..." warnings should not warn when scalar fields are updated 1'] =
	[[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "currentTime({\"tz\":\"UTC-5\"})": Table {
      "localeString": "9/25/2020, 1:08:33 PM",
    },
    "someJSON": Table {
      "foos": Table {
        "bar",
        "baz",
      },
      "oyez": 3,
    },
  },
}
]]

snapshots['writing to the store "Cache data maybe lost..." warnings should not warn when scalar fields are updated 2'] =
	[[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "currentTime({\"tz\":\"UTC-5\"})": Table {
      "msSinceEpoch": 1601053713081,
    },
    "someJSON": Table {
      "asdf": "middle",
      "qwer": "upper",
      "zxcv": "lower",
    },
  },
}
]]

snapshots["writing to the store correctly merges fragment fields along multiple paths 1"] = [[

Table {
  "Item:0f47f85d-8081-466e-9121-c94069a77c3e": Table {
    "__typename": "Item",
    "id": "0f47f85d-8081-466e-9121-c94069a77c3e",
    "value": Table {
      "__typename": "Container",
      "value": Table {
        "__typename": "Value",
        "item": Table {
          "__ref": "Item:6dc3530b-6731-435e-b12a-0089d0ae05ac",
        },
      },
    },
  },
  "Item:6dc3530b-6731-435e-b12a-0089d0ae05ac": Table {
    "__typename": "Item",
    "id": "6dc3530b-6731-435e-b12a-0089d0ae05ac",
    "value": Table {
      "__typename": "Container",
      "text": "Hello World",
      "value": Table {
        "__typename": "Value",
      },
    },
  },
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "item({\"id\":\"123\"})": Table {
      "__ref": "Item:0f47f85d-8081-466e-9121-c94069a77c3e",
    },
  },
}
]]

-- snapshots["writing to the store should not keep reference when type of mixed inlined field changes to non-inlined field 1"] =
-- 	[[

-- [MockFunction] {
--   "calls": Table {
--     Table {
--       "Missing field 'price' while writing result {
--   \"id\": \"1\",
--   \"name\": \"Todo 1\",
--   \"description\": \"Description 1\",
--   \"__typename\": \"ShoppingCartItem\"
-- }",
--     },
--     Table {
--       "Missing field 'expensive' while writing result {
--   \"id\": 1
-- }",
--     },
--     Table {
--       "Missing field 'id' while writing result {
--   \"__typename\": \"Cat\",
--   \"name\": \"cat\"
-- }",
--     },
--   },
--   "results": Table {
--     Table {
--       "type": "return",
--       "value": undefined,
--     },
--     Table {
--       "type": "return",
--       "value": undefined,
--     },
--     Table {
--       "type": "return",
--       "value": undefined,
--     },
--   },
-- }
-- ]]

-- ROBLOX deviation START: expect NULL utility helper instead of js "null" for titleSize
snapshots["writing to the store should respect id fields added by fragments 1"] = [[

Table {
  "AType:a-id": Table {
    "__typename": "AType",
    "b": Table {
      Table {
        "__ref": "BType:b-id",
      },
    },
    "id": "a-id",
  },
  "BType:b-id": Table {
    "__typename": "BType",
    "c": Table {
      "__typename": "CType",
      "title": "Your experience",
      "titleSize": Table {
        "__value": "null",
      },
    },
    "id": "b-id",
  },
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": Table {
      "__ref": "AType:a-id",
    },
  },
}
]]
-- ROBLOX deviation END

snapshots['writing to the store user objects should be able to have { __typename: "Mutation" } 1'] = [[

Table {
  "Gene:{\"id\":\"SLC45A2\"}": Table {
    "__typename": "Gene",
    "id": "SLC45A2",
  },
  "Gene:{\"id\":\"SNAI2\"}": Table {
    "__typename": "Gene",
    "id": "SNAI2",
  },
  "Mutation:{\"gene\":{\"id\":\"SLC45A2\"},\"name\":\"albinism\"}": Table {
    "__typename": "Mutation",
    "gene": Table {
      "__ref": "Gene:{\"id\":\"SLC45A2\"}",
      "id": "SLC45A2",
    },
    "name": "albinism",
  },
  "Mutation:{\"gene\":{\"id\":\"SNAI2\"},\"name\":\"piebaldism\"}": Table {
    "__typename": "Mutation",
    "gene": Table {
      "__ref": "Gene:{\"id\":\"SNAI2\"}",
      "id": "SNAI2",
    },
    "name": "piebaldism",
  },
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "mutations": Table {
      Table {
        "__ref": "Mutation:{\"gene\":{\"id\":\"SLC45A2\"},\"name\":\"albinism\"}",
      },
      Table {
        "__ref": "Mutation:{\"gene\":{\"id\":\"SNAI2\"},\"name\":\"piebaldism\"}",
      },
    },
  },
}
]]

snapshots['writing to the store user objects should be able to have { __typename: "Subscription" } 1'] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "subscriptions": Table {
      Table {
        "__ref": "Subscription:{\"subId\":1}",
      },
      Table {
        "__ref": "Subscription:{\"subId\":2}",
      },
      Table {
        "__ref": "Subscription:{\"subId\":3}",
      },
    },
  },
  "Subscription:{\"subId\":1}": Table {
    "__typename": "Subscription",
    "subId": 1,
    "subscriber": Table {
      "name": "Alice",
    },
  },
  "Subscription:{\"subId\":2}": Table {
    "__typename": "Subscription",
    "subId": 2,
    "subscriber": Table {
      "name": "Bob",
    },
  },
  "Subscription:{\"subId\":3}": Table {
    "__typename": "Subscription",
    "subId": 3,
    "subscriber": Table {
      "name": "Clytemnestra",
    },
  },
}
]]

snapshots["writing to the store writeResultToStore shape checking should warn when it receives the wrong data with non-union fragments 1"] =
	[[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'description' while writing result {\"name\":\"Todo 1\",\"id\":\"1\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]

snapshots["writing to the store writeResultToStore shape checking should write the result data without validating its shape when a fragment matcher is not provided 1"] =
	[[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'description' while writing result {\"name\":\"Todo 1\",\"id\":\"1\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]

return snapshots
