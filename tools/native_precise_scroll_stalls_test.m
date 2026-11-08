#import <Cocoa/Cocoa.h>
#include "precise_scroll_stalls.h"
#include <string.h>

// The exported frame must be found in snapshots of the real main thread.
__attribute__((noinline,visibility("default"))) void precise_scroll_known_slow_work(void) {
    volatile unsigned value=0;
    double end=CACurrentMediaTime()+.15;
    while (CACurrentMediaTime()<end) value++;
}
__attribute__((noinline,visibility("default"))) void precise_scroll_known_gap_work(void) {
    volatile unsigned value=0;
    double end=CACurrentMediaTime()+.15;
    while (CACurrentMediaTime()<end) value++;
}
int main(int argc, char **argv) {
    double epoch=CACurrentMediaTime();
    stall_monitor_start(10);
    usleep(30000);
    if (argc==2 && !strcmp(argv[1],"--gaps")) {
        // An intentionally slow input schedule is idle, not a delayed timer.
        stall_input_progress(6,500*NSEC_PER_MSEC);
        usleep(30000);
        stall_inputs_end();
        stall_input_progress(7,NSEC_PER_MSEC);
        uint64_t first=atomic_load(&stall_next_input_due);
        precise_scroll_known_gap_work();
        stall_input_progress(8,NSEC_PER_MSEC);
        uint64_t second=atomic_load(&stall_next_input_due);
        precise_scroll_known_gap_work();
        stall_inputs_end();
        uint64_t end=stall_now();
        usleep(30000);
        stall_monitor_finish(epoch);
        fprintf(stderr,"STALL_TEST_GAP inputs=7 start_us=%.3f end_us=%.3f\n",
            (first/1e9-epoch)*1e6,(second/1e9-epoch)*1e6);
        fprintf(stderr,"STALL_TEST_GAP inputs=8 start_us=%.3f end_us=%.3f\n",
            (second/1e9-epoch)*1e6,(end/1e9-epoch)*1e6);
        return 0;
    }
    StallScope outer=stall_frame_begin(1);
    precise_scroll_known_slow_work();
    StallScope inner=stall_frame_begin(2);
    precise_scroll_known_slow_work();
    stall_frame_end(inner);
    precise_scroll_known_slow_work();
    stall_frame_end(outer);
    usleep(30000);
    stall_monitor_finish(epoch);
    return 0;
}
