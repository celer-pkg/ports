cmake_minimum_required(VERSION 3.5)
project(gperf LANGUAGES C CXX)

include(CheckCXXSourceCompiles)
include(GNUInstallDirs)

CHECK_CXX_SOURCE_COMPILES("int main(int n) { int dynamic_array[n]; }" HAVE_DYNAMIC_ARRAY)

file(GLOB LIBGP_SOURCES "lib/*.cc" "lib/*.c" "lib/*.h" )

add_library(gp STATIC ${LIBGP_SOURCES})
target_include_directories(gp PUBLIC "${CMAKE_SOURCE_DIR}/lib")

file(GLOB GPERF_SOURCES "src/*.cc" "src/*.c" "src/*.h" )
add_executable(gperf ${GPERF_SOURCES})
target_link_libraries(gperf gp)
target_include_directories(gperf PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

configure_file(config.h.in config.h @ONLY)

install(TARGETS gperf RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
