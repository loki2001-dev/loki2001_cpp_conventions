---
name: cpp
description: C++ 작업에 소스 코드 작성 정책을 적용한다. .h, .cpp 파일을 작성하거나 수정하거나 리뷰할 때, 클래스나 인터페이스나 콜백을 설계할 때, 네이밍이나 include 순서나 코드 스타일이나 스마트 포인터나 에러 처리나 로깅을 다룰 때 반드시 사용한다.
---

### C++

#### 버전
- 프로젝트에서 명시한 C++ 표준을 따르라
- 명시가 없으면 C++17을 기준으로 삼아라

#### 네이밍

| 항목 | 형식 | 예시 |
| --- | --- | --- |
| 파일 | `PascalCase.{h,cpp}` | `TcpSocket.h`, `TcpSocket.cpp` |
| 클래스 | `PascalCase` | `NetworkManager` |
| 인터페이스 | `I` + `PascalCase` | `ISocket`, `ISocketCallback` |
| 멤버 변수 | `_camelCase` | `_windowManager`, `_running` |
| 함수, 메서드 | `camelCase` | `initialize()`, `handleRender()` |
| 로컬 변수, 매개변수 | `camelCase` | `netCallbacks`, `timeoutMs` |
| 상수 | `UPPER_SNAKE_CASE` | `MAX_BUFFER_SIZE` |
| 열거형과 열거자 | `snake_case` | `socket_state::error_state` |
| 구조체 | `snake_case` | `socket_error`, `address_info`, `actuator_command` |
| 타입 별칭 | `snake_case_t` | `error_handler_t` |
| 테스트 함수 | `TDD_` + `camelCase` | `TDD_waitForTcpConnection()` |

- 한 파일에는 하나의 주요 클래스만 둬라
- 헤더와 구현 파일의 이름을 일치시켜라
- 접근자와 통지 함수는 접두사 뒤를 `snake_case`로 이어라: `get_state()`, `set_callback()`, `notify_error()`, `on_tcp_connected()`
- 상태 확인 함수는 `camelCase`를 유지하라: `isConnected()`, `hasCallback()`
- 열거형에는 `enum class`만 사용하라
- 불변식이나 동작이 있는 타입은 `class`(`PascalCase`)로, 필드만 모은 값 타입(메시지, 상태, 설정)은 `struct`(`snake_case`)로 정의하라

#### 파일 구조
- 헤더 가드는 `#pragma once`를 사용하라
- 헤더는 다음 순서로 작성하라: 시스템 헤더, 외부 라이브러리 헤더, 프로젝트 헤더, 전방 선언, 타입 정의, 클래스 선언
- 구현 파일의 include는 다음 순서로 묶고 묶음 사이에 빈 행을 둬라
  1. 자신의 헤더
  2. C 시스템 헤더: `<cstring>`, `<cstdio>`
  3. C++ 시스템 헤더: `<iostream>`, `<memory>`
  4. 외부 라이브러리 헤더: `<uv.h>`, `<glfw3.h>`, `"imgui.h"`
  5. 프로젝트 헤더: 의존성 순서, 알파벳 순서로 정렬하지 마라
- 파일 내부 전용 상수와 함수는 익명 네임스페이스에 둬라
- 클래스 안에서는 `public`, `private` 순서로 두고, `private`은 메서드, 멤버 변수 순서로 둬라
- 소스는 계층별 디렉터리에 둬라: `src/app`, `src/component`, `src/control`, `src/core`, `src/codec`, `src/network`, `src/model`, `src/config`, `src/util` (`architecture` 스킬의 계층 규칙)
- 프로젝트 헤더는 `src` 기준 경로로 include하라: `"core/MessageBus.h"`

