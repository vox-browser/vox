module webaudio

import math

fn close_enough(actual f32, expected f32) bool {
	return math.abs(f64(actual - expected)) < 0.0001
}

fn test_audio_param_timeline_set_and_ramp_events() {
	mut linear := AudioParamTimeline.create(0)
	assert linear.value_at_time(3) == 0
	assert linear.set_value_at_time(2, 1) == .success
	assert linear.value_at_time(0.5) == 0
	assert linear.value_at_time(1) == 2
	assert linear.linear_ramp_to_value_at_time(10, 5, 0, 0) == .success
	assert close_enough(linear.value_at_time(3), 6)
	assert linear.value_at_time(5) == 10

	mut exponential := AudioParamTimeline.create(1)
	assert exponential.exponential_ramp_to_value_at_time(16, 4, 0, 1) == .success
	assert close_enough(exponential.value_at_time(2), 4)
}

fn test_audio_param_timeline_target_and_curve_events() {
	mut target := AudioParamTimeline.create(0)
	assert target.set_target_at_time(10, 0, 1) == .success
	assert close_enough(target.value_at_time(1), f32(10 * (1 - math.exp(-1))))

	mut curve := AudioParamTimeline.create(-1)
	assert curve.set_value_curve_at_time([f32(0), 10, 0], 1, 2) == .success
	assert curve.value_at_time(0.5) == -1
	assert close_enough(curve.value_at_time(1.5), 5)
	assert close_enough(curve.value_at_time(2.5), 5)
	assert curve.value_at_time(3) == 0
}

fn test_audio_param_ramp_after_started_target_snapshots_its_start() {
	mut timeline := AudioParamTimeline.create(0)
	assert timeline.set_target_at_time(10, 0, 1) == .success
	assert timeline.linear_ramp_to_value_at_time(20, 4, 2, 0) == .success
	assert close_enough(timeline.value_at_time(1), f32(10 * (1 - math.exp(-1))))
	start_value := f32(10 * (1 - math.exp(-2)))
	assert close_enough(timeline.value_at_time(2), start_value)
	assert close_enough(timeline.value_at_time(3), start_value + (20 - start_value) / 2)
}

fn test_audio_param_timeline_rejects_value_curve_overlaps() {
	mut curve_first := AudioParamTimeline.create(0)
	assert curve_first.set_value_curve_at_time([f32(0), 1], 1, 2) == .success
	assert curve_first.set_value_at_time(2, 2) == .event_contained_in_value_curve

	mut event_first := AudioParamTimeline.create(0)
	assert event_first.set_value_at_time(2, 2) == .success
	assert event_first.set_value_curve_at_time([f32(0), 1], 1, 2) == .value_curve_overlaps_event
}

fn test_audio_param_timeline_cancellation() {
	mut scheduled := AudioParamTimeline.create(0)
	assert scheduled.set_value_at_time(2, 1) == .success
	assert scheduled.set_value_at_time(4, 2) == .success
	scheduled.cancel_scheduled_values(2)
	assert scheduled.value_at_time(3) == 2

	mut ramp := AudioParamTimeline.create(0)
	assert ramp.linear_ramp_to_value_at_time(10, 10, 0, 0) == .success
	ramp.cancel_and_hold_at_time(4)
	assert close_enough(ramp.value_at_time(4), 4)
	assert close_enough(ramp.value_at_time(8), 4)

	mut target := AudioParamTimeline.create(0)
	assert target.set_target_at_time(10, 0, 1) == .success
	target.cancel_scheduled_values(1)
	assert target.value_at_time(2) == 0

	mut curve := AudioParamTimeline.create(-1)
	assert curve.set_value_curve_at_time([f32(0), 10, 0], 1, 2) == .success
	curve.cancel_and_hold_at_time(2)
	assert curve.value_at_time(3) == 10

	mut curve_at_start := AudioParamTimeline.create(-1)
	assert curve_at_start.set_value_curve_at_time([f32(0), 10, 0], 1, 2) == .success
	curve_at_start.cancel_and_hold_at_time(1)
	assert curve_at_start.value_at_time(2) == -1
}

fn test_audio_param_timeline_samples_using_half_frame_selection() {
	mut timeline := AudioParamTimeline.create(0)
	assert timeline.set_value_at_time(7, 0.5) == .success
	mut output := []f32{len: 2}
	timeline.sample(0, 1, mut output)
	// Selection half a frame ahead makes a mid-frame event govern the nearest
	// sample, while its value is still evaluated at the exact frame time.
	assert output == [f32(7), 7]
}

fn test_audio_param_parameterization_cache_uses_half_open_intervals() {
	cache := ParameterizationCache{
		event_index: 2
		minimum_time: 1.5
		maximum_time: 3.5
		starting_value: 4
	}
	assert !cache.contains(1.499)
	assert cache.contains(1.5)
	assert cache.contains(3.499)
	assert !cache.contains(3.5)

	mut timeline := AudioParamTimeline.create(0)
	assert timeline.set_value_at_time(2, 1) == .success
	assert timeline.linear_ramp_to_value_at_time(10, 5, 0, 0) == .success
	before := timeline.parameterization_cache_for_time(0.5)
	assert before.event_index == none
	assert before.maximum_time or { 0 } == 1.0
	ramp := timeline.parameterization_cache_for_time(3)
	assert ramp.event_index or { -1 } == 1
	assert ramp.minimum_time or { 0 } == 1.0
	assert ramp.maximum_time or { 0 } == 5.0
	assert ramp.starting_value == 2
}

fn test_audio_param_validates_and_clamps_automation_times() {
	mut context := new_audio_context(1, 44_100, true) or { panic(err) }
	mut gain := GainNode.create(mut context.base, GainOptions{}) or { panic(err) }
	context.base.set_current_time(5)
	gain.gain.set_value_at_time(0.25, 1) or { panic(err) }
	assert gain.gain.intrinsic_value_at_time(5) == 0.25

	gain.gain.exponential_ramp_to_value_at_time(0, 6) or {
		assert err.msg().contains('must not be zero')
		return
	}
	assert false
}
