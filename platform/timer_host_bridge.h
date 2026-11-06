#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
/* Native macOS timer registration boundary for the translated Core::Timer. */
#ifndef LIBWEB_V_TIMER_HOST_BRIDGE_H
#define LIBWEB_V_TIMER_HOST_BRIDGE_H
#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <stdbool.h>
#include <pthread.h>
#include "native_state.h"

static bool libweb_v_is_main_thread(void) { return pthread_main_np() != 0; }

typedef struct {
    void* context;
    void (*timeout)(void*);
    CFRunLoopTimerRef timer;
    bool reusable;
    bool delivering;
    bool stopped;
} LibWebVTimerContext;

#define LIBWEB_V_IDLE_TIMER_LIMIT 16
// These main-run-loop registrations own only native callback records. Stopping
// a timer clears both V pointers before an idle registration can enter the pool.
VOX_NATIVE_STATE LibWebVTimerContext* libweb_v_idle_timers[LIBWEB_V_IDLE_TIMER_LIMIT];
VOX_NATIVE_STATE unsigned libweb_v_idle_timer_count;

static void libweb_v_timer_context_release(const void* context)
{
    free((void*)context);
}

static void libweb_v_recycle_timer(LibWebVTimerContext* state)
{
    if (state->reusable && pthread_main_np()
        && libweb_v_idle_timer_count < LIBWEB_V_IDLE_TIMER_LIMIT) {
        libweb_v_idle_timers[libweb_v_idle_timer_count++] = state;
        return;
    }
    CFRunLoopTimerRef timer = state->timer;
    CFRunLoopTimerInvalidate(timer);
    CFRelease(timer);
}

static void libweb_v_timer_callback(CFRunLoopTimerRef timer, void* context)
{
    (void)timer;
    LibWebVTimerContext* state = context;
    if (state->stopped)
        return;
    state->delivering = true;
    void (*timeout)(void*) = state->timeout;
    void* receiver = state->context;
    timeout(receiver);
    state->delivering = false;
    // A handler can stop/restart its Timer and spin a nested loop. The current
    // native registration must not be reused until this callback has returned.
    if (state->stopped)
        libweb_v_recycle_timer(state);
}

static void* libweb_v_register_timer(void* context, int interval_ms, void (*timeout)(void*), bool reuse, bool* reused)
{
    *reused = false;
    // Positive intervals keep their existing automatic repeat schedule. Only
    // equivalent zero-delay registrations on the main run loop are pooled.
    bool reusable = reuse && interval_ms <= 0 && pthread_main_np()
        && CFRunLoopGetCurrent() == CFRunLoopGetMain();
    double delay = interval_ms > 0 ? interval_ms / 1000.0 : 0.0;
    if (reusable && libweb_v_idle_timer_count) {
        LibWebVTimerContext* state = libweb_v_idle_timers[--libweb_v_idle_timer_count];
        libweb_v_idle_timers[libweb_v_idle_timer_count] = NULL;
        state->context = context;
        state->timeout = timeout;
        state->stopped = false;
        CFRunLoopTimerSetNextFireDate(state->timer, CFAbsoluteTimeGetCurrent() + delay);
        *reused = true;
        return state;
    }
    LibWebVTimerContext* state = calloc(1, sizeof(*state));
    if (!state)
        abort();
    state->context = context;
    state->timeout = timeout;
    state->reusable = reusable;
    CFRunLoopTimerContext timer_context = { 0, state, NULL, libweb_v_timer_context_release, NULL };
    // Core's zero interval means an event on the next turn. CF reserves a zero
    // repeat interval for one-shot timers, so retain a minimal native interval;
    // the translated Timer stops single shots before invoking their handler.
    double repeat_interval = delay > 0.0 ? delay : 0.000001;
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
        CFAbsoluteTimeGetCurrent() + delay, repeat_interval, 0, 0, libweb_v_timer_callback, &timer_context);
    if (!timer)
        abort();
    state->timer = timer;
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopCommonModes);
    return state;
}

