// Calibrate proc_pid_rusage CPU units against the POSIX process CPU clock.
#include <libproc.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

static unsigned long long cpu_ns(void) {
    struct timespec value;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &value);
    return (unsigned long long)value.tv_sec * 1000000000ull + value.tv_nsec;
}

int main(void) {
    struct rusage_info_v4 before, after;
    mach_timebase_info_data_t base;
    if (mach_timebase_info(&base) || proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&before)) return 2;
    unsigned long long start = cpu_ns(), end;
    volatile unsigned long long work = 1;
    do {
        for (unsigned i = 0; i < 100000; ++i) work = work * 6364136223846793005ull + i;
        end = cpu_ns();
    } while (end - start < 200000000ull);
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&after)) return 2;
    unsigned long long raw = after.ri_user_time - before.ri_user_time + after.ri_system_time - before.ri_system_time;
    double converted = (double)raw * base.numer / base.denom;
    printf("{\"raw_cpu_delta\":%llu,\"posix_cpu_ns\":%llu,\"mach_numer\":%u,\"mach_denom\":%u,\"converted_cpu_ns\":%.0f,\"converted_to_posix_ratio\":%.9f}\n",
           raw, end-start, base.numer, base.denom, converted, converted/(end-start));
    return !(converted/(end-start) > .98 && converted/(end-start) < 1.02);
}
