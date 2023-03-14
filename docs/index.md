Apollo Client Luau is a port of the javascript [Apollo Client](https://www.apollographql.com/docs/react) state management library.

By and large, [Apollo Client's documentation](https://www.apollographql.com/docs/react/get-started) should be able to serve most Apollo Client users' needs. This documentation site serves as a comprehensive guide to the _differences_ between the Luau and javascript versions of Apollo Client.

If you're new to the Apollo Client library and want **to start learning the concepts of Apollo Client**, begin with the [Apollo Client React documentation](https://www.apollographql.com/docs/react/).

If you want **to find out if a javascript Apollo Client feature is present in the Luau version (and if there are any differences to be aware of)**, check out the [API Reference](api-reference/apollo-client.md).

If you're familiar with the javascript version and want **to learn where the Luau version differs**, start with the [Deviations page](deviations.md).

And if you want **to migrate an existing project from Rodux to ApolloClient + GraphQL**, check out the guide on [Migrating From Rodux](migrating-from-rodux/minimum-requirements.md).

### What is the difference between Apollo Client and GraphQL?
A common point of confusion around Apollo Client is understanding the difference between Apollo Client and GraphQL. The two are often referred to in the same breath, but the libraries serve substantially different purposes.

GraphQL is a query language for your API. Backend engineers can define strict types and relationships for the types of data that can be fetched, and can provide implementation details for how each type of data is fetched. This facilitates code reuse and can combat anti-patterns like over-fetching and under-fetching that manifest in REST APIs. Frontend engineers can make GraphQL requests to fetch the exact shape and quantity of data required.

Apollo Client is a state management tool that is designed for compatibility with GraphQL. Apollo Client provides a set of React hooks for executing GraphQL queries and mutations, and it normalizes and caches the results of the requests. This creates a flat, strongly-typed cache that can be reused across a frontend. Apollo Client also provides utilities for local state management, and is a direct replacement for Redux. 

Apollo Client is not limited to usage with React. The core of Apollo Client is built on the zen observable library, which means that GraphQL queries can be treated as Observables.
