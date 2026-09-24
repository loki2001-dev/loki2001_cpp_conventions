#include "codec/Codec.h"

bool Codec::parse(ByteView frame, frame_body& body) {
    FrameReader reader(frame);
    uint16_t length = 0;
    uint16_t count = 0;
    if (!reader.readU16Be(length) || !reader.readU16Be(count)) {
        return false;
    }
    if (length > MAX_BODY_LENGTH || count > MAX_ITEMS) {
        return false;
    }
    std::memcpy(body.bytes, frame.get_data() + HEADER_SIZE, length);
    for (size_t i = 0; i < count; ++i) {
        body.items[i] = 0;
    }
    return true;
}

uint16_t readRaw(const uint8_t* data, size_t size) {
    if (size < HEADER_SIZE) {
        return 0;
    }
    uint16_t index = (data[3] << 8U) | data[4];
    if (index < TABLE_SIZE && TABLE[index] > 0) {
        return TABLE[index];
    }
    return 0;
}

uint16_t readClamped(ByteView frame) {
    FrameReader reader(frame);
    uint16_t offset = 0;
    if (!reader.readU16Be(offset)) {
        return 0;
    }
    const size_t safe = std::min<size_t>(offset, TABLE_SIZE - 1);
    return TABLE[safe];
}

void localTable() {
    int values[4] = {};
    for (int i = 0; i < 4; ++i) {
        values[i] = i;
    }
}

void Registry::dispatch(ByteView frame) {
    FrameReader reader(frame);
    uint16_t opcode = 0;
    if (!reader.readU16Be(opcode)) {
        return;
    }
    _handlers[opcode](frame);
}
