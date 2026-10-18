#ifndef VOX_ADBLOCK_WORKER_TRANSPORT_H
#define VOX_ADBLOCK_WORKER_TRANSPORT_H
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#ifdef __APPLE__
#include <libproc.h>
#include <sys/resource.h>
#endif

#ifndef VOX_AB_API
#define VOX_AB_API static
#endif
extern char **environ;
enum {
    VOX_AB_EVAL = 1, VOX_AB_QUIT = 2, VOX_AB_READY = 3,
    VOX_AB_RESULT = 4, VOX_AB_EVAL_ERROR = 5, VOX_AB_INIT_ERROR = 6,
    VOX_AB_CLOSED = 7, VOX_AB_TRANSPORT_ERROR = 8
};
static const char *vox_adblock_worker_role = "--vox-adblock-worker-v1";
/* All parent state is protected by the existing adblock mutex. */
static char *vox_adblock_worker_helper;
static pid_t vox_adblock_worker_pid;
/* Native chrome sampling never takes the evaluation lock. This lifecycle lock
   prevents reap/PID reuse while a physical-footprint query holds the child PID.
   Lock order: adblock evaluation mutex -> lifecycle mutex; no reverse acquire. */
static pthread_mutex_t vox_adblock_worker_lifecycle_mutex = PTHREAD_MUTEX_INITIALIZER;
static int vox_adblock_worker_tx = -1, vox_adblock_worker_rx = -1;
static int vox_adblock_worker_life = -1, vox_adblock_worker_timeout;
static uint64_t vox_adblock_worker_sequence;

