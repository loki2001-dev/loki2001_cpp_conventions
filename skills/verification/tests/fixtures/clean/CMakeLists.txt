cmake_minimum_required(VERSION 3.16)
project(good VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(PROJECT_WARNINGS
  $<$<CXX_COMPILER_ID:MSVC>:/W4 /WX /utf-8>
  $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic -Werror>
)

file(GLOB ICONS assets/*.png)
add_library(good_core STATIC src/codec/Codec.cpp src/core/Queues.cpp)
target_include_directories(good_core PUBLIC src)
target_include_directories(good_core SYSTEM PUBLIC 3rdparty/libuv/include)
target_compile_options(good_core PRIVATE ${PROJECT_WARNINGS})

add_executable(good_tests tests/QueuesTest.cpp)
target_link_libraries(good_tests PRIVATE good_core)
target_compile_options(good_tests PRIVATE ${PROJECT_WARNINGS})

enable_testing()
add_test(NAME good_tests COMMAND good_tests)
