/* Native macOS timer registration boundary for the translated Core::Timer. */
#ifndef LIBWEB_V_TIMER_HOST_BRIDGE_H
#define LIBWEB_V_TIMER_HOST_BRIDGE_H
#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

typedef struct {
    void* context;
    void (*timeout)(void*);
} LibWebVTimerContext;

static void libweb_v_timer_context_release(const void* context)
{
    free((void*)context);
}

static void libweb_v_timer_callback(CFRunLoopTimerRef timer, void* context)
{
    (void)timer;
    LibWebVTimerContext* state = context;
    state->timeout(state->context);
}

static void* libweb_v_register_timer(void* context, int interval_ms, void (*timeout)(void*))
{
    LibWebVTimerContext* state = malloc(sizeof(*state));
    if (!state)
        abort();
    state->context = context;
    state->timeout = timeout;
    CFRunLoopTimerContext timer_context = { 0, state, NULL, libweb_v_timer_context_release, NULL };
    double delay = interval_ms > 0 ? interval_ms / 1000.0 : 0.0;
    // Core's zero interval means an event on the next turn. CF reserves a zero
    // repeat interval for one-shot timers, so retain a minimal native interval;
    // the translated Timer stops single shots before invoking their handler.
    double repeat_interval = delay > 0.0 ? delay : 0.000001;
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
        CFAbsoluteTimeGetCurrent() + delay, repeat_interval, 0, 0, libweb_v_timer_callback, &timer_context);
    if (!timer)
        abort();
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopCommonModes);
    return (void*)timer;
}

static void libweb_v_unregister_timer(void* timer)
{
    CFRunLoopTimerInvalidate((CFRunLoopTimerRef)timer);
    CFRelease(timer);
}

static void libweb_v_pump_native_events(double wait_seconds)
{
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, wait_seconds, true);
}
#endif
#endif
