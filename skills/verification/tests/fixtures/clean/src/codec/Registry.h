#pragma once

class Registry {
private:
    std::unordered_map<uint16_t, handler_t> _handlers;
};
