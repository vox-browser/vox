// Isolated scan-region diagnostic. This does not execute V bounds lowering or
// establish browser savings. Both regions must find the same synthetic ink.
#include "../native/include/native_sparse_opacity_ink_darwin.h"
#include "../processmetrics/instruction_counter_darwin.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    const char *control = getenv("VOX_RETAIN_UNBOUNDED_BORDER_EFFECTS");
    int unbounded = control && *control;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    for (int density = 1; density <= 2; ++density) {
        int width = 1024 * density, height = 768 * density;
        for (int resident = 0; resident <= 1; ++resident) {
            VoxOpacityCanvas canvas = native_acquire_opacity_canvas(width, height, space);
            assert(canvas.context);
            size_t pitch = CGBitmapContextGetBytesPerRow(canvas.context);
            if (resident) memset(canvas.pixels, 0, pitch * height);
            // Ink enclosed by the V test's (16,26)-(104,84) candidate bounds.
            // The complete stroke/background output is identical in both modes.
            for (int y = 28 * density; y < 82 * density; ++y)
                for (int x = 18 * density; x < 102 * density; ++x) {
                    uint8_t *p = canvas.pixels + y * pitch + x * 4;
                    p[0] = 17; p[1] = 29; p[2] = 41; p[3] = 128;
                }
            uint64_t before = 0, after = 0, checksum = 0;
            assert(vox_process_instructions(&before) == 0);
            for (int pass = 0; pass < 64; ++pass) {
                int left, top, right, bottom;
                assert(native_opacity_canvas_ink_bounds(canvas, pitch,
                    unbounded ? 0 : 16 * density, unbounded ? 0 : 26 * density,
                    unbounded ? width : 104 * density, unbounded ? height : 84 * density,
                    &left, &top, &right, &bottom));
                assert(left == 18 * density && top == 28 * density
                    && right == 102 * density && bottom == 82 * density);
                checksum += (uint64_t)(left + top + right + bottom);
            }
            assert(vox_process_instructions(&after) == 0 && after >= before);
            printf("{\"scene\":\"%s-%d\",\"instructions\":%llu,\"checksum\":%llu,\"scans\":64}\n",
                resident ? "resident" : "sparse", density,
                (unsigned long long)(after - before), (unsigned long long)checksum);
            native_release_opacity_canvas(canvas, 0, 0, width, height);
            native_discard_opacity_canvas_pool();
        }
    }
    CGColorSpaceRelease(space);
    return 0;
}
