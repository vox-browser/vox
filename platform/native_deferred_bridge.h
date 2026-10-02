#pragma once
#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>
#include <stdint.h>

// Core::EventLoop::current / ThreadEventQueue::deferred_invoke. CoreFoundation
// is the embedding wakeup and origin-thread delivery boundary on macOS.
static void* vox_capture_origin_run_loop(void)
{
    return (void*)CFRetain(CFRunLoopGetCurrent());
}
static void vox_defer_on_origin_run_loop(void* loop, void* context, void (*callback)(void*))
{
    CFRunLoopRef run_loop = (CFRunLoopRef)loop;
    CFRunLoopPerformBlock(run_loop, kCFRunLoopCommonModes, ^{
        callback(context);
        CFRelease(run_loop);
    });
    CFRunLoopWakeUp(run_loop);
}
static uint64_t vox_deferred_thread_identity(void)
{
    return (uint64_t)(uintptr_t)pthread_self();
}
#endif