static int64_t vox_ab_now_ms(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC, &value)) return 0;
    return (int64_t)value.tv_sec * 1000 + value.tv_nsec / 1000000;
}
static int vox_ab_wait_fd(int fd, short events, int64_t deadline) {
    for (;;) {
        int remaining = -1;
        if (deadline) {
            int64_t left = deadline - vox_ab_now_ms();
            if (left <= 0) { errno = ETIMEDOUT; return -1; }
            remaining = left > INT_MAX ? INT_MAX : (int)left;
        }
        struct pollfd item = {fd, events, 0};
        int result = poll(&item, 1, remaining);
        if (result < 0 && errno == EINTR) continue;
        if (!result) { errno = ETIMEDOUT; return -1; }
        if (result < 0) return -1;
        if (item.revents & POLLNVAL) { errno = EBADF; return -1; }
        return 0; /* read/write diagnoses EOF, EPIPE and short frames. */
    }
}
static ssize_t vox_ab_write_without_sigpipe(int fd, const void *bytes, size_t size) {
    sigset_t set, previous, pending;
    sigemptyset(&set); sigaddset(&set, SIGPIPE);
    int code = pthread_sigmask(SIG_BLOCK, &set, &previous);
    if (code) { errno = code; return -1; }
    sigpending(&pending);
    int had_pending = sigismember(&pending, SIGPIPE);
    ssize_t result = write(fd, bytes, size);
    int saved = errno;
    if (result < 0 && saved == EPIPE && !had_pending) {
        sigpending(&pending);
        if (sigismember(&pending, SIGPIPE)) {
            int received;
            (void)sigwait(&set, &received);
        }
    }
    (void)pthread_sigmask(SIG_SETMASK, &previous, NULL);
    errno = saved;
    return result;
}
static int vox_ab_write_all(int fd, const unsigned char *bytes, size_t size,
        int64_t deadline) {
    while (size) {
        if (vox_ab_wait_fd(fd, POLLOUT, deadline)) return -1;
        size_t part = size > 65536 ? 65536 : size;
        ssize_t written = vox_ab_write_without_sigpipe(fd, bytes, part);
        if (written < 0 && (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK)) continue;
        if (written <= 0) return -1;
        bytes += written; size -= (size_t)written;
    }
    return 0;
}
/* 0 is a clean EOF before any byte; -1 includes a truncated frame. */
static int vox_ab_read_all(int fd, unsigned char *bytes, size_t size,
        int64_t deadline, int allow_eof) {
    size_t original = size;
    while (size) {
        if (vox_ab_wait_fd(fd, POLLIN, deadline)) return -1;
        ssize_t got = read(fd, bytes, size);
        if (got < 0 && (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK)) continue;
        if (!got) {
            if (allow_eof && size == original) return 0;
            errno = EPROTO; return -1;
        }
        if (got < 0) return -1;
        bytes += got; size -= (size_t)got;
    }
    return 1;
}
static void vox_ab_put32(unsigned char *out, uint32_t value) {
    for (int i = 0; i < 4; i++) out[i] = (unsigned char)(value >> (24 - 8*i));
}
static uint32_t vox_ab_get32(const unsigned char *in) {
    return ((uint32_t)in[0] << 24) | ((uint32_t)in[1] << 16)
        | ((uint32_t)in[2] << 8) | in[3];
}
VOX_AB_API int vox_adblock_worker_send_frame(int fd, int kind, uint64_t id,
        const unsigned char *bytes, size_t size, int timeout_ms) {
    if (size > INT_MAX - 1 || (size && !bytes) || kind < 1 || kind > 8) {
        errno = EINVAL; return -1;
    }
    unsigned char header[24] = {'V','A','B','W',0,1,0,(unsigned char)kind};
    vox_ab_put32(header + 8, (uint32_t)(id >> 32));
    vox_ab_put32(header + 12, (uint32_t)id);
    vox_ab_put32(header + 16, (uint32_t)size);
    int64_t deadline = timeout_ms ? vox_ab_now_ms() + timeout_ms : 0;
    if (vox_ab_write_all(fd, header, sizeof header, deadline)) return -1;
    return vox_ab_write_all(fd, bytes, size, deadline);
}
VOX_AB_API int vox_adblock_worker_read_frame(int fd, int *kind, uint64_t *id,
        unsigned char **bytes, size_t *size, int timeout_ms) {
    *bytes = NULL; *size = 0;
    unsigned char header[24];
    int64_t deadline = timeout_ms ? vox_ab_now_ms() + timeout_ms : 0;
    int result = vox_ab_read_all(fd, header, sizeof header, deadline, 1);
    if (result != 1) return result;
    if (memcmp(header, "VABW", 4) || header[4] || header[5] != 1 || header[6]
        || header[7] < 1 || header[7] > 8 || vox_ab_get32(header + 20)) {
        errno = EPROTO; return -1;
    }
    uint32_t length = vox_ab_get32(header + 16);
    if (length > INT_MAX - 1) { errno = EMSGSIZE; return -1; }
    unsigned char *copy = malloc((size_t)length + 1);
    if (!copy) { errno = ENOMEM; return -1; }
    if (length && vox_ab_read_all(fd, copy, length, deadline, 0) != 1) {
        free(copy); return -1;
    }
    copy[length] = 0;
    *kind = header[7];
    *id = ((uint64_t)vox_ab_get32(header + 8) << 32) | vox_ab_get32(header + 12);
    *bytes = copy; *size = length;
    return 1;
}
static int vox_ab_pipe(int ends[2]) {
    if (pipe(ends)) return -1;
    if (fcntl(ends[0], F_SETFD, FD_CLOEXEC) < 0
        || fcntl(ends[1], F_SETFD, FD_CLOEXEC) < 0) {
        int saved = errno; close(ends[0]); close(ends[1]); errno = saved; return -1;
    }
    return 0;
}
static void vox_ab_close(int *fd) {
    if (*fd >= 0) { int previous = *fd; *fd = -1; (void)close(previous); }
}
static void vox_ab_reap_owned_child(pid_t pid) {
    if (pid <= 0) return;
    int status;
    for (int attempt = 0; attempt < 200; attempt++) {
        pid_t result = waitpid(pid, &status, WNOHANG);
        if (result == pid || (result < 0 && errno == ECHILD)) return;
        if (result < 0 && errno != EINTR) return;
        struct timespec pause = {0, 1000000}; nanosleep(&pause, NULL);
    }
    /* A zero waitpid result proves this PID is still our unreaped child. */
    pid_t result;
    do { result = waitpid(pid, &status, WNOHANG); } while (result < 0 && errno == EINTR);
    if (result != 0) return;
    (void)kill(pid, SIGKILL);
    do { result = waitpid(pid, &status, 0); } while (result < 0 && errno == EINTR);
}
static void vox_adblock_worker_cleanup(void) {
    pthread_mutex_lock(&vox_adblock_worker_lifecycle_mutex);
    pid_t pid = vox_adblock_worker_pid;
    vox_ab_close(&vox_adblock_worker_tx); vox_ab_close(&vox_adblock_worker_rx);
    vox_ab_close(&vox_adblock_worker_life);
    vox_ab_reap_owned_child(pid);
    vox_adblock_worker_pid = 0;
    pthread_mutex_unlock(&vox_adblock_worker_lifecycle_mutex);
}
VOX_AB_API int vox_adblock_worker_is_configured(void) { return vox_adblock_worker_helper != NULL; }
VOX_AB_API int vox_adblock_worker_get_pid(void) { return (int)vox_adblock_worker_pid; }
VOX_AB_API int vox_adblock_worker_configure(const unsigned char *path, size_t size, int timeout_ms) {
    if (vox_adblock_worker_pid) return EBUSY;
    if (timeout_ms < 0 || size > INT_MAX - 1) return EINVAL;
    if (!size) { free(vox_adblock_worker_helper); vox_adblock_worker_helper = NULL; return 0; }
    if (!path || path[0] != '/' || memchr(path, 0, size)) return EINVAL;
    char *copy = malloc(size + 1);
    if (!copy) return ENOMEM;
    memcpy(copy, path, size); copy[size] = 0;
    if (access(copy, X_OK)) { int saved = errno; free(copy); return saved; }
    free(vox_adblock_worker_helper); vox_adblock_worker_helper = copy;
    vox_adblock_worker_timeout = timeout_ms;
    return 0;
}
static int vox_ab_spawn(void) {
    int requests[2] = {-1,-1}, responses[2] = {-1,-1}, life[2] = {-1,-1};
    int child[3] = {-1,-1,-1}, result = -1;
    if (vox_ab_pipe(requests) || vox_ab_pipe(responses) || vox_ab_pipe(life)) goto done;
    /* High duplicates prevent file-action remaps colliding with originals 3/4/5. */
    child[0] = fcntl(requests[0], F_DUPFD_CLOEXEC, 10);
    child[1] = fcntl(responses[1], F_DUPFD_CLOEXEC, 10);
    child[2] = fcntl(life[0], F_DUPFD_CLOEXEC, 10);
    if (child[0] < 0 || child[1] < 0 || child[2] < 0) goto done;
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    int code = posix_spawn_file_actions_init(&actions);
    if (code) { errno = code; goto done; }
    code = posix_spawnattr_init(&attributes);
    if (code) { posix_spawn_file_actions_destroy(&actions); errno = code; goto done; }
    for (int i = 0; i < 3 && !code; i++) code = posix_spawn_file_actions_adddup2(&actions, child[i], 3+i);
    for (int i = 0; i < 3 && !code; i++) code = posix_spawn_file_actions_addclose(&actions, child[i]);
#ifdef __APPLE__
    if (!code) code = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT);
