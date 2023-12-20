include(ExternalProject)

ExternalProject_Add(
    fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG 10.1.0
    GIT_PROGRESS ON
    CMAKE_CACHE_ARGS
    -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
)

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
