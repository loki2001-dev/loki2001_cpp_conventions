#include "network/Worker.h"

void Worker::run() {
    std::unique_lock<std::mutex> lock(_mutex);
    _wakeup.wait(lock, [this]() {
        return !_running;
    });
    std::this_thread::sleep_for(BACKOFF);
}