#elif defined(__GLIBC__)
    if (!code) code = posix_spawn_file_actions_addclosefrom_np(&actions, 6);
#endif
    pid_t pid = 0;
    char *arguments[] = {vox_adblock_worker_helper, (char*)vox_adblock_worker_role, NULL};
    pthread_mutex_lock(&vox_adblock_worker_lifecycle_mutex);
    if (!code) code = posix_spawn(&pid, vox_adblock_worker_helper, &actions,
        &attributes, arguments, environ);
    posix_spawnattr_destroy(&attributes); posix_spawn_file_actions_destroy(&actions);
    if (code) { pthread_mutex_unlock(&vox_adblock_worker_lifecycle_mutex); errno = code; goto done; }
    /* Deadlines also bound large writes after poll reports partial capacity. */
    if (fcntl(requests[1], F_SETFL, fcntl(requests[1], F_GETFL) | O_NONBLOCK) < 0
        || fcntl(responses[0], F_SETFL, fcntl(responses[0], F_GETFL) | O_NONBLOCK) < 0) {
        int saved = errno;
        close(life[1]); life[1] = -1;
        vox_ab_reap_owned_child(pid); pthread_mutex_unlock(&vox_adblock_worker_lifecycle_mutex); errno = saved; goto done;
    }
    vox_adblock_worker_pid = pid;
    pthread_mutex_unlock(&vox_adblock_worker_lifecycle_mutex);
    vox_adblock_worker_tx = requests[1]; requests[1] = -1;
    vox_adblock_worker_rx = responses[0]; responses[0] = -1;
    vox_adblock_worker_life = life[1]; life[1] = -1;
    result = 0;
