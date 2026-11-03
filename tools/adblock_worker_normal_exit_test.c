#include "../adblock/worker_transport.h"
#include <assert.h>

static pid_t last_worker;

/* Registered before lazy worker startup, so the transport must reap first. */
static void assert_exit_reaped_worker(void) {
    int status = 0;
    assert(vox_adblock_worker_get_pid() == 0);
    errno = 0;
    assert(waitpid(last_worker, &status, WNOHANG) == -1 && errno == ECHILD);
}

int main(int argc, char **argv) {
    assert(argc == 2 || argc == 3);
    assert(atexit(assert_exit_reaped_worker) == 0);
    assert(vox_adblock_worker_configure((const unsigned char *)argv[1],
        strlen(argv[1]), 3000) == 0);
    for (int i = 0; i < 3; ++i) {
        unsigned char *bytes = NULL;
        size_t size = 0;
        assert(vox_adblock_worker_evaluate((const unsigned char *)"ready", 5,
            &bytes, &size) == VOX_AB_RESULT);
        assert(size == 5 && !memcmp(bytes, "ready", size));
        free(bytes);
        last_worker = vox_adblock_worker_get_pid();
        assert(last_worker > 0);
        if (i < 2 || argc == 3) assert(vox_adblock_worker_release() == 1);
    }
    return 0;
}
