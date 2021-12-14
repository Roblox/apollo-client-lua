local Root = script.Parent.ApolloClientBenchmarkModel
local ProcessService = game:GetService("ProcessService")

local Packages = Root.Packages
local benchmark = require(Packages.ApolloClientBenchmarks)

local ok, result = pcall(benchmark)

if not ok then
	warn(result)
	ProcessService:ExitAsync(1)
else
	ProcessService:ExitAsync(0)
end
