#include <mach/mach.h>
#include <mach/mach_vm.h>
static int query_mode;
static mach_vm_offset_t last_query_address;
static mach_vm_size_t last_query_size, last_query_capacity;
static unsigned query_calls;
static kern_return_t query_pages(vm_map_read_t task, mach_vm_offset_t address,
    mach_vm_size_t size, mach_vm_address_t output, mach_vm_size_t *count) {
    last_query_address = address;
    last_query_size = size;
    last_query_capacity = *count;
    ++query_calls;
    if (query_mode == 1) return KERN_FAILURE;
    kern_return_t status = mach_vm_page_range_query(task, address, size, output, count);
    if (status == KERN_SUCCESS && query_mode == 2)
        for (mach_vm_size_t i = 0; i < *count; ++i) ((int *)output)[i] = VM_PAGE_QUERY_PAGE_PAGED_OUT;
    if (status == KERN_SUCCESS && query_mode == 3)
        for (mach_vm_size_t i = 0; i < *count; ++i) ((int *)output)[i] = 1 << 30;
    if (status == KERN_SUCCESS && query_mode == 4 && *count) --*count;
    return status;
}
#define mach_vm_page_range_query query_pages
#include "../native_sparse_opacity_ink_darwin.h"
#undef mach_vm_page_range_query
#include <assert.h>
#include <stdio.h>

static void check_query_range(VoxOpacityCanvas canvas, size_t pitch,
    int left, int top, int right, int bottom) {
    size_t page = (size_t)sysconf(_SC_PAGESIZE), bytes = pitch * CGBitmapContextGetHeight(canvas.context);
    uintptr_t base = (uintptr_t)canvas.pixels;
    const char *retain = getenv("VOX_RETAIN_FULL_OPACITY_PAGE_QUERY");
    uintptr_t first = base, end = base + bytes;
    if (!retain || !*retain) {
        uintptr_t first_pixel = base + pitch * (size_t)top + (size_t)left * 4;
        uintptr_t final_pixel = base + pitch * (size_t)(bottom - 1) + (size_t)(right - 1) * 4;
        first = first_pixel / page * page;
        uintptr_t rounded_end = (final_pixel / page + 1) * page;
        if (rounded_end < end) end = rounded_end;
    }
    assert(query_calls == 1 && last_query_address == first && last_query_size == end - first);
    assert(last_query_capacity == (end - first + page - 1) / page);
    assert(first >= base && end <= base + bytes);
}

static uint64_t footprint(void) {
    task_vm_info_data_t info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS);
    return info.phys_footprint;
}

static void check_reference(VoxOpacityCanvas canvas, size_t pitch,
    int left, int top, int right, int bottom) {
    int expected[] = {right, bottom, left, top}, actual[] = {-1, -2, -3, -4};
    int found = 0;
    for (int y = top; y < bottom; ++y) {
        const uint32_t *row = (const uint32_t *)(canvas.pixels + (size_t)y * pitch);
        for (int x = left; x < right; ++x) {
            if (!row[x]) continue;
            found = 1;
            if (x < expected[0]) expected[0] = x;
            if (y < expected[1]) expected[1] = y;
            if (x + 1 > expected[2]) expected[2] = x + 1;
            if (y + 1 > expected[3]) expected[3] = y + 1;
        }
    }
    query_calls = 0;
    assert(native_opacity_canvas_ink_bounds(canvas, pitch, left, top, right, bottom,
        &actual[0], &actual[1], &actual[2], &actual[3]) == found);
    check_query_range(canvas, pitch, left, top, right, bottom);
    if (found) assert(!memcmp(actual, expected, sizeof(actual)));
    else assert(actual[0] == -1 && actual[1] == -2 && actual[2] == -3 && actual[3] == -4);
}

