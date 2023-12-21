include(ExternalProject)

if (NOT USE_SYSTEM_fmt)
  ExternalProject_Add(
      fmt
      GIT_REPOSITORY https://github.com/fmtlib/fmt.git
      GIT_TAG 10.1.0
      GIT_PROGRESS ON
      INSTALL_COMMAND ""
  )

  ExternalProject_Get_Property(fmt BINARY_DIR)
  set(fmt_DIR ${BINARY_DIR})
else ()
  ExternalProject_Add(
      fmt
      DOWNLOAD_COMMAND ""
      CONFIGURE_COMMAND ""
      BUILD_COMMAND ""
      INSTALL_COMMAND ""
  )

  unset(fmt_DIR CACHE)
  find_package(fmt REQUIRED)
endif ()

ExternalProject_Add(
    inner
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}
    BINARY_DIR "inner-build"
    INSTALL_COMMAND ""
    CMAKE_CACHE_ARGS
    -DUSE_SUPERBUILD:BOOL=OFF
    -Dfmt_DIR:PATH=${fmt_DIR}
    DEPENDS fmt
)
