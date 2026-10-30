#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
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
#elif defined(__linux__)
#include "linux_event_context.h"
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
typedef struct {
    GMainContext *loop;
    void *context;
    void (*callback)(void *);
} VoxDeferredCall;
static void *vox_capture_origin_run_loop(void) { return g_main_context_ref(libweb_v_thread_event_context()); }
static gboolean vox_deliver_deferred_call(gpointer context) {
    VoxDeferredCall *call = context;
    call->callback(call->context);
    return G_SOURCE_REMOVE;
}
static void vox_release_deferred_call(gpointer context) {
    VoxDeferredCall *call = context;
    g_main_context_unref(call->loop);
    free(call);
}
static void vox_defer_on_origin_run_loop(void *loop, void *context, void (*callback)(void *)) {
    VoxDeferredCall *call = malloc(sizeof(*call));
    if (!call) abort();
    *call = (VoxDeferredCall){loop, context, callback};
    GSource *source = g_idle_source_new();
    g_source_set_callback(source, vox_deliver_deferred_call, call, vox_release_deferred_call);
    g_source_attach(source, loop);
    g_source_unref(source);
}
static uint64_t vox_deferred_thread_identity(void) { return (uint64_t)(uintptr_t)pthread_self(); }
#endif

#endif
