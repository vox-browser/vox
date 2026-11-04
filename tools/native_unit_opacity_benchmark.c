// Component diagnostic, not browser acceptance: current-process retired
// instructions cover only repeated compositing, excluding input generation.
#include "../native_opacity_group_darwin.h"
#include "../processmetrics/instruction_counter_darwin.h"
#include <assert.h>
#include <string.h>

__attribute__((noinline)) static void composite(const uint8_t *source,
    const uint8_t *background, uint8_t *result, size_t count)
{
    native_composite_opacity_pixels(source, background, result, count, 1.0f);
}

int main(void)
{
    enum { width = 2048, height = 128, passes = 8 };
    size_t bytes = (size_t)width * height * 4;
    uint8_t *source = malloc(bytes), *background = malloc(bytes), *result = malloc(bytes);
    assert(source && background && result);
    const char *names[] = {"mixed", "mixed-empty-opaque", "sparse", "opaque", "empty"};
    for (int scene = 0; scene < 5; ++scene) {
        for (size_t i = 0; i < bytes / 4; ++i) {
            unsigned alpha = 1 + (i * 73 + i / width * 37) % 254;
            if (scene == 1 && i / 8 % 3 != 0) alpha = i / 8 % 3 == 1 ? 0 : 255;
            if (scene == 2 && i / 8 % 16 != 0) alpha = 0;
            if (scene == 3) alpha = 255;
            if (scene == 4) alpha = 0;
            for (size_t c = 0; c < 3; ++c) {
                source[i * 4 + c] = (i * 29 + c * 61) % (alpha + 1);
                background[i * 4 + c] = i * 37 + c * 19;
            }
            source[i * 4 + 3] = alpha; background[i * 4 + 3] = 255;
        }
        uint64_t before = 0, after = 0;
        assert(vox_process_instructions(&before) == 0);
        for (int pass = 0; pass < passes; ++pass)
            for (int row = 0; row < height; ++row) {
                size_t first = (size_t)row * width * 4;
                composite(source + first, background + first, result + first, width);
            }
        assert(vox_process_instructions(&after) == 0 && after >= before);
        uint64_t checksum = 0;
        for (size_t i = 0; i < bytes; ++i) checksum = checksum * 31 + result[i];
        printf("{\"scene\":\"%s\",\"instructions\":%llu,\"checksum\":%llu,\"pixels\":%zu}\n",
            names[scene], (unsigned long long)(after - before), (unsigned long long)checksum,
            (size_t)width * height * passes);
    }
    free(source); free(background); free(result);
    return 0;
}
