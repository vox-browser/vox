#pragma once

#include <array>
#include <cstdint>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <libdeflate.h>
#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

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
constexpr std::array<Code, 257> literal_codes()
{
    std::array<Code, 257> result {};
    for (unsigned i = 0; i < result.size(); ++i) result[i] = literal(i);
    return result;
}
constexpr auto literals = literal_codes();

// Two literal codes for each little-endian byte pair: code bits in the low 24
// bits and their combined length (at most 18) in the high byte.
constexpr std::array<uint32_t, 65536> pair_codes_table()
{
    std::array<uint32_t, 65536> result {};
    for (unsigned pair = 0; pair < result.size(); ++pair) {
        auto first = literals[pair & 255], second = literals[pair >> 8];
        result[pair] = (first.bits | (second.bits << first.length))
            | ((first.length + second.length) << 24);
    }
    return result;
}
constexpr auto pair_codes = pair_codes_table();

// LSB-first bit writer. While eight bytes of space remain it stores the whole
// accumulator and commits only its complete bytes; near the end it commits
// byte by byte. The stream fits exactly when its ceil(bits / 8) bytes fit, as
// with whole 32-bit words, so the same streams are declined.
struct Writer {
    uint8_t* output;
    size_t capacity, size = 0;
    uint64_t bits = 0;
    unsigned count = 0; // pending bits, below eight after each put
    bool good = true;
    // At most 49 bits per call.
    void put(uint64_t code, unsigned length)
    {
        bits |= code << count;
        count += length;
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        if (capacity - size >= 8) {
            std::memcpy(output + size, &bits, sizeof bits);
            unsigned bytes = count >> 3;
            size += bytes;
            bits >>= 8 * bytes;
            count &= 7;
            return;
        }
#endif
        while (count >= 8) {
            if (size == capacity) { good = false; bits = 0; count = 0; return; }
            output[size++] = uint8_t(bits);
            bits >>= 8;
            count -= 8;
        }
    }
    void put(Code code) { put(code.bits, code.length); }
    bool finish()
    {
        if (!good) return false;
        if (count) {
            if (size == capacity) return false;
            output[size++] = uint8_t(bits);
        }
        return true;
    }
};

// Count the bytes from `bytes` that equal the byte four positions earlier,
// stopping at the first difference or after `available` bytes. The caller
// guarantees four readable bytes before `bytes`. Vector comparisons find the
// same first difference as the byte loop.
inline size_t repeated_prefix(uint8_t const* bytes, size_t available, bool vector)
{
    size_t count = 0;
#if defined(__ARM_NEON) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    if (vector) {
        while (available - count >= 64) {
            uint8_t const* at = bytes + count;
            uint8x16_t equal = vandq_u8(
                vandq_u8(vceqq_u8(vld1q_u8(at), vld1q_u8(at - 4)),
                    vceqq_u8(vld1q_u8(at + 16), vld1q_u8(at + 12))),
                vandq_u8(vceqq_u8(vld1q_u8(at + 32), vld1q_u8(at + 28)),
                    vceqq_u8(vld1q_u8(at + 48), vld1q_u8(at + 44))));
            if (vminvq_u8(equal) != 0xff) break;
            count += 64;
        }
        while (available - count >= 16) {
            uint8x16_t equal = vceqq_u8(vld1q_u8(bytes + count), vld1q_u8(bytes + count - 4));
            // Four mask bits per byte; the lowest clear bit is the first difference.
            uint64_t mask = vget_lane_u64(vreinterpret_u64_u8(
                vshrn_n_u16(vreinterpretq_u16_u8(equal), 4)), 0);
            if (mask != UINT64_MAX) return count + (__builtin_ctzll(~mask) >> 2);
            count += 16;
        }
    }
#else
    (void)vector;
#endif
    uint8_t const* previous = bytes - 4;
    while (count < available && bytes[count] == previous[count]) ++count;
    return count;
}

// The encoder's input stream as one contiguous buffer.
struct FlatSource {
    uint8_t const* input;
    uint8_t const* stream() const { return input; }
    size_t loaded(size_t size) const { return size; }
    bool refill(size_t) { return false; }
};

// The PNG filtered-row stream (a zero filter byte, then each row) read from
// a pitched image without materializing it. Inside a row the stream maps
// directly onto that row; around each filter byte a small seam buffer holds
// the previous row's last bytes, the zero and the next row's first bytes.
// Every mapping keeps the four bytes before the position it was made for.
struct RowSource {
    static constexpr size_t seam_span = 128;
    uint8_t const* rows;
    size_t row_bytes, height, pitch, size;
    uint8_t const* base = nullptr; // stream byte p is base[p] within the mapping
    size_t end = 0;                // first stream byte after the mapping
    std::array<uint8_t, seam_span + 4> seam {};

