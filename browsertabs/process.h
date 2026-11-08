#pragma once
#ifdef _WIN32
#include "process_windows.h"
#else
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdlib.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <unistd.h>

static int vox_tabs_create_directory(char *pattern) {
    return mkdtemp(pattern) ? 0 : (errno ? errno : EINVAL);
}

// Keep the lock inode for the session's entire lifetime. Unlinking a lock on
// release lets a third process lock a different inode while a waiter holds it.
static int vox_tabs_lock(const char *path) {
    int fd = open(path, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
    if (fd < 0) return -1;
    while (flock(fd, LOCK_EX) != 0) {
        if (errno == EINTR) continue;
        close(fd);
        return -1;
    }
    return fd;
}
static void vox_tabs_unlock(int fd) { flock(fd, LOCK_UN); close(fd); }
static int vox_tabs_spawn(const char *exe, char **argv, char **env) {
    pid_t pid;
    return posix_spawn(&pid, exe, NULL, NULL, argv, env) == 0 ? pid : -1;
}
static int vox_tabs_alive(int pid) { return pid > 0 && (kill(pid, 0) == 0 || errno == EPERM); }
static void vox_tabs_terminate(int pid) { if (pid > 0) kill(pid, SIGTERM); }
static int vox_tabs_reap(int pid) { return waitpid(pid, NULL, WNOHANG) != 0; }
#endif

#ifdef __APPLE__
#include <dispatch/dispatch.h>

// Every state save renames a new state.json into the session directory, which
// reports a write on the directory itself.
typedef struct {
    void (*callback)(void *);
    void *context;
    int fd;
} vox_tabs_watch_state;

static dispatch_source_t vox_tabs_watcher;

static void vox_tabs_watch_event(void *data) {
    vox_tabs_watch_state *state = data;
    state->callback(state->context);
}

static void vox_tabs_watch_cancel(void *data) {
    vox_tabs_watch_state *state = data;
    close(state->fd);
    free(state);
}

static void vox_tabs_unwatch(void) {
    if (!vox_tabs_watcher) return;
    dispatch_source_cancel(vox_tabs_watcher);
#if !__has_feature(objc_arc)
    dispatch_release(vox_tabs_watcher);
#endif
    vox_tabs_watcher = NULL;
}

static int vox_tabs_watch(const char *folder, void (*callback)(void *), void *context) {
    vox_tabs_unwatch();
    int fd = open(folder, O_EVTONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    vox_tabs_watch_state *state = malloc(sizeof *state);
    if (!state) { close(fd); return -1; }
    *state = (vox_tabs_watch_state){ callback, context, fd };
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t)fd,
        DISPATCH_VNODE_WRITE, dispatch_get_main_queue());
    if (!source) { vox_tabs_watch_cancel(state); return -1; }
    dispatch_set_context(source, state);
    dispatch_source_set_event_handler_f(source, vox_tabs_watch_event);
    dispatch_source_set_cancel_handler_f(source, vox_tabs_watch_cancel);
    dispatch_resume(source);
    vox_tabs_watcher = source;
    return 0;
}
#else
static int vox_tabs_watch(const char *folder, void (*callback)(void *), void *context) {
    (void)folder; (void)callback; (void)context;
    return -1;
}
#endif
