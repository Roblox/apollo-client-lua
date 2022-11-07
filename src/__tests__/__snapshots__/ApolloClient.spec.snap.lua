-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/__tests__/__snapshots__/ApolloClient.ts.snap

local snapshots = {}

snapshots["ApolloClient constructor will throw an error if cache is not passed in 1"] = [[

"To initialize Apollo Client, you must specify a 'cache' property in the options object. 
For more information, please visit: https://go.apollo.dev/c/docs"
]]

snapshots["ApolloClient write then read will not use a default id getter if either _id or id is present when __typename is not also present 1"] =
	[[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "b": 2,
    "bar": Table {
      "foo": Table {
        "_id": "barfoo",
        "k": 12,
        "l": 13,
      },
      "i": 10,
      "j": 11,
    },
    "foo": Table {
      "bar": Table {
        "__ref": "bar:foobar",
      },
      "c": 3,
      "d": 4,
    },
    "g": 8,
    "h": 9,
  },
  "bar:foobar": Table {
    "__typename": "bar",
    "e": 5,
    "f": 6,
    "id": "foobar",
  },
}
]]

snapshots["ApolloClient write then read will not use a default id getter if either _id or id is present when __typename is not also present 1"] =
	[[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "b": 2,
    "bar": Table {
      "foo": Table {
        "_id": "barfoo",
        "k": 12,
        "l": 13,
      },
      "i": 10,
      "j": 11,
    },
    "foo": Table {
      "bar": Table {
        "__ref": "bar:foobar",
      },
      "c": 3,
      "d": 4,
    },
    "g": 8,
    "h": 9,
  },
  "bar:foobar": Table {
    "__typename": "bar",
    "e": 5,
    "f": 6,
    "id": "foobar",
  },
}
]]

snapshots["ApolloClient writeQuery should warn when the data provided does not match the query shape 1"] = [[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'description' while writing result {\"name\":\"Todo 1\",\"__typename\":\"Todo\",\"id\":\"1\"}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]]

snapshots["ApolloClient write then read will not use a default id getter if id and _id are not present 1"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "b": 2,
    "bar": Table {
      "__typename": "bar",
      "foo": Table {
        "__typename": "foo",
        "k": 12,
        "l": 13,
      },
      "i": 10,
      "j": 11,
    },
    "foo": Table {
      "__typename": "foo",
      "bar": Table {
        "__typename": "bar",
        "e": 5,
        "f": 6,
      },
      "c": 3,
      "d": 4,
    },
    "g": 8,
    "h": 9,
  },
}
]]

snapshots["ApolloClient write then read will use a default id getter if __typename and _id are present 1"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "b": 2,
    "foo": Table {
      "__typename": "foo",
      "bar": Table {
        "__ref": "bar:foobar",
      },
      "c": 3,
      "d": 4,
    },
  },
  "bar:foobar": Table {
    "__typename": "bar",
    "_id": "foobar",
    "e": 5,
    "f": 6,
  },
}
]]

snapshots["ApolloClient write then read will use a default id getter if __typename and id are present 1"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "b": 2,
    "foo": Table {
      "__typename": "foo",
      "bar": Table {
        "__ref": "bar:foobar",
      },
      "c": 3,
      "d": 4,
    },
  },
  "bar:foobar": Table {
    "__typename": "bar",
    "e": 5,
    "f": 6,
    "id": "foobar",
  },
}
]]

snapshots["ApolloClient write then read will use a default id getter if one is not specified and __typename is present along with either _id or id 1"] =
	[[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "b": 2,
    "bar": Table {
      "__typename": "bar",
      "foo": Table {
        "__ref": "foo:barfoo",
      },
      "i": 10,
      "j": 11,
    },
    "foo": Table {
      "__typename": "foo",
      "bar": Table {
        "__ref": "bar:foobar",
      },
      "c": 3,
      "d": 4,
    },
    "g": 8,
    "h": 9,
  },
  "bar:foobar": Table {
    "__typename": "bar",
    "e": 5,
    "f": 6,
    "id": "foobar",
  },
  "foo:barfoo": Table {
    "__typename": "foo",
    "_id": "barfoo",
    "k": 12,
    "l": 13,
  },
}
]]

snapshots["ApolloClient write then read will write data to a specific id 1"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "b": 2,
    "foo": Table {
      "__typename": "foo",
      "bar": Table {
        "__ref": "foobar",
      },
      "c": 3,
      "d": 4,
    },
  },
  "foobar": Table {
    "__typename": "bar",
    "e": 5,
    "f": 6,
    "key": "foobar",
  },
}
]]

