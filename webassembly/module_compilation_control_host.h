/* LibWasm/Types.h Module compilation state. pthread supplies the native
 * Sync::Mutex/ConditionVariable adapter; atomic orders match the source. */
#pragma once
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>

struct vox_wasm_module_compilation_control {
    uint8_t state;
    pthread_mutex_t mutex;
    pthread_cond_t changed;
};

static inline void* vox_wasm_module_compilation_control_create(void)
{
    struct vox_wasm_module_compilation_control* control = calloc(1, sizeof(*control));
    if (!control)
        abort();
    if (pthread_mutex_init(&control->mutex, NULL) != 0
        || pthread_cond_init(&control->changed, NULL) != 0)
        abort();
    return control;
}

static inline int vox_wasm_module_compilation_has_attempted(void const* opaque)
{
    struct vox_wasm_module_compilation_control const* control = opaque;
    return __atomic_load_n(&control->state, __ATOMIC_ACQUIRE) == 2;
}

static inline int vox_wasm_module_compilation_try_begin(void* opaque)
{
    struct vox_wasm_module_compilation_control* control = opaque;
    uint8_t not_started = 0;
    /* Pinned AK::Atomic maps its requested acq_rel to release/acquire here. */
    return __atomic_compare_exchange_n(&control->state, &not_started, 1, 0,
        __ATOMIC_RELEASE, __ATOMIC_ACQUIRE);
}

static inline void vox_wasm_module_compilation_finish(void* opaque)
{
    struct vox_wasm_module_compilation_control* control = opaque;
    if (pthread_mutex_lock(&control->mutex) != 0)
        abort();
    __atomic_store_n(&control->state, 2, __ATOMIC_RELEASE);
    if (pthread_cond_broadcast(&control->changed) != 0)
        abort();
    if (pthread_mutex_unlock(&control->mutex) != 0)
        abort();
}

static inline void vox_wasm_module_compilation_wait(void* opaque)
{
    struct vox_wasm_module_compilation_control* control = opaque;
    if (__atomic_load_n(&control->state, __ATOMIC_ACQUIRE) != 1)
        return;
    if (pthread_mutex_lock(&control->mutex) != 0)
        abort();
    while (__atomic_load_n(&control->state, __ATOMIC_ACQUIRE) == 1) {
        if (pthread_cond_wait(&control->changed, &control->mutex) != 0)
            abort();
    }
    if (pthread_mutex_unlock(&control->mutex) != 0)
        abort();
}

static inline void vox_wasm_module_compilation_control_destroy(void* opaque)
{
    struct vox_wasm_module_compilation_control* control = opaque;
    if (pthread_cond_destroy(&control->changed) != 0
        || pthread_mutex_destroy(&control->mutex) != 0)
        abort();
    free(control);
}
