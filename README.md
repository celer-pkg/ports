# 📦 A repository hosting ports for [Celer](https://github.com/celer-pkg/celer).

This directory contains configuration files for managing third-party C++ libraries and build tools. It provides a centralized repository of port definitions that specify how to download, configure, and build various open-source packages.

## 📁 Directory Structure

### 📦 Package Organization

Each package is organized as follows:
- `<package-name>/` - Package directory
  - `<version>/` - Version-specific subdirectory
    - `port.toml` - Package configuration and build specifications

## ⚙️ Configuration Files

### 📝 port.toml Format

Each `port.toml` file defines how a package should be built and installed. Key sections include:

#### 📦 `[package]`
- `url` - Download URL for the source code
- `ref` - Version reference or tag

#### 🛠️ `[[build_configs]]`
Build configuration array with multiple possible configurations:
- `build_system` - Build system type (cmake, b2, bazel, meson, qmake, makefiles, custom, gyp, nobuild, prebuilt)
- `options` - Build system specific options and flags
- `post_install_windows` - Post-installation commands for Windows
- `post_install_unix` - Post-installation commands for Unix-like systems
- [Other platform-specific or build-specific configurations](https://github.com/celer-pkg/celer/blob/master/docs/en-US/article_port.md)

## 🚀 Usage

These port definitions are typically used by Celer(a package manager) to:
1. Download source packages from specified URLs
2. Extract and prepare the source
3. Build according to the specified build system and options
4. Install to the appropriate directories
5. Generate binary caches for faster future builds

## ➕ Adding New Ports

To add a new port:
1. Create a new directory: `<package-name>/`
2. Create version subdirectory: `<package-name>/<version>/`
3. Add `port.toml` with appropriate configuration
4. Specify download URL, build system, and any custom build options

>You can also create new port toml by executing `celer create --port=name@version`, then proceed with its refinement.

## 🔗 Related

- [Celer](https://github.com/celer-pkg/celer) - A lightweight C/C++ package manager that allows to manager C/C++ libraries through TOML only.
- [Port details](https://github.com/celer-pkg/celer/blob/master/docs/en-US/article_port.md) - Configuring third-party library compilation in a declarative way.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Third-party libraries in the ports repository are licensed under their respective original terms.