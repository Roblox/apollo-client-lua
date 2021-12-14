#!/bin/bash

set -x

echo "Run benchmarks"
roblox-cli run --load.model benchmarks.project.json --run bin/benchmark.lua --lua.globals=__DEV__=true --fastFlags.allOnLuau --fastFlags.overrides "UseDateTimeType3=true" "EnableLoadModule=true" "EnableDelayedTaskMethods=true"

# CI flag: less verbose
# roblox-cli run --load.model benchmarks.project.json --run bin/benchmark.lua --lua.globals=__CI__=true --lua.globals=__MAX_BENCHMARK_TIME__=20 --lua.globals=__MAX_RME__=3 --fastFlags.allOnLuau --fastFlags.overrides "UseDateTimeType3=true" "EnableLoadModule=true" "EnableDelayedTaskMethods=true"
