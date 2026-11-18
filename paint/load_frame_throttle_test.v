module main

import time

fn loading_throttle(cost i64) LoadFrameThrottle {
	return LoadFrameThrottle{
		generation:   7
		presented_ns: 1000 * time.millisecond
		last_end_ns:  2000 * time.millisecond
		last_cost_ns: cost
	}
}

fn test_expensive_loading_frame_waits_for_three_times_its_cost() {
	state := loading_throttle(100 * time.millisecond)
	now := 2100 * time.millisecond
	assert state.deadline(now, 7) == 2300 * time.millisecond
	assert state.deadline(2300 * time.millisecond, 7) == 0
	assert state.deadline(2400 * time.millisecond, 7) == 0
}

fn test_loading_frame_gap_is_capped() {
	state := loading_throttle(400 * time.millisecond)
	assert state.deadline(2100 * time.millisecond, 7) == 2500 * time.millisecond
}

fn test_cheap_frames_new_documents_and_late_frames_are_not_throttled() {
	assert loading_throttle(10 * time.millisecond).deadline(2001 * time.millisecond, 7) == 0
	assert loading_throttle(100 * time.millisecond).deadline(2100 * time.millisecond, 8) == 0
	assert LoadFrameThrottle{}.deadline(2100 * time.millisecond, -1) == 0
	mut late := loading_throttle(100 * time.millisecond)
	late.presented_ns = 0
	late.last_end_ns = 10 * time.second + time.millisecond
	assert late.deadline(10 * time.second + 2 * time.millisecond, 7) == 0
}

fn test_recent_input_keeps_the_normal_frame_cadence() {
	mut state := loading_throttle(100 * time.millisecond)
	state.last_input_ns = 1500 * time.millisecond
	assert state.deadline(2100 * time.millisecond, 7) == 0
	state.last_input_ns = 900 * time.millisecond
	assert state.deadline(2100 * time.millisecond, 7) == 2300 * time.millisecond
}

// A frame ended at 2000 ms with the main thread's CPU clock at 700 ms.
fn quiet_throttle() LoadFrameThrottle {
	mut state := loading_throttle(100 * time.millisecond)
	state.quiet_start_ns = 2000 * time.millisecond
	state.quiet_cpu_ns = 700 * time.millisecond
	return state
}

fn test_idle_page_releases_its_frame_after_a_quiet_window() {
	mut state := quiet_throttle()
	// The gap lasts until 2300 ms; nothing ran and nothing is in flight.
	assert !state.quiet(2020 * time.millisecond, 701 * time.millisecond, false)
	assert state.wait(2020 * time.millisecond, 2300 * time.millisecond) == 30 * time.millisecond
	assert state.quiet(2050 * time.millisecond, 702 * time.millisecond, false)
	// Approving the frame does not consume the streak.
	assert state.quiet(2051 * time.millisecond, 702 * time.millisecond, false)
}

fn test_transfer_in_flight_keeps_the_gap_and_restarts_the_quiet_window() {
	mut state := quiet_throttle()
	assert !state.quiet(2060 * time.millisecond, 700 * time.millisecond, true)
	assert state.quiet_start_ns == 2060 * time.millisecond
	// Its response arrived without script work: quiet for a window from then.
	assert !state.quiet(2100 * time.millisecond, 701 * time.millisecond, false)
	assert state.wait(2100 * time.millisecond, 2300 * time.millisecond) == 10 * time.millisecond
	assert state.quiet(2110 * time.millisecond, 701 * time.millisecond, false)
}

fn test_script_work_keeps_the_gap_and_restarts_the_quiet_window() {
	mut state := quiet_throttle()
	// A 30 ms task after a long idle wait is not diluted by that wait.
	assert !state.quiet(2250 * time.millisecond, 730 * time.millisecond, false)
	assert state.quiet_start_ns == 2250 * time.millisecond
	assert state.quiet_cpu_ns == 730 * time.millisecond
	// Tasks that keep running never leave a quiet window.
	assert !state.quiet(2300 * time.millisecond, 765 * time.millisecond, false)
	assert !state.quiet(2350 * time.millisecond, 800 * time.millisecond, false)
	// Timer ticks and frame checks stay within the idle budget.
	assert state.quiet(2400 * time.millisecond, 808 * time.millisecond, false)
}

fn test_quiet_checks_never_wait_past_the_deadline_or_less_than_a_millisecond() {
	mut state := quiet_throttle()
	assert state.wait(2290 * time.millisecond, 2300 * time.millisecond) == time.millisecond
	state.quiet_start_ns = 2280 * time.millisecond
	assert state.wait(2290 * time.millisecond, 2300 * time.millisecond) == 10 * time.millisecond
	assert state.wait(2290 * time.millisecond, 2500 * time.millisecond) == 40 * time.millisecond
}

fn test_missing_thread_clock_or_streak_never_releases_early() {
	mut state := quiet_throttle()
	assert !state.quiet(2200 * time.millisecond, -1, false)
	// Without a clock nothing is recorded, so the frame waits for its deadline.
	assert state.quiet_start_ns == 2000 * time.millisecond
	mut fresh := loading_throttle(100 * time.millisecond)
	assert !fresh.quiet(2200 * time.millisecond, 700 * time.millisecond, false)
	assert fresh.quiet_start_ns == 2200 * time.millisecond
	assert fresh.wait(2100 * time.millisecond, 2300 * time.millisecond) == 150 * time.millisecond
}
