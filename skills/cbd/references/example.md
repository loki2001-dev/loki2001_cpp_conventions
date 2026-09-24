# CBD 코드 예시

모든 예시는 `cpp` 스킬 규약으로 작성했고 C++17, `-Wall -Wextra -Wpedantic -Werror`, 동봉한 `.clang-format`, `.clang-tidy`를 통과한다.

## 1. 컴포넌트 계약

`src/core/IComponent.h`

```cpp
#pragma once

/**
 * @brief lifetime contract every component implements
 *
 * initialize: acquire resources and subscribe. false excludes this component only
 * start: start timers and connect. false is logged and the others continue
 * stop: stop timers, unsubscribe, release. called in reverse registration order
 */
class IComponent {
public:
    virtual ~IComponent() = default;

    virtual const char* get_name() const = 0;
    virtual bool initialize() = 0;
    virtual bool start() = 0;
    virtual void stop() = 0;
};
```

## 2. 상태 종류별 쓰기 인터페이스

컴포넌트는 자기가 쓰는 상태 종류의 쓰기 인터페이스만 생성자로 받는다. 생성자를 보면 무엇을 쓰는지 알 수 있다.

`src/core/IStateWriter.h`

```cpp
#pragma once

#include <functional>

#include "model/VmsState.h"

// one write interface per state kind. a constructor shows exactly what a component writes
class IVmsStatusWriter {
public:
    virtual ~IVmsStatusWriter() = default;

    virtual void updateVmsState(const std::function<void(vms_state&)>& edit) = 0;
};
```

## 3. 컴포넌트

- 요구 인터페이스(루프, 버스, 쓰기 인터페이스, 설정)는 모두 생성자로 받는다
- 다른 컴포넌트를 include하지 않는다
- 제공, 요구 인터페이스를 클래스 주석에 적는다
- 거절에는 이유를 남긴다

`src/component/VmsComponent.h`

```cpp
#pragma once

#include <cstdint>
#include <string>

#include "core/IComponent.h"
#include "core/IStateWriter.h"
#include "core/MessageBus.h"
#include "core/UvLoop.h"
#include "model/VmsState.h"

struct vms_config {
    std::string host;
    int port;
    uint32_t reconnectIntervalMs;
};

/**
 * @brief variable message sign component
 *
 * provides: vms_status_changed on the bus, vms_state through IVmsStatusWriter
 * requires: vms_text_command from the bus
 */
class VmsComponent : public IComponent {
public:
    VmsComponent(UvLoop& loop, MessageBus& bus, IVmsStatusWriter& statusWriter, vms_config config);
    ~VmsComponent() override;

    VmsComponent(const VmsComponent&) = delete;
    VmsComponent& operator=(const VmsComponent&) = delete;

    const char* get_name() const override;
    bool initialize() override;
    bool start() override;
    void stop() override;

private:
    // bus
    void handleTextCommand(const vms_text_command& command);

    // state
    void set_online(bool online);

    UvLoop& _loop;
    MessageBus& _bus;
    IVmsStatusWriter& _statusWriter;
    vms_config _config;
    subscription_id_t _textSubscription;
    bool _online;
};
```

`src/component/VmsComponent.cpp`

```cpp
#include "component/VmsComponent.h"

#include <utility>

#include "util/log/Logger.h"

VmsComponent::VmsComponent(UvLoop& loop, MessageBus& bus, IVmsStatusWriter& statusWriter, vms_config config)
    : _loop(loop)
    , _bus(bus)
    , _statusWriter(statusWriter)
    , _config(std::move(config))
    , _textSubscription(0)
    , _online(false) {
}

VmsComponent::~VmsComponent() {
    stop();
}

const char* VmsComponent::get_name() const {
    return "vms";
}

bool VmsComponent::initialize() {
    _textSubscription = _bus.subscribe<vms_text_command>([this](const vms_text_command& command) {
        handleTextCommand(command);
    });
    LOG_INFO(vms, life, "initialized host={} port={}", _config.host, _config.port);
    return true;
}

bool VmsComponent::start() {
    LOG_INFO(vms, life, "started reconnect_interval={}ms", _config.reconnectIntervalMs);
    return true;
}

void VmsComponent::stop() {
    if (_textSubscription != 0) {
        _bus.unsubscribe(_textSubscription);
        _textSubscription = 0;
    }
}

void VmsComponent::handleTextCommand(const vms_text_command& command) {
    if (!_online) {
        LOG_WARN(vms, cmd, "rejected reason=offline text_length={}", command.text.size());
        return;
    }
    _statusWriter.updateVmsState([&command](vms_state& state) {
        state.text = command.text;
    });
}

void VmsComponent::set_online(bool online) {
    _online = online;
    _statusWriter.updateVmsState([online](vms_state& state) {
        state.online = online;
    });
    _bus.publish(vms_status_changed{online});
}
```

## 4. 조립 루트

- 구체 컴포넌트 타입을 아는 유일한 곳이다
- 등록 순서대로 시작하고 역순으로 멈춘다
- 한 컴포넌트가 실패해도 나머지는 계속한다

`src/app/Application.h`

```cpp
#pragma once

#include <memory>
#include <vector>

#include "core/IComponent.h"

// composition root. the only place that knows concrete component types
class Application {
public:
    Application() = default;
    ~Application();

    Application(const Application&) = delete;
    Application& operator=(const Application&) = delete;

    void registerComponent(std::unique_ptr<IComponent> component);
    void start();
    void stop();

private:
    std::vector<std::unique_ptr<IComponent>> _components;
    std::vector<IComponent*> _started;
};
```

`src/app/Application.cpp`

```cpp
#include "app/Application.h"

#include <utility>

#include "util/log/Logger.h"

Application::~Application() {
    stop();
}

void Application::registerComponent(std::unique_ptr<IComponent> component) {
    _components.push_back(std::move(component));
}

void Application::start() {
    for (const auto& component : _components) {
        if (!component->initialize()) {
            LOG_ERROR(app, life, "initialize failed component={}", component->get_name());
            continue;
        }
        if (!component->start()) {
            LOG_ERROR(app, life, "start failed component={}", component->get_name());
            component->stop();
            continue;
        }
        _started.push_back(component.get());
    }
    LOG_INFO(app, life, "started components={}/{}", _started.size(), _components.size());
}

void Application::stop() {
    for (auto it = _started.rbegin(); it != _started.rend(); ++it) {
        (*it)->stop();
    }
    _started.clear();
}
```

조립 예시:

```cpp
auto application = std::make_unique<Application>();
application->registerComponent(std::make_unique<IoControlComponent>(loop, bus, stateStore, config.io));
application->registerComponent(std::make_unique<VmsComponent>(loop, bus, stateStore, config.vms));
application->registerComponent(std::make_unique<HmiComponent>(loop, bus, stateStore, config.hmi));
application->start();
```
