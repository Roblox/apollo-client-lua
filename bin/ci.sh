#!/bin/bash

set -x

echo "Remove .robloxrc from dev dependencies"
find Packages/Dev -name "*.robloxrc" | xargs rm -f
find Packages/_Index -name "*.robloxrc" | xargs rm -f

echo "Run static analysis"
selene src benchmark
roblox-cli analyze analyze.project.json
stylua -c src benchmark

echo "Run tests"
roblox-cli run --load.place tests.project.json --run bin/spec.lua --lua.globals=__DEV__=true --fastFlags.allOnLuau --fastFlags.overrides "UseDateTimeType3=true" "EnableLoadModule=true" "EnableDelayedTaskMethods=true" --load.asRobloxScript --headlessRenderer 1 --virtualInput 1 --fs.read=$PWD --lua.globals=CI=true

# run the following command to update new snapshots
# roblox-cli run --load.model tests.project.json --run bin/spec.lua --lua.globals=__DEV__=true --fastFlags.allOnLuau --fastFlags.overrides "UseDateTimeType3=true" "EnableLoadModule=true" "EnableDelayedTaskMethods=true" --load.asRobloxScript --fs.readwrite="$(pwd)" --lua.globals=UPDATESNAPSHOT="new"