static void libweb_v_unregister_timer(void* registration)
{
    LibWebVTimerContext* state = registration;
    state->stopped = true;
    state->context = NULL;
    state->timeout = NULL;
    if (state->reusable) {
        // CF reserves a zero repeat interval for one-shots. Leave our existing
        // repeating registration asleep until another zero-delay task uses it.
        CFRunLoopTimerSetNextFireDate(state->timer, CFAbsoluteTimeGetCurrent() + 3155760000.0);
    }
    if (!state->delivering)
        libweb_v_recycle_timer(state);
}

static unsigned libweb_v_idle_timer_pool_size(void) { return libweb_v_idle_timer_count; }

static bool libweb_v_idle_timer_pool_has_no_receivers(void)
{
    for (unsigned index = 0; index < libweb_v_idle_timer_count; ++index) {
        LibWebVTimerContext* state = libweb_v_idle_timers[index];
        if (state->context || state->timeout || !state->stopped || state->delivering)
            return false;
    }
    return true;
}

static void libweb_v_clear_idle_timer_pool(void)
{
    while (libweb_v_idle_timer_count) {
        LibWebVTimerContext* state = libweb_v_idle_timers[--libweb_v_idle_timer_count];
        libweb_v_idle_timers[libweb_v_idle_timer_count] = NULL;
        state->reusable = false;
        libweb_v_recycle_timer(state);
    }
}

static void libweb_v_pump_native_events(double wait_seconds)
{
    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + wait_seconds;
    CFRunLoopRunResult result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, wait_seconds, true);
    // A completion can make another native source runnable. Drain ready work
    // before handing control back to an expensive HTML turn, without waiting
    // again once the queue is empty. Keep both time and turn bounds.
    for (unsigned turn = 1; turn < 256 && result == kCFRunLoopRunHandledSource
        && CFAbsoluteTimeGetCurrent() < deadline; ++turn)
        result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
}
#elif defined(__linux__)
#include "linux_event_context.h"
#include <stdlib.h>
#include <stdbool.h>
typedef struct { void *context; void (*timeout)(void *); } LibWebVTimerContext;
static gboolean libweb_v_timer_callback(gpointer context) {
    // fire() may unregister its own source and free the callback state.
    LibWebVTimerContext state = *(LibWebVTimerContext *)context;
    state.timeout(state.context);
    return G_SOURCE_CONTINUE;
}
static void *libweb_v_register_timer(void *context, int interval_ms, void (*timeout)(void *), bool reuse, bool *reused) {
    (void)reuse;
    *reused = false;
    LibWebVTimerContext *state = malloc(sizeof(*state));
    if (!state) abort();
    *state = (LibWebVTimerContext){context, timeout};
    GSource *source = g_timeout_source_new(interval_ms > 0 ? interval_ms : 1);
    g_source_set_callback(source, libweb_v_timer_callback, state, free);
    g_source_attach(source, libweb_v_thread_event_context());
    return source;
}
static void libweb_v_unregister_timer(void *timer) {
    g_source_destroy(timer);
    g_source_unref(timer);
}
static gboolean libweb_v_pump_deadline(gpointer context) { (void)context; return G_SOURCE_REMOVE; }
static void libweb_v_pump_native_events(double wait_seconds) {
    GMainContext *context = libweb_v_thread_event_context();
    if (wait_seconds <= 0 || g_main_context_pending(context)) {
        // Bound each pump so a repeating ready source cannot starve painting.
        for (int i = 0; i < 64 && g_main_context_pending(context); ++i)
            g_main_context_iteration(context, FALSE);
        return;
    }
    GSource *deadline = g_timeout_source_new((guint)(wait_seconds * 1000) + 1);
    g_source_set_callback(deadline, libweb_v_pump_deadline, NULL, NULL);
    g_source_attach(deadline, context);
    g_main_context_iteration(context, TRUE);
    g_source_destroy(deadline);
    g_source_unref(deadline);
}
#endif
#endif

#endif
