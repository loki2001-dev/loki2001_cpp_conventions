#include "codec/Codec.h"

bool Codec::parse(ByteView frame, frame_body& body) {
    FrameReader reader(frame);
    uint16_t length = 0;
    if (!reader.readU16Be(length)) {
        return false;
    }
    std::memcpy(body.bytes, frame.get_data() + HEADER_SIZE, length);
    return true;
}

bool Codec::parseItems(ByteView frame, frame_body& body) {
    FrameReader reader(frame);
    uint16_t count = 0;
    if (!reader.readU16Be(count)) {
        return false;
    }
    for (size_t i = 0; i < count; ++i) {
        body.items[i] = 0;
    }
    return true;
}

uint16_t readRaw(const uint8_t* data, size_t size) {
    uint16_t index = (data[3] << 8U) | data[4];
    return TABLE[index];
}

void Registry::dispatch(ByteView frame) {
    FrameReader reader(frame);
    uint16_t slot = 0;
    if (!reader.readU16Be(slot)) {
        return;
    }
    _slots[slot] = 1;
    body.resize(slot);
}
