#include "../native/include/native_snapshot_pixel_runs.h"
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
    std::vector<uint8_t> narrow(output.size(), 0xa5);
    setenv("VOX_DISABLE_WIDE_PIXEL_RUNS", "1", 1);
    size_t narrow_written = vox_snapshot_pixel_runs::compress(source.data() + alignment,
        input.size(), narrow.data() + alignment, capacity);
    unsetenv("VOX_DISABLE_WIDE_PIXEL_RUNS");
    assert(narrow_written == written);
    assert(std::memcmp(narrow.data() + alignment, output.data() + alignment, written) == 0);
    assert(written && written <= capacity);
    std::vector<uint8_t> decoded(input.size());
    uLongf size = decoded.size();
    assert(uncompress(decoded.data(), &size, output.data() + alignment, written) == Z_OK);
    assert(size == input.size() && decoded == input);
    std::vector<uint8_t> legacy(output.size(), 0xa5);
    setenv("VOX_DISABLE_QUAD_PIXEL_LITERALS", "1", 1);
    size_t legacy_written = vox_snapshot_pixel_runs::compress(source.data() + alignment,
        input.size(), legacy.data() + alignment, capacity);
    unsetenv("VOX_DISABLE_QUAD_PIXEL_LITERALS");
    assert(legacy_written && legacy_written <= capacity);
    size = decoded.size();
    assert(uncompress(decoded.data(), &size, legacy.data() + alignment, legacy_written) == Z_OK);
    assert(size == input.size() && decoded == input);
    for (size_t i = 0; i < alignment; ++i) assert(legacy[i] == 0xa5);
    for (size_t i = alignment + capacity; i < legacy.size(); ++i) assert(legacy[i] == 0xa5);
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

// compress_rows() must produce compress()'s exact stream for the materialized
// filter-type-zero rows, without reading row padding or writing past capacity.
static unsigned rows_match_materialized(size_t row_bytes, size_t height, size_t padding, uint32_t seed)
{
    size_t pitch = row_bytes + padding;
    std::vector<uint8_t> image(pitch * height);
    uint32_t state = seed;
    auto next = [&] { state ^= state << 13; state ^= state >> 17; state ^= state << 5; return state; };
    uint32_t background = next();
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < row_bytes; ++x) {
            // Mostly repeated pixels with sparse literals, row-crossing runs
            // and partial trailing pixels.
            image[y * pitch + x] = next() % 211 ? uint8_t(background >> (8 * (x % 4))) : uint8_t(next());
        }
        for (size_t x = row_bytes; x < pitch; ++x) image[y * pitch + x] = uint8_t(next());
    }
    std::vector<uint8_t> rows((row_bytes + 1) * height);
    for (size_t y = 0; y < height; ++y)
        std::memcpy(&rows[y * (row_bytes + 1) + 1], &image[y * pitch], row_bytes);
    std::vector<uint8_t> expected(rows.size() + 4096), actual(expected.size(), 0xa5);
    size_t written = vox_snapshot_pixel_runs::compress(rows.data(), rows.size(), expected.data(), expected.size());
    size_t from_rows = vox_snapshot_pixel_runs::compress_rows(image.data(), row_bytes, height, pitch,
        actual.data(), actual.size());
    assert(from_rows == written);
    assert(!std::memcmp(expected.data(), actual.data(), written));
    if (!written) return 0;
    for (size_t cap : {written - 1, written - 4, size_t(15), written}) {
        std::fill(actual.begin(), actual.end(), 0xa5);
        size_t count = vox_snapshot_pixel_runs::compress_rows(image.data(), row_bytes, height, pitch,
            actual.data(), cap);
        assert(cap < written ? !count : count == written);
        for (size_t i = cap; i < actual.size(); ++i) assert(actual[i] == 0xa5);
    }
    return 1;
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
    assert(!vox_snapshot_pixel_runs::compress_rows(nullptr, 4096, 1, 4096, output, sizeof output));
    assert(!vox_snapshot_pixel_runs::compress_rows(noisy.data(), 4096, 1, 4095, output, sizeof output));
    assert(!vox_snapshot_pixel_runs::compress_rows(noisy.data(), 4094, 1, 4094, output, sizeof output));
    assert(!vox_snapshot_pixel_runs::compress_rows(noisy.data(), 4096, 16, 4096, compressed.data(), compressed.size()));
    unsigned row_cases = 0, encoded = 0;
    // Rows shorter and longer than the seam buffer, padded pitches, a single
    // tall column and the 2048-pixel capture width.
    for (size_t row_bytes : {size_t(1), size_t(3), size_t(4), size_t(7), size_t(64), size_t(127),
            size_t(128), size_t(129), size_t(1000), size_t(4093), size_t(8192)}) {
        for (size_t padding : {size_t(0), size_t(1), size_t(13), size_t(64)}) {
            size_t height = (64 * 1024 + row_bytes) / (row_bytes + 1);
            encoded += rows_match_materialized(row_bytes, height, padding, uint32_t(row_bytes * 31 + padding));
            ++row_cases;
        }
    }
    assert(encoded > row_cases / 2);
    std::printf("PASS %u pitched filter-row streams equal their materialized rows (%u encoded)\n", row_cases, encoded);
}