#### 코딩 스타일
- 4칸 공백으로 들여써라
- 여는 중괄호는 같은 행에 두어라 (K&R 변형)
- 접근 지정자는 `class`와 같은 열에 두어라
- 단일 구문도 중괄호로 감싸라
- 긴 조건은 연산자를 행 끝에 두고 줄바꿈하라
- `case`는 `switch`보다 한 단계 들여쓰고, 모든 `switch`에 `default`를 둬라
- 생성자에서는 멤버 초기화 리스트를 사용하고, 쉼표를 행 앞에 두어라
- 포인터와 참조 기호는 타입에 붙여라: `char* data`, `const std::string& ip`
- const correctness를 지켜라: 상태를 바꾸지 않는 멤버 함수는 `const`, 객체 매개변수는 `const&`
- `auto`는 타입이 캐스트로 드러나거나, 반복자처럼 복잡하거나, 람다일 때만 사용하라
- 포인터에 `auto`를 쓸 때는 `auto*`로 적어라
- 널 포인터는 `nullptr`로 표현하라

#### 소유권
- 단독 소유는 `std::unique_ptr`, 공유 소유는 `std::shared_ptr`, 순환 참조 방지는 `std::weak_ptr`로 표현하라
- 스마트 포인터는 `std::make_unique`, `std::make_shared`로 생성하라
- 원시 포인터는 소유하지 않는 참조와 libuv 콜백에서만 사용하라
- 바이트 버퍼는 포인터와 길이를 따로 넘기지 말고 `ByteView`로 넘겨라
- 자원은 생성자에서 획득하고 소멸자에서 해제하라 (RAII)
- 핸들, 스레드, 버퍼를 소유하는 클래스는 복사 생성자와 복사 대입을 `= delete`하라. 복사되면 같은 자원을 두 번 해제한다
- `ByteView`와 원시 포인터는 소유하지 않는다. 원본보다 오래 보관하지 말고, 임시 객체에서 만들어 반환하지 마라
- 반복 중인 컨테이너를 반복 안에서(콜백을 통해서도) 바꾸지 마라. 반복자가 무효화된다

#### 인터페이스와 콜백
- 인터페이스는 `virtual ~IName() = default;`와 순수 가상 함수만으로 정의하라
- 구현 클래스의 재정의에는 `override`를 붙여라
- 콜백은 `std::function` 멤버를 모은 콜백 구조체에 `[this]` 람다를 대입하는 방식으로 연결하라
- `std::function` 콜백은 호출 전에 비었는지 확인하라: `if (callbacks.onError) { callbacks.onError(error); }`
- 나중에 실행되는 람다(`post()`, 타이머, 전용 스레드, 버스 구독)는 대상 객체가 람다보다 오래 살 때만 `[this]`로 캡처하라. 보장할 수 없으면 `std::weak_ptr`로 캡처하고 `lock()`으로 확인하라
- 나중에 실행되는 람다에서 `[&]`와 지역 변수 참조 캡처를 사용하지 마라

#### 에러 처리와 로깅
- 성공과 실패는 `bool`로 반환하고, 실패 시 `LOG_ERROR`를 남긴 뒤 `false`를 반환하라
- 비동기 에러는 `notify_error(code, message)`로 콜백에 통지하라
- 전제 조건이 맞지 않으면 조기 반환하라
- 소멸자, `stop()`, `shutdown()`에서 예외를 던지지 마라
- 스레드 함수와 콜백(libuv, 전용 스레드 작업) 밖으로 예외를 내보내지 마라. 스레드에서 잡히지 않은 예외는 `std::terminate`로 프로세스를 끝내고, C 콜백을 통과하는 예외는 정의되지 않은 동작이다. 경계에서 잡아 `LOG_ERROR`로 기록하라
- 스마트 포인터는 `if (_ptr)`, 원시 포인터는 `if (ptr != nullptr)`로 확인하라
- 로그는 `LOG_DEBUG`, `LOG_INFO`, `LOG_WARN`, `LOG_ERROR`만 사용하고, 첫 두 인수로 장치 태그와 분류 태그를 넘겨라
- 로그 내용은 영어 소문자 동사구 뒤에 `key=value`로 값을 붙여라: `LOG_ERROR(vms, net, "connect failed code={} message={}", code, message)`
- 명령을 거절하거나 값을 버릴 때는 반드시 이유를 기록하라: `LOG_WARN(hmi, cmd, "rejected reason=out_of_range field=flag value={}", flag)`

