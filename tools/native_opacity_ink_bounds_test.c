#include "../native_opacity_group_darwin.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static unsigned state = 0x63a015de;
static unsigned next(void)
{
    state ^= state << 13; state ^= state >> 17; state ^= state << 5;
    return state;
}

static void check(const uint32_t *pixels, size_t pitch, int l, int t, int r, int b)
{
    int found = 0, expected[] = {r, b, l, t};
    int actual[] = {-1, -2, -3, -4};
    for (int y = t; y < b; ++y) for (int x = l; x < r; ++x) {
        const uint32_t *row = (const uint32_t *)((const uint8_t *)pixels + y * pitch);
        if (!row[x]) continue;
        found = 1;
        if (x < expected[0]) expected[0] = x;
        if (y < expected[1]) expected[1] = y;
        if (x + 1 > expected[2]) expected[2] = x + 1;
        if (y + 1 > expected[3]) expected[3] = y + 1;
    }
    int result = native_opacity_layer_ink_bounds((const uint8_t *)pixels, pitch,
        l, t, r, b, &actual[0], &actual[1], &actual[2], &actual[3]);
    assert(result == found);
    if (found) assert(!memcmp(actual, expected, sizeof(actual)));
    else assert(actual[0] == -1 && actual[1] == -2 && actual[2] == -3 && actual[3] == -4);
}

int main(void)
{
    const int widths[] = {1, 3, 4, 15, 16, 17, 31, 32, 33, 63, 64, 65,
        255, 256, 257, 2049, 4096, 8191};
    size_t comparisons = 0;
    for (size_t index = 0; index < sizeof(widths) / sizeof(widths[0]); ++index) {
        int width = widths[index];
        for (int padding = 0; padding < 8; ++padding) {
            size_t stride = width + padding;
            uint32_t *pixels = calloc(stride * 7, 4);
            assert(pixels);
            for (int pattern = 0; pattern < 6; ++pattern) {
                memset(pixels, 0, stride * 7 * 4);
                for (int y = 0; y < 7; ++y) for (int x = 0; x < (int)stride; ++x) {
                    if (x >= width || pattern == 1 || (pattern == 2 && next() % 131 == 0)
                        || (pattern == 3 && (x == 0 || x == width - 1))
                        || (pattern == 4 && x == width / 2)
                        || (pattern == 5 && y == 3 && x % 17 == 0))
                        pixels[y * stride + x] = 1u << (next() % 32);
                }
                for (int sample = 0; sample < 16; ++sample) {
                    int l = next() % (width + 1), r = l + next() % (width - l + 1);
                    int t = next() % 8, b = t + next() % (8 - t);
                    check(pixels, stride * 4, l, t, r, b); ++comparisons;
                }
                check(pixels, stride * 4, 0, 0, width, 7); ++comparisons;
            }
            free(pixels);
        }
    }
    // End each clipped row at an inaccessible page. A widened load must stay
    // inside the requested range, including every scalar/vector tail length.
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
    uint8_t *mapping = mmap(NULL, page * 2, PROT_READ | PROT_WRITE,
        MAP_PRIVATE | MAP_ANON, -1, 0);
    assert(mapping != MAP_FAILED && mprotect(mapping + page, page, PROT_NONE) == 0);
    for (int width = 1; width < 128; ++width) {
        uint32_t *pixels = (uint32_t *)(mapping + page - width * 4);
        for (int position = -1; position < width; ++position) {
            memset(pixels, 0, width * 4);
            if (position >= 0) pixels[position] = 1u << (position % 32);
            check(pixels, width * 4, 0, 0, width, 1); ++comparisons;
        }
    }
    assert(munmap(mapping, page * 2) == 0);
    printf("Opacity ink bounds: %zu exact comparisons, including protected row tails\n", comparisons);
}
