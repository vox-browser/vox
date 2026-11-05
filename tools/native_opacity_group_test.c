#include "../native_opacity_group_darwin.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

// Preserve the original arithmetic as an independent pixel oracle. In
// particular, neither the divisions nor the final double scale may be folded.
static void reference_composite(const uint8_t *source, const uint8_t *backdrop,
    uint8_t *result, size_t count, float opacity)
{
#pragma clang fp contract(off)
    for (size_t i = 0; i < count; ++i) {
        float alpha = (float)source[i * 4 + 3] / 255.0f;
        alpha *= opacity;
        float remaining = 1.0f - alpha;
        for (int c = 0; c < 4; ++c) {
            float s = (float)source[i * 4 + c] / 255.0f;
            s *= opacity;
            float d = (float)backdrop[i * 4 + c] / 255.0f;
            double value = nearbyint((double)fmaf(d, remaining, s) * 255.0);
            result[i * 4 + c] = value <= 0 ? 0 : value >= 255 ? 255 : (uint8_t)value;
        }
    }
}

static uint32_t random_state = 0xf345a123;
static uint32_t random_value(void)
{
    random_state ^= random_state << 13;
    random_state ^= random_state >> 17;
    random_state ^= random_state << 5;
    return random_state;
}

static void test_composite(void)
{
    uint8_t source[256 * 4], backdrop[256 * 4], expected[256 * 4], actual[256 * 4];
    const float opacities[] = {0, 0.1f, 0.3f, 0.5f, 0.7f, 0.8f, 0.999f, 1};
    size_t pixels = 0;
    // Every source level, destination level and coverage byte, including
    // non-premultiplied inputs, half-level ties and saturated output.
    for (size_t o = 0; o < sizeof(opacities) / sizeof(opacities[0]); ++o)
        for (int alpha = 0; alpha < 256; ++alpha)
            for (int value = 0; value < 256; ++value) {
                for (int d = 0; d < 256; ++d) {
                    source[d * 4] = value; source[d * 4 + 1] = 255 - value;
                    source[d * 4 + 2] = value / 2; source[d * 4 + 3] = alpha;
                    backdrop[d * 4] = d; backdrop[d * 4 + 1] = 255 - d;
                    backdrop[d * 4 + 2] = d / 2; backdrop[d * 4 + 3] = d;
                }
                reference_composite(source, backdrop, expected, 256, opacities[o]);
                native_composite_opacity_pixels(source, backdrop, actual, 256, opacities[o]);
                assert(!memcmp(expected, actual, sizeof(expected)));
                pixels += 256;
            }
    // Empty spans, fully opaque spans and alternating vector blocks. Check
    // every backdrop byte and preserve the scalar results at opacity limits.
    for (int pattern = 0; pattern < 4; ++pattern) {
        for (int i = 0; i < 256; ++i) for (int c = 0; c < 4; ++c) {
            source[i * 4 + c] = pattern == 0 || (pattern == 3 && i / 8 % 2 == 0)
                ? 0 : c == 3 ? 255 : i;
            backdrop[i * 4 + c] = i;
        }
        for (size_t o = 0; o < sizeof(opacities) / sizeof(opacities[0]); ++o) {
            reference_composite(source, backdrop, expected, 256, opacities[o]);
            native_composite_opacity_pixels(source, backdrop, actual, 256, opacities[o]);
            assert(!memcmp(expected, actual, sizeof(expected)));
        }
    }
    // Arbitrary float opacities, unaligned byte buffers, vector tails and
    // exact in-place output. Guards expose writes outside the requested span.
    for (int iteration = 0; iteration < 4096; ++iteration) {
        float opacity = iteration % 4 == 0 ? 1.0f : (float)(random_value() & 0xffffff) / 16777215.0f;
        for (size_t i = 0; i < sizeof(source); ++i) {
            source[i] = random_value(); backdrop[i] = random_value();
        }
        size_t count = iteration % 63;
        memset(expected, 0xa9, sizeof(expected));
        memset(actual, 0xa9, sizeof(actual));
        reference_composite(source + 1, backdrop + 3, expected + 5, count, opacity);
        native_composite_opacity_pixels(source + 1, backdrop + 3, actual + 5, count, opacity);
        assert(!memcmp(expected, actual, sizeof(expected)));
        // The original float SIMD path remains the matched control.
        setenv("VOX_DISABLE_UNIT_OPACITY_INTEGER", "1", 1);
        native_composite_opacity_pixels(source + 1, backdrop + 3, actual + 5, count, opacity);
        assert(!memcmp(expected, actual, sizeof(expected)));
        unsetenv("VOX_DISABLE_UNIT_OPACITY_INTEGER");
        memcpy(actual, backdrop, sizeof(actual));
        reference_composite(source, backdrop, expected, count, opacity);
        native_composite_opacity_pixels(source, actual, actual, count, opacity);
        assert(!memcmp(expected, actual, count * 4));
        assert(!memcmp(actual + count * 4, backdrop + count * 4, sizeof(actual) - count * 4));
        memcpy(actual, source, sizeof(actual));
        native_composite_opacity_pixels(actual, backdrop, actual, count, opacity);
        assert(!memcmp(expected, actual, count * 4));
        assert(!memcmp(actual + count * 4, source + count * 4, sizeof(actual) - count * 4));
    }
    // The SIMD path explicitly leaves nondefault rounding modes to the scalar
    // compositor. Also retain the scalar behavior for unusual opacity inputs.
    for (int mode = 0; mode < 4; ++mode) {
        const int modes[] = {FE_TONEAREST, FE_UPWARD, FE_DOWNWARD, FE_TOWARDZERO};
        assert(fesetround(modes[mode]) == 0);
        for (int i = -4; i <= 8; ++i) {
            float opacity = (float)i / 4;
            reference_composite(source, backdrop, expected, 256, opacity);
            native_composite_opacity_pixels(source, backdrop, actual, 256, opacity);
            assert(!memcmp(expected, actual, sizeof(expected)));
        }
    }
    assert(fesetround(FE_TONEAREST) == 0);
    printf("Opacity composite: %zu exhaustive pixels, tails, aliasing and rounding modes passed\n", pixels);
}

