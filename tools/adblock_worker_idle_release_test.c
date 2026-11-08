#include <pthread.h>
#include <errno.h>
static int fail_idle_thread;
static int create_idle_thread(pthread_t *thread, const pthread_attr_t *attributes,
        void *(*entry)(void *), void *argument) {
    if (fail_idle_thread) return EAGAIN;
    return pthread_create(thread, attributes, entry, argument);
}
#define VOX_AB_CREATE_IDLE_THREAD create_idle_thread
#include "../adblock/worker_transport.h"
#include <assert.h>

static pid_t exiting_workers[2];
static void assert_reaped(pid_t pid) {
    int status;
    errno = 0;
    assert(waitpid(pid, &status, WNOHANG) == -1 && errno == ECHILD);
}
static void assert_exit_reaped(void) {
    assert(!vox_adblock_worker_get_pid() && !vox_ab_retiring.running);
    for (unsigned i = 0; i < 2; ++i) assert_reaped(exiting_workers[i]);
}
static int descriptors(void) {
    int count = 0;
    for (int fd = 0; fd < 1024; ++fd) if (fcntl(fd, F_GETFD) >= 0) ++count;
    return count;
}
static void evaluate(void) {
    unsigned char *bytes = NULL;
    size_t size = 0;
    assert(vox_adblock_worker_evaluate((const unsigned char *)"ready", 5,
        &bytes, &size) == VOX_AB_RESULT);
    assert(size == 5 && !memcmp(bytes, "ready", size));
    free(bytes);
}
int main(int argc, char **argv) {
    assert(argc == 2 || argc == 3);
    if (argc == 3) assert(atexit(assert_exit_reaped) == 0);
    assert(vox_adblock_worker_configure((const unsigned char *)argv[1], strlen(argv[1]), 3000) == 0);
    int baseline = descriptors();
    setenv("VOX_AB_FAKE_MODE", "hang-on-quit", 1);
    evaluate();
    pid_t retiring = vox_adblock_worker_get_pid();
    assert(retiring > 0);
    if (argc == 2) {
        // Failed handoff leaves all transport state usable, with no fd loss.
        fail_idle_thread = 1;
        assert(!vox_adblock_worker_release_idle() && errno == EAGAIN);
        assert(vox_adblock_worker_get_pid() == retiring);
        assert(!vox_ab_retiring.running && descriptors() == baseline + 3);
        evaluate();
        assert(vox_adblock_worker_get_pid() == retiring);
        fail_idle_thread = 0;
    }
    int64_t started = vox_ab_now_ms();
    assert(vox_adblock_worker_release_idle());
    int64_t handoff_ms = vox_ab_now_ms() - started;
    assert(handoff_ms < 100); // A 2s shutdown must never run on the caller.
    assert(vox_adblock_worker_get_pid() == 0 && kill(retiring, 0) == 0);
    uint64_t bytes = 0;
    assert(vox_adblock_worker_memory_bytes(&bytes) == 0 && bytes > 0);
    unsetenv("VOX_AB_FAKE_MODE");
    // Replacement evaluation completes while the old helper ignores quit.
    evaluate();
    pid_t replacement = vox_adblock_worker_get_pid();
    assert(replacement > 0 && replacement != retiring && kill(retiring, 0) == 0);
    assert(!vox_adblock_worker_release_idle()); // At most one retirement slot.
    assert(vox_adblock_worker_get_pid() == replacement);
    assert(vox_adblock_worker_memory_bytes(&bytes) == 0 && bytes > 0);
    if (argc == 3) {
        exiting_workers[0] = retiring;
        exiting_workers[1] = replacement;
        return 0; // Exit cleanup must drain both current and retiring helpers.
    }
    assert(vox_adblock_worker_release()); // Explicit synchronous API drains both.
    assert_reaped(retiring); assert_reaped(replacement);
    assert(!vox_adblock_worker_release());
    assert(vox_adblock_worker_memory_bytes(&bytes) == 0 && bytes == 0);
    assert(descriptors() == baseline);
    // Repeated normal retirement reuses the slot without retaining descriptors.
    for (int i = 0; i < 8; ++i) {
        evaluate();
        pid_t pid = vox_adblock_worker_get_pid();
        assert(vox_adblock_worker_release_idle());
        (void)vox_adblock_worker_release();
        assert_reaped(pid);
        assert(descriptors() == baseline);
    }
    assert(vox_adblock_worker_configure(NULL, 0, 0) == 0);
    printf("Idle worker handoff %lld ms: hung quit, concurrent replacement, bounded retirement, "
        "thread failure, memory ownership, fd cleanup and repeated reap pass\n", (long long)handoff_ms);
    return 0;
}
