#import <Cocoa/Cocoa.h>
#include "precise_scroll_stalls.h"

// The exported frame must be found in snapshots of the real main thread.
__attribute__((noinline,visibility("default"))) void precise_scroll_known_slow_work(void) {
    volatile unsigned value=0;
    double end=CACurrentMediaTime()+.15;
    while (CACurrentMediaTime()<end) value++;
}
int main(void) {
    double epoch=CACurrentMediaTime();
    stall_monitor_start(10);
    usleep(30000);
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
