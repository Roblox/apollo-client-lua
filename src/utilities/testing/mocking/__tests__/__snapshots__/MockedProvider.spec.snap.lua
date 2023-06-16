-- Jest Roblox Snapshot v1, http://roblox.github.io/jest-roblox/snapshot-testing
local exports = {}
exports[ [=[General use should allow querying with the typename 1]=] ] = [=[

Table {
  "__typename": "User",
  "id": "user_id",
}
]=]

exports[ [=[General use should error if the query in the mock and component do not match 1]=] ] = [=[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: {\"username\":\"mock_username\"}
"
]=]

exports[ [=[General use should error if the variables do not deep equal 1]=] ] = [=[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: {\"username\":\"some_user\",\"age\":42}
  
Failed to match 1 mock for this query, which had the following variables:
	  {\"age\":13,\"username\":\"some_user\"}
"
]=]

exports[ [=[General use should error if the variables in the mock and component do not match 1]=] ] = [=[

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
]=]

exports[ [=[General use should mock the data 1]=] ] = [=[

Table {
  "__typename": "User",
  "id": "user_id",
}
]=]

exports[ [=[General use should not error if the variables match but have different order 1]=] ] = [=[

Table {
  "user": Table {
    "__typename": "User",
    "id": "user_id",
  },
}
]=]

exports[ [=[General use should pipe exceptions thrown in custom onError functions through the link chain 1]=] ] = [=[
"oh no!"]=]

exports[ [=[General use should return "Mocked response should contain" errors in response 1]=] ] = [=[
"Mocked response should contain either result or error: {\"query\":\"query GetUser($username: String!) {\\n  user(username: $username) {\\n    id\\n    __typename\\n  }\\n}\\n\"}"]=]

exports[ [=[General use should return "No more mocked responses" errors in response 1]=] ] = [=[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: []
"
]=]

exports[ [=[General use should support custom error handling using setOnError 1]=] ] = [=[

"No more mocked responses for the query: query GetUser($username: String!) {
  user(username: $username) {
    id
    __typename
  }
}

Expected variables: {\"username\":\"mock_username\"}
"
]=]

return exports
