These are not technically [deviations](./deviations.md) between Apollo Client Luau and TypeScript versions, but pitfalls due to the differences between Luau and TypeScript/JavaScript.
Reading nil values from Apollo Client

## Reading nil values from Apollo client

In the TypeScript version, Apollo Client does not allow reads for undefined fields on the client side [see here](https://github.com/apollographql/apollo-client/issues/1701), but it does allow reads for null values (which is how it handles optional field reads). However, Lua does not have this distinction between undefined and null. Therefore, reading optional fields when they have a nil value is not currently possible. This means that even if a field is typed as optional, reading it when it is nil will throw an error.

### Workaround

The current workaround for this is to define a `read` type policy that returns a non-nil default value.

```lua
type Experience {
        universeId: ID!
        thumbnails: [Media]
}
```

```lua
-- Experience Type Policy
local function makeDefaultReadPolicy(defaultValue)
	return function(_self, existingValue)
		return existingValue or defaultValue
	end
end

return {
	keyFields = {"universeId" } else nil,
	fields = {
		thumbnails = {
			read = makeDefaultReadPolicy({}),
		},
	},
}
```
