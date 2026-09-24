# 아키텍처 패턴 예시

모든 예시는 `cpp` 스킬 규약으로 작성했고 C++17, `-Wall -Wextra -Wpedantic -Werror`, 동봉한 `.clang-format`, `.clang-tidy`를 통과한다. 프로젝트에 같은 역할의 클래스가 이미 있으면 그것을 사용하라.

## 목차
1. UvLoop: 루프 소유와 스레드 경계
2. BlockingWorker: 블로킹 호출 격리
3. BoundedQueue: 상한 있는 큐
4. MessageBus: 타입 기반 발행 구독
5. StateSlot: 불변 스냅숏 상태
6. ByteView, FrameReader: 경계 검사
7. 로그 태그

## 1. UvLoop: 루프 소유와 스레드 경계

`post()`가 다른 스레드에서 루프 스레드로 들어오는 유일한 통로다.

`src/core/UvLoop.h`

```cpp
#pragma once

#include <functional>
#include <mutex>
#include <vector>

#include <uv.h>

// owns the libuv loop. post() is the only cross-thread channel into the loop thread
class UvLoop {
public:
    UvLoop();
    ~UvLoop();

    UvLoop(const UvLoop&) = delete;
    UvLoop& operator=(const UvLoop&) = delete;

    uv_loop_t* get_handle();
    void run();

    // thread-safe
    void post(std::function<void()> task);

private:
    static void on_async(uv_async_t* handle);

    uv_loop_t _loop;
    uv_async_t _async;
    std::mutex _mutex;
    std::vector<std::function<void()>> _pending;
};
```

`src/core/UvLoop.cpp`

```cpp
#include "core/UvLoop.h"

#include <utility>

UvLoop::UvLoop()
    : _loop{}
    , _async{} {
    uv_loop_init(&_loop);
    uv_async_init(&_loop, &_async, on_async);
    _async.data = this;
}

UvLoop::~UvLoop() {
    uv_close(reinterpret_cast<uv_handle_t*>(&_async), nullptr);
    uv_run(&_loop, UV_RUN_DEFAULT);
    uv_loop_close(&_loop);
}

uv_loop_t* UvLoop::get_handle() {
    return &_loop;
}

void UvLoop::run() {
    uv_run(&_loop, UV_RUN_DEFAULT);
}

void UvLoop::post(std::function<void()> task) {
    {
        const std::lock_guard<std::mutex> lock(_mutex);
        _pending.push_back(std::move(task));
    }
    uv_async_send(&_async);
}

void UvLoop::on_async(uv_async_t* handle) {
    auto* uvLoop = static_cast<UvLoop*>(handle->data);
    std::vector<std::function<void()>> tasks;
    {
        const std::lock_guard<std::mutex> lock(uvLoop->_mutex);
        tasks.swap(uvLoop->_pending);
    }
    for (auto& task : tasks) {
        task();
    }
}
```

## 2. BlockingWorker: 블로킹 호출 격리

블로킹 호출은 전용 스레드에서 실행하고 결과는 `UvLoop::post()`로 루프에 돌려준다. 요청 큐는 상한이 있고 넘치면 거절한다. 멈출 때는 스레드를 조인한 뒤에 소유 객체를 파괴한다.

`src/network/BlockingWorker.h`

```cpp
#pragma once

#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <functional>
#include <mutex>
#include <thread>
#include <utility>

#include "core/BoundedQueue.h"
#include "core/UvLoop.h"

// runs blocking calls on its own thread and hands results back through UvLoop::post
class BlockingWorker {
public:
    BlockingWorker(UvLoop& loop, size_t capacity)
        : _loop(loop)
        , _queue(capacity, overflow_policy::reject)
        , _running(true)
        , _thread([this]() {
            run();
        }) {
    }

    ~BlockingWorker() {
        stop();
    }

    BlockingWorker(const BlockingWorker&) = delete;
    BlockingWorker& operator=(const BlockingWorker&) = delete;

    // loop thread. false means the queue is full and the request was rejected
    bool submit(std::function<void()> blockingCall, std::function<void()> onDone) {
        push_result result = push_result::rejected;
        {
            const std::lock_guard<std::mutex> lock(_mutex);
            result = _queue.push([this, blockingCall = std::move(blockingCall), onDone = std::move(onDone)]() {
                blockingCall();
                _loop.post(onDone);
            });
        }
        _wakeup.notify_one();
        return result == push_result::accepted;
    }

    void stop() {
        _running = false;
        _wakeup.notify_one();
        if (_thread.joinable()) {
            _thread.join();
        }
    }

private:
    void run() {
        while (_running) {
            std::unique_lock<std::mutex> lock(_mutex);
            _wakeup.wait(lock, [this]() {
                return !_running || _queue.get_size() > 0;
            });
            auto job = _queue.pop();
            lock.unlock();
            if (job) {
                (*job)();
            }
        }
    }

    UvLoop& _loop;
    BoundedQueue<std::function<void()>> _queue;
    std::mutex _mutex;
    std::condition_variable _wakeup;
    std::atomic<bool> _running;
    std::thread _thread;
};
```

