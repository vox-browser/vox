#ifndef VOX_NATIVE_JPEGXL_H
#define VOX_NATIVE_JPEGXL_H
#include <stdint.h>
#include <stddef.h>

#if !defined(_WIN32)
#include <dlfcn.h>
#include <pthread.h>
#include "../../platform/native_state.h"
typedef struct {
    uint32_t (*version)(void);
    uint8_t *(*decode)(const uint8_t *, uint64_t, int32_t *, int32_t *, int32_t *);
    uint8_t *(*decode_paint)(const uint8_t *, uint64_t, int32_t *, int32_t *, int32_t *);
    void (*release)(uint8_t *, uint64_t);
} VoxJPEGXLAPI;
VOX_NATIVE_STATE VoxJPEGXLAPI vox_jxl_api;
VOX_NATIVE_STATE pthread_once_t vox_jpegxl_load_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
static void vox_jpegxl_load(void)
{
    // Prefer the helper beside the pinned executable over mutable build outputs.
    const char *names[] = {"@executable_path/libVoxJPEGXL.dylib",
        "@rpath/libVoxJPEGXL.dylib", "libVoxJPEGXL.dylib", "libVoxJPEGXL.so"};
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
        void *library = dlopen(names[i], RTLD_NOW | RTLD_LOCAL);
        if (!library) continue;
        VoxJPEGXLAPI api = {0};
        api.version = (uint32_t (*)(void))dlsym(library, "vox_jpegxl_rust_api_version");
        api.decode = (uint8_t *(*)(const uint8_t *, uint64_t, int32_t *, int32_t *, int32_t *))
            dlsym(library, "vox_jpegxl_rust_decode");
        api.decode_paint = (uint8_t *(*)(const uint8_t *, uint64_t, int32_t *, int32_t *, int32_t *))
            dlsym(library, "vox_jpegxl_rust_decode_paint");
        api.release = (void (*)(uint8_t *, uint64_t))dlsym(library, "vox_jpegxl_rust_free");
        if (api.version && api.decode && api.decode_paint && api.release && api.version() == 1) {
            vox_jxl_api = api;
            return;
        }
        dlclose(library);
    }
}
static int vox_jpegxl_available(void)
{
    pthread_once(&vox_jpegxl_load_once, vox_jpegxl_load);
    return vox_jxl_api.decode != NULL;
}
static uint8_t *vox_jpegxl_decode_rgba(const uint8_t *bytes, uint64_t length,
    int32_t *width, int32_t *height, int32_t *pitch)
{
    if (width) *width = 0;
    if (height) *height = 0;
    if (pitch) *pitch = 0;
    if (!width || !height || !pitch || !vox_jpegxl_available()) return NULL;
    return vox_jxl_api.decode(bytes, length, width, height, pitch);
}
static uint8_t *vox_jpegxl_decode_paint_rgba(const uint8_t *bytes, uint64_t length,
    int32_t *width, int32_t *height, int32_t *pitch)
{
    if (width) *width = 0;
    if (height) *height = 0;
    if (pitch) *pitch = 0;
    if (!width || !height || !pitch || !vox_jpegxl_available()) return NULL;
    return vox_jxl_api.decode_paint(bytes, length, width, height, pitch);
}
static void vox_jpegxl_free(uint8_t *pixels, uint64_t length)
{
    if (pixels && vox_jpegxl_available()) vox_jxl_api.release(pixels, length);
}
#else
static int vox_jpegxl_available(void) { return 0; }
static uint8_t *vox_jpegxl_decode_rgba(const uint8_t *bytes, uint64_t length,
    int32_t *width, int32_t *height, int32_t *pitch)
{
    (void)bytes; (void)length;
    if (width) *width = 0;
    if (height) *height = 0;
    if (pitch) *pitch = 0;
    return NULL;
}
static uint8_t *vox_jpegxl_decode_paint_rgba(const uint8_t *bytes, uint64_t length,
    int32_t *width, int32_t *height, int32_t *pitch)
{ return vox_jpegxl_decode_rgba(bytes, length, width, height, pitch); }
static void vox_jpegxl_free(uint8_t *pixels, uint64_t length) { (void)pixels; (void)length; }
#endif
#endif
