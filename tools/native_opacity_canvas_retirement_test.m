#include "../native/include/native_opacity_canvas_pool_darwin.h"
#include <assert.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <stdio.h>
#include <unistd.h>

static uint64_t footprint(void) {
    task_vm_info_data_t info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS);
    return info.phys_footprint;
}

int main(void) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    VoxOpacityCanvas warm = native_acquire_opacity_canvas(16, 16, space);
    assert(warm.context);
    native_release_opacity_canvas(warm, 0, 0, 16, 16);
    native_discard_opacity_canvas_pool();
    uint64_t before = footprint();
    const size_t width = 3456, height = 2106;
    VoxOpacityCanvas canvas = native_acquire_opacity_canvas(width, height, space);
    assert(canvas.context);
    CGContextRef identity = canvas.context;
    uint8_t *address = canvas.pixels;
    CGContextSetRGBFillColor(canvas.context, 1, .5, 0, 1);
    CGContextFillRect(canvas.context, CGRectMake(7, 11, 3, 2));
    native_release_opacity_canvas(canvas, 0, 0, width, height);
    uint64_t after = footprint();
    printf("Pooled viewport return footprint growth: %llu bytes\n", (unsigned long long)(after - before));
    fflush(stdout);
    assert(after < before + 4 * 1024 * 1024);
    assert(native_opacity_canvas_pool_bytes == width * height * 4);
    canvas = native_acquire_opacity_canvas(width, height, space);
    assert(canvas.context == identity && canvas.pixels == address);
    for (size_t i = 0; i < width * height * 4; ++i) assert(canvas.pixels[i] == 0);

    // Even a full-size Quartz snapshot must survive retirement and later reuse.
    CGContextSetRGBFillColor(canvas.context, .25, .5, .75, .625);
    CGContextFillRect(canvas.context, CGRectMake(1.125, 2.375, 71.25, 49.5));
    CGImageRef snapshot = CGBitmapContextCreateImage(canvas.context);
    CFDataRef old = CGDataProviderCopyData(CGImageGetDataProvider(snapshot));
    native_release_opacity_canvas(canvas, 0, 0, width, height);
    canvas = native_acquire_opacity_canvas(width, height, space);
    assert(canvas.context == identity && canvas.pixels == address);
    for (size_t i = 0; i < width * height * 4; ++i) assert(canvas.pixels[i] == 0);
    CGContextSetRGBFillColor(canvas.context, 1, 0, 0, 1);
    CGContextFillRect(canvas.context, CGRectMake(0, 0, 100, 100));
    CFDataRef kept = CGDataProviderCopyData(CGImageGetDataProvider(snapshot));
    assert(CFEqual(old, kept));
    CFRelease(old); CFRelease(kept); CGImageRelease(snapshot);
    native_release_opacity_canvas(canvas, 0, 0, width, height);
    native_discard_opacity_canvas_pool();
    mach_vm_address_t region = (mach_vm_address_t)address;
    mach_vm_size_t size = 0;
    vm_region_basic_info_data_64_t info = {0};
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    kern_return_t status = mach_vm_region(mach_task_self(), &region, &size,
        VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &object);
    if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
    assert(status == KERN_INVALID_ADDRESS || (status == KERN_SUCCESS && region > (mach_vm_address_t)address));
    CGColorSpaceRelease(space);
    puts("Virtual capacity, transparent reuse, large snapshot immutability and mapping teardown pass");
}
