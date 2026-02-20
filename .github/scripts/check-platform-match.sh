#!/bin/bash
# Script to check if a port.toml matches a given platform by system_name/system_processor.

set -e

PORT_TOML="$1"
PLATFORM="$2"

if [ ! -f "$PORT_TOML" ]; then
    echo "ERROR: Port TOML not found: $PORT_TOML" >&2
    exit 1
fi

PLATFORM_TOML="conf/platforms/${PLATFORM}.toml"
if [ ! -f "$PLATFORM_TOML" ] && [ -f "../$PLATFORM_TOML" ]; then
    PLATFORM_TOML="../$PLATFORM_TOML"
fi
if [ ! -f "$PLATFORM_TOML" ]; then
    echo "ERROR: Platform TOML not found in workspace: conf/platforms/${PLATFORM}.toml" >&2
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

read_toml_as_lower() {
    local field="$1"
    local toml_file="$2"
    local value

    # Step 1: read field and normalize to lowercase.
    value=$(yq eval "${field}" "$toml_file" | tr '[:upper:]' '[:lower:]')

    # Step 2: treat empty/null as empty string.
    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo ""
    else
        echo "$value"
    fi
}

# Parse platform selectors from platform.toml only.
PLATFORM_SYSTEM_NAME=$(read_toml_as_lower '.toolchain.system_name' "$PLATFORM_TOML")
PLATFORM_PROCESSOR=$(read_toml_as_lower '.toolchain.system_processor' "$PLATFORM_TOML")

# system_name is extensible (e.g. linux/windows/darwin/qnx/mcu...),
# so only validate format.
if [ -z "$PLATFORM_SYSTEM_NAME" ] || ! [[ "$PLATFORM_SYSTEM_NAME" =~ ^[a-z0-9_]+$ ]]; then
    echo "ERROR: Invalid platform system_name '$PLATFORM_SYSTEM_NAME' in $PLATFORM_TOML" >&2
    exit 2
fi
if [ -n "$PLATFORM_PROCESSOR" ] && ! [[ "$PLATFORM_PROCESSOR" =~ ^[a-z0-9_]+$ ]]; then
    echo "ERROR: Invalid platform system_processor '$PLATFORM_PROCESSOR' in $PLATFORM_TOML" >&2
    exit 2
fi

# Check if any build_config matches.
# If both system_name and system_processor are omitted, it matches all platforms.
MATCH_FOUND=false

# Get all build_configs
BUILD_CONFIGS_COUNT=$(yq eval '.build_configs | length' "$PORT_TOML")

if [ "$BUILD_CONFIGS_COUNT" = "0" ] || [ "$BUILD_CONFIGS_COUNT" = "null" ]; then
    echo "ERROR: No build_configs found in $PORT_TOML" >&2
    exit 2
fi

for ((i=0; i<BUILD_CONFIGS_COUNT; i++)); do
    SYSTEM_NAME=$(read_toml_as_lower ".build_configs[$i].system_name" "$PORT_TOML")
    SYSTEM_PROCESSOR=$(read_toml_as_lower ".build_configs[$i].system_processor" "$PORT_TOML")

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
        echo "Match found: system_name='${SYSTEM_NAME:-*}', system_processor='${SYSTEM_PROCESSOR:-*}' matches platform selectors from '$PLATFORM_TOML'"
        break
    fi
done

if [ "$MATCH_FOUND" = "true" ]; then
    echo "Platform ($PLATFORM_SYSTEM_NAME/$PLATFORM_PROCESSOR) is supported by this port"
    exit 0
else
    echo "Platform ($PLATFORM_SYSTEM_NAME/$PLATFORM_PROCESSOR) is NOT supported by this port"
    exit 1
fi
