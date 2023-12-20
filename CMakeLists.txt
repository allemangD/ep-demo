cmake_minimum_required(VERSION 3.28)
project(ep-demo)

option(USE_SUPERBUILD "Build ${PROJECT_NAME} and its dependencies." ON)

if (USE_SUPERBUILD)
  include(SuperBuild.cmake)
  return()
endif ()

find_package(fmt REQUIRED)

add_executable(sample sample.cpp)
target_link_libraries(sample fmt::fmt)

# Pass fmt information through to binary.
target_compile_definitions(sample PRIVATE
    fmt_VERSION="${fmt_VERSION}"
    fmt_CONFIG="${fmt_CONFIG}"
)
