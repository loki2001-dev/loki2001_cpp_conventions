cmake_minimum_required(VERSION 3.10)
project(bad LANGUAGES CXX)

file(GLOB_RECURSE SOURCES src/*.cpp)
file(GLOB ASSETS assets/*.png)
include_directories(src)
Add_Definitions(-DFOO)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")
target_include_directories(bad PUBLIC
  src
  3rdparty/libuv/include)
target_compile_options(bad PRIVATE -Wall -Wextra)
add_executable(bad_tests tests/A.cpp)
add_executable(unit_test tests/B.cpp)  # NOVERIFY(CMAKE-TEST-REGISTER) runs through the simulation script
add_test(NAME other COMMAND other)
# include_directories(commented)
message(STATUS "include_directories( in a string")