done: {
    int saved = errno;
    for (int i = 0; i < 2; i++) { vox_ab_close(&requests[i]); vox_ab_close(&responses[i]); vox_ab_close(&life[i]); }
    for (int i = 0; i < 3; i++) vox_ab_close(&child[i]);
    errno = saved;
    return result;
}}
static int vox_ab_error_payload(unsigned char **bytes, size_t *size, const char *where) {
    char message[512];
    int saved = errno;
    int length = snprintf(message, sizeof message, "Adblock worker %s: %s", where, strerror(saved));
    if (length < 0) length = 0;
    if ((size_t)length >= sizeof message) length = sizeof message - 1;
    *bytes = malloc((size_t)length + 1); *size = 0;
    if (*bytes) { memcpy(*bytes, message, (size_t)length + 1); *size = (size_t)length; }
    return VOX_AB_TRANSPORT_ERROR;
}
VOX_AB_API int vox_adblock_worker_evaluate(const unsigned char *source, size_t length,
        unsigned char **output, size_t *output_size) {
    *output = NULL; *output_size = 0;
    if (!vox_adblock_worker_pid) {
        if (vox_ab_spawn()) {
            vox_ab_error_payload(output, output_size, "spawn"); return VOX_AB_TRANSPORT_ERROR;
        }
        int kind = 0; uint64_t id = 0;
        int received = vox_adblock_worker_read_frame(vox_adblock_worker_rx, &kind, &id,
            output, output_size, vox_adblock_worker_timeout);
        if (received == 1 && kind == VOX_AB_INIT_ERROR && id == 0) {
            vox_adblock_worker_cleanup(); return kind;
        }
        if (received != 1 || kind != VOX_AB_READY || id || *output_size) {
            free(*output); *output = NULL; *output_size = 0;
            errno = received == 0 ? EPIPE : received == 1 ? EPROTO : errno;
            vox_ab_error_payload(output, output_size, "initialization handshake");
            vox_adblock_worker_cleanup(); return VOX_AB_TRANSPORT_ERROR;
        }
        free(*output); *output = NULL; *output_size = 0;
    }
    uint64_t request = ++vox_adblock_worker_sequence;
    if (!request) request = ++vox_adblock_worker_sequence;
    if (vox_adblock_worker_send_frame(vox_adblock_worker_tx, VOX_AB_EVAL, request,
            source, length, vox_adblock_worker_timeout)) {
        vox_ab_error_payload(output, output_size, "request write");
        vox_adblock_worker_cleanup(); return VOX_AB_TRANSPORT_ERROR;
    }
    int kind = 0; uint64_t response = 0;
    int received = vox_adblock_worker_read_frame(vox_adblock_worker_rx, &kind, &response,
        output, output_size, vox_adblock_worker_timeout);
    if (received == 1 && response == request && (kind == VOX_AB_RESULT || kind == VOX_AB_EVAL_ERROR)) return kind;
    free(*output); *output = NULL; *output_size = 0;
    errno = received == 0 ? EPIPE : received == 1 ? EPROTO : errno;
    vox_ab_error_payload(output, output_size, "response read");
    vox_adblock_worker_cleanup(); return VOX_AB_TRANSPORT_ERROR;
}
VOX_AB_API int vox_adblock_worker_release(void) {
    if (!vox_adblock_worker_pid) return 0;
    uint64_t id = ++vox_adblock_worker_sequence;
    if (!id) id = ++vox_adblock_worker_sequence;
    unsigned char *bytes = NULL; size_t length = 0;
    int kind = 0; uint64_t response = 0;
    /* One shared 2s graceful-shutdown budget, independent of eval timeout.
       Closing the lifeline then bounds owned-child reap by a further 200ms. */
    int64_t deadline = vox_ab_now_ms() + 2000;
    if (!vox_adblock_worker_send_frame(vox_adblock_worker_tx, VOX_AB_QUIT, id, NULL, 0, 2000)) {
        int64_t left = deadline - vox_ab_now_ms();
        if (left > 0) {
            int received = vox_adblock_worker_read_frame(vox_adblock_worker_rx, &kind, &response,
                &bytes, &length, (int)left);
            if (received != 1 || kind != VOX_AB_CLOSED || response != id || length != 0)
                errno = received == 0 ? EPIPE : received == 1 ? EPROTO : errno;
        }
    }
    free(bytes);
    vox_adblock_worker_cleanup();
    return 1;
}
/* Process-tree footer accounting for the one directly owned helper. No RSS
   aggregation or private allocator API. A failed live-child query is surfaced
   as unavailable, rather than silently showing only the browser process. */
