#ifndef VOX_BROWSER_REQUEST_SCOPE_H
#define VOX_BROWSER_REQUEST_SCOPE_H
#include <pthread.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <time.h>
#include "../platform/native_state.h"

// These are process-wide, including callers in separately compiled V units.
VOX_NATIVE_STATE pthread_mutex_t vox_resource_slots_mutex VOX_NATIVE_STATE_INIT(PTHREAD_MUTEX_INITIALIZER);
VOX_NATIVE_STATE pthread_cond_t vox_resource_slots_changed VOX_NATIVE_STATE_INIT(PTHREAD_COND_INITIALIZER);
VOX_NATIVE_STATE unsigned vox_resource_slots_active;

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t changed;
    unsigned references;
    atomic_bool cancelled;
} VoxResourceScope;

static void *vox_resource_scope_create(void) {
    VoxResourceScope *scope = calloc(1, sizeof(*scope));
    if (!scope) abort();
    if (pthread_mutex_init(&scope->mutex, NULL) || pthread_cond_init(&scope->changed, NULL)) abort();
    scope->references = 1;
    atomic_init(&scope->cancelled, false);
    return scope;
}
static void vox_resource_scope_retain(void *value) {
    VoxResourceScope *scope = value;
    pthread_mutex_lock(&scope->mutex);
    ++scope->references;
    pthread_mutex_unlock(&scope->mutex);
}
static bool vox_resource_scope_release(void *value) {
    VoxResourceScope *scope = value;
    pthread_mutex_lock(&scope->mutex);
    bool dispose = --scope->references == 0;
    pthread_mutex_unlock(&scope->mutex);
    if (!dispose) return false;
    pthread_cond_destroy(&scope->changed);
    pthread_mutex_destroy(&scope->mutex);
    free(scope);
    return true;
}
static void vox_resource_scope_cancel(void *value) {
    VoxResourceScope *scope = value;
    pthread_mutex_lock(&scope->mutex);
    atomic_store_explicit(&scope->cancelled, true, memory_order_release);
    pthread_cond_broadcast(&scope->changed);
    pthread_mutex_unlock(&scope->mutex);
    // Never take the scheduler lock while holding the publication gate.
    pthread_mutex_lock(&vox_resource_slots_mutex);
    pthread_cond_broadcast(&vox_resource_slots_changed);
    pthread_mutex_unlock(&vox_resource_slots_mutex);
}
static bool vox_resource_scope_cancelled(void *value) {
    VoxResourceScope *scope = value;
    // Do not hold the scheduler lock while waiting for a cache publication.
    return atomic_load_explicit(&scope->cancelled, memory_order_acquire);
}
static bool vox_resource_scope_begin_publication(void *value) {
    VoxResourceScope *scope = value;
    pthread_mutex_lock(&scope->mutex);
    if (!vox_resource_scope_cancelled(scope)) return true;
    pthread_mutex_unlock(&scope->mutex);
    return false;
}
static void vox_resource_scope_end_publication(void *value) {
    pthread_mutex_unlock(&((VoxResourceScope *)value)->mutex);
}
static bool vox_resource_scope_wait(void *value, long long nanoseconds) {
    VoxResourceScope *scope = value;
    struct timespec until;
    clock_gettime(CLOCK_REALTIME, &until);
    if (nanoseconds > 0) {
        until.tv_sec += nanoseconds / 1000000000LL;
        until.tv_nsec += nanoseconds % 1000000000LL;
        if (until.tv_nsec >= 1000000000L) { ++until.tv_sec; until.tv_nsec -= 1000000000L; }
    }
    pthread_mutex_lock(&scope->mutex);
    while (!vox_resource_scope_cancelled(scope) && nanoseconds > 0) {
        if (pthread_cond_timedwait(&scope->changed, &scope->mutex, &until)) break;
    }
    bool cancelled = vox_resource_scope_cancelled(scope);
    pthread_mutex_unlock(&scope->mutex);
    return cancelled;
}
static bool vox_resource_scope_acquire_slot(void *value, unsigned limit) {
    pthread_mutex_lock(&vox_resource_slots_mutex);
    while (vox_resource_slots_active >= limit && !vox_resource_scope_cancelled(value)) {
        pthread_cond_wait(&vox_resource_slots_changed, &vox_resource_slots_mutex);
    }
    bool acquired = !vox_resource_scope_cancelled(value);
    if (acquired) ++vox_resource_slots_active;
    pthread_mutex_unlock(&vox_resource_slots_mutex);
    return acquired;
}
static void vox_resource_release_slot(void) {
    pthread_mutex_lock(&vox_resource_slots_mutex);
    if (!vox_resource_slots_active) abort();
    --vox_resource_slots_active;
    pthread_cond_broadcast(&vox_resource_slots_changed);
    pthread_mutex_unlock(&vox_resource_slots_mutex);
}
#endif
