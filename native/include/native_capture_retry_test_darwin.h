#pragma once
#include "native_layer_presentation_darwin.h"
void native_cancel_capture_retry(void);
void native_schedule_capture_retry(int (*)(void *), void *);

static int native_test_capture_ready(void *context) { return *(int *)context; }

static void native_test_capture_retry_pump(double seconds) {
    double end = NSProcessInfo.processInfo.systemUptime + seconds;
    while (NSProcessInfo.processInfo.systemUptime < end)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.001, true);
}

static int native_test_capture_retry_idle_coalescing_and_cancellation(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        BOOL presenting = native_layer_presenting;
        BOOL working = native_layer_document_work_active;
        int result = 0;
        @try {
            native_cancel_capture_retry();
            native_layer_presenting = YES;
            native_layer_document_work_active = NO;
            uint64_t generation = native_layer_redraw_generation;
            native_schedule_capture_retry(NULL, NULL);
            native_schedule_capture_retry(NULL, NULL);
            native_test_capture_retry_pump(0.04);
            if (native_layer_redraw_generation == generation)
                result |= 1;
            // A successful in-progress frame cancels every outstanding retry.
            native_cancel_capture_retry();
            native_layer_presenting = NO;
            native_test_capture_retry_pump(0.03);
            if (native_layer_redraw_generation == generation)
                result |= 2;
            native_layer_document_work_active = YES;
            native_schedule_capture_retry(NULL, NULL);
            native_test_capture_retry_pump(0.04);
            if (native_layer_redraw_generation == generation)
                result |= 4;
            native_layer_document_work_active = NO;
            native_test_capture_retry_pump(0.03);
            if (native_layer_redraw_generation == generation + 1)
                result |= 8;
            generation = native_layer_redraw_generation;
            native_schedule_capture_retry(NULL, NULL);
            native_schedule_capture_retry(NULL, NULL);
            native_test_capture_retry_pump(0.04);
            if (native_layer_redraw_generation == generation + 1)
                result |= 16;
            generation = native_layer_redraw_generation;
            int ready = 0;
            native_schedule_capture_retry(native_test_capture_ready, &ready);
            native_test_capture_retry_pump(0.05);
            if (native_layer_redraw_generation == generation) result |= 32;
            ready = 1;
            native_test_capture_retry_pump(0.04);
            if (native_layer_redraw_generation == generation + 1) result |= 64;
            generation = native_layer_redraw_generation;
            ready = -1;
            native_schedule_capture_retry(native_test_capture_ready, &ready);
            native_test_capture_retry_pump(0.04);
            ready = 1;
            native_test_capture_retry_pump(0.03);
            if (native_layer_redraw_generation == generation) result |= 128;
        } @finally {
            native_cancel_capture_retry();
            native_layer_presenting = presenting;
            native_layer_document_work_active = working;
        }
        return result;
    }
}
