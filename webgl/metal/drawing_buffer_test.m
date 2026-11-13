#include "drawing_buffer_darwin.h"
#include <assert.h>
#include <mach-o/dyld.h>
#include <stdio.h>

static void assert_no_angle(void)
{
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        char const* name = _dyld_get_image_name(i);
        assert(!strstr(name, "libEGL") && !strstr(name, "libGLES") && !strstr(name, "libANGLE"));
    }
}

int main(void)
{
    @autoreleasepool {
        assert_no_angle();
        void* first = vox_metal_buffer_create();
        void* second = vox_metal_buffer_create();
        assert(first && second);
        assert(vox_metal_buffer_resize(first, 3, 2));
        assert(vox_metal_buffer_resize(second, 3, 2));
        uint8_t pixels[32];
        memset(pixels, 0xaa, sizeof(pixels));
        assert(!vox_metal_buffer_transfer(first, pixels + 4, 23, 0));
        for (int i = 0; i < 32; ++i) assert(pixels[i] == 0xaa);
        assert(vox_metal_buffer_transfer(first, pixels + 4, 24, 0));
        for (int i = 0; i < 32; ++i) assert(pixels[i] == (i >= 4 && i < 28 ? 0 : 0xaa));
        assert(vox_metal_buffer_clear(first, 1, 0.25, 0.5, 1));
        assert(vox_metal_buffer_transfer(first, pixels + 4, 24, 0));
        uint8_t color[] = {255, 64, 128, 255};
        for (int i = 4; i < 28; i += 4) assert(!memcmp(pixels + i, color, 4));
        for (int i = 0; i < 4; ++i) assert(pixels[i] == 0xaa && pixels[28 + i] == 0xaa);
        uint8_t rows[24];
        for (int i = 0; i < 24; ++i) rows[i] = i + 1;
        assert(!vox_metal_buffer_transfer(first, rows, 23, 1));
        assert(vox_metal_buffer_transfer(first, rows, 24, 1));
        assert(!vox_metal_buffer_resize(first, -1, 2));
        assert(!vox_metal_buffer_resize(first, 16385, 2));
        assert(vox_metal_buffer_transfer(first, pixels + 4, 24, 0));
        assert(!memcmp(rows, pixels + 4, 24));
        assert(vox_metal_buffer_transfer(second, pixels + 4, 24, 0));
        for (int i = 4; i < 28; ++i) assert(pixels[i] == 0);
        assert(vox_metal_buffer_resize(first, 2, 3));
        assert(vox_metal_buffer_transfer(first, pixels + 4, 24, 0));
        for (int i = 4; i < 28; ++i) assert(pixels[i] == 0);
        vox_metal_buffer_destroy(first);
        vox_metal_buffer_destroy(second);
        vox_metal_buffer_destroy(NULL);
        assert(!vox_metal_buffer_clear(NULL, 1, 1, 1, 1));
        assert(!vox_metal_buffer_transfer(NULL, pixels, sizeof(pixels), 0));
        for (int i = 0; i < 16; ++i) {
            void* context = vox_metal_buffer_create();
            assert(context && vox_metal_buffer_resize(context, 1, 1));
            vox_metal_buffer_destroy(context);
        }
        assert_no_angle();
        puts("PASS direct Metal GPU clear, initialized resize, bounded row transfers, ownership, lifecycle; no ANGLE loaded");
    }
    return 0;
    return 0;
}
