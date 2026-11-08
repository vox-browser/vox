#ifndef VOX_NATIVE_RASTER_ROW_RANGES_H
#define VOX_NATIVE_RASTER_ROW_RANGES_H
#include <stddef.h>

typedef struct {
    size_t first, count;
} VoxRasterRowRange;

// Form the union of bounded row intervals in place. Callers keep a small,
// fixed-size list; insertion sorting needs no allocation or document bitmap.
static size_t vox_union_raster_rows(VoxRasterRowRange *ranges, size_t count, size_t height) {
    size_t valid = 0;
    for (size_t index = 0; index < count; ++index) {
        VoxRasterRowRange range = ranges[index];
        if (!range.count || range.first >= height) continue;
        if (range.count > height - range.first) range.count = height - range.first;
        size_t position = valid;
        while (position && ranges[position - 1].first > range.first) {
            ranges[position] = ranges[position - 1];
            --position;
        }
        ranges[position] = range;
        ++valid;
    }
    size_t merged = 0;
    for (size_t index = 0; index < valid; ++index) {
        VoxRasterRowRange range = ranges[index];
        if (merged && range.first <= ranges[merged - 1].first + ranges[merged - 1].count) {
            VoxRasterRowRange *previous = &ranges[merged - 1];
            size_t end = range.first + range.count;
            if (end > previous->first + previous->count) previous->count = end - previous->first;
        } else {
            ranges[merged++] = range;
        }
    }
    return merged;
}
#endif
