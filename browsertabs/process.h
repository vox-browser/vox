#pragma once
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
