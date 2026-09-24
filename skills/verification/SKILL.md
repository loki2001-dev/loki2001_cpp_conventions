---
name: verification
description: 구현을 마친 뒤 기존 규약(clang-format, CMake, 커밋 메시지, P1, P2, P3, P5)을 자동으로 검증하고 위반을 고친다. C++ 코드나 CMake 파일을 작성하거나 고친 뒤, 커밋하기 전에, 구현 완료를 보고하기 전에 반드시 사용한다.
---

# 자동 검증

이 스킬은 새 규칙을 만들지 않는다. `cpp`, `cmake`, `architecture`, `testing` 스킬과 `AGENTS.md`의 규칙 중 기계로 판정할 수 있는 부분만 검사한다. 검사는 오탐을 줄이려고 명백한 패턴만 잡는다. 검사를 통과했다고 규칙을 지킨 것이 증명되지는 않는다. 설계 판단은 여전히 에이전트와 사람의 몫이다.

## 실행

현재 작업 공간이 아니라 이 `SKILL.md`와 같은 디렉터리의 `scripts/verify.sh`를 프로젝트 루트에 대해 실행한다.

```bash
scripts/verify.sh /path/to/project
scripts/verify.sh --only p2,p3 /path/to/project
scripts/verify.sh --skip tidy --range origin/main..HEAD /path/to/project
```

| 항목 | 내용 |
| --- | --- |
| 검사 | `format`, `cmake`, `commit`, `conventions`, `tidy`, `p1`, `p2`, `p3`, `p5` (개별 실행: `scripts/check_{name}.sh`) |
| 출력 | `path:line: [RULE-ID] reason. fix: direction` 한 줄에 위반 하나, 검사마다 `name: pass` 또는 `name: N violation(s)` |
| 종료 코드 | 0 통과(건너뛴 검사 포함), 1 위반, 2 인수나 도구 오류 |
| 환경 변수 | `VERIFY_LOOP_DIRS`(루프 스레드 디렉터리), `VERIFY_BUILD_DIR`(`compile_commands.json` 위치), `CLANG_FORMAT`, `CLANG_TIDY` |
| 필요 도구 | bash, POSIX awk, git. `format`은 clang-format, `tidy`는 clang-tidy와 구성된 빌드 |

## 작업 절차

1. 구현을 마치면 `verify.sh`를 실행하라
2. 출력의 `fix:` 방향대로 해당 파일과 줄을 고쳐라
3. 다시 실행해서 `verify: pass`가 나올 때까지 반복하라
4. 오탐이라고 판단하면 해당 줄에 `NOVERIFY` 표식을 이유와 함께 달고, 결과 보고에 오탐으로 적어라
5. 원칙을 실제로 어겨야 한다면 `NOVERIFY`가 아니라 `architecture` 스킬의 원칙 예외 절차(`EX-P{n}-{nnn}`)를 따라라
6. `skipped`로 나온 검사는 통과가 아니다. 결과 보고에 검증하지 못한 항목으로 적어라
7. 이미 푸시한 커밋의 메시지 위반은 히스토리를 고치지 말고 보고만 하라

## 검사 범위와 억제 표식

- 모든 검사에서 제외: `3rdparty/`, `third_party/`, `build*/`, `fixtures/`
- `p3`, `p5`는 제품 코드만 검사한다: `tests/`, `test/`, `simulation/` 제외
- `p1`, `p2`는 루프 스레드 코드만 검사한다: `VERIFY_LOOP_DIRS`, 기본값 `src/component src/control src/codec` (`architecture` 스킬의 계층). 블로킹이 허용되는 `src/network`, `src/core`는 검사하지 않는다

| 표식 | 의미 | 조건 |
| --- | --- | --- |
| `// exception: EX-P2-001 vendor sdk has no async connect` | 승인된 원칙 예외 | ID가 설계 문서의 원칙 예외 표에 있어야 한다 (`conventions` 검사가 대조) |
| `// NOVERIFY(P3-UNCHECKED) length checked by the caller in Link::onFrame` | 검사기의 오탐 | 규칙 ID나 원칙(`P3`)과 이유가 모두 있어야 한다. 이유가 없으면 억제되지 않는다 |

