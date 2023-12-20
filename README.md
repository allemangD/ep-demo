# ep-demo

This is a (very) minimal example of a SuperBuild project, which uses ExternalProject to build and
use a single dependency: `fmt`.

Note that many options often used in practice are omitted for brevity. I've mentioned some of the
relevant omissions here.

## Command-Line Usage

These are the minimal commands to _use_ the SuperBuild.

```shell
cmake -B build
cmake --build build
build/inner-build/sample
```

Output from `sample`:

```text
Using fmt 10.1.0 from /path/to/build/fmt-prefix/lib/cmake/fmt/fmt-config.cmake
```

## SuperBuild Explanation

### `cmake -B build`

This command just declares dependencies of projects. In it, `USE_SUPERBUILD` is ON,
so `SuperBuild.cmake` is executed and CMake returns early.

```cmake
if (USE_SUPERBUILD)
  include(SuperBuild.cmake)
  return()
endif ()
```

`SuperBuild.cmake` contains a build description our dependencies. For brevity I've
left all options for `fmt` default, but in practice we might disable `UPDATE_COMMAND`
or `INSTALL_COMMAND`, or set custom `BINARY_DIR`, or pass additional `CMAKE_ARGS`
`CMAKE_BUILD_TYPE`, etc.

```cmake
ExternalProject_Add(
    fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG 10.1.0
    GIT_PROGRESS ON
    CMAKE_CACHE_ARGS
    -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
)
```

Also note that an ExternalProject need not use CMake, for example a BOOST ExternalProject might use
custom commands. Again, details are omitted for brevity.

See https://gitlab.kitware.com/paraview/common-superbuild/-/blob/master/projects/boost.common.cmake.

```cmake
ExternalProject_Add(
    URL "https://www.paraview.org/files/dependencies/boost_1_83_0.tar.bz2"
    URL_MD5 406f0b870182b4eb17a23a9d8fce967d
    [...]
    CONFIGURE_COMMAND
      <SOURCE_DIR>/bootstrap.sh
        ${boost_bootstrap_toolset}
    BUILD_COMMAND
      <SOURCE_DIR>/b2
        ${boost_options}
        ${boost_platform_options}
        ${boost_extra_options}
    INSTALL_COMMAND
      <SOURCE_DIR>/b2
        ${boost_options}
        ${boost_platform_options}
        ${boost_extra_options}
        install
    [...]
)
```

Finally, `SuperBuild.cmake` contains a build description for `ep-demo`. Note that here I have
customized `SOURCE_DIR`, `BINARY_DIR`, and `INSTALL_COMMAND`.

```cmake
ExternalProject_Add(
    inner
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}
    BINARY_DIR "inner-build"
    INSTALL_COMMAND ""
    CMAKE_CACHE_ARGS
    -DUSE_SUPERBUILD:BOOL=OFF
    -DCMAKE_PREFIX_PATH:PATH=${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS fmt
)
```

I also set `CMAKE_PREFIX_PATH` - it is critical when the _inner_ project is
configured, `find_package(fmt)` locates the correct version. Sometimes we use other methods to do
this, for example I could have set `-Dfmt_ROOT:PATH="fmt-prefix"`
or `-Dfmt_DIR:PATH="fmt-prefix/lib/cmake/fmt"`.

In practice we often include an option like `USE_SYSTEM_fmt` which conditionally
invokes `find_package(fmt)` from the SuperBuild directly, and pass that location on to the inner
build. This way we can avoid building a large dependency if it's already installed.

The `inner-build/CMakeCache` will contain the information on which versions of which libraries are
to be used.

### `cmake --build build`

This command actually executes all the steps for each ExternalProject, in order set by `DEPENDS`. In
this example it's roughly equivalent to this (excluding unused steps like `download`).

```shell
cmake --build build --target fmt
cmake --build build --target inner
cmake --build build -t fmt
cmake --build build -t inner-prefix/src/inner-stamp/inner-configure
cmake --build build -t inner-prefix/src/inner-stamp/inner-build
```

_If_ the inner build has already been configured, then that last command is roughly equivalent
to `cmake --build build/inner-build`. This form is the only way to specify a target in the inner
build:

```shell
cmake --build build/inner-build
cmake --build build/inner-build -t sample ...
```

## CLion Workaround

The workaround I must use to work with CLion is:

1. Load the CMake project with any SuperBuild options (like `USE_SYSTEM_*` etc.)
2. Rename the generated profile to 'SuperBuild'
3. Build all in 'SuperBuild'
    - Note: VCS integration starts complaining about dependency source directories.
4. Create a new profile 'inner'.
    - Choose 'Generator: Let CMake Decide'
    - Choose `build/inner-build` directory (or whatever BINARY_DIR on the inner ExternalProject)
    - __CRITICAL:__ Disable 'SuperBuild' profile before enabling 'inner'.

After enabling 'inner', CLion correctly indexes the inner build directory and all dependencies. Code
actions work fine. Even editing _inner build_ CMake files is fine (e.g. changing target sources,
linkages, etc.). Things are good!

## CLion Issues

However, issues arise when modifying _SuperBuild_ CMake flies (e.g. changing ExternalProject
configurations, adding dependencies, changing steps, changing flags like `USE_SYSTEM_*`).

For example: downgrade fmt to `9.1.0`.

1. __CRITICAL:__ Disable the 'inner' profile and THEN enable the 'SuperBuild' profile.
2. Change `GIT_TAG` to `9.1.0` in `SuperBuild.cmake`
3. Reload CMake project
4. Build All in 'SuperBuild'
5. __CRITICAL:__ Disable the 'SuperBuild' profile and THEN enable the 'inner' profile.
6. Run 'sample'.

```text
Using fmt 9.1.0 from /path/to/build/fmt-prefix/lib/cmake/fmt/fmt-config.cmake
```

A mistake in this process can easily cause CLion to run inappropriate CMake commands and trash
CMakeCache, requiring a complete rebuild.

> Note: after assembling this guide, I think it may be possible to recover from that error by
> deleting the contents of the inner build and building the `inner-configure` target. This would
> require a rebuild of the inner project, but might avoid rebuilding dependencies.

## Ideal workflow

1. Load the CMake project with any SuperBuild options
2. CLion identifies ExternalProjects
    - "inner" projects have no download step and a `SOURCE_DIR` in the project tree.
    - Nice to have: multiple "inner" projects.
    - "dependencies" are other projects with `SOURCE_DIR` in the build tree.
    - Nice to have: understand `DEPENDS` arguments.
3. "Reload CMake" action configures the SuperBuild _and_ executes the Configure step on inner
   projects.
    - `cmake -B build ...`
    - `cmake --build build -t inner-prefix/src/inner-stamp/inner-configure` (use `STAMP_DIR`)
    - This automatically builds dependencies per `DEPENDS` arguments.
    - VCS probably shouldn't try to register dependency sources by default.
4. Show a "build" action for targets of inner projects.
    - `cmake --build build/inner-build -t sample`
    - These are the options when creating configurations.
5. Show a "build" action for dependencies.
    - `cmake --build build -t fmt`
    - Nice to have: These don't appear as "configurations" but in a new "dependencies" list or
      similar.

Ideal workflow for the same task, and the corresponding commands that CLion would execute:

1. Change `GIT_TAG` to `9.1.0` in `SuperBuild.cmake`
2. Reload CMake Project
    - `cmake -B build ...`
    - `cmake --build build -t inner-prefix/src/inner-stamp/inner-configure` (rebuilds fmt)
3. Run 'sample'
    - `cmake --build build/inner-build -t sample`
    - `build/inner-build/sample`
