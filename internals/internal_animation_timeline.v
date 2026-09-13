// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of InternalAnimationTimeline.cpp/.h.
module internals

import animations

@[heap]
pub struct InternalAnimationTimeline {
pub mut:
	timeline &animations.AnimationTimeline
mut:
	time_for_observation_ ?animations.TimeValue
}

pub fn InternalAnimationTimeline.create() &InternalAnimationTimeline {
	return &InternalAnimationTimeline{
		timeline: &animations.AnimationTimeline{
			kind_:         .generic
			current_time_: animations.TimeValue.milliseconds(0)
			monotonic_:    true
		}
	}
}

// The externally controlled clock does not derive a new time from the frame
// timestamp, but every frame still updates its associated animations.
pub fn (mut timeline InternalAnimationTimeline) update_current_time(_ f64) {
	timeline.timeline.update_associated_animations()
}

pub fn (_ &InternalAnimationTimeline) duration() ?animations.TimeValue {
	return none
}

pub fn (mut timeline InternalAnimationTimeline) set_time(time ?f64) {
	// Internals is allowed to control this monotonic test timeline directly.
	timeline.timeline.current_time_ = if value := time {
		animations.TimeValue.milliseconds(value)
	} else {
		none
	}
	for animation_pointer in timeline.timeline.associated_animations() {
		mut animation := unsafe { &animations.Animation(animation_pointer) }
		animation.update()
	}
}

pub fn (mut timeline InternalAnimationTimeline) set_time_for_observation(time f64) {
	timeline.time_for_observation_ = animations.TimeValue.milliseconds(time)
	timeline.timeline.last_current_time_update_task_generation_ = none
}

pub fn (_ &InternalAnimationTimeline) convert_a_timeline_time_to_an_origin_relative_time(_ ?animations.TimeValue) ?f64 {
	return none
}

pub fn (timeline &InternalAnimationTimeline) can_sample_current_time_at_timestamp() bool {
	return timeline.time_for_observation_ != none
}

pub fn (timeline &InternalAnimationTimeline) current_time_at_timestamp(_ f64) ?animations.TimeValue {
	return timeline.time_for_observation_
}

pub fn (timeline &InternalAnimationTimeline) current_time_for_observation() ?animations.TimeValue {
	if observed := timeline.current_time_at_timestamp(0) {
		return observed
	}
	return timeline.current_time()
}

pub fn (timeline &InternalAnimationTimeline) current_time() ?animations.TimeValue {
	return timeline.timeline.current_time()
}
