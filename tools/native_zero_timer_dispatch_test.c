// Native lifetime/reentrancy checks for the same bridge used by V Timer.
#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include "../platform/timer_host_bridge.h"

struct Observation { void* handle; unsigned calls, remaining; };
static void stop_on_delivery(void* opaque)
{
    struct Observation* state = opaque;
    ++state->calls;
    libweb_v_unregister_timer(state->handle);
}
static void pump_until(struct Observation* state, unsigned expected)
{
    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + 2;
    while (state->calls < expected && CFAbsoluteTimeGetCurrent() < deadline)
        libweb_v_pump_native_events(0.005);
    assert(state->calls == expected);
}
static void restart_on_delivery(void* opaque)
{
    struct Observation* state = opaque;
    ++state->calls;
    libweb_v_unregister_timer(state->handle);
    if (--state->remaining)
        state->handle = libweb_v_register_timer(state, 0, restart_on_delivery);
}
static unsigned order[4], count;
static struct Observation nested;
static void outer_delivery(void* opaque)
{
    struct Observation* state = opaque;
    libweb_v_unregister_timer(state->handle);
    order[count++] = 1;
    pump_until(&nested, 1);
    order[count++] = 3;
    ++state->calls;
}
static void inner_delivery(void* opaque)
{
    order[count++] = 2;
    stop_on_delivery(opaque);
}
static void* worker_timer(void* unused)
{
    (void)unused;
    struct Observation state = {0};
    state.handle = libweb_v_register_timer(&state, 0, stop_on_delivery);
    assert(!libweb_v_zero_timer_is_handle(state.handle));
    pump_until(&state, 1);
    return NULL;
}
int main(void)
{
    // Cancelling many queued deliveries must release their C callback state
    // immediately, including middle nodes, without waiting for a future turn.
    for (unsigned batch = 0; batch < 200; ++batch) {
        struct Observation states[32] = {0};
        for (unsigned i = 0; i < 32; ++i)
            states[i].handle = libweb_v_register_timer(&states[i], 0, stop_on_delivery);
        for (unsigned i = 0; i < 32; ++i) {
            unsigned index = (i * 13) % 32;
            assert(states[index].calls == 0);
            libweb_v_unregister_timer(states[index].handle);
        }
        libweb_v_pump_native_events(0);
        for (unsigned i = 0; i < 32; ++i)
            assert(states[i].calls == 0);
    }
    struct Observation restart = { .remaining = 1000 };
    restart.handle = libweb_v_register_timer(&restart, 0, restart_on_delivery);
    pump_until(&restart, 1000);
    libweb_v_pump_native_events(0.001);
    assert(restart.calls == 1000);

    struct Observation outer = {0};
    outer.handle = libweb_v_register_timer(&outer, 0, outer_delivery);
    nested.handle = libweb_v_register_timer(&nested, 0, inner_delivery);
    pump_until(&outer, 1);
    assert(count == 3 && order[0] == 1 && order[1] == 2 && order[2] == 3);

    struct Observation delayed = {0};
    delayed.handle = libweb_v_register_timer(&delayed, 1, stop_on_delivery);
    assert(!libweb_v_zero_timer_is_handle(delayed.handle));
    pump_until(&delayed, 1);
    pthread_t worker;
    assert(!pthread_create(&worker, NULL, worker_timer, NULL));
    assert(!pthread_join(worker, NULL));
    assert(!libweb_v_zero_timer_first && !libweb_v_zero_timer_last);
    puts("NATIVE_ZERO_TIMER_DISPATCH_PASS cancelled=6400 restarts=1000 nested=1 positive=1 worker=1");
    return 0;
}
