// Sampling aid: hold a process at load and at exit so /usr/bin/sample can attach
// for the whole run and symbolicate before the task disappears. Diagnostic only.
#include <stdlib.h>
#include <unistd.h>
static void exit_delay(void) {
    const char *ms = getenv("VOXPROBE_EXIT_DELAY_MS");
    if (ms) usleep((useconds_t)atoi(ms) * 1000);
}
__attribute__((constructor)) static void load_delay(void) {
    const char *ms = getenv("VOXPROBE_DELAY_MS");
    if (ms) usleep((useconds_t)atoi(ms) * 1000);
    atexit(exit_delay);
}
