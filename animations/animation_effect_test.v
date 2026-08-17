module animations

import math

fn test_animation_effect_timing_validation_and_computed_timing() {
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{
		delay:           100
		end_delay:       50
		fill:            .both
		iteration_start: 0.25
		iterations:      2
		duration:        IterationDuration(500.0)
		direction:       .alternate
		easing:          'ease-in'
	})!
	timing := effect.get_timing()
	assert timing.delay == 100
	assert timing.end_delay == 50
	assert timing.fill == .both
	assert timing.iterations == 2
	assert timing.easing == 'ease-in'
	assert effect.active_duration().value == 1000
	assert effect.end_time().value == 1150

	if _ := effect.update_timing(OptionalEffectTiming{ iteration_start: -1 }) {
		assert false
	} else {
		assert err.msg() == 'Invalid iteration start value'
	}
	if _ := effect.update_timing(OptionalEffectTiming{ iterations: math.nan() }) {
		assert false
	} else {
		assert err.msg() == 'Invalid iteration count value'
	}
	if _ := effect.update_timing(OptionalEffectTiming{ duration: IterationDuration('1s') }) {
		assert false
	} else {
		assert err.msg() == 'Invalid duration value'
	}
	if _ := effect.update_timing(OptionalEffectTiming{ easing: 'not-an-easing' }) {
		assert false
	} else {
		assert err.msg() == 'Invalid easing function'
	}
}

fn test_animation_effect_phase_iteration_and_direction() {
	mut timeline := AnimationTimeline.new()
	timeline.set_current_time(TimeValue.milliseconds(0))
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{
		fill:       .both
		iterations: 2
		duration:   IterationDuration(1000.0)
		direction:  .alternate
	})!
	mut animation := Animation.create(effect, timeline)

	animation.set_current_time(TimeValue.milliseconds(-10))!
	assert effect.phase() == .before
	assert (effect.active_time() or { TimeValue.milliseconds(-1) }).value == 0

	animation.set_current_time(TimeValue.milliseconds(250))!
	assert effect.phase() == .active
	assert (effect.current_iteration() or { -1 }) == 0
	assert (effect.simple_iteration_progress() or { -1 }) == 0.25
	assert (effect.directed_progress() or { -1 }) == 0.25

	animation.set_current_time(TimeValue.milliseconds(1250))!
	assert (effect.current_iteration() or { -1 }) == 1
	assert effect.current_direction() == .backwards
	assert (effect.directed_progress() or { -1 }) == 0.75

	animation.set_current_time(TimeValue.milliseconds(2000))!
	assert effect.phase() == .after
	assert (effect.simple_iteration_progress() or { -1 }) == 1
	assert (effect.current_iteration() or { -1 }) == 1
}

fn test_progress_timeline_normalizes_timing_to_percentages() {
	mut timeline := new_scroll_timeline(.block)
	timeline.set_current_time(TimeValue.percentage(25))
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{
		delay:      100
		end_delay:  100
		iterations: 2
		duration:   IterationDuration(400.0)
	})!
	_ = Animation.create(effect, timeline)
	assert effect.start_delay_.type_ == .percentage
	assert effect.start_delay_.value == 10
	assert effect.iteration_duration_.value == 40
	assert effect.end_delay_.value == 10
}
