-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.0-rc.17/src/utilities/testing/mocking/mockLink.ts
local exports = {}
local srcWorkspace = script.Parent.Parent.Parent.Parent
local rootWorkspace = srcWorkspace.Parent
type Error = { name: string, message: string, stack: string? }
local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array, String = LuauPolyfill.Array, LuauPolyfill.String

local HttpService = game:GetService("HttpService")

-- local print = require(rootWorkspace.GraphQL).print
-- local equal = require(srcWorkspace.jsutils.equal)
-- local invariant = require(srcWorkspace.jsutils.invariant).invariant
-- local linkCoreModule = require(script.Parent.Parent.Parent.Parent.link.core)
-- local ApolloLink = linkCoreModule.ApolloLink
-- local Operation = linkCoreModule.Operation
-- ROBLOX todo: use proper type when available
-- type GraphQLRequest = linkCoreModule.GraphQLRequest
type GraphQLRequest = any
-- ROBLOX todo: use proper type when available
-- type FetchResult<TData> = linkCoreModule.FetchResult<TData>
type FetchResult<TData> = any
local utilitiesModule = require(srcWorkspace.utilities)
-- local Observable = utilitiesModule.Observable
-- local addTypenameToDocument = utilitiesModule.addTypenameToDocument
-- local removeClientSetsFromDocument = utilitiesModule.removeClientSetsFromDocument
-- local removeConnectionDirectiveFromDocument = utilitiesModule.removeConnectionDirectiveFromDocument
-- local cloneDeep = utilitiesModule.cloneDeep
local makeUniqueId = utilitiesModule.makeUniqueId

export type ResultFunction<T> = () -> T

-- ROBLOX deviation: HttpService.JSONEncode does not have a replacer function
function replaceUndefined(source, replacement)
	if not Array.isArray(source) then
		return source
	end
	local res = {}
	for i = 1, #source, 1 do
		if source[i] == nil then
			table.insert(res, replacement)
		else
			table.insert(res, source[i])
		end
	end
	return res
end

local function stringifyForDisplay(value: any): string
	local undefId = makeUniqueId("stringifyForDisplay")

	return Array.join(
		String.split(HttpService.JSONEncode(replaceUndefined(value, undefId)), HttpService.JSONEncode(undefId)),
		"<undefined>"
	)
end

export type MockedResponse<TData> = {
	request: GraphQLRequest,
	result: (FetchResult<TData> | ResultFunction<FetchResult<TData>>)?,
	error: Error?,
	delay: number?,
	newData: ResultFunction<FetchResult<TData>>?,
}

-- local function requestToKey(request: any, addTypename: any): string
--   local queryString = (function()
--     if Boolean.toJSBoolean(request.query) then
--       return print((function()
--         if Boolean.toJSBoolean(addTypename) then
--           return addTypenameToDocument(request.query)
--         else
--           return request.query
--         end
--       end)())
--     else
--       return request.query
--     end
--   end)()

--   local requestKey = {query = queryString}

--   return HttpService.JSONEncode(requestKey)
-- end

