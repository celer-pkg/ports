#!/bin/bash
# Script to check if a port.toml matches a given platform by system_name/system_processor.

set -e

PORT_TOML="$1"
PLATFORM="$2"

if [ ! -f "$PORT_TOML" ]; then
    echo "ERROR: Port TOML not found: $PORT_TOML" >&2
    exit 1
fi

# Install yq if not available (TOML parser)
if ! command -v yq &> /dev/null; then
    echo "Installing yq for TOML parsing locally..."
    
    # Detect OS and download appropriate yq binary
    case "$(uname -s)" in
        Linux*)
            YQ_BINARY="yq_linux_amd64"
            YQ_NAME="yq"
            ;;
        Darwin*)
            YQ_BINARY="yq_darwin_amd64"
            YQ_NAME="yq"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            YQ_BINARY="yq_windows_amd64.exe"
            YQ_NAME="yq.exe"
            ;;
        *)
            echo "ERROR: Unsupported OS: $(uname -s)" >&2
            exit 1
            ;;
    esac
    
    curl -sSL -o "./$YQ_NAME" "https://github.com/mikefarah/yq/releases/latest/download/$YQ_BINARY"
    chmod +x "./$YQ_NAME"
    export PATH="$(pwd):$PATH"
else
    # If yq is not in PATH but exists in current dir, add it to PATH
    if [ -f "./yq" ] || [ -f "./yq.exe" ]; then
        export PATH="$(pwd):$PATH"
    fi
fi

# Parse platform as "<processor>-<system>-...".
PLATFORM_PROCESSOR=$(echo "$PLATFORM" | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')
PLATFORM_SYSTEM_NAME=$(echo "$PLATFORM" | cut -d'-' -f2 | tr '[:upper:]' '[:lower:]')

# system_name is extensible (e.g. linux/windows/darwin/qnx/mcu...),
# so only validate format.
if ! [[ "$PLATFORM_SYSTEM_NAME" =~ ^[a-z0-9_]+$ ]]; then
    echo "ERROR: Invalid platform system_name '$PLATFORM_SYSTEM_NAME' parsed from '$PLATFORM'" >&2
    exit 2
fi

# Check if any build_config matches.
# If both system_name and system_processor are omitted, it matches all platforms.
MATCH_FOUND=false

# Get all build_configs
BUILD_CONFIGS_COUNT=$(yq eval '.build_configs | length' "$PORT_TOML")

if [ "$BUILD_CONFIGS_COUNT" = "0" ] || [ "$BUILD_CONFIGS_COUNT" = "null" ]; then
    echo "No build_configs found in $PORT_TOML, matches all platforms"
    MATCH_FOUND=true
else
    for ((i=0; i<BUILD_CONFIGS_COUNT; i++)); do
        SYSTEM_NAME=$(yq eval ".build_configs[$i].system_name // \"\"" "$PORT_TOML" | tr '[:upper:]' '[:lower:]')
        SYSTEM_PROCESSOR=$(yq eval ".build_configs[$i].system_processor // \"\"" "$PORT_TOML" | tr '[:upper:]' '[:lower:]')

        # Empty means no constraint.
        if [ "$SYSTEM_NAME" = "null" ]; then
            SYSTEM_NAME=""
        fi
        if [ "$SYSTEM_PROCESSOR" = "null" ]; then
            SYSTEM_PROCESSOR=""
        fi

        # system_name is extensible, so only validate token format when specified.
        if [ -n "$SYSTEM_NAME" ] && ! [[ "$SYSTEM_NAME" =~ ^[a-z0-9_]+$ ]]; then
            echo "ERROR: Invalid system_name '$SYSTEM_NAME' in $PORT_TOML (build_configs[$i])" >&2
            exit 2
        fi

        # system_processor is extensible (current common values: aarch64, x86_64),
        # so only validate it is a non-empty normalized token when specified.
        if [ -n "$SYSTEM_PROCESSOR" ] && ! [[ "$SYSTEM_PROCESSOR" =~ ^[a-z0-9_]+$ ]]; then
            echo "ERROR: Invalid system_processor '$SYSTEM_PROCESSOR' in $PORT_TOML (build_configs[$i])" >&2
            exit 2
        fi

        # No selector specified => global match.
        if [ -z "$SYSTEM_NAME" ] && [ -z "$SYSTEM_PROCESSOR" ]; then
            MATCH_FOUND=true
            break
        fi

        SYSTEM_NAME_MATCH=true
        SYSTEM_PROCESSOR_MATCH=true

        if [ -n "$SYSTEM_NAME" ] && [ "$SYSTEM_NAME" != "$PLATFORM_SYSTEM_NAME" ]; then
            SYSTEM_NAME_MATCH=false
        fi
        if [ -n "$SYSTEM_PROCESSOR" ] && [ "$SYSTEM_PROCESSOR" != "$PLATFORM_PROCESSOR" ]; then
            SYSTEM_PROCESSOR_MATCH=false
        fi

        if [ "$SYSTEM_NAME_MATCH" = "true" ] && [ "$SYSTEM_PROCESSOR_MATCH" = "true" ]; then
            MATCH_FOUND=true
            echo "Match found: system_name='${SYSTEM_NAME:-*}', system_processor='${SYSTEM_PROCESSOR:-*}' matches platform='$PLATFORM'"
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