    // Copy stream bytes [position, position + count) into `bytes`.
    void copy(size_t position, uint8_t* bytes, size_t count) const
    {
        size_t stride = row_bytes + 1, r = position / stride, c = position % stride;
        while (count) {
            if (c == 0) { *bytes++ = 0; --count; c = 1; continue; }
            size_t n = stride - c < count ? stride - c : count;
            std::memcpy(bytes, rows + r * pitch + c - 1, n);
            bytes += n; count -= n; c += n;
            if (c == stride) { ++r; c = 0; }
        }
    }
    // Map at least [position - 4, min(size, position + 9)).
    void map(size_t position)
    {
        size_t stride = row_bytes + 1, r = position / stride, c = position % stride;
        size_t row_end = (r + 1) * stride;
        if (c >= 5 && row_end - position > 8) {
            // Interior: stream byte r * stride + 1 + x is rows[r * pitch + x].
            base = rows + r * pitch - (r * stride + 1);
            end = row_end;
            return;
        }
        size_t origin = position >= 4 ? position - 4 : 0;
        end = size - origin < seam.size() ? size : origin + seam.size();
        copy(origin, seam.data(), end - origin);
        base = seam.data() - origin;
    }
    void load() { map(0); }
    bool refill(size_t position)
    {
        if (end >= size) return false;
        map(position);
        return true;
    }
    uint8_t const* stream() const { return base; }
    size_t loaded(size_t) const { return end; }
};

// A run starting at `position` (its first four bytes repeat the previous
// four): extend it through refills and write its matches and leftover bytes.
template<typename Source>
[[gnu::always_inline]] inline size_t encode_run(Source& source, Writer& writer, size_t size, size_t position,
    uint8_t const*& stream, size_t& loaded, bool wide_runs)
{
    size_t start = position;
    for (;;) {
        size_t available = loaded - position;
        size_t count = repeated_prefix(stream + position, available, wide_runs);
        position += count;
        if (count < available || !source.refill(position)) break;
        stream = source.stream();
        loaded = source.loaded(size);
    }
    size_t remaining = position - start;
    while (remaining >= 3) {
        unsigned length = remaining > 258 ? 258 : unsigned(remaining);
        writer.put(matches[length]);
        if (!writer.good) return position;
        remaining -= length;
    }
    for (size_t byte = position - remaining; byte < position; ++byte) writer.put(literals[stream[byte]]);
    return position;
}

// Unmatched RGBA spans usually need all four bytes; write their codes
// together. A match starting inside this quartet may be missed; the
// output-size ceiling still declines a poorly compressed stream.
// `bytes` holds the four input bytes, the first in its low byte.
[[gnu::always_inline]] inline void put_quad(Writer& writer, uint32_t bytes)
{
    uint32_t low = pair_codes[bytes & 0xffff], high = pair_codes[bytes >> 16];
    writer.put((low & 0xffffff) | (uint64_t(high & 0xffffff) << (low >> 24)), (low >> 24) + (high >> 24));
}

[[gnu::always_inline]] inline uint32_t quad_at(uint8_t const* input)
{
    return input[0] | (input[1] << 8) | (input[2] << 16) | (uint32_t(input[3]) << 24);
}

// Writes the zlib header and DEFLATE data; the caller stores the four-byte
// Adler-32 trailer at the returned size minus four. In the main loop every
// position has four bytes before it and at least eight loaded after it, so it
// needs no bounds checks; a run may still extend through later refills. The
// last bytes of the stream take the checked loop.
template<bool Quad, typename Source>
inline size_t encode_stream(Source& source, size_t size, uint8_t* output, size_t limit, bool wide_runs)
{
    output[0] = 0x78; output[1] = 0x01;
    Writer writer {output + 2, limit - 6};
    writer.put({3, 3}); // final block, fixed Huffman codes
    uint8_t const* stream = source.stream();
    size_t loaded = source.loaded(size);
    size_t position = 0;
    // No run can start in the first four bytes. Four single literals have the
    // same codes as a quad.
    if (size >= 4) {
        put_quad(writer, quad_at(stream));
        position = 4;
    }
    for (;;) {
        size_t safe = loaded == size ? (size >= 8 ? size - 8 : 0) : loaded - 8;
        while (position < safe) {
            if (!writer.good) return 0;
            uint8_t const* input = stream + position;
            uint32_t current, previous;
            std::memcpy(&current, input, 4);
            std::memcpy(&previous, input - 4, 4);
            if (current == previous) {
                position = encode_run(source, writer, size, position, stream, loaded, wide_runs);
                safe = loaded == size ? (size >= 8 ? size - 8 : 0) : loaded - 8;
            } else if (Quad) {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
                put_quad(writer, current);
#else
                put_quad(writer, quad_at(input));
#endif
                position += 4;
            } else {
                writer.put(literals[input[0]]);
                ++position;
            }
        }
        if (loaded == size) break;
        source.refill(position);
        stream = source.stream();
        loaded = source.loaded(size);
    }
    while (position < size) {
        if (!writer.good) return 0;
        uint8_t const* input = stream + position;
        if (position >= 4 && size - position >= 4 && !std::memcmp(input, input - 4, 4)) {
            position = encode_run(source, writer, size, position, stream, loaded, wide_runs);
        } else if (Quad && size - position >= 4) {
            put_quad(writer, quad_at(input));
            position += 4;
        } else {
            writer.put(literals[input[0]]);
            ++position;
        }
    }
    writer.put(literal(256));
    if (!writer.finish()) return 0;
    return writer.size + 6;
}

