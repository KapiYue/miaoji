#!/bin/sh

set -eu

script_directory=$(CDPATH= cd "$(dirname "$0")" && pwd)
repository_path=${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd "$script_directory/../.." && pwd)}
config_path="$repository_path/client/MiaoJiConfig.xcconfig"

# This file contains only public client configuration and is intentionally
# version-controlled. Do not regenerate it from optional Xcode Cloud variables:
# doing so can silently omit a required value and produce a broken archive.
if [ ! -f "$config_path" ]; then
    echo "error: client/MiaoJiConfig.xcconfig is missing from the repository." >&2
    exit 1
fi

echo "Using version-controlled client/MiaoJiConfig.xcconfig for Xcode Cloud."
