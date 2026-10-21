#ifndef VOX_THREAD_SCRATCH_LEASES_H
#define VOX_THREAD_SCRATCH_LEASES_H

#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

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

static pthread_key_t vox_thread_scratch_key;
static pthread_once_t vox_thread_scratch_once = PTHREAD_ONCE_INIT;

static int32_t vox_thread_scratch_poison_enabled(const unsigned char *label, int64_t length) {
    const char *poison = getenv("VOX_ARENA_POISON");
    if (poison && strcmp(poison, "1") == 0) return 1;
    const char *names = getenv("VOX_ARENA_NO_REUSE");
    if (!names) names = "";
    for (const char *start = names;;) {
        const char *end = strchr(start, ',');
        size_t bytes = end ? (size_t)(end - start) : strlen(start);
        if (bytes == (size_t)length && (!bytes || memcmp(start, label, bytes) == 0))
            return 1;
        if (!end) return 0;
        start = end + 1;
    }
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
