#!/bin/bash
# Script to check if a port.toml matches a given platform pattern

set -e

PORT_TOML="$1"
PLATFORM="$2"

if [ ! -f "$PORT_TOML" ]; then
    echo "ERROR: Port TOML not found: $PORT_TOML" >&2
    exit 1
fi

# Install yq if not available (TOML parser)
if ! command -v yq &> /dev/null; then
    echo "Installing yq for TOML parsing..."
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
fi

# Check if any build_config has a matching pattern
# If no pattern is specified, it matches all platforms
MATCH_FOUND=false

# Get all build_configs
BUILD_CONFIGS_COUNT=$(yq eval '.build_configs | length' "$PORT_TOML")

if [ "$BUILD_CONFIGS_COUNT" = "0" ] || [ "$BUILD_CONFIGS_COUNT" = "null" ]; then
    echo "No build_configs found in $PORT_TOML, matches all platforms"
    MATCH_FOUND=true
else
    for ((i=0; i<BUILD_CONFIGS_COUNT; i++)); do
        PATTERN=$(yq eval ".build_configs[$i].pattern // \"\"" "$PORT_TOML")
        
        # If no pattern specified, matches all platforms
        if [ -z "$PATTERN" ] || [ "$PATTERN" = "null" ]; then
            MATCH_FOUND=true
            break
        fi
        
        # Check if pattern matches (exact match or regex)
        if [[ "$PLATFORM" =~ $PATTERN ]]; then
            MATCH_FOUND=true
            echo "Match found: pattern='$PATTERN' matches platform='$PLATFORM'"
            break
        fi
    done
fi

if [ "$MATCH_FOUND" = "true" ]; then
    echo "Platform $PLATFORM is supported by this port"
    exit 0
else
    echo "Platform $PLATFORM is NOT supported by this port"
    exit 1
fi
