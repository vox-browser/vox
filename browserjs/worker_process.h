// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_BROWSERJS_WORKER_PROCESS_H
#define VOX_BROWSERJS_WORKER_PROCESS_H

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

// Private, versioned IPC for an independently executing script agent. All
// channel operations belong to the owning event-loop thread. No V/DOM/JSC
// state crosses threads, and no read or write blocks that event loop.
#define VOX_JS_WORKER_ROLE "--vox-script-worker-v1"
#define VOX_JS_WORKER_MAX_FRAME (16u * 1024u * 1024u)
#define VOX_JS_WORKER_MAX_QUEUE (64u * 1024u * 1024u)
#define VOX_JS_WORKER_IO_QUANTUM (1024u * 1024u)

typedef struct vox_js_worker_output {
    struct vox_js_worker_output *next;
    size_t length, offset;
    unsigned char bytes[];
} vox_js_worker_output;

typedef struct vox_js_worker_process {
    pid_t pid;
    int fd, lifetime_fd, failed;
    unsigned char header[12];
    size_t header_used, payload_used, payload_length;
    uint32_t kind;
    unsigned char *payload;
    vox_js_worker_output *first, *last;
    size_t queued, allocated;
} vox_js_worker_process;

static uint32_t vox_js_worker_u32(const unsigned char *p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16)
        | ((uint32_t)p[2] << 8) | p[3];
}

static void vox_js_worker_put_u32(unsigned char *p, uint32_t n)
{
    p[0] = (unsigned char)(n >> 24); p[1] = (unsigned char)(n >> 16);
    p[2] = (unsigned char)(n >> 8); p[3] = (unsigned char)n;
}

static int vox_js_worker_fail(vox_js_worker_process *p, int code)
{
    p->failed = code;
    errno = code;
    return -1;
}

static int vox_js_worker_nonblocking(int fd)
{
    int flags = fcntl(fd, F_GETFL);
    if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) return -1;
    if (fcntl(fd, F_SETFD, FD_CLOEXEC) < 0) return -1;
#ifdef SO_NOSIGPIPE
    int yes = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof yes) < 0) return -1;
#endif
    return 0;
}

static vox_js_worker_process *vox_js_worker_channel(int fd)
{
    if (vox_js_worker_nonblocking(fd) < 0) return NULL;
    vox_js_worker_process *p = calloc(1, sizeof *p);
    if (!p) return NULL;
    p->fd = fd;
    p->lifetime_fd = -1;
    return p;
}

// The sender owns a private copy, including binary NUL bytes. A rejected queue
// operation changes nothing and never partially publishes a frame.
static int vox_js_worker_queue(vox_js_worker_process *p, uint32_t kind,
    const unsigned char *bytes, size_t length)
{
    if (p->failed) { errno = p->failed; return -1; }
    if (!kind || length > VOX_JS_WORKER_MAX_FRAME || (length && !bytes)) {
        errno = EINVAL; return -1;
    }
    size_t total = 12 + length;
    if (sizeof(vox_js_worker_output) + total > VOX_JS_WORKER_MAX_QUEUE - p->allocated) {
        errno = ENOBUFS; return -1;
    }
    vox_js_worker_output *out = malloc(sizeof *out + total);
    if (!out) return -1;
    out->next = NULL; out->offset = 0; out->length = total;
    memcpy(out->bytes, "VXW1", 4);
    vox_js_worker_put_u32(out->bytes + 4, kind);
    vox_js_worker_put_u32(out->bytes + 8, (uint32_t)length);
    if (length) memcpy(out->bytes + 12, bytes, length);
    if (p->last) p->last->next = out;
    else p->first = out;
    p->last = out;
    p->queued += total;
    p->allocated += sizeof *out + total;
    return 0;
}

// 1: drained, 0: pending, -1: terminal I/O error. Limit work per turn even
// when the peer is actively draining a very large queue.
static int vox_js_worker_flush(vox_js_worker_process *p)
{
    if (p->failed) { errno = p->failed; return -1; }
    size_t budget = VOX_JS_WORKER_IO_QUANTUM;
    while (p->first && budget) {
        vox_js_worker_output *out = p->first;
        size_t part = out->length - out->offset;
        if (part > budget) part = budget;
        int flags = 0;
#ifdef MSG_NOSIGNAL
        flags = MSG_NOSIGNAL;
#endif
        ssize_t count = send(p->fd, out->bytes + out->offset, part, flags);
        if (count < 0) {
            if (errno == EINTR) continue;
            if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
            return vox_js_worker_fail(p, errno);
        }
        if (!count) return vox_js_worker_fail(p, EPIPE);
        out->offset += (size_t)count;
        p->queued -= (size_t)count;
        budget -= (size_t)count;
        if (out->offset == out->length) {
            p->first = out->next;
            if (!p->first) p->last = NULL;
            p->allocated -= sizeof *out + out->length;
            free(out);
        }
    }
    return p->first ? 0 : 1;
}