static void check_row_backing_classification(void) {
    int dispositions[512];
    size_t cases = 0;
    const int widths[] = {1, 3, 4, 17, 65};
    for (size_t page = 16; page <= 256; page *= 4)
    for (int pattern = 0; pattern < 4; ++pattern) {
        for (size_t i = 0; i < 512; ++i)
            dispositions[i] = pattern == 0 ? 0 : pattern == 1 ? VM_PAGE_QUERY_PAGE_PAGED_OUT
                : (i % (size_t)(pattern + 1) == 0 ? 1 << 30 : 0);
        for (size_t wi = 0; wi < sizeof(widths) / sizeof(widths[0]); ++wi)
        for (size_t padding = 0; padding < 4; ++padding)
        for (int y = 0; y < 8; ++y) {
            int width = widths[wi];
            size_t pitch = ((size_t)width + padding) * 4;
            for (int left = 0; left < width; ++left)
            for (int right = left + 1; right <= width; ++right) {
                int zero = 0, backed = 0;
                for (int x = left; x < right; ++x) {
                    if (dispositions[((size_t)y * pitch + (size_t)x * 4) / page]) backed = 1;
                    else zero = 1;
                }
                assert(native_opacity_row_backing_kind(dispositions, page, 0, pitch, left, right, y)
                    == (backed && zero ? 2 : backed));
                // A cropped metadata array begins at a real page inside the
                // canvas. Index relative to that page, with no pointer before
                // the array even when the crop begins well after row zero.
                size_t first_page = ((size_t)y * pitch + (size_t)left * 4) / page;
                assert(native_opacity_row_backing_kind(dispositions + first_page,
                    page, first_page, pitch, left, right, y) == (backed && zero ? 2 : backed));
                ++cases;
            }
        }
    }
    printf("%zu exact cropped row-backing classifications pass\n", cases);
}

