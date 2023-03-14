The core API of Apollo Client Luau is directly aligned with the API of the typescript version. However, there are some minor deviations around executing class methods, unpacking query and mutation results, and testing react components.

## Executing Class Methods
JavaScript uses `.` notation to execute all class methods, while Luau uses `:` notation to execute non-static methods and `.` to execute static methods. When calling methods directly on an ApolloClient or InMemoryCache instance, you should always use `:` notation to ensure that `self` is passed to the method as the first argument. If you call these methods with `.` notation, Luau will assume that the first argument passed to the method is `self`, which often results in hard-to-catch bugs. Examples of the correct usage can be found in the [full api documentation](./api-reference/apollo-client.md).

## Passing `self` to `read` and `merge` Type Policies
In lua, the `read` and `merge` type policy definitions expect self as the first argument. Detailed examples of the correct usage of `read` and `merge` can be found in the [API docs](./api-reference/apollo-client#type-policies.md).

Correct usage:
```lua
read = function(_self, data, options) ... end
merge = function(_self, existing, incoming, options) ... end
```

## Unpacking results from useQuery, useMutation
JavaScript has a feature called [Object Destructuring](https://basarat.gitbook.io/typescript/future-javascript/destructuring#object-destructuring) that is not available in Luau. This allows for variables to be easily parsed from the return object of a function. In Apollo Client, this feature is often used to parse the result of useQuery, useMutation, and useLazyQuery:
```js
const { data, loading, error } = useQuery(GET_DOGS)

const [setDogs, { data, loading, error }] = useMutation(SET_DOGS)

const [getDogs, { data, loading, error }] = useLazyQuery(GET_DOGS)
```

In luau, we have to manually destructure these objects and arrays:
```lua
local queryResult = useQuery(GET_DOGS)
local data = queryResult.data
local error = queryResult.error
local loading = queryResult.loading

local mutationRef = useMutation(SET_DOGS)
local setDogs = mutationRef[1]
local data = mutationRef[2].data
local error = mutationRef[2].error
local loading = mutationRef[2].loading

local lazyRef = useLazyQuery(GET_DOGS)
local getDogs = lazyRef[1]
local data = lazyRef[2].data
local error = lazyRef[2].error
local loading = lazyRef[2].loading
```

The result of useQuery, useMutation, etc. are all strongly typed, which should allow analysis to catch any typos or nil index bugs at build time.

## Apollo Client Testing
In javascript, the apollo client testing module is imported via `import { MockedProvider } from "@apollo/client/testing`. In Luau, Apollo Client Testing is exported as a separate dev-dependency, rather than via the Apollo Client package. You can import it from `Packages.Dev.ApolloClientTesting`.
