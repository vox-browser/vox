#include <mach/mach.h>
#include <mach/mach_vm.h>
static int query_mode;
static kern_return_t query_pages(vm_map_read_t task, mach_vm_offset_t address,
    mach_vm_size_t size, mach_vm_address_t output, mach_vm_size_t *count) {
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

static uint64_t footprint(void) {
    task_vm_info_data_t info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS);
    return info.phys_footprint;
}

int main(void) {
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
            int found = native_opacity_canvas_ink_bounds(canvas, pitch, x, y, (int)width, 709,
                &left, &top, &right, &bottom);
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
