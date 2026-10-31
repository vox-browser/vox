#ifndef VOX_NATIVE_EVENT_FAIRNESS_TEST_H
#define VOX_NATIVE_EVENT_FAIRNESS_TEST_H
#include <stdint.h>
#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
typedef struct { CFRunLoopSourceRef source; int32_t delivered; } VoxNativeEventFairness;
static void vox_fairness_step(void* pointer);
static void vox_fairness_schedule(VoxNativeEventFairness* state) {
    CFRunLoopSourceContext context = {0};
    context.info = state;
    context.perform = vox_fairness_step;
    state->source = CFRunLoopSourceCreate(NULL, 0, &context);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), state->source, kCFRunLoopDefaultMode);
    CFRunLoopSourceSignal(state->source);
}
static void vox_fairness_step(void* pointer) {
    VoxNativeEventFairness* state = pointer;
    ++state->delivered;
    // Each completion makes a fresh native source runnable. Returning after
    // the first source leaves the remaining ready chain for the caller's next
    // potentially expensive HTML turn.
    if (state->delivered < 5) {
        CFRunLoopSourceInvalidate(state->source);
        CFRelease(state->source);
        vox_fairness_schedule(state);
    }
}
static void* vox_fairness_create(void) {
    VoxNativeEventFairness* state = calloc(1, sizeof(*state));
    vox_fairness_schedule(state);
    return state;
}
static int32_t vox_fairness_delivered(void* pointer) { return ((VoxNativeEventFairness*)pointer)->delivered; }
static void vox_fairness_destroy(void* pointer) {
    VoxNativeEventFairness* state = pointer;
    CFRunLoopSourceInvalidate(state->source);
    CFRelease(state->source);
    free(state);
}
#else
static void* vox_fairness_create(void) { return 0; }
static int32_t vox_fairness_delivered(void* pointer) { return 0; }
static void vox_fairness_destroy(void* pointer) { }
#endif
#endif
