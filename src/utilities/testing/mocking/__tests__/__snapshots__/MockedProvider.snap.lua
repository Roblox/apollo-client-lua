-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/mocking/__tests__/__snapshots__/MockedProvider.test.tsx.snap

local snapshots = {}

snapshots["General use should allow querying with the typename 1"] = [[

Table {
  "__typename": "User",
  "id": "user_id",
}
]]

snapshots["General use should error if the query in the mock and component do not match 1"] = [[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: {\"username\":\"mock_username\"}
"
]]

snapshots["General use should error if the variables do not deep equal 1"] = [[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: {\"age\":42,\"username\":\"some_user\"}
  
Failed to match 1 mock for this query, which had the following variables:
	  {\"username\":\"some_user\",\"age\":13}
"
]]

snapshots["General use should error if the variables in the mock and component do not match 1"] = [[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: {\"username\":\"other_user\"}
  
Failed to match 1 mock for this query, which had the following variables:
	  {\"username\":\"mock_username\"}
"
]]

snapshots["General use should mock the data 1"] = [[

Table {
  "__typename": "User",
  "id": "user_id",
}
]]

snapshots["General use should not error if the variables match but have different order 1"] = [[

Table {
  "user": Table {
    "__typename": "User",
    "id": "user_id",
  },
}
]]

snapshots["General use should pipe exceptions thrown in custom onError functions through the link chain 1"] = [[
"oh no!"]]

snapshots['General use should return "Mocked response should contain" errors in response 1'] = [[
"Mocked response should contain either result or error: {\"query\":\"query GetUser($username: String!) {\\n  user(username: $username) {\\n    id\\n    __typename\\n  }\\n}\\n\"}"]]

snapshots['General use should return "No more mocked responses" errors in response 1'] = [[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: []
"
]]

snapshots["General use should support custom error handling using setOnError 1"] = [[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: {\"username\":\"mock_username\"}
"
]]

return snapshots
