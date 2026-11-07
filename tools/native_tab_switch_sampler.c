// Sample which windows of the given processes are on screen.
//
// usage: native_tab_switch_sampler DURATION_MS PID...
//
// Polls the window server's on-screen list (owner PID, layer and bounds need
// no screen-recording permission) about every 2 ms and prints one JSON line
// per change: {"t":NANOSECONDS,"windows":[[pid,x,y,width,height],...]}. Only
// ordinary (layer 0) windows with a visible alpha are reported, in front-to-
// back order. Used to verify that switching tab processes never leaves the
// browser window absent from the screen.
#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static int number(CFDictionaryRef window, CFStringRef key, double *value) {
    CFNumberRef ref = CFDictionaryGetValue(window, key);
    return ref && CFNumberGetValue(ref, kCFNumberDoubleType, value);
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s DURATION_MS PID...\n", argv[0]);
        return 2;
    }
    long duration = strtol(argv[1], NULL, 10);
    int count = argc - 2;
    int *pids = calloc((size_t)count, sizeof *pids);
    for (int i = 0; i < count; i++) pids[i] = atoi(argv[i + 2]);
    uint64_t start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    char previous[8192] = "", current[8192];
    for (;;) {
        uint64_t now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        if ((long)((now - start) / 1000000) > duration) break;
        CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
        size_t used = (size_t)snprintf(current, sizeof current, "[");
        CFIndex total = windows ? CFArrayGetCount(windows) : 0;
        int first = 1;
        for (CFIndex i = 0; i < total; i++) {
            CFDictionaryRef window = CFArrayGetValueAtIndex(windows, i);
            double pid = 0, layer = -1, alpha = 0;
            if (!number(window, kCGWindowOwnerPID, &pid) || !number(window, kCGWindowLayer, &layer)) continue;
            number(window, kCGWindowAlpha, &alpha);
            if (layer != 0 || alpha <= 0) continue;
            int known = 0;
            for (int p = 0; p < count; p++) known |= pids[p] == (int)pid;
            if (!known) continue;
            CGRect bounds = CGRectZero;
            CFDictionaryRef rect = CFDictionaryGetValue(window, kCGWindowBounds);
            if (rect) CGRectMakeWithDictionaryRepresentation(rect, &bounds);
            if (used < sizeof current - 128)
                used += (size_t)snprintf(current + used, sizeof current - used, "%s[%d,%.0f,%.0f,%.0f,%.0f]",
                    first ? "" : ",", (int)pid, bounds.origin.x, bounds.origin.y,
                    bounds.size.width, bounds.size.height);
            first = 0;
        }
        if (windows) CFRelease(windows);
        snprintf(current + used, sizeof current - used, "]");
        if (strcmp(current, previous) != 0) {
            printf("{\"t\":%llu,\"windows\":%s}\n", (unsigned long long)(now - start), current);
            fflush(stdout);
            strcpy(previous, current);
        }
        usleep(2000);
    }
    return 0;
}