// 1: one complete malloc-owned frame; 0: pending; 2: clean EOF; -1: invalid
// frame, truncated stream or I/O failure. Never dispatch an incomplete value.
static int vox_js_worker_receive(vox_js_worker_process *p, uint32_t *kind,
    unsigned char **bytes, size_t *length)
{
    *bytes = NULL; *length = 0; *kind = 0;
    if (p->failed) { errno = p->failed; return -1; }
    size_t budget = VOX_JS_WORKER_IO_QUANTUM;
    while (budget) {
        int header = p->header_used < sizeof p->header;
        size_t remaining = header ? sizeof p->header - p->header_used
            : p->payload_length - p->payload_used;
        if (!remaining) {
            *kind = p->kind; *bytes = p->payload; *length = p->payload_length;
            p->payload = NULL;
            p->header_used = p->payload_used = p->payload_length = 0;
            return 1;
        }
        size_t part = remaining < budget ? remaining : budget;
        unsigned char *destination = header ? p->header + p->header_used
            : p->payload + p->payload_used;
        ssize_t count = recv(p->fd, destination, part, 0);
        if (count < 0) {
            if (errno == EINTR) continue;
            if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
            return vox_js_worker_fail(p, errno);
        }
        if (!count) {
            if (p->header_used || p->payload_used)
                return vox_js_worker_fail(p, EPROTO);
            return 2;
        }
        budget -= (size_t)count;
        if (header) {
            p->header_used += (size_t)count;
            if (p->header_used == sizeof p->header) {
                p->kind = vox_js_worker_u32(p->header + 4);
                p->payload_length = vox_js_worker_u32(p->header + 8);
                if (memcmp(p->header, "VXW1", 4) || !p->kind
                    || p->payload_length > VOX_JS_WORKER_MAX_FRAME)
                    return vox_js_worker_fail(p, EPROTO);
                if (p->payload_length) {
                    p->payload = malloc(p->payload_length);
                    if (!p->payload) return vox_js_worker_fail(p, ENOMEM);
                }
            }
        } else p->payload_used += (size_t)count;
    }
    return 0;
}

static int vox_js_worker_wait(vox_js_worker_process *p, int timeout_ms)
{
    if (p->failed) { errno = p->failed; return -1; }
    if (timeout_ms < 0) { errno = EINVAL; return -1; }
    struct pollfd fd = {p->fd, POLLIN | (p->first ? POLLOUT : 0), 0};
    // EINTR returns control to the agent instead of restarting its deadline.
    int result = poll(&fd, 1, timeout_ms);
    if (result < 0 && errno == EINTR) return 0;
    return result;
}

static void vox_js_worker_reap(pid_t pid)
{
    if (pid > 0) {
        int status;
        pid_t result;
        do { result = waitpid(pid, &status, WNOHANG); }
        while (result < 0 && errno == EINTR);
        // Only a live, unreaped owned child may be signalled. ECHILD must
        // never turn a recycled PID into a termination target.
        if (!result) {
            (void)kill(pid, SIGKILL);
            do { result = waitpid(pid, &status, 0); }
            while (result < 0 && errno == EINTR);
        }
    }
}

static void vox_js_worker_destroy(vox_js_worker_process *p)
{
    if (!p) return;
    close(p->fd);
    if (p->lifetime_fd >= 0) close(p->lifetime_fd);
    vox_js_worker_reap(p->pid);
    while (p->first) {
        vox_js_worker_output *next = p->first->next;
        free(p->first); p->first = next;
    }
    free(p->payload);
    free(p);
}

static int vox_js_worker_high_fd(int fd)
{
    int result = fcntl(fd, F_DUPFD_CLOEXEC, 5);
    int saved = errno;
    close(fd);
    errno = saved;
    return result;
}