int main(void) {
    check_row_backing_classification();
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    VoxOpacityCanvas canvas = native_acquire_opacity_canvas(3456, 2106, space);
    assert(canvas.context);
    // Nonzero RGB with alpha zero is still included, exactly as in the old scan.
    canvas.pixels[11 * 3456 * 4 + 7 * 4] = 31;
    canvas.pixels[12 * 3456 * 4 + 9 * 4 + 3] = 255;
    int left, top, right, bottom;
    uint64_t before = footprint();
    assert(native_opacity_canvas_ink_bounds(canvas, 3456 * 4, 0, 0, 3456, 2106,
        &left, &top, &right, &bottom));
    uint64_t after = footprint();
    assert(left == 7 && top == 11 && right == 10 && bottom == 13);
    printf("Sparse viewport ink scan footprint growth: %lld bytes\n", (long long)(after - before));
    fflush(stdout);
    assert(after < before + 4 * 1024 * 1024);
    int l0, t0, r0, b0;
    assert(native_opacity_layer_ink_bounds(canvas.pixels, 3456 * 4, 0, 0, 3456, 2106,
        &l0, &t0, &r0, &b0));
    assert(left == l0 && top == t0 && right == r0 && bottom == b0);
    native_release_opacity_canvas(canvas, 0, 0, 3456, 2106);
    canvas = native_acquire_opacity_canvas(3456, 2106, space);
    assert(!native_opacity_canvas_ink_bounds(canvas, 3456 * 4, 0, 0, 3456, 2106,
        &left, &top, &right, &bottom));
    native_release_opacity_canvas(canvas, 0, 0, 3456, 2106);
    native_discard_opacity_canvas_pool();
    size_t cases = 0;
    for (size_t width = 509; width <= 517; width += 4) {
        const size_t height = 709, pitch = width * 4;
        canvas = native_acquire_opacity_canvas(width, height, space);
        assert(canvas.context);
        for (size_t i = 0; i < width * height * 4; i += 16381)
            canvas.pixels[i] = (uint8_t)(i % 255 + 1);
        for (query_mode = 0; query_mode <= 4; ++query_mode)
        for (int y = 0; y < 709; y += 71) for (int x = 0; x < (int)width; x += 53) {
            query_calls = 0;
            int found = native_opacity_canvas_ink_bounds(canvas, pitch, x, y, (int)width, 709,
                &left, &top, &right, &bottom);
            check_query_range(canvas, pitch, x, y, (int)width, 709);
            int expected = native_opacity_layer_ink_bounds(canvas.pixels, pitch, x, y, (int)width, 709,
                &l0, &t0, &r0, &b0);
            assert(found == expected);
            if (found) assert(left == l0 && top == t0 && right == r0 && bottom == b0);
            ++cases;
        }
        native_release_opacity_canvas(canvas, 0, 0, width, height);
        native_discard_opacity_canvas_pool();
    }
    query_mode = 0;

    // Nonzero origins and last partial pages exercise both endpoint rounding
    // and crop-relative metadata indices. Fully backed, sparse and empty data
    // agree with a separate scalar pixel oracle under every query outcome.
    for (int pattern = 0; pattern < 3; ++pattern) {
        const int width = 1021, height = 311;
        size_t pitch = (size_t)width * 4;
        canvas = native_acquire_opacity_canvas(width, height, space);
        assert(canvas.context);
        if (pattern == 0) memset(canvas.pixels, 0, pitch * height);
        if (pattern != 2) {
            ((uint32_t *)(canvas.pixels + 93 * pitch))[207] = 0x100;
            ((uint32_t *)(canvas.pixels + 217 * pitch))[813] = 0x200;
            ((uint32_t *)(canvas.pixels + 310 * pitch))[1020] = 0x400;
        }
        for (query_mode = 0; query_mode <= 4; ++query_mode)
        for (int t = 91; t <= 310; t += 73)
        for (int crop = 0; crop < 4; ++crop) {
            check_reference(canvas, pitch, crop == 0 ? 0 : 203, t,
                crop == 2 ? 817 : width, crop == 3 ? t + 1 : height);
            ++cases;
        }
        native_release_opacity_canvas(canvas, 0, 0, width, height);
        native_discard_opacity_canvas_pool();
    }
    query_mode = 0;

    // Force backing without adding ink, then search hollow and irregular bands.
    // This oracle visits every requested pixel and does not use bounds helpers.
    for (int width = 1023; width <= 1025; ++width) {
        const int height = 257;
        size_t pitch = (size_t)width * 4;
        canvas = native_acquire_opacity_canvas(width, height, space);
        assert(canvas.context);
        for (int pattern = 0; pattern < 3; ++pattern) {
            memset(canvas.pixels, 0, pitch * height);
            for (int y = 0; y < height; ++y) {
                uint32_t *row = (uint32_t *)(canvas.pixels + (size_t)y * pitch);
                for (int x = 0; x < width; ++x)
                    if ((pattern == 0 && (y == 2 || y == height - 3)
                            && (x == width / 4 || x == width * 3 / 4))
                        || (pattern == 1 && ((y == 1 && x == 1)
                            || (y == height - 2 && x == width - 2)))
                        || (pattern == 2 && y % 9 == 0
                            && x >= width / 4 && x < width * 3 / 4))
                        row[x] = 1u << ((x + y) % 32);
            }
            for (query_mode = 0; query_mode <= 4; ++query_mode)
            for (int crop = 0; crop < 3; ++crop) {
                check_reference(canvas, pitch, crop == 2 ? width / 4 : crop,
                    crop, width - crop, height - crop); ++cases;
            }
        }
        native_release_opacity_canvas(canvas, 0, 0, width, height);
        native_discard_opacity_canvas_pool();
    }
    query_mode = 0;

    // Only the middle page of each row is backed. A clipped backed band may
    // be grouped without reading the untouched padding pages on either side.
    int words = (int)(sysconf(_SC_PAGESIZE) / 4), wide = words * 3, tall = 512;
    size_t pitch = (size_t)wide * 4;
    canvas = native_acquire_opacity_canvas(wide, tall, space);
    assert(canvas.context);
    for (int y = 0; y < tall; ++y)
        memset(canvas.pixels + (size_t)y * pitch + (size_t)words * 4, 0, (size_t)words * 4);
    ((uint32_t *)(canvas.pixels + 17 * pitch))[words + 17] = 1;
    ((uint32_t *)(canvas.pixels + (size_t)(tall - 19) * pitch))[words * 2 - 19] = 0x100u;
    before = footprint();
    assert(native_opacity_canvas_ink_bounds(canvas, pitch, words + 9, 0, words * 2 - 11, tall,
        &left, &top, &right, &bottom));
    after = footprint();
    assert(left == words + 17 && top == 17 && right == words * 2 - 18 && bottom == tall - 18);
    assert(after < before + 1024 * 1024);
    check_reference(canvas, pitch, words + 9, 0, words * 2 - 11, tall); ++cases;
    native_release_opacity_canvas(canvas, 0, 0, wide, tall);
    native_discard_opacity_canvas_pool();

    // Small malloc-backed canvases keep the original byte scan.
    canvas = native_acquire_opacity_canvas(17, 13, space);
    canvas.pixels[3 * 17 * 4 + 9 * 4 + 2] = 19;
    assert(native_opacity_canvas_ink_bounds(canvas, 17 * 4, 0, 0, 17, 13,
        &left, &top, &right, &bottom));
    assert(left == 9 && top == 3 && right == 10 && bottom == 4);
    native_release_opacity_canvas(canvas, 0, 0, 17, 13);
    native_discard_opacity_canvas_pool();
    CGColorSpaceRelease(space);
    printf("%zu exact clipped scans across page and row boundaries, empty reuse, compressed/unknown flags and failed/short queries pass\n", cases);
}
