#ifndef VOX_THREAD_SCRATCH_LEASES_H
#define VOX_THREAD_SCRATCH_LEASES_H

#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "native_state.h"

typedef struct VoxThreadScratchLease {
    void *scope;
    const unsigned char *label;
    int64_t label_len;
    uint64_t generation;
    int32_t active;
    int32_t entered;
    int32_t poison;
} VoxThreadScratchLease;

typedef struct VoxThreadScratchLeaseChunk {
    struct VoxThreadScratchLeaseChunk *next;
    VoxThreadScratchLease slots[16];
} VoxThreadScratchLeaseChunk;

VOX_NATIVE_STATE pthread_key_t vox_thread_scratch_key;
VOX_NATIVE_STATE pthread_once_t vox_thread_scratch_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);

static int32_t vox_thread_scratch_matches_poison_configuration(int32_t poison,
    const char *names, const unsigned char *label, int64_t length) {
    if (poison) return 1;
    for (const char *start = names;;) {
        const char *end = strchr(start, ',');
        size_t bytes = end ? (size_t)(end - start) : strlen(start);
        if (bytes == (size_t)length && (!bytes || memcmp(start, label, bytes) == 0))
            return 1;
        if (!end) return 0;
        start = end + 1;
    }
}

// The uncached reader remains available for explicit diagnostic comparisons.
static int32_t vox_thread_scratch_poison_enabled(const unsigned char *label, int64_t length) {
    const char *poison = getenv("VOX_ARENA_POISON");
    const char *names = getenv("VOX_ARENA_NO_REUSE");
    return vox_thread_scratch_matches_poison_configuration(
        poison && strcmp(poison, "1") == 0, names ? names : "", label, length);
}

VOX_NATIVE_STATE pthread_once_t vox_thread_scratch_configuration_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
VOX_NATIVE_STATE int32_t vox_thread_scratch_configuration_poison;
VOX_NATIVE_STATE int32_t vox_thread_scratch_configuration_uncached;
VOX_NATIVE_STATE const char *vox_thread_scratch_configuration_names;

// Like the reusable arena policy, scratch policy is launch configuration. Own
// the selected-label bytes so later environment storage changes cannot dangle.
static void vox_thread_scratch_initialize_configuration(void) {
    const char *poison = getenv("VOX_ARENA_POISON");
    vox_thread_scratch_configuration_poison = poison && strcmp(poison, "1") == 0;
    const char *names = getenv("VOX_ARENA_NO_REUSE");
    vox_thread_scratch_configuration_names = strdup(names ? names : "");
    if (!vox_thread_scratch_configuration_names) abort();
    const char *uncached = getenv("VOX_DISABLE_SCRATCH_POISON_CACHE");
    vox_thread_scratch_configuration_uncached = uncached && *uncached;
    const char *diagnostics = getenv("VOX_SCRATCH_POISON_CACHE_DIAGNOSTICS");
    if (diagnostics && *diagnostics)
        fprintf(stderr, "Vox scratch policy: cached launch poison configuration\n");
}

static int32_t vox_thread_scratch_cached_poison_enabled(const unsigned char *label, int64_t length) {
    if (pthread_once(&vox_thread_scratch_configuration_once, vox_thread_scratch_initialize_configuration))
        abort();
    if (vox_thread_scratch_configuration_uncached)
        return vox_thread_scratch_poison_enabled(label, length);
    return vox_thread_scratch_matches_poison_configuration(vox_thread_scratch_configuration_poison,
        vox_thread_scratch_configuration_names, label, length);
}

static void vox_thread_scratch_destroy(void *pointer) {
    VoxThreadScratchLeaseChunk *chunk = pointer;
    while (chunk) {
        VoxThreadScratchLeaseChunk *next = chunk->next;
        free(chunk);
        chunk = next;
    }
}

static void vox_thread_scratch_initialize(void) {
    if (pthread_key_create(&vox_thread_scratch_key, vox_thread_scratch_destroy))
        abort();
}

// Descriptors have thread lifetime, with storage bounded by simultaneous
// leases. Generation checks make copied handles safe after a slot is reused.
// Their payloads continue to use V's ordinary scoped arena implementation.
static VoxThreadScratchLease *vox_thread_scratch_acquire(void) {
    if (pthread_once(&vox_thread_scratch_once, vox_thread_scratch_initialize))
        abort();
    VoxThreadScratchLeaseChunk *head = pthread_getspecific(vox_thread_scratch_key);
    for (VoxThreadScratchLeaseChunk *chunk = head; chunk; chunk = chunk->next) {
        for (size_t index = 0; index < 16; ++index) {
            VoxThreadScratchLease *lease = &chunk->slots[index];
            if (!lease->active && lease->generation != UINT64_MAX) {
                ++lease->generation;
                lease->active = 1;
                return lease;
            }
        }
    }
    VoxThreadScratchLeaseChunk *chunk = calloc(1, sizeof(*chunk));
    if (!chunk) abort();
    chunk->next = head;
    if (pthread_setspecific(vox_thread_scratch_key, chunk)) abort();
    chunk->slots[0].generation = 1;
    chunk->slots[0].active = 1;
    return &chunk->slots[0];
}

#endif
