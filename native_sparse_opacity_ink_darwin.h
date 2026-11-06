#ifndef VOX_NATIVE_SPARSE_OPACITY_INK_DARWIN_H
#define VOX_NATIVE_SPARSE_OPACITY_INK_DARWIN_H
#include "native_opacity_group_darwin.h"
#include "native_opacity_canvas_pool_darwin.h"
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <unistd.h>

// Only dedicated anonymous mappings owned by these adapters qualify. After a
// synchronous draw/flush, a page with no backing in its VM object/shadow chain is
// still zero-fill. Do not read it merely to discover transparent pixels.
// Resident, compressed and all other nonzero dispositions retain the ordinary
// byte scan. Query failure also falls back to that scan.
VOX_NATIVE_STATE int vox_opacity_backed_band_reported;

// 0: all queried pages are untouched; 1: every queried page may contain ink;
// 2: mixed. Only the requested interval matters, not padding outside the crop.
static int native_opacity_row_backing_kind(const int *dispositions, size_t page,
    size_t pitch, int left, int right, int y)
{
    size_t row = (size_t)y * pitch;
    size_t index = (row + (size_t)left * 4) / page;
    size_t end = row + (size_t)right * 4;
    int kind = dispositions[index] != 0;
    for (size_t limit = (index + 1) * page; limit < end; limit += page) {
        if ((dispositions[++index] != 0) != kind) return 2;
    }
    return kind;
}

static int native_opacity_canvas_ink_bounds(VoxOpacityCanvas canvas, size_t pitch,
    int left, int top, int right, int bottom, int *ink_left, int *ink_top,
    int *ink_right, int *ink_bottom)
{
    size_t bytes = native_opacity_canvas_bytes(canvas);
    long page = sysconf(_SC_PAGESIZE);
    if (bytes < VOX_OPACITY_CANVAS_MAPPED_MIN_BYTES || page <= 0 || page % 4 != 0
        || (uintptr_t)canvas.pixels % (size_t)page != 0
        || pitch != CGBitmapContextGetBytesPerRow(canvas.context))
        return native_opacity_layer_ink_bounds(canvas.pixels, pitch, left, top,
            right, bottom, ink_left, ink_top, ink_right, ink_bottom);
    if (left < 0 || top < 0 || left >= right || top >= bottom
        || (size_t)right > CGBitmapContextGetWidth(canvas.context)
        || (size_t)bottom > CGBitmapContextGetHeight(canvas.context)) return 0;
    size_t pages = (bytes - 1) / (size_t)page + 1;
    if (pages > SIZE_MAX / sizeof(int)) return 0;
    int *dispositions = (int *)malloc(pages * sizeof(int));
    mach_vm_size_t count = pages;
    if (!dispositions || mach_vm_page_range_query(mach_task_self(),
            (mach_vm_offset_t)canvas.pixels, bytes, (mach_vm_address_t)dispositions,
            &count) != KERN_SUCCESS || count != pages) {
        free(dispositions);
        return native_opacity_layer_ink_bounds(canvas.pixels, pitch, left, top,
            right, bottom, ink_left, ink_top, ink_right, ink_bottom);
    }
    int found = 0, min_x = right, min_y = bottom, max_x = left, max_y = top;
    size_t untouched = 0, inspected = 0;
    const int group_rows = right - left >= 64 && bottom - top >= 4
        && native_opacity_margin_bounds_enabled();
    for (int y = top; y < bottom; ++y) {
        if (group_rows) {
            int kind = native_opacity_row_backing_kind(dispositions, (size_t)page,
                pitch, left, right, y);
            if (kind == 0) {
                untouched += (size_t)(right - left) * 4;
                continue;
            }
            if (kind == 1) {
                int band_end = y + 1;
                while (band_end < bottom && native_opacity_row_backing_kind(dispositions,
                        (size_t)page, pitch, left, right, band_end) == 1) ++band_end;
                // Every requested pixel was eligible for the old byte scan.
                // Keep its byte accounting, but let one bounds call omit the
                // bounded interior of this whole band. Untouched pages and
                // unrequested padding are never read.
                inspected += (size_t)(right - left) * 4 * (size_t)(band_end - y);
                int x0, y0, x1, y1;
                if (native_opacity_layer_ink_bounds(canvas.pixels, pitch,
                        left, y, right, band_end, &x0, &y0, &x1, &y1)) {
                    found = 1;
                    if (x0 < min_x) min_x = x0;
                    if (x1 > max_x) max_x = x1;
                    if (y0 < min_y) min_y = y0;
                    if (y1 > max_y) max_y = y1;
                }
                if (band_end - y >= 4
                    && !__atomic_exchange_n(&vox_opacity_backed_band_reported, 1, __ATOMIC_RELAXED)) {
                    const char *diagnostics = getenv("VOX_OPACITY_MARGIN_BOUNDS_DIAGNOSTICS");
                    if (diagnostics && *diagnostics)
                        fprintf(stderr, "Vox opacity backed bands: coalesced rows=%d\n", band_end - y);
                }
                y = band_end - 1;
                continue;
            }
        }
        size_t row = (size_t)y * pitch;
        size_t offset = row + (size_t)left * 4, end = row + (size_t)right * 4;
        while (offset < end) {
            size_t index = offset / (size_t)page;
            size_t limit = (index + 1) * (size_t)page;
            if (limit > end) limit = end;
            if (dispositions[index] != 0) {
                inspected += limit - offset;
                int x0, y0, x1, y1;
                if (native_opacity_layer_ink_bounds(canvas.pixels, pitch,
                        (int)((offset - row) / 4), y, (int)((limit - row) / 4), y + 1,
                        &x0, &y0, &x1, &y1)) {
                    found = 1;
                    if (x0 < min_x) min_x = x0;
                    if (x1 > max_x) max_x = x1;
                    if (y0 < min_y) min_y = y0;
                    if (y1 > max_y) max_y = y1;
                }
            } else untouched += limit - offset;
            offset = limit;
        }
    }
    free(dispositions);
    if (getenv("VOX_SPARSE_BITMAP_INK_DIAGNOSTICS"))
        fprintf(stderr, "VOX_SPARSE_BITMAP_INK queried_bytes=%zu untouched_bytes=%zu inspected_bytes=%zu\n",
            bytes, untouched, inspected);
    if (!found) return 0;
    *ink_left = min_x; *ink_top = min_y;
    *ink_right = max_x; *ink_bottom = max_y;
    return 1;
}
#endif
