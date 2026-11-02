#pragma once

#ifdef LADYBIRD_V_HAS_SNAPSHOT_DEFLATE
#include <libdeflate.h>

// The capture bridge discovers this optional service from its loaded native
// renderer. Keep compression ownership local and preserve zlib fallback.
extern "C" __attribute__((visibility("default")))
size_t ladybird_v_snapshot_compress_zlib(void const* input, size_t size,
    void* output, size_t capacity)
{
    if (!input || !output || !size || size > 64 * 1024 * 1024 || !capacity) return 0;
    auto* compressor = libdeflate_alloc_compressor(1);
    if (!compressor) return 0;
    size_t written = libdeflate_zlib_compress(compressor, input, size, output, capacity);
    libdeflate_free_compressor(compressor);
    return written;
}
#endif
