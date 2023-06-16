-- Jest Roblox Snapshot v1, http://roblox.github.io/jest-roblox/snapshot-testing
local exports = {}
exports[ [=[mutation results should warn when the result fields don't match the query fields 1]=] ] = [=[

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
]=]

exports[ [=[mutation results should warn when the result fields don't match the query fields 2]=] ] = [=[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'description' while writing result {\"id\":\"2\",\"__typename\":\"createTodo\",\"name\":\"Todo 2\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]=]

exports[ [=[mutation results should write results to cache according to errorPolicy 1]=] ] = [=[
Table {}]=]

exports[ [=[mutation results should write results to cache according to errorPolicy 2]=] ] = [=[

Table {
  "Person:{\"name\":\"Jenn Creighton\"}": Table {
    "__typename": "Person",
    "name": "Jenn Creighton",
  },
  "ROOT_MUTATION": Table {
    "__typename": "Mutation",
  },
}
]=]

exports[ [=[mutation results should write results to cache according to errorPolicy 3]=] ] = [=[

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
]=]

return exports
