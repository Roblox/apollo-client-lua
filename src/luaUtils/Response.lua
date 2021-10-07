local promiseModule = require(script.Parent.Promise)
type Promise<T> = promiseModule.Promise<T>

-- ROBLOX TODO: add Response type to LuauPolyfill
type Body = { text: (self: Body) -> Promise<string> }

export type Response = Body & { status: number }

return {}
