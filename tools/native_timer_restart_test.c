#include <CoreFoundation/CoreFoundation.h>
#include <assert.h>
#include <stdio.h>

static unsigned registrations, deliveries;
static void counted_add_timer(CFRunLoopRef loop, CFRunLoopTimerRef timer, CFRunLoopMode mode)
{
    ++registrations;
    CFRunLoopAddTimer(loop, timer, mode);
}
#define CFRunLoopAddTimer counted_add_timer
#include "../platform/timer_host_bridge.h"
#undef CFRunLoopAddTimer

static void timeout(void* context) { assert(context == &deliveries); ++deliveries; }

static void* restart_on_another_run_loop(void* timer)
{
    assert(!libweb_v_restart_timer(timer, 500));
    return NULL;
}

int main(void)
{
    void* timer = libweb_v_register_timer(&deliveries, 500, timeout);
    assert(timer && registrations == 1);
    CFRunLoopTimerContext context = {0};
    CFRunLoopTimerGetContext(timer, &context);
    void* owned_context = context.info;
    for (unsigned i = 0; i < 10000; ++i) {
        CFRunLoopTimerSetNextFireDate(timer, CFAbsoluteTimeGetCurrent() + 30);
        CFAbsoluteTime before = CFAbsoluteTimeGetCurrent();
        assert(libweb_v_restart_timer(timer, 500));
        CFAbsoluteTime after = CFAbsoluteTimeGetCurrent();
        CFAbsoluteTime deadline = CFRunLoopTimerGetNextFireDate(timer);
        assert(deadline >= before + .5 - .00001 && deadline <= after + .5 + .00001);
        assert(CFRunLoopTimerGetInterval(timer) == .5);
        CFRunLoopTimerGetContext(timer, &context);
        assert(context.info == owned_context && registrations == 1 && deliveries == 0);
    }
    CFAbsoluteTime deadline = CFRunLoopTimerGetNextFireDate(timer);
    assert(!libweb_v_restart_timer(timer, 100));
    assert(!libweb_v_restart_timer(timer, 0));
    assert(!libweb_v_restart_timer(timer, -1));
    assert(CFRunLoopTimerGetNextFireDate(timer) == deadline);
    pthread_t worker;
    assert(!pthread_create(&worker, NULL, restart_on_another_run_loop, timer));
    assert(!pthread_join(worker, NULL));
    assert(CFRunLoopTimerGetNextFireDate(timer) == deadline);
    CFRunLoopTimerInvalidate(timer);
    assert(!libweb_v_restart_timer(timer, 500));
    libweb_v_unregister_timer(timer);
    assert(!libweb_v_restart_timer(NULL, 500));
    void* zero = libweb_v_register_timer(&deliveries, 0, timeout);
    assert(zero && !libweb_v_restart_timer(zero, 500));
    libweb_v_unregister_timer(zero);
    puts("10,000 timer restarts: one registration, preserved callback ownership, exact reset deadlines; changed intervals, invalid and zero timers decline safely");
    return 0;
}
