module animations

import dom

fn test_cancel_invalidates_the_target_and_discards_compositor_effects() {
	mut document := dom.Document.create(dom.url_about_blank())
	target := document.create_element('div')!
	mut effect := KeyframeEffect.with_duration(target, []BaseKeyframe{}, 1000)!
	mut timeline := AnimationTimeline.new()
	timeline.set_current_time(TimeValue.milliseconds(100))
	mut animation := Animation.create(effect.as_animation_effect(), timeline)
	animation.play()!
	animation.update()
	effect.set_is_compositor_driven(true)
	animation.effect_invalidated_ = false
	document.needs_animated_style_update = false
	// Upstream clears start/hold before obtaining the active time with fill Both.
	// Without an observation override, the newly idle effect is unresolved.
	animation.saved_cancel_time_ = TimeValue.milliseconds(57)
	animation.cancel()
	assert animation.play_state() == .idle
	assert animation.release_saved_cancel_time() == none
	assert animation.effect_invalidated_
	assert !effect.is_compositor_driven()
	assert document.needs_animated_style_update
}

fn test_cascade_cancellation_can_suppress_redundant_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	target := document.create_element('div')!
	mut effect := KeyframeEffect.with_duration(target, []BaseKeyframe{}, 1000)!
	mut animation := Animation.create(effect.as_animation_effect(), none)
	effect.set_is_compositor_driven(true)
	animation.effect_invalidated_ = false
	document.needs_animated_style_update = false
	animation.cancel_with_invalidation(.no)
	assert !animation.effect_invalidated_
	assert effect.is_compositor_driven()
	assert !document.needs_animated_style_update
}

fn test_idle_cancel_still_invalidates_and_retains_unrelated_time_state() {
	mut effect := AnimationEffect.new()
	mut animation := Animation.create(effect, none)
	animation.effect_invalidated_ = false
	animation.previous_current_time_ = TimeValue.milliseconds(3)
	animation.pending_playback_rate_ = 2
	animation.auto_align_start_time_ = true
	animation.cancel()
	assert animation.effect_invalidated_
	assert (animation.pending_playback_rate_ or { panic('missing pending rate') }) == 2
	assert animation.auto_align_start_time_
	assert (animation.previous_current_time_ or { panic('missing previous time') }).value == 3
	assert animation.emitted_events().len == 0
}