## 3. BoundedQueue: 상한 있는 큐

넘침 정책은 큐마다 정한다. 최신 상태가 중요하면 가장 오래된 것을 버리고, 요청이면 거절하고 호출자에게 알린다. 넘칠 때마다 누적 버림 수를 로그에 남긴다.

`src/core/BoundedQueue.h`

```cpp
#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <optional>
#include <utility>

enum class overflow_policy {
    drop_oldest,
    reject
};

enum class push_result {
    accepted,
    dropped_oldest,
    rejected
};

// every queue has a ceiling. the caller logs dropped_total whenever push is not accepted
template <typename T>
class BoundedQueue {
public:
    BoundedQueue(size_t capacity, overflow_policy policy)
        : _capacity(capacity)
        , _policy(policy) {
    }

    push_result push(T item) {
        if (_items.size() < _capacity) {
            _items.push_back(std::move(item));
            return push_result::accepted;
        }
        _droppedTotal += 1;
        if (_policy == overflow_policy::reject) {
            return push_result::rejected;
        }
        _items.pop_front();
        _items.push_back(std::move(item));
        return push_result::dropped_oldest;
    }

    std::optional<T> pop() {
        if (_items.empty()) {
            return std::nullopt;
        }
        T item = std::move(_items.front());
        _items.pop_front();
        return item;
    }

    size_t get_size() const {
        return _items.size();
    }

    uint64_t get_dropped_total() const {
        return _droppedTotal;
    }

private:
    std::deque<T> _items;
    size_t _capacity;
    overflow_policy _policy;
    uint64_t _droppedTotal = 0;
};
```

## 4. MessageBus: 타입 기반 발행 구독

발행자는 구독자를 모른다. 잘못된 타입은 컴파일되지 않는다.

`src/core/MessageBus.h`

```cpp
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <typeindex>
#include <unordered_map>
#include <utility>
#include <vector>

#include "core/BoundedQueue.h"
#include "util/log/Logger.h"

using subscription_id_t = uint64_t;

// typed publish and subscribe. runs on the loop thread only. producers never know their consumers
class MessageBus {
public:
    explicit MessageBus(size_t capacity)
        : _queue(capacity, overflow_policy::drop_oldest) {
    }

    template <typename T>
    subscription_id_t subscribe(std::function<void(const T&)> handler) {
        const subscription_id_t id = ++_lastId;
        _handlers[std::type_index(typeid(T))].push_back({id, [handler](const void* message) {
                                                             handler(*static_cast<const T*>(message));
                                                         }});
        return id;
    }

    void unsubscribe(subscription_id_t id) {
        for (auto& entry : _handlers) {
            auto& list = entry.second;
            for (auto it = list.begin(); it != list.end(); ++it) {
                if (it->id == id) {
                    list.erase(it);
                    return;
                }
            }
        }
    }

    template <typename T>
    void publish(T message) {
        auto shared = std::make_shared<const T>(std::move(message));
        const push_result result = _queue.push([this, shared]() {
            dispatch(std::type_index(typeid(T)), shared.get());
        });
        if (result != push_result::accepted) {
            LOG_WARN(bus, sys, "queue overflow dropped_total={}", _queue.get_dropped_total());
        }
    }

    // called by the loop once per turn
    void drain() {
        while (auto task = _queue.pop()) {
            (*task)();
        }
    }

private:
    struct handler_entry {
        subscription_id_t id;
        std::function<void(const void*)> invoke;
    };

    void dispatch(std::type_index type, const void* message) {
        const auto found = _handlers.find(type);
        if (found == _handlers.end()) {
            return;
        }
        for (const auto& entry : found->second) {
            entry.invoke(message);
        }
    }

    BoundedQueue<std::function<void()>> _queue;
    std::unordered_map<std::type_index, std::vector<handler_entry>> _handlers;
    subscription_id_t _lastId = 0;
};
```

## 5. StateSlot: 불변 스냅숏 상태

갱신은 복사, 수정, 전체 교체 순서로 한다. 읽는 쪽은 절반만 바뀐 상태를 볼 수 없다.

`src/core/StateSlot.h`

```cpp
#pragma once

#include <memory>
#include <mutex>
#include <shared_mutex>
#include <utility>

// readers hold an immutable snapshot. writers copy, edit, then swap the whole value
template <typename T>
class StateSlot {
public:
    std::shared_ptr<const T> get_snapshot() const {
        const std::shared_lock<std::shared_mutex> lock(_mutex);
        return _value;
    }

    template <typename Edit>
    void update(Edit&& edit) {
        const std::unique_lock<std::shared_mutex> lock(_mutex);
        auto next = std::make_shared<T>(*_value);
        std::forward<Edit>(edit)(*next);
        _value = std::move(next);
    }

private:
    mutable std::shared_mutex _mutex;
    std::shared_ptr<const T> _value = std::make_shared<const T>();
};
```

