#include "component/Good.h"

void Good::request() {
    const bool accepted = _worker.submit(
        [client = _client, request, response]() {
            *response = client->send(request);
            std::this_thread::sleep_for(RETRY_DELAY);
        },
        [this, response]() {
            handleResult(*response);
        });
    // std::this_thread::sleep_for is not called here
    LOG_INFO(vms, life, "sleep(1) in a string is fine accepted={}", accepted);
    _timer.start(DELAY_MS, [this]() {
        poll();
    });
    connect(ip, port);
    _socket->connect(ip, port);
    uv_getaddrinfo(_loop, &_resolve, onResolved, host, nullptr, nullptr);
    const auto now = std::chrono::system_clock::now();
    std::thread::id owner = std::this_thread::get_id();
}
