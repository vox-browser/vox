#include "../native/include/native_raster_row_ranges.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static uint32_t state = 0x71830129;
static uint32_t random_word(void) {
    state ^= state << 13; state ^= state >> 17; state ^= state << 5;
    return state;
}

int main(void) {
    size_t cases = 0;
    for (size_t height = 0; height <= 64; ++height) {
        for (size_t count = 0; count <= 49; ++count) {
            for (int trial = 0; trial < 12; ++trial) {
                struct { size_t before; VoxRasterRowRange rows[49]; size_t after; } fixture;
                fixture.before = fixture.after = (size_t)0x1234abcd;
                unsigned char expected[64] = {0}, actual[64] = {0};
                for (size_t index = 0; index < count; ++index) {
                    size_t first = random_word() % 80, length = random_word() % 80;
                    if (trial == 0) first = 0, length = height;
                    if (trial == 1) first = index, length = 1;
                    if (trial == 2) first = 1, length = SIZE_MAX;
                    fixture.rows[index] = (VoxRasterRowRange){first, length};
                    for (size_t row = 0; row < height; ++row)
                        if (row >= first && row - first < length) expected[row] = 1;
                }
                size_t merged = vox_union_raster_rows(fixture.rows, count, height);
                assert(merged <= count);
                for (size_t index = 0; index < merged; ++index) {
                    VoxRasterRowRange range = fixture.rows[index];
                    assert(range.count && range.first < height && range.count <= height - range.first);
                    if (index) assert(fixture.rows[index - 1].first + fixture.rows[index - 1].count < range.first);
                    memset(actual + range.first, 1, range.count);
                }
                assert(!memcmp(actual, expected, height));
                assert(fixture.before == (size_t)0x1234abcd && fixture.after == (size_t)0x1234abcd);
                ++cases;
            }
        }
    }
    VoxRasterRowRange edge[] = {{SIZE_MAX - 3, SIZE_MAX}, {SIZE_MAX - 4, 1}, {SIZE_MAX, 1}};
    assert(vox_union_raster_rows(edge, 3, SIZE_MAX) == 1);
    assert(edge[0].first == SIZE_MAX - 4 && edge[0].count == 4);
    assert(vox_union_raster_rows(NULL, 0, 0) == 0);
    printf("Raster row union: %zu exact coverage/canary cases plus SIZE_MAX boundaries passed\n", cases);
    return 0;
}
