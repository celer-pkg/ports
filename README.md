# celer-ports

This directory contains the public port definitions used by celer. A port is usually a `port.toml` file plus optional helper files such as patches or `cmake_config.toml`.

## Layout

- Public ports live at `ports/<bucket>/<name>/<version>/port.toml`.
- `<bucket>` is the lowercase first character of the package name. Non-alphanumeric names go under `other`.
- The same version directory may also contain patches, helper files, or `cmake_config.toml` for `prebuilt` ports.
- A project can override a public port at `conf/projects/<project>/<name>/<version>/port.toml`. Non-zero fields in the project port override the public one.

## How celer resolves a port

- Each port has one `[package]` table and one or more `[[build_configs]]` entries.
- Celer selects exactly one matching `build_config`.
- `system_name` and `system_processor` are selectors. If both are omitted, the config is global.
- Matching more than one config is an error.
- For `dev_dependencies` and `build_tool` ports, config matching uses the host machine rather than the target toolchain.

## `port.toml` overview

### `[package]`

- `url`: Git URL, archive URL, or `file:///...` local source path.
- `ref`: Git tag, branch, commit, or archive version identifier.
- `checksum`: Optional source checksum. Recommended for archives.
- `cache_repo`: Allow restoring and storing the source tree from repo cache.
- `depth`: Optional shallow-clone depth for Git sources.
- `archive`: Optional archive filename override.
- `src_dir`: Optional subdirectory inside the source tree that contains the real project.
- `ignore_submodule`: Skip Git submodule checkout.
- `build_tool`: Mark the port as a host-side build tool. These ports are built natively and installed under `installed/<host>-dev`. They are currently supported on Linux hosts.

### `[[build_configs]]`

Selectors:

- `system_name`
- `system_processor`

Core build fields:

- `build_system`: One of `cmake`, `makefiles`, `meson`, `qmake`, `b2`, `gyp`, `nobuild`, `prebuilt`, or `custom`.
- `cmake_generator`
- `build_tools`
- `options`
- `build_in_source`
- `autogen_options`

Build shape and language:

- `library_type`
- `build_shared`
- `build_static`
- `build_type`
- `c_standard`
- `cxx_standard`

Source fixes and environment:

- `envs`
- `patches`

Dependencies:

- `dependencies`
- `dev_dependencies`

Hooks around built-in stages:

- `pre_configure`
- `post_configure`
- `pre_build`
- `fix_build`
- `post_build`
- `pre_install`
- `post_install`

Full custom stage commands:

- `configure`
- `build`
- `install`

Most build-config fields also support `_windows`, `_linux` variants, for example `options_linux`, `dependencies_windows`. These platform-specific fields override the base field. For slice fields such as `options`, `dependencies`, or `dev_dependencies`, the override replaces the entire list instead of appending to it.

`build_system` also accepts a version suffix for `cmake`, `meson`, and `gyp`, for example `cmake@3.30.3`.

## Expression variables

Celer expands variables in `options`, hooks, and related string fields. The most commonly used port-local variables are:

- `${REPO_DIR}`
- `${SRC_DIR}`
- `${BUILD_DIR}`
- `${PACKAGE_DIR}`
- `${DEPS_DIR}`
- `${DEPS_DEV_DIR}`

See `docs/en-US/article_port.md` and `docs/en-US/article_expvars.md` for deeper background.

## Minimal example

```toml
[package]
  url = "https://github.com/google/googletest.git"
  ref = "v1.17.0"

[[build_configs]]
  build_system = "cmake"
  options = [
    "-DBUILD_TESTING=OFF",
    "-DBUILD_SHARED_LIBS=ON",
  ]
  options_windows = [
    "-DBUILD_TESTING=OFF",
    "-DBUILD_SHARED_LIBS=ON",
    "-Dgtest_force_shared_crt=ON",
  ]
  dev_dependencies = ["pkgconf@2.4.3"]
```

On Windows, `options_windows` replaces `options`, so repeat any shared options you still need.

## Workflow

- Create a scaffold with `celer create --port name@version`.
- Place patches and helper files in the same version directory as `port.toml`.
- Keep `build_configs` mutually exclusive. Prefer one global config plus platform-specific override fields when possible.

## Related

- [Root README](../README.md)
- [Port details](../docs/en-US/article_port.md)
- [Expression variables](../docs/en-US/article_expvars.md)

## License

This repository is licensed under the MIT License. Third-party libraries in the ports tree keep their original licenses.
