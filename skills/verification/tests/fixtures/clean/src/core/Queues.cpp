#include "core/Queues.h"

Queues::Queues()
    : _requests(CAPACITY, overflow_policy::reject)
    , _events(CAPACITY, overflow_policy::drop_oldest) {
}

bool Queues::isFull() const {
    return _items.size() >= _capacity;
}

void Queues::sample(float value) {
    std::deque<int> local;
    local.push_back(1);
    _history.push_back(value);
    if (_history.size() > MAX_HISTORY) {
        _history.pop_front();
    }
}

bool Queues::request(int value) {
    return _requests.push(value) == push_result::accepted;
}

void Queues::publish(int value) {
    const push_result result = _events.push([this, value]() {
        handle(value);
    });
    if (result != push_result::accepted) {
        LOG_WARN(bus, sys, "queue overflow dropped_total={}", _events.get_dropped_total());
    }
}
