#pragma once
// CPU time consumed by the calling thread, in nanoseconds, or -1 where the
// platform has no per-thread clock. Idle waits in the run loop do not advance it.
#if defined(__APPLE__) || defined(__linux__)
#include <time.h>

static long long vox_thread_cpu_time_ns(void) {
	struct timespec value;
	if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &value) != 0) return -1;
	return (long long)value.tv_sec * 1000000000LL + (long long)value.tv_nsec;
}
#elif defined(_WIN32)
#include <windows.h>

static long long vox_thread_cpu_time_ns(void) {
	FILETIME created, exited, kernel, user;
	if (!GetThreadTimes(GetCurrentThread(), &created, &exited, &kernel, &user)) return -1;
	ULARGE_INTEGER kernel_time, user_time;
	kernel_time.LowPart = kernel.dwLowDateTime;
	kernel_time.HighPart = kernel.dwHighDateTime;
	user_time.LowPart = user.dwLowDateTime;
	user_time.HighPart = user.dwHighDateTime;
	// FILETIME counts 100 ns intervals.
	return (long long)((kernel_time.QuadPart + user_time.QuadPart) * 100ULL);
}
#else
static long long vox_thread_cpu_time_ns(void) { return -1; }
#endif
