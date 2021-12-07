-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/__tests__/__snapshots__/mutationResults.ts.snap

local snapshots = {}

snapshots["mutation results should warn when the result fields don't match the query fields 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'description' while writing result {\"name\":\"Todo 2\",\"__typename\":\"createTodo\",\"id\":\"2\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]

snapshots["mutation results should write results to cache according to errorPolicy 1"] = [[Table {}]]

snapshots["mutation results should write results to cache according to errorPolicy 2"] = [[

Table {
  "Person:{\"name\":\"Jenn Creighton\"}": Table {
    "__typename": "Person",
    "name": "Jenn Creighton",
  },
  "ROOT_MUTATION": Table {
    "__typename": "Mutation",
  },
}
]]

snapshots["mutation results should write results to cache according to errorPolicy 3"] = [[

Table {
  "Person:{\"name\":\"Ellen Shapiro\"}": Table {
    "__typename": "Person",
    "name": "Ellen Shapiro",
  },
  "Person:{\"name\":\"Jenn Creighton\"}": Table {
    "__typename": "Person",
    "name": "Jenn Creighton",
  },
  "ROOT_MUTATION": Table {
    "__typename": "Mutation",
  },
}
]]

return snapshots
