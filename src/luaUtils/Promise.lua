export type PromiseLike<T> = {
	andThen: (
		PromiseLike<T>, -- self
		((T) -> ...(nil | T | PromiseLike<T>))?, -- resolve
		((any) -> ...(nil | T | PromiseLike<T>))? -- reject
	) -> PromiseLike<T>,
}

type Status = string

export type Promise<T> = {
	andThen: (
		Promise<T>, -- self
		((T) -> ...(nil | T | PromiseLike<T>))?, -- resolve
		((any) -> ...(nil | T | PromiseLike<T>))? -- reject
	) -> Promise<T>,

	catch: (Promise<T>, ((any) -> ...(nil | T | PromiseLike<nil>))) -> Promise<T>,

	onCancel: (Promise<T>, () -> ()?) -> boolean,

	expect: (Promise<T>) -> T,
	await: (Promise<T>) -> (boolean, ...any),
	awaitStatus: (Promise<T>) -> (Status, ...any),

	timeout: (Promise<T>, seconds: number, rejectionValue: any?) -> Promise<T>,

	finally: (Promise<T>, (Status) -> ...any) -> Promise<T>,
}

return {}
