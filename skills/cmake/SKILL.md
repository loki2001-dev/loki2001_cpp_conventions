---
name: cmake
description: CMake 작업에 빌드 컨벤션을 적용한다. CMakeLists.txt나 .cmake 파일이나 빌드 스크립트를 작성하거나 수정할 때, 타깃이나 의존 라이브러리나 컴파일 옵션이나 시험 타깃이나 새니타이저 구성을 추가할 때 반드시 사용한다.
---

### CMake
- 버전: `cmake_minimum_required(VERSION 3.16)`
- 생성기는 Ninja, 기본 구성은 `Release`를 사용하라
- 소스 디렉터리 밖에서 빌드하라: `build/`
- 타깃 기반 명령만 사용하라: `target_include_directories`, `target_link_libraries`, `target_compile_options`
- 전역 명령을 사용하지 마라: `include_directories`, `link_libraries`, `add_definitions`
- 프로젝트 헤더를 `"core/MessageBus.h"`처럼 `src` 기준 경로로 include할 수 있도록 `src`를 include 경로로 지정하라
- 소스 파일을 `file(GLOB ...)`로 수집하지 말고 명시적으로 나열하라
- 공개 의존성은 `PUBLIC`, 내부 의존성은 `PRIVATE`으로 구분하라
- 경고는 오류로 취급하라: MSVC `/W4 /WX`, GCC와 Clang `-Wall -Wextra -Wpedantic -Werror`
- MSVC에서는 소스를 `/utf-8`로 컴파일하라
- 서드파티 라이브러리는 `3rdparty/`에 버전을 고정해서 커밋하라. 패키지 관리자에 의존하지 마라
- 서드파티 헤더는 `SYSTEM`으로 추가해서 경고 정책이 서드파티 코드에 걸리지 않게 하라
- 시험 타깃(Catch2)은 별도 실행 파일로 만들고 배포 산출물에 포함하지 마라
- `compile_commands.json`을 생성하라
- 헤더를 고친 뒤 증분 빌드 결과가 의심되면 다시 빌드하라. 헤더 의존성이 기록되지 않으면 오래된 오브젝트가 링크된다
- 다음 형태를 기준으로 삼아라

```cmake
cmake_minimum_required(VERSION 3.16)
project(st1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(PROJECT_WARNINGS
  $<$<CXX_COMPILER_ID:MSVC>:/W4 /WX /utf-8>
  $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic -Werror>
)

add_library(st1_core STATIC
  src/core/UvLoop.cpp
  src/core/MessageBus.cpp
  src/component/VmsComponent.cpp
  src/app/Application.cpp
)
target_include_directories(st1_core PUBLIC src)
target_include_directories(st1_core SYSTEM PUBLIC 3rdparty/libuv/include)
target_link_libraries(st1_core PUBLIC uv_a)
target_compile_options(st1_core PRIVATE ${PROJECT_WARNINGS})

add_executable(st1 src/app/main.cpp)
target_link_libraries(st1 PRIVATE st1_core)
target_compile_options(st1 PRIVATE ${PROJECT_WARNINGS})

add_executable(st1_tests
  tests/FrameReaderTest.cpp
  tests/BoundedQueueTest.cpp
)
target_link_libraries(st1_tests PRIVATE st1_core Catch2::Catch2WithMain)
target_compile_options(st1_tests PRIVATE ${PROJECT_WARNINGS})
```

### 새니타이저
- 메모리 오류(SIGSEGV, use-after-free, 이중 해제)와 데이터 경쟁, 교착을 잡기 위해 새니타이저 구성을 둬라
- `PROJECT_SANITIZER` 캐시 변수로 고르고, 모든 타깃에 타깃 기반 명령으로 붙여라
  - `address`: AddressSanitizer + UndefinedBehaviorSanitizer
  - `thread`: ThreadSanitizer. `address`와 함께 쓸 수 없으므로 빌드 디렉터리를 따로 둬라
- GCC와 Clang에서 사용하라. MSVC는 `/fsanitize=address`만 지원한다
- 배포 산출물은 새니타이저 없이 `Release`로 빌드하라
- 새니타이저 경고는 억제하지 말고 고쳐라. 서드파티 코드에서 나는 경고만 억제 파일에 이유와 함께 등록하라

```cmake
set(PROJECT_SANITIZER "" CACHE STRING "empty, address or thread")

set(PROJECT_SANITIZER_FLAGS)
if(PROJECT_SANITIZER STREQUAL "address")
  set(PROJECT_SANITIZER_FLAGS -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
elseif(PROJECT_SANITIZER STREQUAL "thread")
  set(PROJECT_SANITIZER_FLAGS -fsanitize=thread -fno-omit-frame-pointer)
elseif(NOT PROJECT_SANITIZER STREQUAL "")
  message(FATAL_ERROR "unknown PROJECT_SANITIZER=${PROJECT_SANITIZER}")
endif()

target_compile_options(st1_core PRIVATE ${PROJECT_SANITIZER_FLAGS})
foreach(target st1 st1_tests)
  target_compile_options(${target} PRIVATE ${PROJECT_SANITIZER_FLAGS})
  target_link_options(${target} PRIVATE ${PROJECT_SANITIZER_FLAGS})
endforeach()
```

```bash
cmake -S . -B build-asan -G Ninja -DCMAKE_BUILD_TYPE=Debug -DPROJECT_SANITIZER=address
cmake --build build-asan
ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 ./build-asan/st1_tests

cmake -S . -B build-tsan -G Ninja -DCMAKE_BUILD_TYPE=Debug -DPROJECT_SANITIZER=thread
cmake --build build-tsan
TSAN_OPTIONS=halt_on_error=1 ./build-tsan/st1_tests
```