static int reference_bounds(const uint8_t *pixels, size_t pitch, int l, int t, int r, int b, int *result)
{
    int found = 0;
    int bounds[] = {r, b, l, t};
    for (int y = t; y < b; ++y) for (int x = l; x < r; ++x) {
        uint32_t pixel;
        memcpy(&pixel, pixels + (size_t)y * pitch + (size_t)x * 4, 4);
        if (!pixel) continue;
        found = 1;
        if (x < bounds[0]) bounds[0] = x;
        if (y < bounds[1]) bounds[1] = y;
        if (x + 1 > bounds[2]) bounds[2] = x + 1;
        if (y + 1 > bounds[3]) bounds[3] = y + 1;
    }
    if (found) memcpy(result, bounds, sizeof(bounds));
    return found;
}

static void test_bounds(void)
{
    size_t comparisons = 0;
    for (int width = 1; width <= 65; ++width) for (int padding = 0; padding <= 12; padding += 4) {
        size_t pitch = (size_t)width * 4 + padding;
        uint8_t *pixels = malloc(pitch * 17);
        assert(pixels);
        for (int iteration = 0; iteration < 128; ++iteration) {
            memset(pixels, 0, pitch * 17);
            for (int y = 0; y < 17; ++y) {
                memset(pixels + y * pitch + width * 4, 255, padding);
                for (int x = 0; x < width; ++x) {
                    // Dense, empty and sparse rows, with each channel alone
                    // marking ink even when alpha is zero.
                    if ((iteration % 4 == 1) || (iteration % 4 >= 2 && random_value() % 23 == 0))
                        pixels[y * pitch + x * 4 + iteration % 4] = 1 + random_value() % 255;
                }
            }
            int left = random_value() % (width + 1), top = random_value() % 18;
            int right = left + random_value() % (width - left + 1);
            int bottom = top + random_value() % (18 - top);
            int expected[] = {-1, -2, -3, -4}, actual[] = {-1, -2, -3, -4};
            int found = reference_bounds(pixels, pitch, left, top, right, bottom, expected);
            assert(native_opacity_layer_ink_bounds(pixels, pitch, left, top, right, bottom,
                &actual[0], &actual[1], &actual[2], &actual[3]) == found);
            assert(!memcmp(expected, actual, sizeof(expected)));
            ++comparisons;
        }
        free(pixels);
    }
    printf("Opacity bounds: %zu exact region/padding comparisons passed\n", comparisons);
}

