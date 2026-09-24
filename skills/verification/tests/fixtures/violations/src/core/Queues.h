#pragma once

class Queues {
public:
    void add(int value);

private:
    std::deque<int> _unbounded;
    std::queue<std::function<void()>> _tasks;
    std::deque<int> _allowed;  // exception: EX-P5-001 drained every turn and filled by one producer
    BoundedQueue<int> _dropQueue;
    BoundedQueue<int> _silentQueue;
};