표식은 같은 줄이나 바로 위의 주석만 있는 줄에 둔다.

## format

- **Rule**: 모든 C++ 파일은 프로젝트 루트의 `.clang-format`(`cpp` 스킬의 `assets/.clang-format`)을 따른다
- **Detection**: 파일마다 `clang-format --dry-run --Werror --style=file`을 실행한다. 파일마다 어긋난 줄을 최대 다섯 개 보고한다
- **Allowed exceptions**: `// clang-format off`와 `// clang-format on` 사이
- **Failure message**: `path:line: [FORMAT] code is not clang-formatted`, `.clang-format:1: [FORMAT-CONFIG] the project has no .clang-format`
- **How to fix**: `clang-format -i path`를 실행한다. 설정 파일이 없으면 `cpp` 스킬의 파일을 루트에 복사한다

## cmake

- **Rule**: `cmake` 스킬의 규칙. 타깃 기반 명령만 사용하고, 소스를 명시적으로 나열하고, 경고를 오류로 다루고, `compile_commands.json`을 만들고, 시험을 `ctest`에 등록하고, 소스 디렉터리 밖에서 빌드한다
- **Detection**: `CMakeLists.txt`와 `*.cmake`의 명령을 주석과 줄바꿈을 걷어낸 뒤 명령 단위로 판정한다. 명령 이름의 대소문자는 가리지 않는다

| ID | 검출 |
| --- | --- |
| `CMAKE-GLOB` | `file(GLOB` 또는 `GLOB_RECURSE` 패턴에 C/C++ 확장자나 `src/`, `tests/`가 있다 |
| `CMAKE-GLOBAL-COMMAND` | `include_directories`, `link_libraries`, `link_directories`, `add_definitions`, `add_compile_definitions`, `add_compile_options`, `add_link_options` |
| `CMAKE-GLOBAL-FLAGS` | `set`, `string(APPEND)`, `list(APPEND)`로 `CMAKE_C_FLAGS*`, `CMAKE_CXX_FLAGS*`, `CMAKE_*_LINKER_FLAGS*`를 바꾼다 |
| `CMAKE-3RDPARTY-SYSTEM` | `target_include_directories`에 `3rdparty` 경로가 있는데 `SYSTEM`이 없다 |
| `CMAKE-MIN-VERSION` | 루트 `CMakeLists.txt`에 `cmake_minimum_required`가 없거나 3.16보다 낮다 |
| `CMAKE-COMPILE-COMMANDS` | `set(CMAKE_EXPORT_COMPILE_COMMANDS ON)`도 `CMakePresets.json`의 설정도 없다 |
| `CMAKE-WARNINGS` | `-Wall -Wextra -Wpedantic -Werror` 중 하나가 없다. `MSVC`를 언급하는 프로젝트는 `/W4 /WX /utf-8`도 본다 |
| `CMAKE-TEST-REGISTER` | 이름에 `test`나 `tests`가 들어간 `add_executable` 타깃이 `add_test`에 없다 |
| `CMAKE-ENABLE-TESTING` | `add_test`가 있는데 `enable_testing()`이나 `include(CTest)`가 없다 |
| `CMAKE-IN-SOURCE` | 프로젝트 루트에 `CMakeCache.txt`나 `CMakeFiles/`가 있다 |

- **Allowed exceptions**: 에셋처럼 소스가 아닌 파일의 `file(GLOB)`. 파일 이름에 `toolchain`이 들어간 파일의 전역 명령과 전역 플래그. `NOVERIFY(CMAKE-...)` 표식
- **Failure message**: `CMakeLists.txt:6: [CMAKE-GLOBAL-COMMAND] include_directories() changes every target in the directory`
- **How to fix**: 메시지의 `fix:`를 따른다. 기준 형태는 `cmake` 스킬의 예시다. 경고 플래그는 `PROJECT_WARNINGS` 목록을 `target_compile_options`로 붙인다

## commit