static vox_js_worker_process *vox_js_worker_spawn(const char *executable)
{
    if (!executable || !*executable) { errno = EINVAL; return NULL; }
    int pair[2], life[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, pair)) return NULL;
    if (pipe(life)) { close(pair[0]); close(pair[1]); return NULL; }
    // Move every endpoint above the reserved child descriptors before dup2.
    // This also handles callers whose stdin/stdout are already closed.
    int fds[4] = {pair[0], pair[1], life[0], life[1]};
    int code = 0;
    for (int i = 0; i < 4; ++i) {
        fds[i] = vox_js_worker_high_fd(fds[i]);
        if (fds[i] < 0) { code = errno; break; }
    }
    vox_js_worker_process *p = NULL;
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    int have_actions = 0, have_attributes = 0;
    if (!code) { code = posix_spawn_file_actions_init(&actions); have_actions = !code; }
    if (!code) { code = posix_spawnattr_init(&attributes); have_attributes = !code; }
    if (!code) code = posix_spawn_file_actions_adddup2(&actions, fds[1], 3);
    if (!code) code = posix_spawn_file_actions_adddup2(&actions, fds[2], 4);
    if (!code) code = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    if (!code) code = posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
    if (!code) code = posix_spawn_file_actions_adddup2(&actions, STDERR_FILENO, STDERR_FILENO);
    short flags = POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF;
#ifdef __APPLE__
    flags |= POSIX_SPAWN_CLOEXEC_DEFAULT;
#else
    // glibc 2.34+, matching the Linux browser's supported build environment.
    if (!code) code = posix_spawn_file_actions_addclosefrom_np(&actions, 5);
#endif
    sigset_t mask, defaults;
    sigemptyset(&mask); sigemptyset(&defaults);
    sigaddset(&defaults, SIGPIPE); sigaddset(&defaults, SIGTERM);
    sigaddset(&defaults, SIGINT);
    if (!code) code = posix_spawnattr_setsigmask(&attributes, &mask);
    if (!code) code = posix_spawnattr_setsigdefault(&attributes, &defaults);
    if (!code) code = posix_spawnattr_setflags(&attributes, flags);
    pid_t pid = 0;
    extern char **environ;
    char *const arguments[] = {(char *)executable, (char *)VOX_JS_WORKER_ROLE, NULL};
    if (!code) code = posix_spawn(&pid, executable, &actions, &attributes, arguments, environ);
    if (have_attributes) posix_spawnattr_destroy(&attributes);
    if (have_actions) posix_spawn_file_actions_destroy(&actions);
    if (!code) {
        p = vox_js_worker_channel(fds[0]);
        if (!p) {
            code = errno;
            vox_js_worker_reap(pid);
        } else {
            p->pid = pid; p->lifetime_fd = fds[3];
            fds[0] = fds[3] = -1;
        }
    }
    for (int i = 0; i < 4; ++i) if (fds[i] >= 0) close(fds[i]);
    if (code) errno = code;
    return p;
}

static void *vox_js_worker_watch_parent(void *unused)
{
    (void)unused;
    unsigned char byte;
    // This descriptor is a separate lifeline: a worker running an infinite
    // JavaScript loop still exits when its owning browser process disappears.
    for (;;) {
        ssize_t count = read(4, &byte, 1);
        if (count < 0 && errno == EINTR) continue;
        _exit(count == 0 ? 0 : 74);
    }
}

static vox_js_worker_process *vox_js_worker_begin_child(void)
{
    int type = 0;
    socklen_t size = sizeof type;
    struct stat lifetime;
    if (getsockopt(3, SOL_SOCKET, SO_TYPE, &type, &size) || type != SOCK_STREAM
        || fstat(4, &lifetime) || !S_ISFIFO(lifetime.st_mode)) {
        errno = EINVAL; return NULL;
    }
    vox_js_worker_process *p = vox_js_worker_channel(3);
    if (!p) return NULL;
    if (fcntl(4, F_SETFD, FD_CLOEXEC) < 0) {
        int saved = errno; vox_js_worker_destroy(p); errno = saved; return NULL;
    }
    pthread_t thread;
    int code = pthread_create(&thread, NULL, vox_js_worker_watch_parent, NULL);
    if (code) { vox_js_worker_destroy(p); errno = code; return NULL; }
    pthread_detach(thread);
    return p;
}
#endif
