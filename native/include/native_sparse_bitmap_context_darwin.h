#ifndef VOX_NATIVE_SPARSE_BITMAP_CONTEXT_DARWIN_H
#define VOX_NATIVE_SPARSE_BITMAP_CONTEXT_DARWIN_H
#include <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/mman.h>
#include "../../platform/native_state.h"

// Dedicated anonymous storage gives the sparse ink query a known zero-fill
// object. The CGContext owns it through its release callback, including when
// an immutable image/provider keeps the completed context alive.
typedef struct {
    void *pixels;
    size_t bytes;
    int references, callback_fired;
} VoxSparseBitmapStorage;

#ifdef VOX_TEST_SPARSE_BITMAP_CONTEXT
VOX_NATIVE_STATE size_t native_test_sparse_bitmap_live_bytes;
VOX_NATIVE_STATE unsigned native_test_sparse_bitmap_releases;
#endif

static void native_sparse_bitmap_release(VoxSparseBitmapStorage *storage) {
    if (__atomic_sub_fetch(&storage->references, 1, __ATOMIC_ACQ_REL)) return;
    munmap(storage->pixels, storage->bytes);
#ifdef VOX_TEST_SPARSE_BITMAP_CONTEXT
    __atomic_fetch_sub(&native_test_sparse_bitmap_live_bytes, storage->bytes, __ATOMIC_RELAXED);
    __atomic_fetch_add(&native_test_sparse_bitmap_releases, 1, __ATOMIC_RELAXED);
#endif
    free(storage);
}

static void native_sparse_bitmap_context_released(void *info, void *pixels) {
    (void)pixels;
    VoxSparseBitmapStorage *storage = (VoxSparseBitmapStorage *)info;
    __atomic_store_n(&storage->callback_fired, 1, __ATOMIC_RELEASE);
    native_sparse_bitmap_release(storage);
}

static CGContextRef native_create_sparse_bitmap_context(size_t width, size_t height,
    CGColorSpaceRef color) {
    if (!width || !height || width > SIZE_MAX / 4
        || height > 64 * 1024 * 1024 / (width * 4)) return NULL;
    size_t bytes = width * 4 * height;
    if (bytes < 1024 * 1024) return NULL;
    void *pixels = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (pixels == MAP_FAILED) return NULL;
    VoxSparseBitmapStorage *storage = (VoxSparseBitmapStorage *)calloc(1, sizeof(*storage));
    if (!storage) { munmap(pixels, bytes); return NULL; }
    *storage = (VoxSparseBitmapStorage){.pixels = pixels, .bytes = bytes, .references = 2};
#ifdef VOX_TEST_SPARSE_BITMAP_CONTEXT
    __atomic_fetch_add(&native_test_sparse_bitmap_live_bytes, bytes, __ATOMIC_RELAXED);
#endif
    CGContextRef context = CGBitmapContextCreateWithData(pixels, width, height,
        8, width * 4, color, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
        native_sparse_bitmap_context_released, storage);
    // Keep the creating reference until CoreGraphics has finished its failure
    // cleanup, whether or not it invoked the data-release callback.
    if (!context && !__atomic_load_n(&storage->callback_fired, __ATOMIC_ACQUIRE))
        native_sparse_bitmap_release(storage);
    native_sparse_bitmap_release(storage);
    return context;
}
#endif
