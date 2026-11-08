// Component diagnostic only: fresh-process instruction counts cover repeated
// compositing, excluding input generation, the independent oracle and checksum.
#include "../native/include/native_opacity_group_darwin.h"
#include "../processmetrics/instruction_counter_darwin.h"
#include <assert.h>
#include <string.h>

__attribute__((noinline)) static void composite(const uint8_t *source,
    const uint8_t *background, uint8_t *result, size_t count, float opacity)
{
    native_composite_opacity_pixels(source, background, result, count, opacity);
}

static void reference(const uint8_t *source, const uint8_t *background,
    uint8_t *result, size_t count, float opacity)
{
#pragma clang fp contract(off)
    for (size_t i = 0; i < count; ++i) {
        float remaining = 1.0f - ((float)source[i * 4 + 3] / 255.0f) * opacity;
        for (size_t c = 0; c < 4; ++c) {
            float s = ((float)source[i * 4 + c] / 255.0f) * opacity;
            float d = (float)background[i * 4 + c] / 255.0f;
            double value = nearbyint((double)fmaf(d, remaining, s) * 255.0);
            result[i * 4 + c] = value <= 0 ? 0 : value >= 255 ? 255 : (uint8_t)value;
        }
    }
}

int main(int argc, char **argv)
{
    enum { width = 2048, height = 128, passes = 8 };
    size_t requested_span = argc > 1 ? strtoul(argv[1], NULL, 10) : 0;
    assert(argc <= 2 && (!requested_span || (requested_span <= width && width % requested_span == 0)));
    size_t bytes = (size_t)width * height * 4;
    uint8_t *source = malloc(bytes), *background = malloc(bytes);
    uint8_t *result = malloc(bytes), *expected = malloc(bytes);
    assert(source && background && result && expected);
    const char *names[] = {"mixed", "mixed-empty-opaque", "opaque",
        "halfway-fallback", "short-spans", "unit-opacity", "empty"};
    for (int scene = 0; scene < 7; ++scene) {
        float opacity = scene == 3 ? 0.5f : scene == 5 ? 1.0f : 0.37f;
        size_t span = requested_span ? requested_span : scene == 4 ? 128 : width;
        for (size_t i = 0; i < bytes / 4; ++i) {
            unsigned alpha = 1 + (i * 73 + i / width * 37) % 254;
            if (scene == 1 && i / 8 % 3 != 0) alpha = i / 8 % 3 == 1 ? 0 : 255;
            if (scene == 2 || scene == 3) alpha = 255;
            if (scene == 6) alpha = 0;
            for (size_t c = 0; c < 3; ++c) {
                source[i * 4 + c] = scene == 3 ? 0 : (i * 29 + c * 61) % (alpha + 1);
                background[i * 4 + c] = scene == 3 ? 33 : i * 37 + c * 19;
            }
            source[i * 4 + 3] = alpha; background[i * 4 + 3] = 255;
        }
        reference(source, background, expected, bytes / 4, opacity);
        uint64_t before = 0, after = 0;
        assert(vox_process_instructions(&before) == 0);
        for (int pass = 0; pass < passes; ++pass)
            for (size_t first = 0; first < bytes; first += span * 4)
                composite(source + first, background + first, result + first, span, opacity);
        assert(vox_process_instructions(&after) == 0 && after >= before);
        assert(!memcmp(result, expected, bytes));
        uint64_t checksum = 0;
        for (size_t i = 0; i < bytes; ++i) checksum = checksum * 31 + result[i];
        printf("{\"scene\":\"%s\",\"instructions\":%llu,\"checksum\":%llu,\"pixels\":%zu,\"span\":%zu}\n",
            names[scene], (unsigned long long)(after - before), (unsigned long long)checksum,
            (size_t)width * height * passes, span);
    }
    free(source); free(background); free(result); free(expected);
    return 0;
}
