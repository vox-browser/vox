module platform

import time

fn test_thread_cpu_clock_advances_with_work_and_not_with_sleep() {
	start := thread_cpu_time_ns()
	if start < 0 {
		eprintln('skipping: no per-thread CPU clock')
		return
	}
	time.sleep(60 * time.millisecond)
	after_sleep := thread_cpu_time_ns()
	// Sleeping consumes almost no CPU time.
	assert after_sleep >= start
	assert after_sleep - start < 20 * time.millisecond
	mut value := u64(1)
	wall := time.sys_mono_now()
	for time.sys_mono_now() - wall < 40 * time.millisecond {
		value = value * 6364136223846793005 + 1442695040888963407
	}
	after_work := thread_cpu_time_ns()
	assert value != 0
	// A busy loop is charged to this thread; allow for preemption.
	assert after_work - after_sleep > 10 * time.millisecond
}
