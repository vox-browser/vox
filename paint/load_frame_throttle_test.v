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
