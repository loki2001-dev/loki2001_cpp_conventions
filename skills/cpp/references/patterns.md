# C++ 패턴 예시

## 목차
1. 구현 파일 구조
2. 콜백 구조체와 람다
3. 인터페이스
4. 에러 처리
5. 로깅
6. RAII
7. libuv 비동기
8. std::thread
9. 테스트 함수
10. 주석

## 1. 구현 파일 구조

```cpp
#include "Application.h"

#include <cstring>

#include <chrono>
#include <iostream>
#include <thread>

#include <glfw3.h>
#include "imgui.h"

#include "window/GlfwWindowManager.h"
#include "ui/UiRenderer.h"
#include "ui/UiState.h"
#include "network/NetworkManager.h"
#include "util/log/Logger.h"

namespace {
constexpr int DEFAULT_WINDOW_WIDTH = 1920;
constexpr int DEFAULT_WINDOW_HEIGHT = 1080;
}  // namespace

Application::Application()
    : _running(false)
    , _pingSuccess(false)
    , _showPingPopup(false) {
}
```

## 2. 콜백 구조체와 람다

```cpp
struct network_callbacks {
    std::function<void()> onTcpConnected;
    std::function<void()> onTcpClosed;
    std::function<void(const char*, size_t)> onTcpDataReceived;
    std::function<void(const socket_error&)> onError;
    std::function<void(size_t)> onSendComplete;
};

void Application::setupNetworkCallbacks() {
    network_callbacks netCallbacks;

    netCallbacks.onTcpConnected = [this]() {
        LOG_INFO(tcp, net, "connected");
    };

    netCallbacks.onTcpDataReceived = [this](const char* data, size_t length) {
        std::string received(data, length);
        _uiState->commandResponseText += received;
    };

    _networkManager->setCallbacks(netCallbacks);
}
```

## 3. 인터페이스

```cpp
class ISocketCallback {
public:
    virtual ~ISocketCallback() = default;

    virtual void on_tcp_connected() = 0;
    virtual void on_tcp_closed() = 0;
    virtual void on_tcp_data_received(const char* data, size_t length) = 0;
    virtual void on_error(const socket_error& error) = 0;
    virtual void on_send_complete(size_t bytes) = 0;
};
```

## 4. 에러 처리

```cpp
struct socket_error {
    int code;
    std::string message;
};

bool Application::initialize() {
    if (!_windowManager->initialize()) {
        LOG_ERROR(app, life, "initialize failed target=window");
        return false;
    }
    return true;
}

void TcpSocket::close() {
    if (_state == socket_state::disconnected) {
        return;
    }
    set_state(socket_state::closing);
    uv_close(reinterpret_cast<uv_handle_t*>(&_socket), on_close);
}

void TcpSocket::notify_error(int code, const std::string& message) {
    if (_callback) {
        socket_error error{code, message};
        _callback->on_error(error);
    }
}
```

## 5. 로깅

```cpp
LOG_INFO(app, life, "initializing");
LOG_INFO(app, life, "initialized components={}/{}", startedCount, totalCount);
LOG_INFO(tcp, net, "connected peer={}:{}", ip, port);
LOG_WARN(hmi, cmd, "rejected reason=manual target=ramp");
LOG_WARN(bus, sys, "queue overflow dropped_total={}", droppedTotal);
LOG_ERROR(vms, prot, "dropped reason=length_ceiling length={} ceiling={}", length, ceiling);
```

- 첫 인수는 장치 태그, 둘째 인수는 분류 태그다 (`architecture` 스킬의 로그 규칙)
- 내용은 영어 소문자 동사구 뒤에 `key=value`를 붙인다
- 실패와 거절에는 `reason=`을 붙인다

## 6. RAII

```cpp
TcpSocket::~TcpSocket() {
    if (_initialized && _state != socket_state::disconnected) {
        close();
    }
}

Application::~Application() {
    shutdown();
}

void Application::shutdown() {
    if (_networkManager) {
        _networkManager->stop();
    }
    if (_uiRenderer) {
        _uiRenderer->shutdown();
    }
    if (_windowManager) {
        _windowManager->shutdown();
    }
}
```

버퍼는 `std::vector<char>`나 `std::unique_ptr<char[]>`로 소유하고, C API에는 `.data()`나 `.get()`으로 넘긴다.

```cpp
struct write_request {
    uv_write_t req;
    std::unique_ptr<char[]> data;
    TcpSocket* socket;
};
```

## 7. libuv 비동기

```cpp
void TcpSocket::on_connect(uv_connect_t* req, int status) {
    auto* tcpSocket = static_cast<TcpSocket*>(req->data);
    delete req;

    if (status < 0) {
        tcpSocket->set_state(socket_state::error_state);
        tcpSocket->notify_error(status, uv_strerror(status));
        return;
    }

    tcpSocket->set_state(socket_state::connected);
    if (tcpSocket->_callback) {
        tcpSocket->_callback->on_tcp_connected();
    }
}

bool TcpSocket::connect(const std::string& ip, int port) {
    sockaddr_in dest{};
    int result = uv_ip4_addr(ip.c_str(), port, &dest);
    if (result < 0) {
        notify_error(result, uv_strerror(result));
        return false;
    }
    auto* req = new uv_connect_t;
    req->data = this;
    result = uv_tcp_connect(req, &_socket, reinterpret_cast<const sockaddr*>(&dest), on_connect);
    if (result < 0) {
        delete req;
        notify_error(result, uv_strerror(result));
        return false;
    }
    return true;
}
```

## 8. std::thread

컴포넌트 코드에서 스레드를 직접 만들지 마라. 블로킹 호출은 전송 계층의 전용 스레드에서 실행하고, 결과는 `UvLoop::post()`로 루프에 돌려준다 (`architecture` 스킬의 `BlockingWorker` 예시).

```cpp
void VlmComponent::requestInference(const inference_request& request) {
    auto response = std::make_shared<inference_response>();
    const bool accepted = _worker.submit(
        [client = _client, request, response]() {
            *response = client->send(request);
        },
        [this, response]() {
            handleInferenceResult(*response);
        });
    if (!accepted) {
        LOG_WARN(vlm, sys, "rejected reason=queue_full");
    }
}
```

- 스레드 간 공유 플래그는 `std::atomic<bool>`로 선언한다
- 작업 스레드와 완료 콜백 사이의 결과는 `std::shared_ptr`로 공유한다. 지역 변수를 참조로 캡처하지 않는다
- 소유 객체를 파괴하기 전에 스레드를 조인한다

## 9. 테스트 함수

```cpp
constexpr int DEFAULT_TEST_TIMEOUT_MS = 5000;

void TDD_ensureDisconnected();
bool TDD_waitForTcpConnection(int timeoutMs = DEFAULT_TEST_TIMEOUT_MS);
bool TDD_waitForFullDisconnection(int timeoutMs = DEFAULT_TEST_TIMEOUT_MS);
void TDD_runConnectionTests(const std::string& tcpIp, int tcpPort,
                            const std::string& udpIp, int udpPort,
                            int repeatCounts);
```

형식: `TDD_{action}{Test}{Detail}`

## 10. 주석

```cpp
/**
 * @brief connect to the remote host
 * @param ip remote ip address
 * @param port remote port number
 * @return true on success, false on failure
 */
bool connect(const std::string& ip, int port);

class Application {
private:
    // callback
    void setupCallbacks();
    void setupNetworkCallbacks();

    // render
    void handleRender();

    // test helper
    void TDD_ensureDisconnected();
};
```
