#include <assert.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include "processmetrics/thread_instruction_counter_darwin.h"
#include "processmetrics/instruction_counter_darwin.h"

static int valid_reader(uint32_t kind, void *dst, size_t size) {
    assert(kind == 1 && size == sizeof(struct vox_thread_cpi));
    *(struct vox_thread_cpi *)dst = (struct vox_thread_cpi){123, 456};
    return 0;
}
static int failed_reader(uint32_t kind, void *dst, size_t size) {
    valid_reader(kind, dst, size); errno = EACCES; return -1;
}
static int errno_free_failure(uint32_t kind, void *dst, size_t size) {
    valid_reader(kind, dst, size); return -1;
}
static int positive_failure(uint32_t kind, void *dst, size_t size) {
    valid_reader(kind, dst, size); return EINVAL;
}
static int no_instructions(uint32_t kind, void *dst, size_t size) {
    valid_reader(kind, dst, size); ((struct vox_thread_cpi *)dst)->instructions = 0; return 0;
}
static int no_cycles(uint32_t kind, void *dst, size_t size) {
    valid_reader(kind, dst, size); ((struct vox_thread_cpi *)dst)->cycles = 0; return 0;
}
static uint64_t worker_instructions;
static void *worker(void *unused) {
    (void)unused;
    uint64_t begin = 0, end = 0;
    assert(vox_thread_instructions(&begin) == 0);
    volatile uint64_t checksum = 7;
    for (uint64_t i = 0; i < 5000000; ++i) checksum = checksum * 33 + i;
    assert(checksum != 0);
    assert(vox_thread_instructions(&end) == 0 && end > begin);
    worker_instructions = end - begin;
    return NULL;
}
int main(void) {
    uint64_t output = 999;
    assert(vox_thread_instructions_from_reader(NULL, valid_reader) == EINVAL);
    assert(vox_thread_instructions_from_reader(&output, NULL) == ENOTSUP && output == 0);
    assert(vox_thread_instructions_from_reader(&output, failed_reader) == EACCES && output == 0);
    assert(vox_thread_instructions_from_reader(&output, errno_free_failure) == EIO && output == 0);
    assert(vox_thread_instructions_from_reader(&output, positive_failure) == EINVAL && output == 0);
    assert(vox_thread_instructions_from_reader(&output, no_instructions) == ENOTSUP && output == 0);
    assert(vox_thread_instructions_from_reader(&output, no_cycles) == ENOTSUP && output == 0);
    assert(vox_thread_instructions_from_reader(&output, valid_reader) == 0 && output == 123);
    int status = vox_thread_instructions(&output);
    if (status) {
        assert(output == 0);
        printf("THREAD_COUNTER_UNAVAILABLE %d\n", status);
        return 0;
    }
    uint64_t process_before = 0, main_before = 0, main_after = 0, process_after = 0;
    assert(vox_process_instructions(&process_before) == 0);
    assert(vox_thread_instructions(&main_before) == 0);
    pthread_t id;
    assert(pthread_create(&id, NULL, worker, NULL) == 0);
    assert(pthread_join(id, NULL) == 0);
    assert(vox_thread_instructions(&main_after) == 0 && main_after > main_before);
    assert(vox_process_instructions(&process_after) == 0 && process_after > process_before);
    uint64_t process_delta = process_after - process_before;
    uint64_t main_delta = main_after - main_before;
    assert(worker_instructions > 1000000 && process_delta > main_delta);
    assert(process_delta - main_delta >= worker_instructions);
    printf("THREAD_COUNTER_PASS process=%" PRIu64 " main=%" PRIu64 " worker=%" PRIu64 "\n",
        process_delta, main_delta, worker_instructions);
}
