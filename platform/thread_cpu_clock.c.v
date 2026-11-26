module platform

#include "@DIR/thread_cpu_clock.h"

fn C.vox_thread_cpu_time_ns() i64

// thread_cpu_time_ns returns the CPU time the calling thread has consumed, or
// a negative value where the platform has no per-thread clock. A thread that
// waits in its run loop does not advance it, so the difference between two
// readings tells how busy the thread was in between.
pub fn thread_cpu_time_ns() i64 {
	return C.vox_thread_cpu_time_ns()
}
