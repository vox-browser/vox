#pragma once

#include <array>
#include <cstdint>
#include <cstring>
#include <libdeflate.h>

// A bounded DEFLATE stream for images dominated by repeated RGBA pixels. The
// distance-four matches also cover the PNG row-filter byte without assuming a
// particular image size or row alignment. Other input keeps the general codec.
namespace vox_snapshot_pixel_runs {
struct Code { uint32_t bits; unsigned length; };
constexpr uint32_t reverse(uint32_t bits, unsigned count)
{
    uint32_t result = 0;
    for (unsigned i = 0; i < count; ++i) { result = (result << 1) | (bits & 1); bits >>= 1; }
    return result;
}
constexpr Code literal(unsigned symbol)
{
    return symbol <= 143 ? Code{reverse(0x30 + symbol, 8), 8}
        : symbol <= 255 ? Code{reverse(0x190 + symbol - 144, 9), 9}
        : symbol <= 279 ? Code{reverse(symbol - 256, 7), 7}
        : Code{reverse(0xc0 + symbol - 280, 8), 8};
}
constexpr std::array<Code, 259> match_codes()
{
    constexpr unsigned bases[] = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258};
    constexpr unsigned extra[] = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0};
    std::array<Code, 259> result {};
    for (unsigned length = 3; length <= 258; ++length) {
        unsigned index = 28;
        if (length != 258) { index = 0; while (index < 27 && length >= bases[index + 1]) ++index; }
        auto code = literal(257 + index);
        code.bits |= (length - bases[index]) << code.length;
        code.length += extra[index];
        code.bits |= 24u << code.length; // reversed fixed distance code 3: distance four
        code.length += 5;
        result[length] = code;
    }
    return result;
}
constexpr auto matches = match_codes();

struct Writer {
    uint8_t* output;
    size_t capacity, size = 0;
    uint64_t bits = 0;
    unsigned count = 0;
    bool good = true;
    void put(Code code)
    {
        bits |= uint64_t(code.bits) << count;
        count += code.length;
        if (count < 32) return;
        if (capacity - size < 4) { good = false; return; }
        uint32_t word = uint32_t(bits);
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        std::memcpy(output + size, &word, sizeof word);
#else
        for (unsigned i = 0; i < 4; ++i) output[size + i] = word >> (8 * i);
#endif
        size += 4; bits >>= 32; count -= 32;
    }
    bool finish()
    {
        if (!good || capacity - size < (count + 7) / 8) return false;
        while (count) { output[size++] = uint8_t(bits); bits >>= 8; count = count > 8 ? count - 8 : 0; }
        return true;
    }
};

inline size_t compress(void const* source, size_t size, void* destination, size_t capacity)
{
    if (!source || !destination || size < 4096 || size > 64 * 1024 * 1024 || capacity < 16) return 0;
    auto const* input = static_cast<uint8_t const*>(source);
    // Sampling avoids a second full encoder on photographic or noisy images.
    size_t sampled = 0, repeated = 0;
    for (size_t offset = 4; offset + 64 <= size; offset += 4096) {
        for (size_t byte = 0; byte < 64; byte += 4) {
            ++sampled;
            if (!std::memcmp(input + offset + byte, input + offset + byte - 4, 4)) ++repeated;
        }
    }
    if (!sampled || repeated * 4 < sampled * 3) return 0;
    // Never trade the general codec's compression for an almost raw stream.
    size_t limit = size / 5 + 65536;
    if (limit > capacity) limit = capacity;
    auto* output = static_cast<uint8_t*>(destination);
    output[0] = 0x78; output[1] = 0x01;
    Writer writer {output + 2, limit - 6};
    writer.put({3, 3}); // final block, fixed Huffman codes
    size_t position = 0;
    while (position < size) {
        if (!writer.good) return 0;
        if (position >= 4 && size - position >= 4
            && !std::memcmp(input + position, input + position - 4, 4)) {
            size_t start = position;
            while (size - position >= 8
                && !std::memcmp(input + position, input + position - 4, 8)) position += 8;
            while (position < size && input[position] == input[position - 4]) ++position;
            size_t remaining = position - start;
            while (remaining >= 3) {
                unsigned length = remaining > 258 ? 258 : unsigned(remaining);
                writer.put(matches[length]);
                if (!writer.good) return 0;
                remaining -= length;
            }
            for (size_t byte = position - remaining; byte < position; ++byte) writer.put(literal(input[byte]));
        } else {
            writer.put(literal(input[position++]));
        }
    }
    writer.put(literal(256));
    if (!writer.finish()) return 0;
    auto sum = libdeflate_adler32(1, input, size);
    for (unsigned byte = 0; byte < 4; ++byte) output[writer.size + 2 + byte] = uint8_t(sum >> (24 - 8 * byte));
    return writer.size + 6;
}
}
