local srcWorkspace = script.Parent.Parent
local rootWorkspace = srcWorkspace.Parent

local HttpService = game:GetService("HttpService")

local LuauPolyfill = require(rootWorkspace.LuauPolyfill)
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object

local JestGlobals = require(rootWorkspace.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local describe = JestGlobals.describe

local React = require(rootWorkspace.React)

local gql = require(rootWorkspace.GraphQLTag).default

local testingLibraryModule = require(rootWorkspace.Dev.ReactTestingLibrary)
local render = testingLibraryModule.render
local waitFor = testingLibraryModule.waitFor

local ApolloClient = require(srcWorkspace.core).ApolloClient
local InMemoryCache = require(srcWorkspace.cache).InMemoryCache

local Query = require(srcWorkspace.react.components.Query).Query
local ApolloProvider = require(srcWorkspace.react.context).ApolloProvider

local query = gql([[
        query {
            launchesPast(limit: 10) {
              mission_name
              launch_date_local
              launch_site {
                site_name_long
              }
            }
        }
]])
_G.fetch = require(rootWorkspace.RobloxRequests).fetch

describe("real endpoint", function()
	-- ROBLOX FIXME: API is down
	it.skip("should work", function()
		local client = ApolloClient.new({
			uri = "https://api.spacex.land/graphql/",
			cache = InMemoryCache.new(),
		})

		local loaded = false

		local function Component()
			return React.createElement(Query, { query = query }, function(result: any)
				if result.loading then
					return React.createElement("TextLabel", { Text = "Loading" })
				else
					loaded = true
					local launchesPast = Array.map(
						Array.map(result.data.launchesPast, function(l)
							return HttpService:JSONEncode(l)
						end),
						function(text)
							return React.createElement("TextLabel", {
								Text = text,
							})
						end
					)

					return React.createElement(
						React.Fragment,
						nil,
						React.createElement("TextLabel", {
							Text = "Results:",
						}),
						React.createElement("TextLabel", nil, table.unpack(launchesPast))
					)
				end
			end)
		end
		local getAllByText = render(
			React.createElement(ApolloProvider, { client = client }, React.createElement(Component, nil))
		).getAllByText

		expect(#getAllByText("Loading")).toBe(1)

		waitFor(function()
			expect(loaded).toBeTruthy()
		end, { timeout = 5000 }):expect()

		local resultsLabels = getAllByText("Results:")
		expect(#resultsLabels).toBe(1)
		-- ROBLOX note: Luau doesn't support type refinements on a subscript, so extract a tmp variable so it tracks the Parent ~= nil
		local firstResultLabel = resultsLabels[1]
		local secondChild = firstResultLabel.Parent ~= nil and firstResultLabel.Parent:GetDescendants()[2]
		expect(secondChild).toBeDefined()
		local resultsValues = secondChild:GetDescendants()
		expect(#resultsValues).toBe(10)
		Array.forEach(resultsValues, function(result)
			local resultTable = HttpService:JSONDecode(result.Text)
			expect(Array.sort(Object.keys(resultTable))).toEqual({
				"__typename",
				"launch_date_local",
				"launch_site",
				"mission_name",
			})
			local launchSite = resultTable.launch_site
			expect(launchSite.__typename).toBe("LaunchSite")
		end)
	end)
end)

return {}
