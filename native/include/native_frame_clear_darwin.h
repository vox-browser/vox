#ifndef VOX_NATIVE_FRAME_CLEAR_DARWIN_H
#define VOX_NATIVE_FRAME_CLEAR_DARWIN_H

#include <dispatch/dispatch.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    uint8_t *pixels;
    size_t row_bytes, pitch, rows, lanes;
    uint8_t value;
} VoxFrameClear;

static void vox_frame_clear_range(void *context, size_t lane) {
    const VoxFrameClear *clear = (const VoxFrameClear *)context;
    size_t first = clear->rows * lane / clear->lanes;
    size_t end = clear->rows * (lane + 1) / clear->lanes;
    uint8_t *row = clear->pixels + first * clear->pitch;
    if (clear->row_bytes == clear->pitch) {
        memset(row, clear->value, (end - first) * clear->row_bytes);
        return;
    }
    for (size_t y = first; y < end; ++y)
        memset(clear->pixels + y * clear->pitch, clear->value, clear->row_bytes);
}

static size_t vox_frame_clear_lanes(size_t row_bytes, size_t rows) {
    size_t available = row_bytes * rows / (2u * 1024u * 1024u);
    if (available > 4) available = 4;
    return available > rows ? rows : available;
}

// The caller owns the bitmap until this returns. Assign whole rows and
// leave padding alone unless the caller includes it in row_bytes.
static size_t vox_fill_frame_rows(uint8_t *pixels, size_t row_bytes, size_t pitch, size_t rows,
    uint8_t value) {
    if (!pixels || !row_bytes || row_bytes > pitch || !rows || pitch > SIZE_MAX / rows) return 0;
    VoxFrameClear clear = {pixels, row_bytes, pitch, rows, 1, value};
    size_t available = vox_frame_clear_lanes(row_bytes, rows);
    if (available > 1 && !getenv("VOX_SERIAL_FRAME_CLEAR")) {
        clear.lanes = available;
        dispatch_apply_f(clear.lanes, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),
            &clear, vox_frame_clear_range);
    } else {
        vox_frame_clear_range(&clear, 0);
    }
    return clear.lanes;
}

static void vox_clear_frame_rows(uint8_t *pixels, size_t row_bytes, size_t pitch, size_t rows) {
    size_t lanes = vox_fill_frame_rows(pixels, row_bytes, pitch, rows, 255);
    if (lanes && getenv("VOX_PARALLEL_FRAME_CLEAR_DIAGNOSTICS"))
        fprintf(stderr, "VOX_FRAME_CLEAR rows=%zu row_bytes=%zu lanes=%zu\n",
            rows, row_bytes, lanes);
}

#endif
