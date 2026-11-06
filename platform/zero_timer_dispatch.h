// Zero-delay main-thread timer delivery. The V Timer still owns cancellation,
// single-shot/repeating policy, callback lifetime and interval changes.
#ifndef LIBWEB_V_ZERO_TIMER_DISPATCH_H
#define LIBWEB_V_ZERO_TIMER_DISPATCH_H
#include "native_state.h"
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct LibWebVZeroTimer LibWebVZeroTimer;
struct LibWebVZeroTimer {
    void* context;
    void (*timeout)(void*);
    LibWebVZeroTimer* previous;
    LibWebVZeroTimer* next;
    unsigned references;
    bool queued;
    bool cancelled;
};

VOX_NATIVE_STATE pthread_mutex_t libweb_v_zero_timer_lock VOX_NATIVE_STATE_INIT(PTHREAD_MUTEX_INITIALIZER);
VOX_NATIVE_STATE pthread_once_t libweb_v_zero_timer_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
VOX_NATIVE_STATE CFRunLoopSourceRef libweb_v_zero_timer_source;
VOX_NATIVE_STATE LibWebVZeroTimer* libweb_v_zero_timer_first;
VOX_NATIVE_STATE LibWebVZeroTimer* libweb_v_zero_timer_last;
VOX_NATIVE_STATE bool libweb_v_zero_timer_disabled;
VOX_NATIVE_STATE bool libweb_v_zero_timer_diagnostics;
VOX_NATIVE_STATE bool libweb_v_zero_timer_reported;

// Callers hold the queue lock. Removing a node transfers its queue reference
// to the current delivery; it does not release the node during a callback.
static void libweb_v_zero_timer_unlink(LibWebVZeroTimer* timer)
{
    if (timer->previous)
        timer->previous->next = timer->next;
    else
        libweb_v_zero_timer_first = timer->next;
    if (timer->next)
        timer->next->previous = timer->previous;
    else
        libweb_v_zero_timer_last = timer->previous;
    timer->previous = timer->next = NULL;
    timer->queued = false;
}

static void libweb_v_zero_timer_append(LibWebVZeroTimer* timer)
{
    timer->previous = libweb_v_zero_timer_last;
    timer->next = NULL;
    if (libweb_v_zero_timer_last)
        libweb_v_zero_timer_last->next = timer;
    else
        libweb_v_zero_timer_first = timer;
    libweb_v_zero_timer_last = timer;
    timer->queued = true;
}

static void libweb_v_zero_timer_signal(void)
{
    CFRunLoopSourceSignal(libweb_v_zero_timer_source);
    CFRunLoopWakeUp(CFRunLoopGetMain());
}

static void libweb_v_zero_timer_perform(void* unused)
{
    (void)unused;
    pthread_mutex_lock(&libweb_v_zero_timer_lock);
    LibWebVZeroTimer* timer = libweb_v_zero_timer_first;
    if (!timer) {
        pthread_mutex_unlock(&libweb_v_zero_timer_lock);
        return;
    }
    libweb_v_zero_timer_unlink(timer);
    void* context = timer->context;
    void (*timeout)(void*) = timer->timeout;
    bool pending = libweb_v_zero_timer_first != NULL;
    pthread_mutex_unlock(&libweb_v_zero_timer_lock);

    // Deliver one timer per source invocation. Signal the remaining queue
    // before the callback so a nested native pump can run another timer.
    if (pending)
        libweb_v_zero_timer_signal();
    if (libweb_v_zero_timer_diagnostics && !libweb_v_zero_timer_reported) {
        libweb_v_zero_timer_reported = true;
        fprintf(stderr, "VOX_ZERO_TIMER_DISPATCH delivered=1\n");
    }
    timeout(context);

    pthread_mutex_lock(&libweb_v_zero_timer_lock);
    bool cancelled = timer->cancelled;
    if (cancelled)
        --timer->references;
    else
        libweb_v_zero_timer_append(timer); // Transfer delivery reference back.
    bool dispose = timer->references == 0;
    pthread_mutex_unlock(&libweb_v_zero_timer_lock);
    if (dispose)
        free(timer);
    if (!cancelled)
        libweb_v_zero_timer_signal();
}

static void libweb_v_zero_timer_initialize(void)
{
    const char* control = getenv("VOX_RETAIN_CF_ZERO_TIMERS");
    libweb_v_zero_timer_disabled = control && control[0] == '1';
    const char* diagnostic = getenv("VOX_ZERO_TIMER_DIAGNOSTICS");
    libweb_v_zero_timer_diagnostics = diagnostic && diagnostic[0] == '1';
    if (libweb_v_zero_timer_disabled)
        return;
    CFRunLoopSourceContext context = { 0 };
    context.perform = libweb_v_zero_timer_perform;
    libweb_v_zero_timer_source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    if (!libweb_v_zero_timer_source)
        abort();
    // One process-lifetime native source, with no V callback or owner stored in
    // its context. Cancelled timers are unlinked and released immediately.
    CFRunLoopAddSource(CFRunLoopGetMain(), libweb_v_zero_timer_source, kCFRunLoopCommonModes);
}

static bool libweb_v_zero_timer_is_handle(void* handle)
{
    return ((uintptr_t)handle & 1) != 0;
}

static void* libweb_v_register_zero_timer(void* context, void (*timeout)(void*))
{
    if (!pthread_main_np())
        return NULL;
    pthread_once(&libweb_v_zero_timer_once, libweb_v_zero_timer_initialize);
    if (libweb_v_zero_timer_disabled)
        return NULL;
    LibWebVZeroTimer* timer = calloc(1, sizeof(*timer));
    if (!timer)
        abort();
    timer->context = context;
    timer->timeout = timeout;
    timer->references = 2; // Registration and queued delivery.
    pthread_mutex_lock(&libweb_v_zero_timer_lock);
    libweb_v_zero_timer_append(timer);
    pthread_mutex_unlock(&libweb_v_zero_timer_lock);
    libweb_v_zero_timer_signal();
    return (void*)((uintptr_t)timer | 1);
}

static void libweb_v_unregister_zero_timer(void* handle)
{
    LibWebVZeroTimer* timer = (LibWebVZeroTimer*)((uintptr_t)handle & ~(uintptr_t)1);
    pthread_mutex_lock(&libweb_v_zero_timer_lock);
    timer->cancelled = true;
    timer->context = NULL;
    timer->timeout = NULL;
    if (timer->queued) {
        libweb_v_zero_timer_unlink(timer);
        --timer->references;
    }
    bool dispose = --timer->references == 0;
    pthread_mutex_unlock(&libweb_v_zero_timer_lock);
    if (dispose)
        free(timer);
}
#endif
