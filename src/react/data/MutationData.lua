-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/react/data/MutationData.ts
local exports = {}

local srcWorkspace = script.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Boolean, Object = LuauPolyfill.Boolean, LuauPolyfill.Object
type Object = { [string]: any }

local equal = require(srcWorkspace.jsutils.equal)
local DocumentType = require(script.Parent.Parent.parser).DocumentType
local errorsModule = require(srcWorkspace.errors)
local ApolloError = errorsModule.ApolloError
type ApolloError = errorsModule.ApolloError
local typesModule = require(script.Parent.Parent.types.types)
type MutationDataOptions<TData, TVariables, TContext, TCache> =
	typesModule.MutationDataOptions<TData, TVariables, TContext, TCache>
type MutationTuple<TData, TVariables, TContext, TCache> = typesModule.MutationTuple<TData, TVariables, TContext, TCache>
type MutationFunctionOptions<TData, TVariables, TContext, TCache> =
	typesModule.MutationFunctionOptions<TData, TVariables, TContext, TCache>
type MutationResult<TData> = typesModule.MutationResult<TData>
local OperationData = require(script.Parent.OperationData).OperationData

local coreModule = require(srcWorkspace.core)
-- local MutationOptions = coreModule.MutationOptions
local mergeOptions = coreModule.mergeOptions
-- local ApolloCache = coreModule.ApolloCache
-- local OperationVariables = coreModule.OperationVariables
-- local DefaultContext = coreModule.DefaultContext

-- ROBLOX TODO: use proper type when available
-- local FetchResult = require(script.Parent.Parent.Parent.link.core).FetchResult
type FetchResult<TData> = { data: TData, errors: any }

type MutationResultWithoutClient<TData> = {
	data: (TData | nil)?,
	error: ApolloError?,
	loading: boolean,
	called: boolean,
}

local MutationData = setmetatable({}, { __index = OperationData })
MutationData.__index = MutationData

type MutationData<TData, TVariables, TContext, TCache> = {
	execute: (
		self: MutationData<TData, TVariables, TContext, TCache>,
		result: MutationResultWithoutClient<TData>
	) -> MutationTuple<TData, TVariables, TContext, TCache>,
	afterExecute: (self: MutationData<TData, TVariables, TContext, TCache>) -> (),
	cleanup: (self: MutationData<TData, TVariables, TContext, TCache>) -> (),
}

type MutationDataConstructorArgs<TData, TVariables, TContext, TCache> = {
	options: MutationDataOptions<TData, TVariables, TContext, TCache>,
	context: any,
	result: MutationResultWithoutClient<TData>,
	setResult: (MutationResultWithoutClient<TData>) -> any,
}

function MutationData.new(ref: MutationDataConstructorArgs<any, any, any, any>): MutationData<any, any, any, any>
	local self: any = OperationData.new(ref.options, ref.context)
	self:verifyDocumentType(ref.options.mutation, DocumentType.Mutation)
	self.result = ref.result
	self.setResult = ref.setResult
	self.mostRecentMutationId = 0
	return (setmetatable(self, MutationData) :: any) :: MutationData<any, any, any, any>
end

function MutationData:execute(result: any): MutationTuple<any, any, any, any>
	self.isMounted = true
	self:verifyDocumentType(self:getOptions().mutation, DocumentType.Mutation)
	return { self.runMutation, Object.assign(result, { client = self:refreshClient().client }) }
end

function MutationData:afterExecute()
	self.isMounted = true
	return function(...)
		return self:unmount(...)
	end
end

function MutationData:cleanup()
	-- // No cleanup required.
end

function MutationData:runMutation(mutationFunctionOptions: Object?)
	if mutationFunctionOptions == nil then
		mutationFunctionOptions = {}
	end
	self:onMutationStart()
	local mutationId = self:generateNewMutationId()

	return self
		:mutate(mutationFunctionOptions)
		:andThen(function(response)
			self:onMutationCompleted(response, mutationId)
			return response
		end)
		:catch(function(error_: ApolloError)
			local onError = self:getOptions().onError
			self:onMutationError(error_, mutationId)
			if Boolean.toJSBoolean(onError) then
				onError(error_)
				return {
					data = nil,
					errors = error_,
				}
			else
				error(error_)
			end
		end)
end

function MutationData:mutate(options: MutationFunctionOptions<any, any, any, any>)
	return self:refreshClient().client:mutate(mergeOptions(self:getOptions(), options))
end

function MutationData:onMutationStart()
	if not self.result.loading and not self:getOptions().ignoreResults then
		self:updateResult({
			loading = true,
			error_ = nil,
			data = nil,
			called = true,
		})
	end
end

function MutationData:onMutationCompleted(response: FetchResult<any>, mutationId: number)
	local options = self:getOptions()
	local onCompleted, ignoreResults = options.onCompleted, options.ignoreResults

	local data, errors = response.data, response.errors

	local error_ = (function(): ApolloError | nil
		if
			Boolean.toJSBoolean((function()
				if Boolean.toJSBoolean(errors) then
					return #errors > 0
				else
					return errors
				end
			end)())
		then
			return ApolloError.new({ graphQLErrors = errors })
		else
			return nil
		end
	end)()

	local function callOncomplete()
		if Boolean.toJSBoolean(onCompleted) then
			return onCompleted(data)
		else
			return nil
		end
	end

	if self:isMostRecentMutation(mutationId) and not ignoreResults then
		self:updateResult({
			called = true,
			loading = false,
			data = data,
			error_ = error_,
		})
	end
	callOncomplete()
end

function MutationData:onMutationError(error_: ApolloError, mutationId: number)
	if self:isMostRecentMutation(mutationId) then
		self:updateResult({
			loading = false,
			error_ = error_,
			data = nil,
			called = true,
		})
	end
end

function MutationData:generateNewMutationId(): number
	(self :: { mostRecentMutationId: number }).mostRecentMutationId += 1
	return self.mostRecentMutationId
end

function MutationData:isMostRecentMutation(mutationId: number)
	return self.mostRecentMutationId == mutationId
end

function MutationData:updateResult(result: MutationResultWithoutClient<any>): MutationResultWithoutClient<any> | nil
	if self.isMounted and (not self.previousResult or not equal(self.previousResult, result)) then
		self:setResult(result)
		self.previousResult = result
		return result
	end
	return nil
end

exports.MutationData = MutationData

return exports