VOX_AB_API int vox_adblock_worker_memory_bytes(uint64_t *bytes) {
    if (!bytes) { errno = EINVAL; return -1; }
    *bytes = 0;
    int result = 0;
    pthread_mutex_lock(&vox_adblock_worker_lifecycle_mutex);
    pid_t pid = vox_adblock_worker_pid;
    if (pid > 0) {
#ifdef __APPLE__
        struct rusage_info_v4 usage;
        memset(&usage, 0, sizeof usage);
        result = proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&usage);
        if (!result) *bytes = usage.ri_phys_footprint;
#else
        errno = ENOTSUP; result = -1;
#endif
    }
    pthread_mutex_unlock(&vox_adblock_worker_lifecycle_mutex);
    return result;
}
static void *vox_ab_parent_lifetime_thread(void *unused) {
    (void)unused;
    unsigned char byte;
    for (;;) {
        ssize_t result = read(5, &byte, 1);
        if (result < 0 && errno == EINTR) continue;
        /* The parent never writes; EOF or an invalid lifeline ends the helper. */
        _exit(0);
    }
}
VOX_AB_API int vox_adblock_worker_begin_lifetime_watch(void) {
    struct stat info;
    for (int fd = 3; fd <= 5; fd++) {
        if (fstat(fd, &info) || !S_ISFIFO(info.st_mode)) return -1;
        int flags = fcntl(fd, F_GETFL);
        if (flags < 0 || (flags & O_ACCMODE) != (fd == 4 ? O_WRONLY : O_RDONLY)) return -1;
    }
    pthread_t thread;
    int code = pthread_create(&thread, NULL, vox_ab_parent_lifetime_thread, NULL);
    if (code) return -1;
    pthread_detach(thread);
    return 0;
}
#endif
