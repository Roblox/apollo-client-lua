# Apollo Client

!!! info
	This page is intended to provide *brief* descriptions, examples, and notes about deviations in behavior or API. For complete feature documentation of upstream-aligned features, follow the `View Apollo Client Docs` link and consult the Apollo Client docs.

Apollo Client is a state management library designed around GraphQL. Apollo Client exports react hooks for fetching GraphQL Queries and Mutations, APIs for reading and writing remote and local data to the `InMemoryCache`, and reactive vairables for storing local state. 

### Luau-only Pitfalls
#### Passing `self` to Methods
!!! caution
A common pitfall when using Apollo Client and GraphQL in Luau is not passing the self argument to functions. Apollo Client methods should generally be called with `:` notation, rather than `.` notation. For example, calling `client.query(options)` will result in an error. The correct usage is `client:query(options)`. 
  
Type policies also take self as the first argument. For example, a read type policy should have the following function signature: `<T>(self, existing: T?, options: FieldFunctionOptions) -> T`

#### Immutability
!!! caution
Immutability is key in apollo client. You never want to directly mutate the cache, or your component may not update. Cryo is the recommended library for combining Arrays and Dictionaries with immutability. 

### API Deviations

#### Not Supported
The following API members are notable absences relative to Apollo Client 0.3.4:

* Hooks.useSubscription
* ApolloClient.subscribe
* InMemoryCache.updateFragment
* InMemoryCache.updateQuery
* Server-side rendering

Many Custom Apollo Links are not supported. The following are not supported: 

  * BatchHttpLink
  * setContext
  * onError
  * createPersistedQueryLink
  * RestLink
  * RetryLink
  * SchemaLink
  * GraphQLWsLink

## Core

### ApolloClient

