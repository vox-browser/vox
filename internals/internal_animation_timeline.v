// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of InternalAnimationTimeline.cpp/.h.
module internals

import animations

@[heap]
pub struct InternalAnimationTimeline {
pub mut:
	timeline &animations.AnimationTimeline
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

// Upstream's update_current_time override intentionally does nothing.
pub fn (timeline &InternalAnimationTimeline) update_current_time(_ f64) {}

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

pub fn (timeline &InternalAnimationTimeline) current_time() ?animations.TimeValue {
	return timeline.timeline.current_time()
}
