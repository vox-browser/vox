#pragma once
#include <errno.h>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
static int vox_profile_lock(const char *path) {
    int fd = open(path, O_CREAT|O_RDWR|O_CLOEXEC, 0600);
    if (fd < 0) return -1;
    while (flock(fd, LOCK_EX) != 0) {
        if (errno == EINTR) continue;
        close(fd); return -1;
    }
    return fd;
}
static void vox_profile_unlock(int fd) { if (fd >= 0) { flock(fd, LOCK_UN); close(fd); } }
