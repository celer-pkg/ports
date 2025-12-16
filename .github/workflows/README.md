# GitHub Actions for Ports Validation

This directory contains CI workflows to automatically validate new ports when they are submitted.

## 📋 Current Workflows

- **aarch64-linux-ubuntu-22.04-gcc-11.5.0.yml** - Validates ports for ARM64 Linux Ubuntu 22.04 with GCC 11.5.0

## 🚀 How It Works

When a new port is submitted or modified:

1. **Detect Changes** - The workflow identifies which ports were modified
2. **Parse TOML** - Reads `port.toml` and extracts `build_configs[].pattern`
3. **Match Platform** - Checks if the pattern matches the workflow's platform
4. **Build & Validate** - If matched, compiles the port using celer
5. **Upload Logs** - On failure, uploads build logs as artifacts

## ➕ Adding a New Platform Workflow

To add validation for another platform (e.g., `x86_64-linux-ubuntu-22.04-gcc-11.5.0`):

```bash
# Copy the existing workflow
cp aarch64-linux-ubuntu-22.04-gcc-11.5.0.yml x86_64-linux-ubuntu-22.04-gcc-11.5.0.yml

# Edit the file and change:
# 1. The workflow name
# 2. The PLATFORM environment variable
# 3. Remove QEMU setup if not cross-compiling
```

Example changes needed:

```yaml
name: Build Ports - x86_64-linux-ubuntu-22.04-gcc-11.5.0  # Change name

env:
  PLATFORM: x86_64-linux-ubuntu-22.04-gcc-11.5.0  # Change platform

# Remove or comment out the QEMU step for native x86_64:
# - name: Set up QEMU for ARM64
#   if: steps.check_match.outputs.should_build == 'true'
#   uses: docker/setup-qemu-action@v3
#   with:
#     platforms: arm64
```

## 🔧 Requirements

- Ports must have a valid `port.toml` with `build_configs` section
- The celer tool must be available from GitHub releases
- Platform configuration must exist in the conf repository

## 📊 Viewing Results

- Go to **Actions** tab in the repository
- Click on a workflow run to see which ports were built
- Download build logs from failed jobs for debugging

## 🛠️ Scripts

- **check-platform-match.sh** - TOML parser to check if a port matches a platform pattern
  - Uses `yq` for precise TOML parsing
  - Supports regex pattern matching
  - Returns exit code 0 if matched, 1 if not matched
