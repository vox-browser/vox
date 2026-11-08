module css

import dom
import math

// Embedders may decline a redundant style invalidation from a clock tick.
// The timeline update and animation event processing still run normally.
pub type AnimationClockDemandFilter = fn (&dom.Document, f64) bool

pub fn set_document_animation_clock_demand_filter(document &dom.Document, callback AnimationClockDemandFilter) {
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	mut computer := css_style_computer_for(document)
	computer.animation_clock_demand_filter_ = callback
}

// Does advancing the document clock require another sample? Scroll timelines
// use the current scroll source, and completed document effects retain their
// final value. A seek or rewind into the active interval remains eligible.
pub fn (animation &CSSAnimation) needs_style_sample_from_clock(time_ms f64) bool {
	if animation.play_state_ != .running || animation.effect_ == unsafe { nil } { return true }
	effect := animation.effect_
	if timeline := animation.timeline_ {
		if timeline.kind == .scroll {
			if timeline.scroll_subject_id == none { return true }
			mut source := unsafe { &AnimationTimeline(timeline) }
			_ := source.sample_anonymous_scroll_source() or {
				return effect.current_phase != .idle || effect.output_progress != none
			}
			current := timeline.current_time_ms() or { return true }
			previous := animation.last_sample_time_ or { return true }
			return current != previous
		}
	}
	if effect.current_phase == .after && animation.last_sample_time_ != none
		&& math.is_finite(effect.iteration_count) && math.is_finite(effect.specified_iteration_duration) {
		end := animation.start_time_ + effect.specified_start_delay
			+ math.max(0.0, effect.specified_iteration_duration) * math.max(0.0, effect.iteration_count)
		return !math.is_finite(end) || time_ms < end
	}
	return true
}
