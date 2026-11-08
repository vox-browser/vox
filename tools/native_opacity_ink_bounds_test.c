#include "../native/include/native_opacity_group_darwin.h"
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

    // Horizontal limits can be established by different rows. Empty gaps and
    // tails must not change the last painted row, nor may cropped-out ink help.
    for (int height = 3; height <= 33; ++height) {
        size_t stride = 71;
        uint32_t *pixels = calloc(stride * height, 4);
        assert(pixels);
        for (int last = 1; last < height; ++last) {
            memset(pixels, 0, stride * height * 4);
            pixels[2] = 1; pixels[stride + 66] = 0x80000000u;
            pixels[(size_t)last * stride + 37] = 0x100u;
            // Padding and pixels outside the crop never supply a bound.
            for (int y = 0; y < height; ++y) pixels[y * stride + 70] = ~0u;
            check(pixels, stride * 4, 2, 0, 67, height); ++comparisons;
            check(pixels, stride * 4, 3, 0, 66, height); ++comparisons;
        }
        free(pixels);
    }

    // Every tail probe ends immediately before an inaccessible page. Exercise
    // vector widths and all possible nonzero positions in the final row.
    mapping = mmap(NULL, page * 18, PROT_READ | PROT_WRITE,
        MAP_PRIVATE | MAP_ANON, -1, 0);
    assert(mapping != MAP_FAILED);
    for (int y = 0; y < 9; ++y)
        assert(mprotect(mapping + (y * 2 + 1) * page, page, PROT_NONE) == 0);
    for (int width = 1; width < 128; ++width) {
        uint32_t *pixels = (uint32_t *)(mapping + page - width * 4);
        for (int position = -1; position < width; ++position) {
            for (int y = 0; y < 9; ++y)
                memset((uint8_t *)pixels + y * page * 2, 0, width * 4);
            pixels[0] = 1; pixels[width - 1] = 0x100u;
            if (position >= 0)
                ((uint32_t *)((uint8_t *)pixels + page * 16))[position] = 1u << (position % 32);
            check(pixels, page * 2, 0, 0, width, 9); ++comparisons;
        }
    }
    assert(munmap(mapping, page * 18) == 0);

    // Hollow bands leave a wide, already bounded interior even though neither
    // crop edge contains ink. Later rows may still extend either X bound.
    const int band_widths[] = {63, 64, 65, 127, 128, 129, 511, 512, 513};
    const int band_heights[] = {4, 5, 17, 33};
    for (size_t wi = 0; wi < sizeof(band_widths) / sizeof(band_widths[0]); ++wi)
    for (size_t hi = 0; hi < sizeof(band_heights) / sizeof(band_heights[0]); ++hi) {
        int width = band_widths[wi], height = band_heights[hi];
        size_t stride = (size_t)width + 7;
        uint32_t *pixels = calloc(stride * height, 4);
        assert(pixels);
        for (int pattern = 0; pattern < 6; ++pattern) {
            memset(pixels, 0, stride * height * 4);
            for (int y = 0; y < height; ++y) {
                pixels[y * stride + width + 3] = ~0u;
                for (int x = 0; x < width; ++x) {
                    if ((pattern == 0 && (y == 0 || y == height - 1)
                            && (x == width / 4 || x == width * 3 / 4))
                        || (pattern == 1 && ((y == 0 || y == height - 1)
                                && (x == width / 3 || x == width * 2 / 3)))
                        || (pattern == 1 && ((y == 1 && x == 1)
                                || (y == height - 2 && x == width - 2)))
                        || (pattern == 2 && y == 0 && x == width / 2)
                        || (pattern == 3 && (y == 0 || y == height - 1)
                            && (x == 0 || x == width - 1))
                        || (pattern == 4 && y % 3 == 1 && x >= width / 4
                            && x < width * 3 / 4 && next() % 17 == 0)
                        || (pattern == 5 && y == height / 2 && x == width / 2))
                        pixels[y * stride + x] = 1u << (next() % 32);
                }
            }
            for (int crop = 0; crop < 4; ++crop) {
                int inset = crop & 1;
                check(pixels, stride * 4, inset, crop / 2, width - inset,
                    height - crop / 2); ++comparisons;
            }
        }
        free(pixels);
    }

    // Partial-width bounds must also permit an unread interior. Each middle
    // row has accessible margins around a protected center page. The complete
    // row scan would fault while searching these otherwise empty rows.
    if (native_opacity_margin_bounds_enabled()) {
        mapping = mmap(NULL, page * 24, PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANON, -1, 0);
        assert(mapping != MAP_FAILED);
        int words = (int)(page / 4), width = words * 3;
        uint32_t *pixels = (uint32_t *)mapping;
        pixels[words - 1] = 1;
        pixels[words * 2] = 0x10000u;
        ((uint32_t *)(mapping + page * 21))[words + 1] = 0x100u;
        for (int y = 1; y < 7; ++y)
            assert(mprotect(mapping + (y * 3 + 1) * page, page, PROT_NONE) == 0);
        int bounds[4];
        assert(native_opacity_layer_ink_bounds(mapping, page * 3, 0, 0, width, 8,
            &bounds[0], &bounds[1], &bounds[2], &bounds[3]));
        assert(bounds[0] == words - 1 && bounds[1] == 0
            && bounds[2] == words * 2 + 1 && bounds[3] == 8);
        assert(munmap(mapping, page * 24) == 0);
    }

    // A resolved interior is unnecessary input. Protect it to prove that the
    // candidate consumes just the first and last rows in this dense-bound case.
    if (native_opacity_trim_ink_rows()) {
        mapping = mmap(NULL, page * 4, PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANON, -1, 0);
        assert(mapping != MAP_FAILED);
        uint32_t *pixels = (uint32_t *)mapping;
        pixels[0] = 1; pixels[31] = 0x10000u;
        ((uint32_t *)(mapping + page * 3))[17] = 0x100u;
        assert(mprotect(mapping + page, page * 2, PROT_NONE) == 0);
        int bounds[4];
        assert(native_opacity_layer_ink_bounds(mapping, page, 0, 0, 32, 4,
            &bounds[0], &bounds[1], &bounds[2], &bounds[3]));
        assert(bounds[0] == 0 && bounds[1] == 0 && bounds[2] == 32 && bounds[3] == 4);
        assert(munmap(mapping, page * 4) == 0);
    }
    printf("Opacity ink bounds: %zu exact comparisons, including protected row tails\n", comparisons);
}
