#!/bin/bash
# Script to check if a port.toml matches a given platform by system_name/system_processor.

set -e

PORT_TOML="$1"
PLATFORM="$2"

echo "-- Input argument: PORT_TOML=${PORT_TOML}"
echo "-- Input argument: PLATFORM=${PLATFORM}"

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
  value=$(yq eval "${field}" "$toml_file" 2>/dev/null | tr '[:upper:]' '[:lower:]')

  # Step 2: treat empty/null as empty string.
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo ""
  else
    echo "$value"
  fi
}

# Extract major.minor from a version string (e.g. "14.50.35717" -> "14.50").
minor_version() {
  local v="$1"
  local major="${v%%.*}"
  local rest="${v#*.}"
  local minor="${rest%%.*}"
  echo "${major}.${minor}"
}

# Parse platform selectors from platform.toml only.
PLATFORM_SYSTEM_NAME=$(read_toml_as_lower '.toolchain.system_name' "$PLATFORM_TOML")
PLATFORM_PROCESSOR=$(read_toml_as_lower '.toolchain.system_processor' "$PLATFORM_TOML")
PLATFORM_TOOLCHAIN_VERSION=$(read_toml_as_lower '.toolchain.version' "$PLATFORM_TOML")

echo "-- Read PLATFORM_SYSTEM_NAME: ${PLATFORM_SYSTEM_NAME}"
echo "-- Read PLATFORM_PROCESSOR: ${PLATFORM_PROCESSOR}"
echo "-- Read PLATFORM_TOOLCHAIN_VERSION: ${PLATFORM_TOOLCHAIN_VERSION}"

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
BUILD_CONFIGS_COUNT=$(yq eval '.build_configs | length' "$PORT_TOML" 2>/dev/null)

if [ "$BUILD_CONFIGS_COUNT" = "0" ] || [ "$BUILD_CONFIGS_COUNT" = "null" ]; then
  echo "ERROR: No build_configs found in $PORT_TOML" >&2
  exit 2
fi