static void test_byte_opacity_large_spans(void)
{
    enum { bytes = 1024 * 4 + 32 };
    uint8_t source[bytes], backdrop[bytes], expected[bytes], actual[bytes];
    size_t pixels = 0;
    const size_t counts[] = {0, 7, 8, 255, 256, 257, 511, 768, 1024};
    for (int iteration = 0; iteration < 2048; ++iteration) {
        float opacity = (float)(random_value() & 0xffffff) / 16777215.0f;
        if (iteration % 8 == 0) opacity = nextafterf(0.5f, iteration % 16 ? 0 : 1);
        if (iteration % 8 == 1) opacity = nextafterf(0.1f, iteration % 16 ? 0 : 1);
        for (size_t i = 0; i < bytes; ++i) {
            source[i] = random_value(); backdrop[i] = random_value();
        }
        size_t count = counts[iteration % (sizeof(counts) / sizeof(counts[0]))];
        memset(expected, 0xa9, bytes); memset(actual, 0xa9, bytes);
        reference_composite(source + 1, backdrop + 3, expected + 5, count, opacity);
        native_composite_opacity_pixels(source + 1, backdrop + 3, actual + 5, count, opacity);
        assert(!memcmp(expected, actual, bytes));
        reference_composite(source, backdrop, expected, count, opacity);
        memcpy(actual, backdrop, bytes);
        native_composite_opacity_pixels(source, actual, actual, count, opacity);
        assert(!memcmp(expected, actual, count * 4));
        assert(!memcmp(actual + count * 4, backdrop + count * 4, bytes - count * 4));
        memcpy(actual, source, bytes);
        native_composite_opacity_pixels(actual, backdrop, actual, count, opacity);
        assert(!memcmp(expected, actual, count * 4));
        assert(!memcmp(actual + count * 4, source + count * 4, bytes - count * 4));
        pixels += count * 3;
    }
    // An exact byte-unit half can be biased in normalized GPU arithmetic.
    // The guard must reject it, and the public compositor must retain it.
    for (size_t i = 0; i < 1024; ++i) {
        source[i * 4] = source[i * 4 + 1] = source[i * 4 + 2] = 0;
        source[i * 4 + 3] = 255;
        backdrop[i * 4] = backdrop[i * 4 + 1] = backdrop[i * 4 + 2] = 33;
        backdrop[i * 4 + 3] = 255;
    }
    reference_composite(source, backdrop, expected, 1024, 0.5f);
    assert(expected[0] == 17);
    native_composite_opacity_pixels(source, backdrop, actual, 1024, 0.5f);
    assert(!memcmp(expected, actual, 1024 * 4));
#if defined(__aarch64__) && !defined(VOX_OPACITY_DISABLE_NEON)
    uint8x8x4_t output;
    assert(!native_opacity_unambiguous_byte_block(vld4_u8(source), vld4_u8(backdrop),
        vdupq_n_f32(0.5f), vdupq_n_f32(0.5f), vdupq_n_f32(0.5f), &output));
    for (size_t i = 0; i < 8; ++i) {
        source[i * 4] = 10; source[i * 4 + 1] = 20; source[i * 4 + 2] = 30;
        source[i * 4 + 3] = 100;
        backdrop[i * 4] = 40; backdrop[i * 4 + 1] = 50; backdrop[i * 4 + 2] = 60;
    }
    float remaining = 1 - ((float)100 / 255) * 0.25f;
    assert(native_opacity_unambiguous_byte_block(vld4_u8(source), vld4_u8(backdrop),
        vdupq_n_f32(0.25f), vdupq_n_f32(remaining), vdupq_n_f32(remaining), &output));
    vst4_u8(actual, output); reference_composite(source, backdrop, expected, 8, 0.25f);
    assert(!memcmp(expected, actual, 8 * 4));
#endif
    printf("Byte opacity: %zu large-span/alias pixels and halfway guards passed\n", pixels);
}

static void *test_concurrent_spans(void *argument)
{
    uint32_t seed = 0xa398d751u + (uint32_t)(uintptr_t)argument;
    uint8_t source[256 * 4], backdrop[256 * 4], expected[256 * 4], actual[256 * 4];
    for (int iteration = 0; iteration < 128; ++iteration) {
        for (size_t i = 0; i < sizeof(source); ++i) {
            seed = seed * 1664525u + 1013904223u; source[i] = seed >> 24;
            seed = seed * 1664525u + 1013904223u; backdrop[i] = seed >> 24;
        }
        const size_t counts[] = {31, 32, 33, 64, 128, 256};
        size_t count = counts[iteration % 6];
        float opacity = iteration % 2 ? 0.37f : 0.5f;
        reference_composite(source, backdrop, expected, count, opacity);
        native_composite_opacity_pixels(source, backdrop, actual, count, opacity);
        assert(!memcmp(expected, actual, count * 4));
    }
    return NULL;
}

int main(void)
{
    // Race first-use policy initialization with independent buffers. Retain
    // exact oracle behavior on both sides of the short-span threshold.
    pthread_t threads[4];
    for (uintptr_t i = 0; i < 4; ++i)
        assert(pthread_create(&threads[i], NULL, test_concurrent_spans, (void *)i) == 0);
    for (size_t i = 0; i < 4; ++i) assert(pthread_join(threads[i], NULL) == 0);
    puts("Byte opacity: 512 concurrent first-use/span-boundary comparisons passed");
    test_composite();
    test_bounds();
    test_byte_opacity_large_spans();
    return 0;
}