- **Rule**: 커밋 제목은 `add:`, `fix:`, `refactor:`, `docs:`, `test:`로 시작하고 영문 소문자로 쓴다. 호환을 깨는 변경은 `add!:`처럼 `!`를 붙인다 (`AGENTS.md`의 형상 지침)
- **Detection**: 기본 범위는 아직 푸시하지 않은 커밋(`@{upstream}..HEAD`)이다. upstream이 없으면 모든 커밋을 본다. `--range`, `--all`, `--message-file`(commit-msg 훅)로 바꿀 수 있다. 제목에 영문 대문자나 ASCII가 아닌 문자가 있으면 위반이다. 본문은 검사하지 않는다
- **Allowed exceptions**: 병합 커밋, git이 만든 `Revert "..."`, 호스팅 서비스가 만든 루트 커밋 `Initial commit`, `fixup!`과 `squash!` 접두사(뒤의 제목은 검사한다)
- **Failure message**: `commit 1a2b3c4: [COMMIT-PREFIX] subject "Update readme" does not start with add:, fix:, refactor:, docs: or test:`, `[COMMIT-CASE] subject "docs: Update readme" is not lowercase english`
- **How to fix**: 마지막 커밋은 `git commit --amend`, 그 이전의 푸시하지 않은 커밋은 `git rebase -i`로 제목을 고친다. 커밋을 논리 단위로 나눴는지는 검사하지 않으므로 직접 확인한다

## conventions

- **Rule**: `cpp` 스킬의 규약 중 clang-tidy가 보지 못하는 것과 `architecture` 스킬의 원칙 예외 표
- **Detection**: `cpp` 스킬의 `scripts/check`를 실행한다: `#pragma once`, 자기 헤더 우선, include 묶음 순서, `detach()`, 이유 없는 `NOLINT`, 설계 문서에 없는 `EX-P{n}-{nnn}` 표식
- **Allowed exceptions**: 없음. 억제 자체를 검사하는 단계다
- **Failure message**: `src/network/TcpSocket.cpp:3: system or external header after project header: vector`
- **How to fix**: `cpp` 스킬의 파일 구조 규칙을 따르고, 예외 표식은 설계 문서의 원칙 예외 표에 먼저 올린다

## tidy

- **Rule**: `cpp` 스킬의 `.clang-tidy`: 네이밍, 금지 사항, `clang-analyzer-*`
- **Detection**: `compile_commands.json`이 `VERIFY_BUILD_DIR`, `build/`, 루트 중 한 곳에 있고 clang-tidy가 설치되어 있으면 `.cpp` 파일마다 실행한다. 둘 중 하나라도 없으면 `skipped`다
- **Allowed exceptions**: 검사 이름과 이유를 적은 `NOLINT(check-name) reason`
- **Failure message**: clang-tidy의 `path:line:column: error: ... [check-name]` 뒤에 `fix:`를 붙인다
- **How to fix**: `cmake -S . -B build -G Ninja`로 구성한 뒤 다시 실행하고, 이름과 금지 사항을 `cpp` 스킬에 맞춘다

## p1

- **Rule**: P1. 컴포넌트 코드는 하나의 루프 스레드에서만 실행한다. 이 검사는 P1을 증명하지 않고, 명백한 위반만 잡는다
- **Detection**: 루프 스레드 코드에서 다음을 찾는다

| ID | 검출 |
| --- | --- |
| `P1-THREAD` | `std::thread`, `std::jthread`, `std::async`, `pthread_create`, `CreateThread`, `_beginthreadex` |
| `P1-LOCK` | `std::mutex`, `std::lock_guard`, `std::unique_lock`, `std::scoped_lock`, `std::shared_mutex`, `std::condition_variable` 등. `architecture` 스킬: 컴포넌트 코드에는 락을 두지 마라 |
| `P1-WORKER-CAPTURE` | `submit(blockingCall, onDone)`의 첫 람다(작업 스레드에서 실행)가 `this`, `*this`, `&`, `=`, `&name`을 캡처한다 |
| `P1-WORKER-STATE` | 첫 람다 본문에서 `_member`에 대입하거나 `this->`를 쓴다 |

