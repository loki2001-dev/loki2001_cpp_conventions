#include "component/Bad.h"

void Bad::poll() {
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    _cond.wait(lock);
    ::connect(fd, addr, len);
    getaddrinfo(host, port, &hints, &res);
    std::thread worker([this]() {
        run();
    });
    std::lock_guard<std::mutex> guard(_mutex);
    _worker.submit(
        [this]() {
            _state = 3;
        },
        [this]() {
            _state = 4;
            std::this_thread::sleep_for(ONE_SECOND);
        });
    usleep(SETTLE_US);  // exception: EX-P2-001 vendor sdk needs settle time
    sleep(1);           // NOVERIFY(P2-SLEEP)
    system("reboot");
    uv_run(loop, UV_RUN_DEFAULT);
    curl_easy_perform(curl);
}

void Bad::request() {
    _worker.submit(
        [&]() {
            *response = client->send(request);
        },
        [this]() {
            done();
        });
}
