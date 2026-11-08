#include "native/include/native_svg_mask_pixels.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t random_state = 0x5c31e297;
static uint8_t random_byte(void)
{
    random_state ^= random_state << 13;
    random_state ^= random_state >> 17;
    random_state ^= random_state << 5;
    return (uint8_t)random_state;
}

static void check(size_t width, size_t height, size_t padding, size_t offset,
    int color, int luminance)
{
    size_t source_stride = width * (color ? 4 : 1) + padding;
    size_t mask_stride = width * 4 + padding;
    size_t source_size = source_stride * height + offset + 16;
    size_t mask_size = mask_stride * height + offset + 16;
    uint8_t *source = malloc(source_size);
    uint8_t *before = malloc(source_size);
    uint8_t *expected = malloc(mask_size);
    uint8_t *actual = malloc(mask_size);
    assert(source && before && expected && actual);
    for (size_t i = 0; i < source_size; ++i) {
        source[i] = random_byte();
    }
    memcpy(before, source, source_size);
    memset(expected, 0xa5, mask_size);
    memset(actual, 0xa5, mask_size);
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            const uint8_t *pixel = source + offset + y * source_stride + x * (color ? 4 : 1);
            uint8_t alpha = color ? luminance
                ? (uint8_t)((54u * pixel[0] + 183u * pixel[1] + 19u * pixel[2]) >> 8)
                : pixel[3] : pixel[0];
            memset(expected + offset + y * mask_stride + x * 4, alpha, 4);
        }
    }
    native_convert_svg_mask_pixels(source + offset, source_stride,
        actual + offset, mask_stride, width, height, color, luminance);
    assert(memcmp(expected, actual, mask_size) == 0);
    assert(memcmp(source, before, source_size) == 0);
    free(actual);
    free(expected);
    free(before);
    free(source);
}

static void check_all_colors(void)
{
    // Every RGB triple, including channels greater than alpha, checks the
    // exact truncating luminance formula rather than a floating approximation.
    uint8_t source[256 * 4], output[256 * 4];
    for (unsigned r = 0; r < 256; ++r) {
        for (unsigned g = 0; g < 256; ++g) {
            for (unsigned b = 0; b < 256; ++b) {
                source[b * 4] = (uint8_t)r;
                source[b * 4 + 1] = (uint8_t)g;
                source[b * 4 + 2] = (uint8_t)b;
                source[b * 4 + 3] = (uint8_t)(r ^ g ^ b);
            }
            native_convert_svg_mask_pixels(source, sizeof(source), output,
                sizeof(output), 256, 1, 1, 1);
            for (unsigned b = 0; b < 256; ++b) {
                uint8_t alpha = (uint8_t)((54u * r + 183u * g + 19u * b) >> 8);
                for (unsigned channel = 0; channel < 4; ++channel) {
                    assert(output[b * 4 + channel] == alpha);
                }
            }
        }
    }
    // Exhaust every alpha value in both source formats and both flag states.
    for (unsigned x = 0; x < 256; ++x) source[x] = (uint8_t)x;
    for (int luminance = 0; luminance < 2; ++luminance) {
        native_convert_svg_mask_pixels(source, 256, output, 1024, 256, 1, 0, luminance);
        for (unsigned x = 0; x < 256; ++x)
            for (unsigned c = 0; c < 4; ++c) assert(output[x * 4 + c] == x);
    }
    for (unsigned x = 0; x < 256; ++x) source[x * 4 + 3] = (uint8_t)x;
    native_convert_svg_mask_pixels(source, 1024, output, 1024, 256, 1, 1, 0);
    for (unsigned x = 0; x < 256; ++x)
        for (unsigned c = 0; c < 4; ++c) assert(output[x * 4 + c] == x);
}

int main(void)
{
    const size_t widths[] = {0, 1, 2, 7, 15, 16, 17, 31, 32, 33, 63, 65, 257, 1476, 1492};
    size_t cases = 0;
    for (size_t i = 0; i < sizeof(widths) / sizeof(widths[0]); ++i) {
        for (size_t padding = 0; padding < 4; ++padding) {
            for (int mode = 0; mode < 4; ++mode) {
                check(widths[i], 9, padding, padding, mode / 2, mode % 2);
                ++cases;
            }
        }
    }
    for (int mode = 0; mode < 4; ++mode) {
        check(1492, 1696, 13, 3, mode / 2, mode % 2);
        check(1476, 1461, 7, 1, mode / 2, mode % 2);
        cases += 2;
    }
    native_convert_svg_mask_pixels(NULL, 0, NULL, 0, 0, 12, 1, 1);
    native_convert_svg_mask_pixels(NULL, 0, NULL, 0, 12, 0, 1, 1);
    check_all_colors();
    printf("SVG mask pixels: %zu stride/tail/guard scenes, all 16777216 RGB triples and all alpha values passed\n", cases);
    return 0;
}