- **Allowed exceptions**: `std::thread::id`, `std::this_thread::get_id`, `std::atomic`. 두 번째 람다(`onDone`, 루프 스레드에서 실행)의 모든 코드. `EX-P1-...` 표식
- **Failure message**: `src/component/VlmComponent.cpp:42: [P1-WORKER-CAPTURE] the blocking lambda passed to submit runs on the worker thread but captures this`
- **How to fix**: 블로킹 작업은 `src/network`의 `BlockingWorker`에 넘기고, 첫 람다는 값이나 `shared_ptr`만 캡처하며, 상태 변경은 `onDone`에서 한다 (`cpp` 스킬 `references/patterns.md` §8)

## p2

- **Rule**: P2. 블로킹 호출은 전용 스레드에서만 한다. 루프 스레드 코드에서 명백한 블로킹 호출을 잡는다
- **Detection**: 주석과 문자열을 걷어낸 코드에서 다음을 찾는다. `submit()`의 첫 람다 본문은 작업 스레드이므로 건너뛴다

| ID | 검출 |
| --- | --- |
| `P2-SLEEP` | `this_thread::sleep_for`, `sleep_until`, `sleep`, `usleep`, `nanosleep`, `Sleep` |
| `P2-WAIT` | `.wait(`, `.wait_for(`, `.wait_until(`, `std::future` 변수의 `.get()` |
| `P2-SOCKET` | 전역 이름공간 호출 `::connect`, `::accept`, `::recv`, `::read`, `::write`, `::send`, `::select`, `::poll` 등 |
| `P2-DNS` | `getaddrinfo`, `gethostbyname` (`uv_getaddrinfo`는 허용) |
| `P2-PROCESS` | `system`, `popen`, `pclose`, `WNOHANG` 없는 `waitpid` |
| `P2-STDIN` | `std::cin` |
| `P2-LOOP-RUN` | `uv_run` |
| `P2-SYNC-FS` | 콜백 자리에 `nullptr`나 `NULL`을 넘긴 `uv_fs_*` |
| `P2-SYNC-API` | `MQTTClient_connect`, `MQTTClient_publish`, `MQTTClient_waitForCompletion`, `curl_easy_perform`, `lws_service` 등 `architecture` 스킬이 전용 스레드 대상으로 적은 동기 API |

- **Allowed exceptions**: 멤버 호출(`_socket->connect(`, `reader.read(`)과 같은 이름의 멤버 함수 정의. `system_clock` 같은 식별자 일부. 작업 스레드 람다. `src/network`와 `src/core`. `EX-P2-...` 표식
- **Failure message**: `src/component/HmiComponent.cpp:88: [P2-SLEEP] sleep blocks the loop thread`
- **How to fix**: 지연은 `UvTimer`로, 블로킹 호출은 `BlockingWorker::submit`이나 `src/network`의 전용 스레드로 옮기고 결과는 `UvLoop::post`로 돌려받는다

## p3

- **Rule**: P3. 외부에서 온 길이, 개수, 인덱스, 오프셋은 버퍼 경계로 쓰기 전에 범위를 검사한다. 고정 오프셋으로 외부 버퍼를 직접 읽지 않는다
- **Detection**: 함수마다 외부 값을 추적한다
  - 외부 값: 리더 호출의 출력 인수(`reader.readU16Be(length)`), 바이트 순서 변환 결과(`ntohs` 등), 외부 버퍼에서 읽은 값(`data[3]`, `(data[1] << 8) | data[2]`), 외부 값으로 계산한 값(`offset + length`)
  - 외부 버퍼: `uint8_t*`, `unsigned char*`, `std::byte*` 매개변수, `data`나 `buf`처럼 이름 붙은 `char*` 매개변수, `get_data()`, libuv `buf->base`
  - 검사로 인정: 비교 연산자, `if`나 `while` 조건에 등장, `std::min`, `std::max`, `std::clamp`, `.at()`. `for` 헤더의 반복 상한은 검사가 아니다

| ID | 검출 |
| --- | --- |
| `P3-UNCHECKED` | 검사하지 않은 외부 값이 첨자, `memcpy`/`memmove`/`memset`/`strncpy`/`copy_n`, `ByteView` 생성, `resize`/`reserve`, `new[]`에 쓰인다. 검사하지 않은 개수까지 도는 반복 변수로 첨자를 쓰는 경우도 포함한다 |
| `P3-FIXED-OFFSET` | 크기 비교가 한 번도 없는 함수에서 외부 버퍼를 숫자나 상수 오프셋으로 읽는다 |

