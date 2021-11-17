local exports = {}
local QueryManager = require(script.Parent.Parent.Parent.Parent.core.QueryManager).QueryManager
local mockLinkModule = require(script.Parent.mockLink)
local mockSingleLink = mockLinkModule.mockSingleLink
type MockedResponse_ = mockLinkModule.MockedResponse_
local InMemoryCache = require(script.Parent.Parent.Parent.Parent.cache.inmemory.inMemoryCache).InMemoryCache

-- Helper method for the tests that construct a query manager out of a
-- a list of mocked responses for a mocked network interface.
exports.default = function(reject: (reason: any) -> ...any, ...: MockedResponse_)
	return QueryManager.new({
		link = mockSingleLink(...),
		cache = InMemoryCache.new({ addTypename = false }),
	})
end

return exports
