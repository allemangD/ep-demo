# ep-demo

This is a (very) minimal example of a SuperBuild project, which uses ExternalProject to build and
use a single dependency: `fmt`. Note that many options often used in practice are omitted for
brevity.

## Command-Line Usage

These are the minimal commands to _use_ the SuperBuild.

```shell
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
build/inner-build/sample
```

```text
Using fmt 10.1.0 from /path/to/build/fmt-prefix/lib/cmake/fmt/fmt-config.cmake
```

Or, with more verbose commands:

```shell
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -t inner-prefix/src/inner-stamp/inner-configure
cmake --build build/inner-build -t sample
build/inner-build/sample
```

## CLion Workaround

To load this project I must:

1. Load the project with any SuperBuild options (like `USE_SYSTEM_fmt`)
2. Rename the generated profile to 'SuperBuild'
3. Build all in 'SuperBuild'
    - Note: VCS integration complains about dependency source directories.
4. __CRITICAL:__ Disable 'SuperBuild' profile.
5. Create a new profile 'inner'.
    - Choose 'Generator: Let CMake Decide'
   - Choose `build/inner-build` build directory (or whatever `BINARY_DIR` on the inner
     ExternalProject)
6. Run 'sample' configuration.

CLion correctly indexes the inner build directory and all dependencies. Things are good! Even
editing inner-build CMake is fine, e.g. changing `add_executable` or `target_compile_definitions`
lines.

## CLion Issues

Issues arise when editing _SuperBuild_ CMake, e.g. changing ExternalProject arguments or SuperBuild
options like `USE_SYSTEM_fmt`.

For example, to downgrade `fmt` to `9.1.0`, I must:

1. __CRITICAL:__ disable the 'inner' profile
2. Enable the 'SuperBuild' profile.
3. Change `GIT_TAG` to `9.1.0` in `SuperBuild.cmake`
4. Reload CMake project
5. Build All in 'SuperBuild'
6. __CRITICAL:__ disable the 'SuperBuild' profile
7. Enable the 'inner' profile.
8. Run 'sample' configuration.

```text
Using fmt 9.1.0 from /path/to/build/fmt-prefix/lib/cmake/fmt/fmt-config.cmake
```

## Ideal workflow

I want to edit CMake like I have the 'SuperBuild' profile enabled, but I want to edit C++ and
configurations like I have the 'inner' profile enabled.

When I load the project, I should set SuperBuild CMake options, but CLion should detect the inner
build and index that, not the SuperBuild.

"Reload CMake Project" should re-configure the SuperBuild and then use the CMake `*-configure`
target to reconfigure the inner projects.

## Suggestion

After the top-level CMake project loads, detect ExternalProjects with `SOURCE_DIR` in the project
source tree. Mark these as "inner" projects.

Create a CMake profile for each inner project using its `BINARY_DIR`, but such that reloading an
inner project uses appropriate commands on the SuperBuild.

I shouldn't be able to set CMake options on the inner project directly.

```shell
# Reload inner build
cmake -B <SUPERBUILD_BINARY_DIR>
cmake --build <SUPERBUILD_BINARY_DIR> -t <STAMP_DIR>/<name>-configure
# e.g. "cmake --build build -t inner-prefix/src/inner-stamp/inner-configure"

# Build inner target
cmake --build <BINARY_DIR> -t <target>
# e.g. "cmake --build build/inner-build -t sample"
```

Nice-to-have:

- ExternalProjects with `SOURCE_DIR` _not_ in the project source tree are "dependencies" and there
  is some mechanism to rebuild these. They shouldn't appear in "configurations" but in some other
  location instead.
- Not all dependencies can be built, for example if an ExternalProject downloads prebuilt
  binaries, but they could still be updated or patched.

```shell
# Rebuild dependency
cmake --build build -t <name>
# e.g. "cmake --build build -t fmt"
```
