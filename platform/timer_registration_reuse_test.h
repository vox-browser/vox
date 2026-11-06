#ifndef VOX_TIMER_REGISTRATION_REUSE_TEST_H
#define VOX_TIMER_REGISTRATION_REUSE_TEST_H
#ifdef __APPLE__
#include "timer_host_bridge.h"
static void vox_timer_pool_worker_timeout(void* receiver) { (void)receiver; abort(); }
static void* vox_timer_pool_worker(void* result)
{
    bool reused = true;
    LibWebVTimerContext* state = libweb_v_register_timer(result, 0,
        vox_timer_pool_worker_timeout, true, &reused);
    *(bool*)result = !reused && !state->reusable;
    libweb_v_unregister_timer(state);
    return NULL;
}
static bool vox_timer_pool_worker_is_not_pooled(void)
{
    bool result = false;
    pthread_t worker;
    if (pthread_create(&worker, NULL, vox_timer_pool_worker, &result))
        return false;
    return !pthread_join(worker, NULL) && result;
}
#endif
#endif
