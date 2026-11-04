#ifndef VOX_NATIVE_AVIF_H
#define VOX_NATIVE_AVIF_H
#include <stdint.h>
#include <stddef.h>
#if defined(__APPLE__) || defined(__linux__)
#include <dlfcn.h>
#include <pthread.h>
#if defined(__linux__)
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#endif
typedef struct {
    int (*sniff)(const uint8_t *, uint64_t);
    uint8_t *(*decode)(const uint8_t *, uint64_t, int, int32_t *, int32_t *, int32_t *);
    void (*release)(uint8_t *);
} VoxAVIFAPI;
static VoxAVIFAPI vox_avif_api;
static void vox_avif_load(void)
{
#if defined(__APPLE__)
    const char *names[] = {"@executable_path/libVoxAVIF.dylib", "@rpath/libVoxAVIF.dylib"};
#else
    char sibling[PATH_MAX] = {0};
    ssize_t count = readlink("/proc/self/exe", sibling, sizeof(sibling) - 1);
    char *slash = count > 0 ? strrchr(sibling, '/') : NULL;
    if (slash) snprintf(slash + 1, sizeof(sibling) - (size_t)(slash + 1 - sibling), "libVoxAVIF.so");
    const char *names[] = {sibling, "libVoxAVIF.so"};
#endif
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
        if (!names[i][0]) continue;
        void *library = dlopen(names[i], RTLD_NOW | RTLD_LOCAL);
        if (!library) continue;
        uint32_t (*version)(void) = (uint32_t (*)(void))dlsym(library, "vox_avif_api_version");
        VoxAVIFAPI api = {0};
        api.sniff = (int (*)(const uint8_t *, uint64_t))dlsym(library, "vox_avif_sniff");
        api.decode = (uint8_t *(*)(const uint8_t *, uint64_t, int, int32_t *, int32_t *, int32_t *))
            dlsym(library, "vox_avif_decode");
        api.release = (void (*)(uint8_t *))dlsym(library, "vox_avif_free");
        if (version && version() == 1 && api.sniff && api.decode && api.release) {
            vox_avif_api = api;
            return;
        }
        dlclose(library);
    }
}
static int vox_avif_available(void)
{
    static pthread_once_t once = PTHREAD_ONCE_INIT;
    pthread_once(&once, vox_avif_load);
    return vox_avif_api.decode != NULL;
}
static int vox_avif_is_avif(const uint8_t *bytes, uint64_t length)
{ return vox_avif_available() && vox_avif_api.sniff(bytes, length); }
static uint8_t *vox_avif_decode_rgba(const uint8_t *bytes, uint64_t length, int premultiply,
    int32_t *width, int32_t *height, int32_t *pitch)
{
    if (width) *width = 0;
    if (height) *height = 0;
    if (pitch) *pitch = 0;
    if (!width || !height || !pitch || !vox_avif_available()) return NULL;
    return vox_avif_api.decode(bytes, length, premultiply, width, height, pitch);
}
static void vox_avif_release(uint8_t *pixels)
{ if (pixels && vox_avif_available()) vox_avif_api.release(pixels); }
#else
static int vox_avif_available(void) { return 0; }
static int vox_avif_is_avif(const uint8_t *bytes, uint64_t length) { (void)bytes; (void)length; return 0; }
static uint8_t *vox_avif_decode_rgba(const uint8_t *bytes, uint64_t length, int premultiply,
    int32_t *width, int32_t *height, int32_t *pitch)
{
    (void)bytes; (void)length; (void)premultiply;
    if (width) *width = 0;
    if (height) *height = 0;
    if (pitch) *pitch = 0;
    return NULL;
}
static void vox_avif_release(uint8_t *pixels) { (void)pixels; }
#endif
#endif
