#include "core/Queues.h"

Queues::Queues()
    : _dropQueue(CAPACITY, overflow_policy::drop_oldest)
    , _silentQueue(CAPACITY, overflow_policy::drop_oldest) {
}

void Queues::add(int value) {
    _silentQueue.push(value);
    const push_result result = _dropQueue.push(value);
    if (result != push_result::accepted) {
        return;
    }
}