#### 주석
- 한 줄 설명은 `//`, 여러 줄 설명은 `/* */`를 사용하라
- 공개 함수 문서는 `/** @brief @param @return */` 형식을 사용하라
- 클래스 안의 멤버 묶음은 영어 소문자 섹션 주석으로 구분하라: `// callback`, `// render`, `// test helper`

#### 금지 사항
- `NULL`과 `0`을 널 포인터로 사용하지 마라
- `new`와 `delete`를 직접 사용하지 마라 (예외: 아래 libuv 요청 객체)
- `malloc`과 `free`를 사용하지 마라
- C 스타일 캐스트를 사용하지 마라: `static_cast`, `reinterpret_cast`, `const_cast`를 사용하라
- 매직 넘버를 사용하지 마라: 이름 있는 `constexpr` 상수로 정의하라
- 전역 변수를 사용하지 마라
- `std::thread::detach()`를 사용하지 마라
- 락, 스레드 정지 순서, 자식 프로세스 규칙은 `architecture` 스킬의 "동기화와 수명", "프로세스와 비정상 종료"를 따르라

#### libuv 예외
- libuv 요청 객체(`uv_connect_t`, `uv_write_t` 등)는 C API에 넘겨야 하므로 `new`로 생성할 수 있다
- 이 객체는 반드시 완료 콜백의 첫머리에서 `delete`하라
- libuv 콜백은 `static` 함수로 정의하고 `data` 필드에서 `static_cast`로 객체를 복원하라
- libuv 핸들(`uv_tcp_t`, `uv_timer_t` 등)과 그 핸들을 담은 객체의 메모리는 `uv_close` 완료 콜백이 불린 뒤에만 해제하라. `uv_close` 직후에 해제하면 루프가 해제된 메모리를 읽는다

#### 상세 예시
- 콜백, 인터페이스, 에러 통지, 로깅, RAII, libuv, 스레드, 테스트 함수의 전체 예시는 `references/patterns.md`를 읽어라
- 컴포넌트 구조는 `cbd` 스킬, 스레드와 큐와 프레임 검사와 설정은 `architecture` 스킬, 시험은 `testing` 스킬을 함께 적용하라

#### 검사
- 프로젝트에 설정 파일이 없으면 이 스킬의 `assets/.clang-format`과 `assets/.clang-tidy`를 프로젝트 루트에 복사하라
- 다음 검사를 통과하라

```bash
clang-format --dry-run --Werror $(git ls-files '*.cpp' '*.h')
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
clang-tidy -p build $(git ls-files '*.cpp')
cmake --build build
```

- `clang-tidy`가 검사하지 못하는 항목(메서드 이름, 구조체 이름, include 묶음 순서)은 직접 확인하라

#### 기준 형태

```cpp
#pragma once

#include <memory>
#include <string>

#include <uv.h>

#include "model/ByteView.h"
#include "network/ISocket.h"
#include "network/ISocketCallback.h"

class TcpSocket : public ISocket {
public:
    explicit TcpSocket(uv_loop_t* loop);
    ~TcpSocket() override;

    bool connect(const std::string& ip, int port) override;
    void close() override;
    bool isConnected() const override;
    socket_state get_state() const override;
    void set_callback(std::shared_ptr<ISocketCallback> callback) override;

private:
    // libuv callback
    static void on_connect(uv_connect_t* req, int status);
    static void on_close(uv_handle_t* handle);

    // state
    void set_state(socket_state newState);
    void notify_error(int code, const std::string& message);

    uv_loop_t* _loop;
    uv_tcp_t _socket;
    std::shared_ptr<ISocketCallback> _callback;
    socket_state _state;
    bool _initialized;
};
```
