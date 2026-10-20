#pragma once
#import <Metal/Metal.h>
// Included after gg's Sokol implementation in the generated test unit.

static id<MTLDevice> native_image_test_device;
static bool native_image_test_start_gpu(void) {
    native_image_test_device = MTLCreateSystemDefaultDevice();
    if (!native_image_test_device) return false;
    sg_setup(&(sg_desc){
        .environment = { .metal = { .device = (__bridge const void*)native_image_test_device } }
    });
    return sg_isvalid();
}
static void native_image_test_stop_gpu(void) {
    sg_shutdown();
#if !__has_feature(objc_arc)
    [native_image_test_device release];
#endif
    native_image_test_device = nil;
}
