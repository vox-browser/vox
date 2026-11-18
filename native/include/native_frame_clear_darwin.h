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
} VoxFrameClear;

static void vox_frame_clear_range(void *context, size_t lane) {
    const VoxFrameClear *clear = (const VoxFrameClear *)context;
    size_t first = clear->rows * lane / clear->lanes;
    size_t end = clear->rows * (lane + 1) / clear->lanes;
    uint8_t *row = clear->pixels + first * clear->pitch;
    if (clear->row_bytes == clear->pitch) {
        memset(row, 255, (end - first) * clear->row_bytes);
        return;
    }
    for (size_t y = first; y < end; ++y)
        memset(clear->pixels + y * clear->pitch, 255, clear->row_bytes);
}

// The caller has flushed Quartz and owns the bitmap until this returns.
// Assign whole rows so workers preserve both pitch padding and paint order.
static void vox_clear_frame_rows(uint8_t *pixels, size_t row_bytes, size_t pitch, size_t rows) {
    if (!pixels || !row_bytes || row_bytes > pitch || !rows || pitch > SIZE_MAX / rows) return;
    VoxFrameClear clear = {pixels, row_bytes, pitch, rows, 1};
    size_t available = row_bytes * rows / (2u * 1024u * 1024u);
    if (available > 4) available = 4;
    if (available > rows) available = rows;
    if (available > 1 && !getenv("VOX_SERIAL_FRAME_CLEAR")) {
        clear.lanes = available;
        dispatch_apply_f(clear.lanes, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),
            &clear, vox_frame_clear_range);
    } else {
        vox_frame_clear_range(&clear, 0);
    }
    if (getenv("VOX_PARALLEL_FRAME_CLEAR_DIAGNOSTICS"))
        fprintf(stderr, "VOX_FRAME_CLEAR rows=%zu row_bytes=%zu lanes=%zu\n",
            rows, row_bytes, clear.lanes);
}

#endif
