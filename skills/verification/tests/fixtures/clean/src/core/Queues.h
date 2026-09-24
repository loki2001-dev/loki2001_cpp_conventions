#pragma once

class Queues {
private:
    std::deque<float> _history;
    std::deque<int> _items;
    BoundedQueue<int> _requests;
    BoundedQueue<int> _events;
};
