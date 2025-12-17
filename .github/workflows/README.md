# GitHub Actions for Ports Validation

This directory contains CI workflows to automatically validate new ports when they are submitted.

## 📋 Current Workflows

- **aarch64-linux-ubuntu-22.04-gcc-11.5.0.yml** - Validates ports for ARM64 Linux Ubuntu 22.04 with GCC 11.5.0
- **x86_64-windows-msvc-14.44.yml** - Validates ports for x86_64 Windows with MSVC 14.44

## 🚀 How It Works

When a new port is submitted or modified:

1. **Detect Changes** - Identifies which port was modified (only allows one port per commit)
2. **Parse TOML** - Reads `port.toml` and extracts `build_configs[].pattern`
3. **Match Platform** - Checks if the pattern matches the workflow's platform
4. **Build & Validate** - If matched, downloads celer and compiles the port
5. **Report Results** - Shows success/failure with detailed logs

All steps are combined in a single job for cleaner GitHub Checks UI.

## 🔒 Validation Rules

- ✅ **One port per commit** - Multiple ports in a single commit will be rejected
- ✅ **Pattern matching** - Port is only built on platforms matching its `pattern` field
- ✅ **Automatic skip** - Non-matching platforms are automatically skipped (no error)

## 📝 Platform Patterns

Ports specify which platforms they support using the `pattern` field in `port.toml`:

```toml
[[build_configs]]
pattern = "*linux*"        # Only Linux platforms
build_system = "cmake"
# ...

[[build_configs]]
pattern = "*windows*"      # Only Windows platforms  
build_system = "cmake"
# ...
```

Common patterns:
- `*linux*` - All Linux platforms
- `*windows*` - All Windows platforms
- `x86_64-linux*` - x86_64 Linux only
- `aarch64-linux*` - AArch64 Linux only
- `*` or omitted - All platforms (default)

Pattern matching uses shell globbing (wildcards).

## ➕ Adding a New Platform Workflow

To add validation for another platform (e.g., `x86_64-linux-ubuntu-22.04-clang-21.1.4`):

### Step 1: Copy Existing Workflow

```bash
# For Linux platforms
cp aarch64-linux-ubuntu-22.04-gcc-11.5.0.yml x86_64-linux-ubuntu-22.04-clang-21.1.4.yml

# For Windows platforms
cp x86_64-windows-msvc-14.44.yml x86_64-windows-clang-cl-14.44.yml
```

### Step 2: Update Platform Details

Edit the new file and change:

```yaml
# 1. Change the workflow name
name: Build Ports - x86_64-linux-ubuntu-22.04-clang-21.1.4

# 2. Update the PLATFORM environment variable
env:
  PLATFORM: x86_64-linux-ubuntu-22.04-clang-21.1.4

# 3. Adjust runner OS if needed
jobs:
  build-port:
    runs-on: ubuntu-22.04  # or windows-2022 for Windows
```

### Step 3: Platform-Specific Adjustments

**For cross-compilation (ARM64):**
```yaml
# Keep QEMU setup
- name: Set up QEMU for ARM64
  if: steps.check_match.outputs.should_build == 'true'
  uses: docker/setup-qemu-action@v3
  with:
    platforms: arm64
```

**For native x86_64:**
```yaml
# Remove QEMU step - not needed for native builds
```

**For Windows:**
```yaml
# Add MSVC setup
- name: Setup MSVC
  if: steps.check_match.outputs.should_build == 'true'
  uses: ilammy/msvc-dev-cmd@v1
  with:
    arch: amd64

# Use shell: bash for all steps
# Use celer.exe instead of celer
# Use cmd //c "mklink /J ..." for directory junctions
```

## 🔧 Requirements

- Ports must have a valid `port.toml` with `build_configs` section
- The celer tool must be available from GitHub releases:
  - `x86_64-linux.tar.gz` for Linux workflows
  - `x86_64-windows.tar.gz` for Windows workflows
- Platform configuration must exist in `test-conf` repository

## 📊 Viewing Results

- Go to **Actions** tab in the repository
- Click on a workflow run to see build status
- Each platform shows as a single check (e.g., "Build Ports - windows-amd64-msvc-14.44")
- View step-by-step logs within each job
- Skipped builds show as "should_build=false" in logs

## 🛠️ Scripts

### check-platform-match.sh

TOML parser to check if a port matches a platform pattern.

**Features:**
- Uses `yq` for precise TOML parsing
- Auto-downloads correct `yq` binary for OS (Linux/macOS/Windows)
- Supports glob pattern matching (`*`, `?`, etc.)
- Returns proper exit codes:
  - `0` - Platform matches (should build)
  - `1` - Platform doesn't match (skip build)
  - `2+` - Script error (fail workflow)

**Usage:**
```bash
chmod +x .github/scripts/check-platform-match.sh
.github/scripts/check-platform-match.sh poco/1.14.2/port.toml x86_64-linux-ubuntu-22.04-gcc-11.5.0
```

## 🐛 Troubleshooting

### Workflow Shows Green but Port Wasn't Built

This is expected if the port's `pattern` doesn't match the platform. Check the logs:
```
Platform x86_64-windows-msvc-enterprise-14.44 is NOT supported by this port
should_build=false
```

### Script Errors (wget/binary format/etc.)

These now properly fail the workflow with a red ✗. Check:
1. OS detection in `check-platform-match.sh` is correct
2. `yq` binary download URL is accessible
3. Network connectivity

### Multiple Ports Rejected

Error message:
```
Multiple ports detected in single commit. Please submit one port at a time.
```

**Solution:** Split changes into separate commits, one port per commit.

## 🎯 Best Practices

1. **Test locally first** - Run `celer install <port>@<version> --dev` locally before pushing
2. **Use appropriate patterns** - Don't claim `*` if only Linux is supported
3. **One port per PR** - Makes review and CI easier
4. **Check CI early** - Fix any failures before requesting review
5. **Add platform workflows gradually** - Start with most common platforms

## 🔮 Future Enhancements

Potential improvements:
- Add more platforms (macOS, other Linux distros)
- Cache celer downloads between runs
- Parallel testing of multiple platforms
- Automated pattern validation
- Build time metrics and reporting