- **Allowed exceptions**: `std::map`, `std::unordered_map`으로 선언된 이름의 첨자. 람다 캡처 목록과 속성(`[[...]]`). 같은 줄에서 먼저 비교하는 경우(`if (index < COUNT && table[index])`). 내부 데이터(루프 상수, 컨테이너 자신의 `size()`). `EX-P3-...` 표식
- **Failure message**: `src/codec/PerceptionCodec.cpp:57: [P3-UNCHECKED] external value length (read at line 49) is used as a buffer bound without a range check`
- **How to fix**: 길이 상한 상수나 남은 길이와 비교하고 벗어나면 프레임을 버리고 기록한다. 가능하면 `FrameReader`와 `readBytes`로 읽는다 (`architecture` 스킬의 프레임과 값 검사)

## p5

- **Rule**: P5. 비동기 큐와 멤버 큐에는 상한과 넘침 정책이 있고, 버림은 기록한다
- **Detection**: 헤더와 구현 파일을 한 쌍으로 묶어 본다

| ID | 검출 |
| --- | --- |
| `P5-UNBOUNDED` | `_name` 멤버로 선언된 `std::queue`, `std::deque`, `std::priority_queue`인데 `_name.size()`를 무엇과도 비교하지 않는다 |
| `P5-PUSH-IGNORED` | `BoundedQueue` 멤버의 `push` 결과를 버린다(문장이 `_queue.push(`로 시작하거나 `(void)`로 버린다) |
| `P5-DROP-NOT-LOGGED` | `overflow_policy::drop_oldest`로 만든 큐의 `push` 문장이 끝난 뒤 다섯 줄 안에 `LOG_WARN`이나 `LOG_ERROR`가 없다 |

- **Allowed exceptions**: 지역 변수와 매개변수(임시 컨테이너). `_items.size() < _capacity`처럼 크기를 비교하는 멤버(직접 만든 상한 큐, 크기 제한 이력 버퍼). `reject` 큐의 결과를 호출자에게 돌려주는 경우(`return _queue.push(...)` 포함). `EX-P5-...` 표식
- **Failure message**: `src/core/Queues.h:12: [P5-UNBOUNDED] member queue _tasks (std::queue) has no capacity check`
- **How to fix**: `BoundedQueue<T>(capacity, overflow_policy::...)`를 사용하고, 결과가 `push_result::accepted`가 아니면 `LOG_WARN`으로 누적 버림 수를 남기거나 호출자에게 거절을 알린다 (`architecture` 스킬의 큐 규칙)

## 자동 검증하지 않는 것

다음은 검사하지 않는다. 설계 검토와 결과 보고에서 직접 확인하라.

- 커밋이 논리 단위로 나뉘었는지
- P1 전체(공유 상태 경로, `UvLoop::post` 외의 스레드 경계), P4(실패 응답과 거절 이유)
- 부호 없는 뺄셈 전의 크기 확인, 구조체 필드로 전달된 외부 값, 람다 매개변수와 여러 줄 함수 선언의 버퍼 매개변수
- `std::vector`나 `std::list`로 만든 작업 목록(예: `UvLoop`의 `_pending`), 구조체 필드 큐
- 생성기(Ninja)와 기본 구성(`Release`), `PUBLIC`과 `PRIVATE` 구분, 타깃마다 경고 목록을 붙였는지
- 시간 계약, 보안 규칙, 인터페이스 변경 규칙

## 시험

```bash
tests/test
```

`tests/fixtures/violations`는 규칙마다 위반을 담고, 출력은 `tests/expected/violations.txt`와 한 글자도 달라서는 안 된다. `tests/fixtures/clean`은 허용 예외를 담고 통과해야 한다. 스킬 문서의 모든 코드 예제(`tests/extract-examples`)도 통과해야 한다. 검사를 바꾸면 세 가지를 모두 확인하라.
