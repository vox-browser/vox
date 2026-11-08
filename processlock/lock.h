#pragma once
#include <errno.h>
#include <fcntl.h>
#ifdef _WIN32
#include <io.h>
#include <sys/stat.h>
#include "../platform/windows_path.h"
static int vox_profile_lock(const char *path) {
    wchar_t *wide = vox_windows_wide_path(path);
    if (!wide) return -1;
    int fd = _wopen(wide, _O_CREAT | _O_RDWR | _O_BINARY | _O_NOINHERIT, _S_IREAD | _S_IWRITE);
    free(wide);
    if (fd < 0) return -1;
    OVERLAPPED offset = {0};
    if (!LockFileEx((HANDLE)_get_osfhandle(fd), LOCKFILE_EXCLUSIVE_LOCK, 0, 1, 0, &offset)) {
        _close(fd);
        return -1;
    }
    return fd;
}
static void vox_profile_unlock(int fd) {
    if (fd < 0) return;
    OVERLAPPED offset = {0};
    UnlockFileEx((HANDLE)_get_osfhandle(fd), 0, 1, 0, &offset);
    _close(fd);
}
#else
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
#endif