## 6. ByteView, FrameReader: 경계 검사

포인터와 길이는 항상 함께 다닌다. 읽기 전에 남은 길이를 확인하고, 모자라면 `false`를 돌려주어 호출자가 프레임을 버리게 한다. 고정 오프셋으로 읽는 코드는 쓰지 않는다.

`src/model/ByteView.h`

```cpp
#pragma once

#include <cstddef>
#include <cstdint>

// pointer and length always travel together
class ByteView {
public:
    ByteView() = default;
    ByteView(const uint8_t* data, size_t size)
        : _data(data)
        , _size(size) {
    }

    const uint8_t* get_data() const {
        return _data;
    }
    size_t get_size() const {
        return _size;
    }

private:
    const uint8_t* _data = nullptr;
    size_t _size = 0;
};
```

`src/codec/FrameReader.h`

```cpp
#pragma once

#include <cstddef>
#include <cstdint>

#include "model/ByteView.h"

// checks the remaining length before every read. false means drop the frame
class FrameReader {
public:
    explicit FrameReader(ByteView view)
        : _view(view) {
    }

    bool readU8(uint8_t& value) {
        if (get_remaining() < 1) {
            return false;
        }
        value = _view.get_data()[_offset];
        _offset += 1;
        return true;
    }

    bool readU16Be(uint16_t& value) {
        uint8_t high = 0;
        uint8_t low = 0;
        if (get_remaining() < sizeof(uint16_t) || !readU8(high) || !readU8(low)) {
            return false;
        }
        value = static_cast<uint16_t>((high << 8U) | low);
        return true;
    }

    bool readBytes(size_t length, ByteView& out) {
        if (get_remaining() < length) {
            return false;
        }
        out = ByteView(_view.get_data() + _offset, length);
        _offset += length;
        return true;
    }

    size_t get_remaining() const {
        return _view.get_size() - _offset;
    }

private:
    ByteView _view;
    size_t _offset = 0;
};
```

코덱에서의 사용:

```cpp
constexpr uint16_t PERCEPTION_MAX_BODY_LENGTH = 8192;

bool PerceptionCodec::parseHeader(ByteView frame, perception_header& header) {
    FrameReader reader(frame);
    uint16_t length = 0;
    if (!reader.readU8(header.version) || !reader.readU16Be(length) || !reader.readU8(header.opcode)) {
        LOG_WARN(radar, prot, "dropped reason=short_header size={}", frame.get_size());
        return false;
    }
    if (length > PERCEPTION_MAX_BODY_LENGTH) {
        LOG_WARN(radar, prot, "dropped reason=length_ceiling length={} ceiling={}", length, PERCEPTION_MAX_BODY_LENGTH);
        return false;
    }
    header.length = length;
    return true;
}
```

## 7. 로그 태그

장치 태그와 분류 태그는 `enum class`로 정의하고, 매크로의 첫 두 인수로 넘긴다. 로거가 수준, 시각(밀리초), 스레드 번호를 붙인다.

`src/util/log/Logger.h`

```cpp
#pragma once

#include <iostream>
#include <string>

enum class log_level {
    debug,
    info,
    warn,
    error
};

enum class log_tag {
    app,
    config,
    bus,
    vms,
    radar,
    vlm,
    hmi,
    tcp,
    serial,
    mqtt,
    http
};

enum class log_category {
    life,
    cfg,
    net,
    tx,
    rx,
    cmd,
    stat,
    hw,
    prot,
    sys,
    test
};

template <typename... Args>
void logWrite(log_level level, log_tag tag, log_category category, const std::string& format, const Args&... /*args*/) {
    std::cerr << static_cast<int>(level) << static_cast<int>(tag) << static_cast<int>(category) << format << '\n';
}

#define LOG_DEBUG(tag, category, ...) logWrite(log_level::debug, log_tag::tag, log_category::category, __VA_ARGS__)
#define LOG_INFO(tag, category, ...) logWrite(log_level::info, log_tag::tag, log_category::category, __VA_ARGS__)
#define LOG_WARN(tag, category, ...) logWrite(log_level::warn, log_tag::tag, log_category::category, __VA_ARGS__)
#define LOG_ERROR(tag, category, ...) logWrite(log_level::error, log_tag::tag, log_category::category, __VA_ARGS__)
```

출력 형식:

```text
[I][00:45:56.807][217080] [hmi ][LIFE] started port=80 status_push=1000ms
 |  |             |        |     |     └ content, key=value
 |  |             |        |     └ category tag
 |  |             |        └ device tag
 |  |             └ thread id
 |  └ time to the millisecond
 └ level
```