for ((i=0; i<BUILD_CONFIGS_COUNT; i++)); do
  # Read system_names array as JSON format, then convert to space-separated lowercase
  # This is more reliable than trying to parse YAML output
  SYSTEM_NAMES_JSON=$(yq eval ".build_configs[$i].system_names | @json" "$PORT_TOML" 2>/dev/null || echo '""')
  echo "-- Raw JSON SYSTEM_NAMES: ${SYSTEM_NAMES_JSON}"
  
  # Parse JSON array and convert to space-separated string
  if [ "$SYSTEM_NAMES_JSON" = '""' ] || [ "$SYSTEM_NAMES_JSON" = "null" ] || [ -z "$SYSTEM_NAMES_JSON" ]; then
    SYSTEM_NAMES=""
  else
    # Use jq to parse JSON array, or fallback to manual parsing if jq not available
    if command -v jq &> /dev/null; then
      SYSTEM_NAMES=$(echo "$SYSTEM_NAMES_JSON" | jq -r 'if type == "array" then map(ascii_downcase) | join(" ") elif type == "null" then "" else . | ascii_downcase end' 2>/dev/null || echo "")
    else
      # Fallback: simple text processing for JSON array
      SYSTEM_NAMES=$(echo "$SYSTEM_NAMES_JSON" | sed 's/^\[//; s/\]$//; s/"//g; s/,/ /g' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    fi
  fi
  
  echo "-- Parsed SYSTEM_NAMES in build_config($i): |${SYSTEM_NAMES}|"
  
  SYSTEM_NAME=""
  
  # If system_names is not specified, fall back to system_name.
  if [ -z "$SYSTEM_NAMES" ]; then
    SYSTEM_NAME=$(read_toml_as_lower ".build_configs[$i].system_name" "$PORT_TOML")
    echo "-- No SYSTEM_NAMES, fallback to SYSTEM_NAME in build_config($i): |${SYSTEM_NAME}|"
  fi
  
  SYSTEM_PROCESSOR=$(read_toml_as_lower ".build_configs[$i].system_processor" "$PORT_TOML")
  echo "-- SYSTEM_PROCESSOR in build_config($i): |${SYSTEM_PROCESSOR}|"

  TOOLCHAIN_VERSION=$(read_toml_as_lower ".build_configs[$i].toolchain_version" "$PORT_TOML")
  echo "-- TOOLCHAIN_VERSION in build_config($i): |${TOOLCHAIN_VERSION}|"

  # Check system_name_except / system_names_except (platform exclusion list)
  SYSTEM_NAME_EXCEPT=$(read_toml_as_lower ".build_configs[$i].system_name_except" "$PORT_TOML")
  echo "-- SYSTEM_NAME_EXCEPT in build_config($i): |${SYSTEM_NAME_EXCEPT}|"
  if [ -n "$SYSTEM_NAME_EXCEPT" ] && [ "$SYSTEM_NAME_EXCEPT" = "$PLATFORM_SYSTEM_NAME" ]; then
    echo "-- Platform $PLATFORM_SYSTEM_NAME excluded by system_name_except"
    continue
  fi
  # Check system_names_except (array form) — each element excludes that platform
  if yq eval ".build_configs[$i].system_names_except[]" "$PORT_TOML" 2>/dev/null | grep -qix "$PLATFORM_SYSTEM_NAME"; then
    echo "-- Platform $PLATFORM_SYSTEM_NAME excluded by system_names_except"
    continue
  fi

  # system_names/system_name are extensible, so only validate token format when specified.
  if [ -n "$SYSTEM_NAMES" ]; then
    while IFS=' ' read -r token; do
      if [ -n "$token" ] && ! [[ "$token" =~ ^[a-z0-9_]+$ ]]; then
        echo "ERROR: Invalid system_name '$token' in $PORT_TOML (build_configs[$i].system_names)" >&2
        exit 2
      fi
    done <<< "$SYSTEM_NAMES"
  fi
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

  # No selector specified => global match (only if no selector fields are defined)
  BUILD_CONFIG_RAW=$(yq eval ".build_configs[$i]" "$PORT_TOML" 2>/dev/null | grep -i "system_names\|system_name\|system_processor\|system_names_except\|system_name_except\|toolchain_version" | wc -l)
  echo "-- BUILD_CONFIG_RAW field count: ${BUILD_CONFIG_RAW}"
  
  if [ "$BUILD_CONFIG_RAW" = "0" ] && [ -z "$SYSTEM_NAMES" ] && [ -z "$SYSTEM_NAME" ] && [ -z "$SYSTEM_PROCESSOR" ] && [ -z "$SYSTEM_NAME_EXCEPT" ] && [ -z "$TOOLCHAIN_VERSION" ]; then
    echo "-- No selector specified => matches all platforms"
    MATCH_FOUND=true
    break
  fi

  SYSTEM_NAME_MATCH=true
  SYSTEM_PROCESSOR_MATCH=true
  TOOLCHAIN_VERSION_MATCH=true

  # Check system_names list first (takes precedence over system_name)
  if [ -n "$SYSTEM_NAMES" ]; then
    SYSTEM_NAME_MATCH=false
    while IFS=' ' read -r name; do
      if [ -n "$name" ] && [ "$name" = "$PLATFORM_SYSTEM_NAME" ]; then
        SYSTEM_NAME_MATCH=true
        break
      fi
    done <<< "$SYSTEM_NAMES"
  elif [ -n "$SYSTEM_NAME" ] && [ "$SYSTEM_NAME" != "$PLATFORM_SYSTEM_NAME" ]; then
    SYSTEM_NAME_MATCH=false
  fi

  if [ -n "$SYSTEM_PROCESSOR" ] && [ "$SYSTEM_PROCESSOR" != "$PLATFORM_PROCESSOR" ]; then
    SYSTEM_PROCESSOR_MATCH=false
  fi

  # Check toolchain_version (compare major.minor part).
  if [ -n "$TOOLCHAIN_VERSION" ]; then
    if [ "$(minor_version "$PLATFORM_TOOLCHAIN_VERSION")" != "$(minor_version "$TOOLCHAIN_VERSION")" ]; then
      TOOLCHAIN_VERSION_MATCH=false
    fi
  fi

  echo "-- SYSTEM_NAME_MATCH=${SYSTEM_NAME_MATCH}, SYSTEM_PROCESSOR_MATCH=${SYSTEM_PROCESSOR_MATCH}, TOOLCHAIN_VERSION_MATCH=${TOOLCHAIN_VERSION_MATCH}"
  
  if [ "$SYSTEM_NAME_MATCH" = "true" ] && [ "$SYSTEM_PROCESSOR_MATCH" = "true" ] && [ "$TOOLCHAIN_VERSION_MATCH" = "true" ]; then
    MATCH_FOUND=true
    NAMES_DISPLAY="${SYSTEM_NAMES:-${SYSTEM_NAME:-*}}"
    echo "-- Match found: system_name='${NAMES_DISPLAY}', system_processor='${SYSTEM_PROCESSOR:-*}' matches platform selectors from '$PLATFORM_TOML'"
    break
  fi
done

if [ "$MATCH_FOUND" = "true" ]; then
  echo "-- Platform ($PLATFORM_SYSTEM_NAME/$PLATFORM_PROCESSOR) is supported by this port"
  exit 0
else
  echo "-- Platform ($PLATFORM_SYSTEM_NAME/$PLATFORM_PROCESSOR) is NOT supported by this port"
  exit 1
fi
