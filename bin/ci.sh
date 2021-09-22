#!/bin/bash

set -x

echo "Build project"
rojo build tests.project.json --output model.rbxm
echo "Remove .robloxrc from dev dependencies"
find Packages/Dev -name "*.robloxrc" | xargs rm -f
find Packages/_Index -name "*.robloxrc" | xargs rm -f

echo "Run static analysis"
selene src
roblox-cli analyze tests.project.json --new-argument-parsing --fastFlags.overrides "LuauTarjanChildLimit=10000" --fastFlags.overrides "LuauTypeInferIterationLimit=10000"
stylua -c src

echo "Run tests"
roblox-cli run --load.model model.rbxm --run bin/spec.lua --lua.globals=__DEV__=true --fastFlags.allOnLuau --fastFlags.overrides "UseDateTimeType3=true" "EnableLoadModule=true" "EnableDelayedTaskMethods=true"