-- ROBLOX deviation START: convert Object and Array to Table
snapshots[ [=[ApolloClient writeFragment should warn when the data provided does not match the fragment shape 1]=] ] =
	[=[

[MockFunction] {
  "calls": Table {
    Table {
      "Missing field 'e' while writing result {\"__typename\":\"Bar\",\"i\":10}",
    },
  },
  "results": Table {
    Table {
      "type": "return",
    },
  },
}
]=]

snapshots[ [=[ApolloClient writeFragment will write some deeply nested data into the store at any id 1]=] ] = [=[

Table {
  "__META": Table {
    "extraRootIds": Table {
      "foo",
    },
  },
  "bar": Table {
    "__typename": "Bar",
    "i": 7,
  },
  "foo": Table {
    "__typename": "Foo",
    "e": 4,
    "h": Table {
      "__ref": "bar",
    },
  },
}
]=]

snapshots[ [=[ApolloClient writeFragment will write some deeply nested data into the store at any id 2]=] ] = [=[

Table {
  "__META": Table {
    "extraRootIds": Table {
      "foo",
    },
  },
  "bar": Table {
    "__typename": "Bar",
    "i": 7,
    "j": 8,
    "k": 9,
  },
  "foo": Table {
    "__typename": "Foo",
    "e": 4,
    "f": 5,
    "g": 6,
    "h": Table {
      "__ref": "bar",
    },
  },
}
]=]

snapshots[ [=[ApolloClient writeFragment will write some deeply nested data into the store at any id 3]=] ] = [=[

Table {
  "__META": Table {
    "extraRootIds": Table {
      "bar",
      "foo",
    },
  },
  "bar": Table {
    "__typename": "Bar",
    "i": 10,
    "j": 8,
    "k": 9,
  },
  "foo": Table {
    "__typename": "Foo",
    "e": 4,
    "f": 5,
    "g": 6,
    "h": Table {
      "__ref": "bar",
    },
  },
}
]=]

snapshots[ [=[ApolloClient writeFragment will write some deeply nested data into the store at any id 4]=] ] = [=[

Table {
  "__META": Table {
    "extraRootIds": Table {
      "bar",
      "foo",
    },
  },
  "bar": Table {
    "__typename": "Bar",
    "i": 10,
    "j": 11,
    "k": 12,
  },
  "foo": Table {
    "__typename": "Foo",
    "e": 4,
    "f": 5,
    "g": 6,
    "h": Table {
      "__ref": "bar",
    },
  },
}
]=]

snapshots[ [=[ApolloClient writeFragment will write some deeply nested data into the store at any id 5]=] ] = [=[

Table {
  "__META": Table {
    "extraRootIds": Table {
      "bar",
      "foo",
    },
  },
  "bar": Table {
    "__typename": "Bar",
    "i": 7,
    "j": 8,
    "k": 9,
  },
  "foo": Table {
    "__typename": "Foo",
    "e": 4,
    "f": 5,
    "g": 6,
    "h": Table {
      "__ref": "bar",
    },
  },
}
]=]

snapshots[ [=[ApolloClient writeFragment will write some deeply nested data into the store at any id 6]=] ] = [=[

Table {
  "__META": Table {
    "extraRootIds": Table {
      "bar",
      "foo",
    },
  },
  "bar": Table {
    "__typename": "Bar",
    "i": 10,
    "j": 11,
    "k": 12,
  },
  "foo": Table {
    "__typename": "Foo",
    "e": 4,
    "f": 5,
    "g": 6,
    "h": Table {
      "__ref": "bar",
    },
  },
}
]=]

snapshots[ [=[ApolloClient write then read will write data locally which will then be read back 1]=] ] = [=[

Table {
  "__META": Table {
    "extraRootIds": Table {
      "bar",
      "foo",
    },
  },
  "bar": Table {
    "__typename": "Bar",
    "d": 8,
    "e": 9,
    "f": 6,
  },
  "foo": Table {
    "__typename": "Foo",
    "a": 7,
    "b": 2,
    "bar": Table {
      "__ref": "bar",
    },
    "c": 3,
  },
}
]=]
-- ROBLOX deviation END

snapshots["ApolloClient writeQuery will write some deeply nested data to the store 1"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "d": Table {
      "__typename": "D",
      "e": 4,
    },
  },
}
]]

snapshots["ApolloClient writeQuery will write some deeply nested data to the store 2"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "d": Table {
      "__typename": "D",
      "h": Table {
        "__typename": "H",
        "i": 7,
      },
    },
  },
}
]]

snapshots["ApolloClient writeQuery will write some deeply nested data to the store 3"] = [[

Table {
  "ROOT_QUERY": Table {
    "__typename": "Query",
    "a": 1,
    "b": 2,
    "c": 3,
    "d": Table {
      "__typename": "D",
      "e": 4,
      "f": 5,
      "g": 6,
      "h": Table {
        "__typename": "H",
        "i": 7,
        "j": 8,
        "k": 9,
      },
    },
  },
}
]]

return snapshots
