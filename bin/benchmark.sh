#!/bin/bash

set -x

echo "Run benchmarks"
roblox-cli run --load.project benchmark.project.json --run bin/benchmark.lua --lua.globals=__DEV__=true --fastFlags.allOnLuau --fastFlags.overrides "UseDateTimeType3=true" "EnableLoadModule=true" "EnableDelayedTaskMethods=true"