[View Apollo Client Docs](https://www.apollographql.com/docs/react/api/core/ApolloClient)

#### Constructor
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local ApolloClient = require(Packages.ApolloClient).ApolloClient
local InMemoryCache = require(Packages.ApolloClient).InMemoryCache
local HttpLink = require(Packages.ApolloClient).HttpLink

local cache = InMemoryCache.new()

local link = HttpLink.new({
  uri = "/api",
  fetch = function(uri, requestOptions)
    return fetch(uri, requestOptions)
  end
})

local client = ApolloClient.new({
  cache = cache,
  link = link,
})
```

#### watchQuery
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local GET_TODOS = gql([[
  getTodos($id: String!) {
    todos(id: $id) {
      id
      description
      completed
    }
  }
]])


client:watchQuery({
  query = GET_TODOS,
  notifyOnNetworkStatusChange = false,
}),
```

#### query
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local GET_TODOS = gql([[
  getTodos($id: String!) {
    todos(id: $id) {
      id
      description
      completed
    }
  }
]])


client:query({
  query = GET_TODOS,
  errorPolicy = "all",
  fetchPolicy = "network-only"
  variables = {
    id = "5"
  }
}),
```


#### mutate
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local CREATE_TODO = gql([[
  mutation createTodo {
    createTodo {
      id
      name
      __typename
    }
  }
]])

client:mutate({
  mutation = CREATE_TODO,
  updateQueries = {
    todos = function(_self, prev, ref)
      local mutationResult = ref.mutationResult
      local newTodo = mutationResult.data.createTodo
      local newResults = {
        todos = Cryo.List.join(prev.todos, { newTodo }),
      }
      return newResults
    end,
  },
})
```

#### readQuery
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local GET_TODOS = gql([[
  getTodos($id: String!) {
    todos(id: $id) {
      id
      description
      completed
    }
  }
]])


client:readQuery({
  query = GET_TODOS,
  variables = {
    id = "5",
  }
}, true),
```

#### readFragment
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local TODOS_FRAGMENT = gql([[
  fragment myTodo on Todo {
    id
    description
    completed
  }
]])


client:readFragment({
  fragment = TODOS_FRAGMENT,
  id = "5"
}, true),
```

#### writeQuery
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local GET_TODOS = gql([[
  getTodos($id: String!) {
    todos(id: $id) {
      id
      description
      completed
    }
  }
]])


client:writeQuery({
  query = TODOS_FRAGMENT,
  variables = {
    id = "5"
  },
  data = {
    todos = {
      __typename = "Todo",
      id = "5",
      description = "Take out the trash",
      completed = false,
    }
  }
}, true),
```

#### writeFragment
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local TODOS_FRAGMENT = gql([[
  fragment myTodo on Todo {
    id
    description
    completed
  }
]])


client:writeFragment({
  fragment = TODOS_FRAGMENT,
  id = "5",
  data = {
    __typename = "Todo",
    id = "5",
    description = "Take out the trash",
    completed = true,
  }
}, true),
```

#### resetStore
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
client:resetStore()
```

#### onResetStore
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
client:onResetStore(function()
  print("reset store")
end)
```

#### clearStore
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
client:clearStore()
```

#### onClearStore
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
client:onClearStore(function()
  print("reset store")
end)
```

#### stop
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
client:stop()
```

#### reFetchObservableQueries
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
client:reFetchObservableQueries(false)
```

#### refetchQueries
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
client:refetchQueries({
  include = { "GetAuthor" , "GetAuthor2" }
})
```

### ObservableQuery

[View Apollo Client Docs](https://www.apollographql.com/docs/react/api/core/ObservableQuery)

#### result
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local observableQuery = client:watchQuery({
  query = query,
  variables = variables,
})

observableQuery:result():andThen(function(result)
  print(result.data)
end)
```

#### getCurrentResult
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local currentResult = observableQuery:getCurrentResult()
```

#### refetch
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local GET_PEOPLE = gql([[
  query people($first: Int) {
    allPeople(first: $first) {
      people {
        name
      }
    }
  }
]])

local observable = client:watchQuery({
  query = GET_PEOPLE,
  variables = { first = 0 },
  notifyOnNetworkStatusChange = true,
})

observable:subscribe({
  next = function(result)
    observable:refetch({ first = 1 })
  end
})
```

#### setOptions
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
observableQuery:setOptions({
  fetchPolicy = "cache-only",
  errorPolicy = "all",
})
```

#### setVariables
<img alt='Aligned' src='../../images/aligned.svg'/>

!!! danger "internal use only"

#### fetchMore
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
observableQuery:fetchMore({
  variables = {
    x = 2
  }
})
```

#### updateQuery
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
observableQuery:updateQuery(function(data, ref) 
  local variables = ref.variables
  local oldCars = data.cars
  local newCars = ref.fetchMoreCars.cars
end)
```

#### startPolling
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
observableQuery:startPolling(50)
```

#### stopPolling
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
observableQuery:stopPolling()
```

#### subscribeToMore
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
observableQuery:subscribeToMore({})
```

### InMemoryCache

[View Apollo Client Docs](https://www.apollographql.com/docs/react/api/cache/InMemoryCache)

#### Constructor
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local InMemoryCache = require(Packages.ApolloClient).InMemoryCache

local cache = InMemoryCache.new({
  addTypename = true,
  resultCaching = true,
  possibleTypes = {
    User = { "Player", "Creator" }
  },
  typePolicies = {
    Feed = {
      fields = {
        sorts = {
          merge = function(_self, existing, incoming, options)
            return Cryo.List.join(existing, incoming)
          end
        }
      }
    }
  }
})
```

#### readQuery
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local ref = cache:readQuery({
  query: gql([[
    query ReadTodo {
      todo(id: 5) {
        id
        text
        completed
      }
    }
  ]]),
})

expect(ref.todo).toEqual({
  id = "5",
  text = "Wash the dishes",
  completed = false,
})
```

#### writeQuery
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
cache:writeQuery({
  query: gql([[
    query ReadTodo($id: ID!) {
      todo(id: $id) {
        id
        text
        completed
      }
    }
  ]]),
  data = {
    todo = {
      __typename = "Todo",
      id = 5,
      text = "Buy Grapes",
      completed = false,
    }
  }
  variables = {
    id = 5,
  }
})
```

#### readFragment
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
cache:readFragment({
  id = "5",
  fragment = gql([[
    fragment myTodo on Todo {
      id
      description
      completed
    }
  ]])
})
```

#### writeFragment
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
cache:writeFragment({
  id = "5",
  fragment = gql([[
    fragment myTodo on Todo {
      completed
    }
  ]]),
  data = {
    completed = true
  }
})
```

#### identify
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local bookYearFragment = gql([[
  fragment BookYear on Book {
    publicationYear
  }
]])

local invisibleManBook = {
  __typename = 'Book',
  isbn = "9780679601395", -- the key is isbn
  title = "Invisible Man",
  author = {
    __typename = "Author",
    name = "Ralph Ellison",
  },
}

local fragmentResult = cache.writeFragment({
  id = cache:identify(invisibleManBook),
  fragment = bookYearFragment,
  data = {
    publicationYear = '1952'
  }
})
```

#### modify
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
cache:modify({
  id = cache:identify(myObject),
  fields = {
    name = function(_self, cachedName) {
      return string.upper(cachedName);
    },
  },
});
```

#### gc
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
cache:gc()
```

#### evict
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
cache:evict({ id = "my-object-id", fieldName = "myFieldName" })
```

#### extract
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local snapshot = cache:extract()
```

#### restore
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
-- save a snapshot
local snapshot = cache:extract()

-- clear the cache
cache:restore({})

-- restore the state to the previous snapshot
cache:restore(snapshot)
```

### ReactiveVar
[View Apollo Client Docs](https://www.apollographql.com/docs/react/api/cache/InMemoryCache#makevar)

#### makeVar
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local cartItems = makeVar({});

-- Output: {}
print(cartItems())

-- Update reactive variable
cartItems({ 1, 2, 3, 4 })

-- Output: {1, 2, 3, 4}
print(cartItems())
```

### Type Policies
[View Apollo Client Docs](https://www.apollographql.com/docs/react/caching/cache-field-behavior/)

#### Initialization
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local cache = InMemoryCache.new({
  typePolicies = {
    Query = {
      fields = {
        getFeed = {
          read = function(_self, _existing, options)
            return options:toReference({
              __typename = "Feed",
              id = options.args.id
            })
          end
        }
      }
    },
    Feed = {
      fields = {
        sorts = {
          read = function(_self, existing, options)
            if options:readField("under9") then
              return Cryo.List.filter(existing, function(value)
                return value.under9
              end)
            end
            return existing
          end
        }
      }
    }
  }
})
```

#### keyFields
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local cache = InMemoryCache.new({
  typePolicies = {
    Feed = {
      keyFields = { "feedId", "pageType" }
    }
  }
})
```

#### keyArgs
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local cache = InMemoryCache.new({
  typePolicies = {
    Query = {
      fields = {
        feed = {
          keyFields = { "id", "pageType" }
        }
      }
    }
  }
})
```

#### read
<img alt='Deviation' src='../../images/deviation.svg'/>

!!! caution
    
    Apollo Client Luau passes `self` as the first argument to the `read` type policy. The other arguments are shifted over by one. `existing` data is passed as the second argument and `options` as the third.

```lua
local cache = InMemoryCache.new({
  typePolicies = {
    Feed = {
      fields = {
        sorts = {
          read = function(_self, sorts, options)
            if options:readField("under9") then
              return Cryo.List.filter(sorts, function(sortItem)
                return not sortItem.under9
              end)
            end
            return sorts
          end
        }
      }
    }
  }
})
```

#### merge
<img alt='Deviation' src='../../images/deviation.svg'/>

!!! caution
    
    Apollo Client Luau passes `self` as the first argument to the `merge` type policy. The other arguments are shifted over by one. `existing` data is passed as the second argument, `incoming` data as the third, and `options` as the fourth.

```lua
local cache = InMemoryCache.new({
  typePolicies = {
    Feed = {
      fields = {
        sorts = {
          merge = function(_self, existingSorts, incomingSorts, options)
            if not options:readField("under9") then
              return Cryo.List.join(existingSorts, incomingSorts)
            end

            local filteredSorts = Cryo.List.filter(incomingSorts, function(sortItem)
              return not sortItem.under9
            end)
            
            return Cryo.List.join(existingSorts, filteredSorts)
          end
        }
      }
    }
  }
})
```

#### FieldFunctionOptions
<img alt='Deviation' src='../../images/deviation.svg'/>

!!! caution
    
    The methods on the `FieldFunctionOptions` Object must be called with `:` notation, rather than `.` notation.

```lua

type FieldFunctionOptions = {
  cache: InMemoryCache,
  args: Record<string, any>?,
  fieldName: string,
  field: FieldNode?,
  variables: Record<string, any>?,
  isReference: (self, obj: any): boolean,
  toReference: (self, objOrIdOrRef: StoreObject | string | Reference, mergeIntoStore: boolean?): Reference?,
  readField: <T>(self, nameOrField: string | FieldNode, foreignObjOrRef: StoreObject | Reference): T,
  canRead: (self, value: StoreValue): boolean,
  storeage: Record<string, any>,
  mergeObjects: <T>(self, existing: T, incoming: T): T
}

local read = function(_self, data, options: FieldFunctionOptions)
  local book = options:readField("book")
  local authorReference = options:toReference({
    __typename = "Author",
    id = "3"
  })
end
```

## React

### Context

[View Apollo Client Docs](https://www.apollographql.com/docs/react/api/react/hooks#the-apolloprovider-component)

#### ApolloProvider
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local client = ApolloClient.new({
  cache= InMemoryCache.new(),
  uri: "http://localhost:4000/graphql"
});

local function App()
  return React.createElement(ApolloProvider, {
    client = client
  },
    React.createElement(HomePage)
  )
end

```

#### ApolloConsumer
<img alt='Aligned' src='../../images/aligned.svg'/>

!!! danger
  
    ApolloClient instances passed to `ApolloProvider` should be consumed via the useApolloClient hook instead of the ApolloConsumer. 

### Hooks

[View Apollo Client Docs](https://www.apollographql.com/docs/react/api/react/hooks)

#### useQuery
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local GET_GREETING = gql([[
  query GetGreeting($language: String!) {
    greeting(language: $language) {
      message
    }
  }
]])

local function Hello()
  local ref = useQuery(GET_GREETING, {
    variables= { language = 'english' },
  })
  if ref.error then
    return React.createElement("TextLabel", {
      Text = "Error",
    })
  end

  if ref.loading then
    return React.createElement("TextLabel", {
      Text = "Loading ...",
    })
  end

  return React.createElement("TextLabel", {
    Text = ref.data.greeting.message,
  })
end
```

#### useLazyQuery
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local GET_GREETING = gql([[
  query GetGreeting($language: String!) {
    greeting(language: $language) {
      message
    }
  }
]])

local function Hello()
  local lazyRef = useLazyQuery(GET_GREETING, {
    variables= { language = 'english' },
  })
  local loadGreeting = lazyRef[1]
  local ref = lazyRef[2]

  if ref.called and ref.loading then
    return React.createElement("TextLabel", {
      Text = "Loading ...",
    })
  end

  if not ref.called then
    return React.createElement("TextButton", {
      Text = "Load Greeting",
      [React.Event.Activated] = function()
        loadGreeting
      end
    })
  end

  return React.createElement("TextLabel", {
    Text = ref.data.greeting.message,
  })
end
```


#### useMutation
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local ADD_TODO = gql([[
  mutation AddTodo($type: String!) {
    addTodo(type: $type) {
      id
      type
    }
  }
]])

local function AddTodo()
  local input
  local mutationRef = useMutation(ADD_TODO);

  local addTodo = mutationRef[1]
  local ref = mutationRef[2]

  return React.createElement(Form, {
    onSubmit = function(rbx)
      addTodo({
        variables = {
          type = rbx.Text,
        }
      })
      rbx.Text = ""
    end
  })
end
```

#### useApolloClient
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local function SomeComponent()
  -- this client is the same as the one passed to ApolloProvider
  local client = useApolloClient();
end
```

#### useReactiveVar
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local cartItemsVar = makeVar({});

local function Cart()
  local cartItems = useReactiveVar(cartItemsVar);
  
  return React.createElement("Frame", {}, Cryo.List.map(cartItems, function(item)
    return React.createElement(CartItem, item)
  end))
end
```

### Testing
[View Apollo Client Docs](https://www.apollographql.com/docs/react/api/react/testing)

!!! caution "Apollo Client Testing Minimum Requirements"

    Apollo Client Testing requires Jest ^3 and ReactTestingLibrary ^12. You will experience errors if you try to use MockedProvider in a TestEZ environment.

!!! note "Importing Apollo Client Testing"

    Apollo Client Testing is exported as a separate dev-dependency, rather than via the Apollo Client package. You can import it from `Packages.Dev.ApolloClientTesting`

#### MockedProvider
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local GET_DOG_QUERY = gql([[
  query GetDog($name: String) {
    dog(name: $name) {
      id
      name
      breed
    }
  }
]])

local mocks = {
  {
    request = {
      query = GET_DOG_QUERY,
      variables = {
        name = "Buck"
      }
    },
    result = {
      data = {
        dog = { id = "1", name = "Buck", breed = "bulldog" }
      }
    }
  }
}

it("renders without error", function()
  local result = render(
    React.createElement(MockedProvider, {
      mocks = mocks, 
      addTypename = false,
    },
      React.createElement(Dog, {
        name = "Buck",
      })
    )
  )
  expect(result.findByText("Loading..."):expect()).toBeDefined()
  expect(result.findByText("Buck is a poodle"):expect()).toBeDefined()
end)
```

## Apollo Link
[View Apollo Client Docs](https://www.apollographql.com/docs/react/api/link/introduction)

#### ApolloLink
<img alt='Aligned' src='../../images/aligned.svg'/>

```lua
local timeStartLink = ApolloLink.new(function(_self, operation, forward)
  operation:setContext({ start = os.clock() });
  return forward(operation);
end)
```

### HttpLink

```lua
local link = HttpLink.new({
  uri = "http://localhost:4000/graphql"
  fetch = fetchLocal
})
```