--error("not implemented"); --[[ ROBLOX TODO: Unhandled node for type: ClassDeclaration ]]
--[[ class MockLink extends ApolloLink {
  public operation: Operation;
  public addTypename: Boolean = true;
  private mockedResponsesByKey: { [key: string]: MockedResponse[] } = {};

  constructor(
    mockedResponses: ReadonlyArray<MockedResponse>,
    addTypename: Boolean = true
  ) {
    super();
    this.addTypename = addTypename;
    if (mockedResponses) {
      mockedResponses.forEach(mockedResponse => {
        this.addMockedResponse(mockedResponse);
      });
    }
  }

  public addMockedResponse(mockedResponse: MockedResponse) {
    const normalizedMockedResponse = this.normalizeMockedResponse(
      mockedResponse
    );
    const key = requestToKey(
      normalizedMockedResponse.request,
      this.addTypename
    );
    let mockedResponses = this.mockedResponsesByKey[key];
    if (!mockedResponses) {
      mockedResponses = [];
      this.mockedResponsesByKey[key] = mockedResponses;
    }
    mockedResponses.push(normalizedMockedResponse);
  }

  public request(operation: Operation): Observable<FetchResult> | null {
    this.operation = operation;
    const key = requestToKey(operation, this.addTypename);
    const unmatchedVars: Array<Record<string, any>> = [];
    const requestVariables = operation.variables || {};
    const mockedResponses = this.mockedResponsesByKey[key];
    const responseIndex = mockedResponses ? mockedResponses.findIndex((res, index) => {
      const mockedResponseVars = res.request.variables || {};
      if (equal(requestVariables, mockedResponseVars)) {
        return true;
      }
      unmatchedVars.push(mockedResponseVars);
      return false;
    }) : -1;

    const response = responseIndex >= 0
      ? mockedResponses[responseIndex]
      : void 0;

    let configError: Error;

    if (!response) {
      configError = new Error(
`No more mocked responses for the query: ${print(operation.query)}
Expected variables: ${stringifyForDisplay(operation.variables)}
${unmatchedVars.length > 0 ? `
Failed to match ${unmatchedVars.length} mock${
  unmatchedVars.length === 1 ? "" : "s"
} for this query, which had the following variables:
${unmatchedVars.map(d => `  ${stringifyForDisplay(d)}`).join('\n')}
` : ""}`);
    } else {
      mockedResponses.splice(responseIndex, 1);

      const { newData } = response;
      if (newData) {
        response.result = newData();
        mockedResponses.push(response);
      }

      if (!response.result && !response.error) {
        configError = new Error(
          `Mocked response should contain either result or error: ${key}`
        );
      }
    }

    return new Observable(observer => {
      const timer = setTimeout(() => {
        if (configError) {
          try {
            // The onError function can return false to indicate that
            // configError need not be passed to observer.error. For
            // example, the default implementation of onError calls
            // observer.error(configError) and then returns false to
            // prevent this extra (harmless) observer.error call.
            if (this.onError(configError, observer) !== false) {
              throw configError;
            }
          } catch (error) {
            observer.error(error);
          }
        } else if (response) {
          if (response.error) {
            observer.error(response.error);
          } else {
            if (response.result) {
              observer.next(
                typeof response.result === 'function'
                  ? (response.result as ResultFunction<FetchResult>)()
                  : response.result
              );
            }
            observer.complete();
          }
        }
      }, response && response.delay || 0);

      return () => {
        clearTimeout(timer);
      };
    });
  }

  private normalizeMockedResponse(
    mockedResponse: MockedResponse
  ): MockedResponse {
    const newMockedResponse = cloneDeep(mockedResponse);
    const queryWithoutConnection = removeConnectionDirectiveFromDocument(
      newMockedResponse.request.query
    );
    invariant(queryWithoutConnection, "query is required");
    newMockedResponse.request.query = queryWithoutConnection!;
    const query = removeClientSetsFromDocument(newMockedResponse.request.query);
    if (query) {
      newMockedResponse.request.query = query;
    }
    return newMockedResponse;
  }
} ]]
--exports[error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: ClassDeclaration ]]
--[[ class MockLink extends ApolloLink {
  public operation: Operation;
  public addTypename: Boolean = true;
  private mockedResponsesByKey: { [key: string]: MockedResponse[] } = {};

  constructor(
    mockedResponses: ReadonlyArray<MockedResponse>,
    addTypename: Boolean = true
  ) {
    super();
    this.addTypename = addTypename;
    if (mockedResponses) {
      mockedResponses.forEach(mockedResponse => {
        this.addMockedResponse(mockedResponse);
      });
    }
  }

  public addMockedResponse(mockedResponse: MockedResponse) {
    const normalizedMockedResponse = this.normalizeMockedResponse(
      mockedResponse
    );
    const key = requestToKey(
      normalizedMockedResponse.request,
      this.addTypename
    );
    let mockedResponses = this.mockedResponsesByKey[key];
    if (!mockedResponses) {
      mockedResponses = [];
      this.mockedResponsesByKey[key] = mockedResponses;
    }
    mockedResponses.push(normalizedMockedResponse);
  }

  public request(operation: Operation): Observable<FetchResult> | null {
    this.operation = operation;
    const key = requestToKey(operation, this.addTypename);
    const unmatchedVars: Array<Record<string, any>> = [];
    const requestVariables = operation.variables || {};
    const mockedResponses = this.mockedResponsesByKey[key];
    const responseIndex = mockedResponses ? mockedResponses.findIndex((res, index) => {
      const mockedResponseVars = res.request.variables || {};
      if (equal(requestVariables, mockedResponseVars)) {
        return true;
      }
      unmatchedVars.push(mockedResponseVars);
      return false;
    }) : -1;

    const response = responseIndex >= 0
      ? mockedResponses[responseIndex]
      : void 0;

    let configError: Error;

    if (!response) {
      configError = new Error(
`No more mocked responses for the query: ${print(operation.query)}
Expected variables: ${stringifyForDisplay(operation.variables)}
${unmatchedVars.length > 0 ? `
Failed to match ${unmatchedVars.length} mock${
  unmatchedVars.length === 1 ? "" : "s"
} for this query, which had the following variables:
${unmatchedVars.map(d => `  ${stringifyForDisplay(d)}`).join('\n')}
` : ""}`);
    } else {
      mockedResponses.splice(responseIndex, 1);

      const { newData } = response;
      if (newData) {
        response.result = newData();
        mockedResponses.push(response);
      }

      if (!response.result && !response.error) {
        configError = new Error(
          `Mocked response should contain either result or error: ${key}`
        );
      }
    }

    return new Observable(observer => {
      const timer = setTimeout(() => {
        if (configError) {
          try {
            // The onError function can return false to indicate that
            // configError need not be passed to observer.error. For
            // example, the default implementation of onError calls
            // observer.error(configError) and then returns false to
            // prevent this extra (harmless) observer.error call.
            if (this.onError(configError, observer) !== false) {
              throw configError;
            }
          } catch (error) {
            observer.error(error);
          }
        } else if (response) {
          if (response.error) {
            observer.error(response.error);
          } else {
            if (response.result) {
              observer.next(
                typeof response.result === 'function'
                  ? (response.result as ResultFunction<FetchResult>)()
                  : response.result
              );
            }
            observer.complete();
          }
        }
      }, response && response.delay || 0);

      return () => {
        clearTimeout(timer);
      };
    });
  }

  private normalizeMockedResponse(
    mockedResponse: MockedResponse
  ): MockedResponse {
    const newMockedResponse = cloneDeep(mockedResponse);
    const queryWithoutConnection = removeConnectionDirectiveFromDocument(
      newMockedResponse.request.query
    );
    invariant(queryWithoutConnection, "query is required");
    newMockedResponse.request.query = queryWithoutConnection!;
    const query = removeClientSetsFromDocument(newMockedResponse.request.query);
    if (query) {
      newMockedResponse.request.query = query;
    }
    return newMockedResponse;
  }
} ]]
--] = error("not implemented") --[[ ROBLOX TODO: Unhandled node for type: ClassDeclaration ]]
--[[ class MockLink extends ApolloLink {
  public operation: Operation;
  public addTypename: Boolean = true;
  private mockedResponsesByKey: { [key: string]: MockedResponse[] } = {};

  constructor(
    mockedResponses: ReadonlyArray<MockedResponse>,
    addTypename: Boolean = true
  ) {
    super();
    this.addTypename = addTypename;
    if (mockedResponses) {
      mockedResponses.forEach(mockedResponse => {
        this.addMockedResponse(mockedResponse);
      });
    }
  }

  public addMockedResponse(mockedResponse: MockedResponse) {
    const normalizedMockedResponse = this.normalizeMockedResponse(
      mockedResponse
    );
    const key = requestToKey(
      normalizedMockedResponse.request,
      this.addTypename
    );
    let mockedResponses = this.mockedResponsesByKey[key];
    if (!mockedResponses) {
      mockedResponses = [];
      this.mockedResponsesByKey[key] = mockedResponses;
    }
    mockedResponses.push(normalizedMockedResponse);
  }

  public request(operation: Operation): Observable<FetchResult> | null {
    this.operation = operation;
    const key = requestToKey(operation, this.addTypename);
    const unmatchedVars: Array<Record<string, any>> = [];
    const requestVariables = operation.variables || {};
    const mockedResponses = this.mockedResponsesByKey[key];
    const responseIndex = mockedResponses ? mockedResponses.findIndex((res, index) => {
      const mockedResponseVars = res.request.variables || {};
      if (equal(requestVariables, mockedResponseVars)) {
        return true;
      }
      unmatchedVars.push(mockedResponseVars);
      return false;
    }) : -1;

    const response = responseIndex >= 0
      ? mockedResponses[responseIndex]
      : void 0;

    let configError: Error;

    if (!response) {
      configError = new Error(
`No more mocked responses for the query: ${print(operation.query)}
Expected variables: ${stringifyForDisplay(operation.variables)}
${unmatchedVars.length > 0 ? `
Failed to match ${unmatchedVars.length} mock${
  unmatchedVars.length === 1 ? "" : "s"
} for this query, which had the following variables:
${unmatchedVars.map(d => `  ${stringifyForDisplay(d)}`).join('\n')}
` : ""}`);
    } else {
      mockedResponses.splice(responseIndex, 1);

      const { newData } = response;
      if (newData) {
        response.result = newData();
        mockedResponses.push(response);
      }

      if (!response.result && !response.error) {
        configError = new Error(
          `Mocked response should contain either result or error: ${key}`
        );
      }
    }

    return new Observable(observer => {
      const timer = setTimeout(() => {
        if (configError) {
          try {
            // The onError function can return false to indicate that
            // configError need not be passed to observer.error. For
            // example, the default implementation of onError calls
            // observer.error(configError) and then returns false to
            // prevent this extra (harmless) observer.error call.
            if (this.onError(configError, observer) !== false) {
              throw configError;
            }
          } catch (error) {
            observer.error(error);
          }
        } else if (response) {
          if (response.error) {
            observer.error(response.error);
          } else {
            if (response.result) {
              observer.next(
                typeof response.result === 'function'
                  ? (response.result as ResultFunction<FetchResult>)()
                  : response.result
              );
            }
            observer.complete();
          }
        }
      }, response && response.delay || 0);

      return () => {
        clearTimeout(timer);
      };
    });
  }

  private normalizeMockedResponse(
    mockedResponse: MockedResponse
  ): MockedResponse {
    const newMockedResponse = cloneDeep(mockedResponse);
    const queryWithoutConnection = removeConnectionDirectiveFromDocument(
      newMockedResponse.request.query
    );
    invariant(queryWithoutConnection, "query is required");
    newMockedResponse.request.query = queryWithoutConnection!;
    const query = removeClientSetsFromDocument(newMockedResponse.request.query);
    if (query) {
      newMockedResponse.request.query = query;
    }
    return newMockedResponse;
  }
} ]]
-- export error("not implemented"); --[[ ROBLOX TODO: Unhandled node for type: TSInterfaceDeclaration ]]
--  --[[ interface MockApolloLink extends ApolloLink {
--   operation?: Operation;
-- } ]]
-- local function mockSingleLink(__unhandledIdentifier__ --[[ ROBLOX TODO: Unhandled node for type: RestElement ]]
--  --[[ ...mockedResponses: Array<any> ]]): any
-- local maybeTypename = mockedResponses[tostring(mockedResponses.length - 1)]
-- local mocks = mockedResponses:slice(0, mockedResponses.length - 1)
-- if typeof(maybeTypename) ~= "boolean" then
-- mocks = mockedResponses;
-- maybeTypename = true;
-- end
-- return MockLink.new(mocks, maybeTypename)
-- end
-- exports.mockSingleLink = mockSingleLink
return exports
