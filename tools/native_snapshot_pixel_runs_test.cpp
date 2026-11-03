#include "../native_snapshot_pixel_runs.h"
#include <zlib.h>
#include <cassert>
#include <cstdio>
#include <vector>

static size_t round_trip(std::vector<uint8_t> const& input, size_t alignment)
{
    std::vector<uint8_t> source(input.size() + alignment, 0x72);
    std::memcpy(source.data() + alignment, input.data(), input.size());
    std::vector<uint8_t> output(input.size() + 8192, 0xa5);
    size_t capacity = output.size() - alignment - 16;
    size_t written = vox_snapshot_pixel_runs::compress(source.data() + alignment,
        input.size(), output.data() + alignment, capacity);
    assert(written && written <= capacity);
    std::vector<uint8_t> decoded(input.size());
    uLongf size = decoded.size();
    assert(uncompress(decoded.data(), &size, output.data() + alignment, written) == Z_OK);
    assert(size == input.size() && decoded == input);
    for (size_t i = 0; i < alignment; ++i) assert(output[i] == 0xa5);
    for (size_t i = alignment + capacity; i < output.size(); ++i) assert(output[i] == 0xa5);
    // A partially written stream is discarded on overflow; the caller's bounds
    // remain intact even when a final word or checksum cannot fit.
    for (size_t cap : {size_t(0), size_t(1), size_t(15), written - 1, written}) {
        std::fill(output.begin(), output.end(), 0xa5);
        size_t count = vox_snapshot_pixel_runs::compress(source.data() + alignment,
            input.size(), output.data() + alignment, cap);
        assert(count <= cap);
        if (cap < written) assert(!count);
        else assert(count == written);
        for (size_t i = alignment + cap; i < output.size(); ++i) assert(output[i] == 0xa5);
    }
    return written;
}

int main()
{
    uint8_t byte = 0, output[32] {};
    assert(!vox_snapshot_pixel_runs::compress(nullptr, 4096, output, sizeof output));
    assert(!vox_snapshot_pixel_runs::compress(&byte, 4096, nullptr, sizeof output));
    assert(!vox_snapshot_pixel_runs::compress(&byte, 4095, output, sizeof output));
    assert(!vox_snapshot_pixel_runs::compress(&byte, 64 * 1024 * 1024 + 1, output, sizeof output));
    unsigned cases = 0;
    // Exercise every short-match/Huffman boundary, 258-byte splitting, partial
    // pixels, literal values and aligned/unaligned input/output addresses.
    for (size_t tail = 0; tail <= 320; ++tail) {
        std::vector<uint8_t> input(65536 + tail, 0xff);
        for (size_t i = 0; i < input.size(); ++i) input[i] = uint8_t(13 + (i % 4) * 71);
        for (size_t run = 3, offset = 80; run <= 258 && offset + run + 8 < 60000; ++run) {
            for (size_t i = 0; i < run; ++i) input[offset + i] = uint8_t(run);
            offset += run + 4;
        }
        for (size_t i = input.size() - tail; i < input.size(); ++i) input[i] = uint8_t(i * 37);
        round_trip(input, tail % 16); ++cases;
    }
    for (size_t length : {size_t(4096), size_t(4097), size_t(65535), size_t(65536),
            size_t(65537), size_t(1024 * 1024), size_t(64 * 1024 * 1024)}) {
        round_trip(std::vector<uint8_t>(length, 0), 3); ++cases;
    }
    std::vector<uint8_t> noisy(65536), compressed(noisy.size());
    uint32_t state = 0x791ea;
    for (auto& value : noisy) { state ^= state << 13; state ^= state >> 17; state ^= state << 5; value = state; }
    assert(!vox_snapshot_pixel_runs::compress(noisy.data(), noisy.size(), compressed.data(), compressed.size()));
    std::printf("PASS %u bounded repeated-pixel zlib round trips and noisy-input fallback\n", cases);
}
