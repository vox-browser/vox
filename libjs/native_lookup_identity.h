#ifndef VOX_LIBJS_NATIVE_LOOKUP_IDENTITY_H
#define VOX_LIBJS_NATIVE_LOOKUP_IDENTITY_H
#include <sys/stat.h>
#include <stdint.h>

// Device, inode, size and nanosecond modification/status-change times of a
// file. Returns 0 on success. Used to recognize an already verified library.
static inline int vox_libjs_native_file_identity(const char *path, uint64_t out[7]) {
	struct stat info;
	if (stat(path, &info) != 0) return -1;
	out[0] = (uint64_t)info.st_dev;
	out[1] = (uint64_t)info.st_ino;
	out[2] = (uint64_t)info.st_size;
#if defined(__APPLE__)
	out[3] = (uint64_t)info.st_mtimespec.tv_sec;
	out[4] = (uint64_t)info.st_mtimespec.tv_nsec;
	out[5] = (uint64_t)info.st_ctimespec.tv_sec;
	out[6] = (uint64_t)info.st_ctimespec.tv_nsec;
#else
	out[3] = (uint64_t)info.st_mtim.tv_sec;
	out[4] = (uint64_t)info.st_mtim.tv_nsec;
	out[5] = (uint64_t)info.st_ctim.tv_sec;
	out[6] = (uint64_t)info.st_ctim.tv_nsec;
#endif
	return 0;
}
#endif
