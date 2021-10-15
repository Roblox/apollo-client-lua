-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/errors/index.ts
local exports = {}

local srcWorkspace = script.Parent
local Packages = srcWorkspace.Parent
local LuauPolyfill = require(Packages.LuauPolyfill)
type Record<T, U> = { [T]: U }
type Array<T> = LuauPolyfill.Array<T>
type Object = LuauPolyfill.Object

type Error = LuauPolyfill.Error

-- ROBLOX deviation: add polyfills for JS Primitives
local Boolean, Array, Error = LuauPolyfill.Boolean, LuauPolyfill.Array, LuauPolyfill.Error

local invariant = require(srcWorkspace.jsutils.invariant).invariant
local DEV = require(srcWorkspace.utilities).DEV
invariant("boolean" == typeof(DEV), tostring(DEV))

local GraphQL = require(Packages.GraphQL)
type GraphQLError = GraphQL.GraphQLError

local isNonEmptyArray = require(srcWorkspace.utilities).isNonEmptyArray

--[[ ROBLOX TODO: replace when available]]
-- local ServerParseError = require(srcWorkspace.link.http).ServerParseError
-- local ServerError = require(srcWorkspace.link.utils).ServerError
type ServerParserError = Object
type ServerError = Object

local hasOwnProperty = require(srcWorkspace.luaUtils.hasOwnProperty)

local ApolloError = setmetatable({}, { __index = Error })
ApolloError.__index = ApolloError

local function isApolloError(err: Error): boolean
	return hasOwnProperty(err, "graphQLErrors")
end

exports.isApolloError = isApolloError

local function generateErrorMessage(err: ApolloError)
	local message = ""
	if
		isNonEmptyArray(err.graphQLErrors) and isNonEmptyArray(err.graphQLErrors) or isNonEmptyArray(err.clientErrors)
	then
		local errors = Array.concat(
			(Boolean.toJSBoolean(err.graphQLErrors) and err.graphQLErrors or {}),
			(Boolean.toJSBoolean(err.clientErrors) and err.clientErrors or {})
		)
		for _, error_ in pairs(errors) do
			local errorMessage = (function()
				if Boolean.toJSBoolean(error_) then
					return error_.message
				else
					return "Error message not found."
				end
			end)()
			message ..= ("%s\n"):format(errorMessage)
		end
	end
	if err.networkError ~= nil then
		message ..= ("%s\n"):format((err.networkError :: any).message)
	end
	message = string.gsub(message, "\n$", "")
	return message
end

export type ApolloError = Error & {
	message: string,
	graphQLErrors: Array<GraphQLError>,
	clientErrors: Array<Error>,
	networkError: Error | ServerParserError | ServerError | nil,
	--[[
  // An object that can be used to provide some additional information
  // about an error, e.g. specifying the type of error this is. Used
  // internally within Apollo Client.
  ]]
	extraInfo: any,
}

type ApolloErrorConstructorArg = {
	message: string?,
	graphQLErrors: Array<GraphQLError>?,
	clientErrors: Array<Error>?,
	networkError: (Error | ServerParserError | ServerError | nil)?,
	errorMessage: string?,
	extraInfo: any?,
}

function ApolloError.new(ref: ApolloErrorConstructorArg): ApolloError
	local graphQLErrors, clientErrors, networkError, errorMessage, extraInfo =
		ref.graphQLErrors, ref.clientErrors, ref.networkError, ref.errorMessage, ref.extraInfo

	local self = Error.new(errorMessage)
	self.graphQLErrors = Boolean.toJSBoolean(graphQLErrors) and graphQLErrors or {}
	self.clientErrors = Boolean.toJSBoolean(clientErrors) and clientErrors or {}
	self.networkError = Boolean.toJSBoolean(networkError) and networkError or nil
	self.message = Boolean.toJSBoolean(errorMessage) and errorMessage or generateErrorMessage(self)
	self.extraInfo = extraInfo

	return setmetatable(self, ApolloError)
end

exports.ApolloError = ApolloError

return exports