template<typename Source>
inline size_t encode(Source& source, size_t size, uint8_t* output, size_t limit)
{
    bool const wide_runs = !std::getenv("VOX_DISABLE_WIDE_PIXEL_RUNS");
    bool const quad_literals = !std::getenv("VOX_DISABLE_QUAD_PIXEL_LITERALS");
    size_t written = quad_literals ? encode_stream<true>(source, size, output, limit, wide_runs)
        : encode_stream<false>(source, size, output, limit, wide_runs);
    if (written && std::getenv("VOX_QUAD_PIXEL_LITERAL_DIAGNOSTICS"))
        std::fprintf(stderr, "VOX_PIXEL_RUN_CODEC quad_literals=%d input=%zu output=%zu\n",
            int(quad_literals && size >= 4), size, written);
    return written;
}

// Sampling avoids a second full encoder on photographic or noisy images.
// `span` returns 68 stream bytes starting four bytes before its offset.
template<typename Span>
inline bool mostly_repeated(size_t size, Span span)
{
    size_t sampled = 0, repeated = 0;
    for (size_t offset = 4; offset + 64 <= size; offset += 4096) {
        uint8_t const* bytes = span(offset) + 4;
        for (size_t byte = 0; byte < 64; byte += 4) {
            ++sampled;
            if (!std::memcmp(bytes + byte, bytes + byte - 4, 4)) ++repeated;
        }
    }
    return sampled && repeated * 4 >= sampled * 3;
}

inline void store_adler(uint8_t* output, size_t written, uint32_t adler)
{
    for (unsigned byte = 0; byte < 4; ++byte) output[written - 4 + byte] = uint8_t(adler >> (24 - 8 * byte));
}

// Never trade the general codec's compression for an almost raw stream.
inline size_t output_limit(size_t size, size_t capacity)
{
    size_t limit = size / 5 + 65536;
    return limit > capacity ? capacity : limit;
}

inline size_t compress(void const* source, size_t size, void* destination, size_t capacity)
{
    if (!source || !destination || size < 4096 || size > 64 * 1024 * 1024 || capacity < 16) return 0;
    auto const* input = static_cast<uint8_t const*>(source);
    if (!mostly_repeated(size, [input](size_t offset) { return input + offset - 4; })) return 0;
    FlatSource flat {input};
    auto* output = static_cast<uint8_t*>(destination);
    size_t written = encode(flat, size, output, output_limit(size, capacity));
    if (written) store_adler(output, written, libdeflate_adler32(1, input, size));
    return written;
}

// Compress PNG image data for unfiltered rows directly from a pitched image:
// the same zlib stream compress() produces for the materialized rows, each
// preceded by its zero filter-type byte. Returns 0 where compress() declines.
inline size_t compress_rows(void const* image, size_t row_bytes, size_t height, size_t pitch,
    void* destination, size_t capacity)
{
    if (!image || !destination || !row_bytes || !height || pitch < row_bytes || capacity < 16
        || row_bytes >= 64 * 1024 * 1024 || height > 64 * 1024 * 1024 / (row_bytes + 1)) return 0;
    size_t size = (row_bytes + 1) * height;
    if (size < 4096 || (height > 1 && pitch > (SIZE_MAX - row_bytes) / (height - 1))) return 0;
    auto const* rows = static_cast<uint8_t const*>(image);
    RowSource source {rows, row_bytes, height, pitch, size};
    uint8_t sample[68];
    if (!mostly_repeated(size, [&](size_t offset) { source.copy(offset - 4, sample, sizeof sample); return sample; }))
        return 0;
    source.load();
    auto* output = static_cast<uint8_t*>(destination);
    size_t written = encode(source, size, output, output_limit(size, capacity));
    if (!written) return 0;
    uint32_t adler = 1;
    uint8_t const filter = 0;
    for (size_t row = 0; row < height; ++row) {
        adler = libdeflate_adler32(adler, &filter, 1);
        adler = libdeflate_adler32(adler, rows + row * pitch, row_bytes);
    }
    store_adler(output, written, adler);
    return written;
}
}
