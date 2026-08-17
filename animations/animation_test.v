module animations

import dom

fn new_test_animation() (&Animation, &AnimationEffect, &AnimationTimeline) {
	mut timeline := AnimationTimeline.new()
	timeline.set_current_time(TimeValue.milliseconds(100))
	timeline.monotonic_ = true
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{
		fill:     .both
		duration: IterationDuration(1000.0)
	}) or { panic(err) }
	animation := Animation.create(effect, timeline)
	return animation, effect, timeline
}

fn test_animation_play_pause_finish_and_cancel() {
	mut animation, _, mut timeline := new_test_animation()
	assert animation.play_state() == .idle
	animation.play()!
	assert animation.pending()
	assert animation.ready().state() == .pending
	animation.update()
	assert animation.play_state() == .running
	assert animation.ready().state() == .fulfilled

	timeline.set_current_time(TimeValue.milliseconds(600))
	assert (animation.current_time() or { TimeValue.milliseconds(-1) }).value == 500
	animation.pause()!
	assert animation.pending()
	animation.update()
	assert animation.play_state() == .paused
	assert (animation.current_time() or { TimeValue.milliseconds(-1) }).value == 500

	animation.play()!
	animation.update()
	animation.finish()!
	assert animation.play_state() == .finished
	assert animation.finished().state() == .fulfilled
	assert animation.emitted_events().last().type_name() == 'finish'
	current_numberish := animation.emitted_events().last().current_time() or {
		assert false
		return
	}
	assert current_numberish is f64

	animation.cancel()
	assert animation.play_state() == .idle
	assert animation.emitted_events().last().type_name() == 'cancel'
	assert animation.finished().state() == .pending
}

fn test_animation_numberish_validation_and_reverse() {
	mut scroll := new_scroll_timeline(.y)
	scroll.set_current_time(TimeValue.percentage(50))
	mut animation := Animation.create(none, scroll)
	animation.set_current_time_numberish(CSSNumberish(PercentageValue{25}))!
	assert (animation.current_time() or { TimeValue.percentage(-1) }).value == 25
	if _ := animation.set_current_time_numberish(CSSNumberish(10.0)) {
		assert false
	} else {
		assert err.msg().contains('percentage')
	}
	animation.reverse()!
	assert (animation.pending_playback_rate_ or { 0 }) == -1
}

fn test_animation_playback_event_is_a_dom_event() {
	event := AnimationPlaybackEvent.create('finish', AnimationPlaybackEventInit{
		EventInit:    dom.EventInit{
			bubbles: true
		}
		current_time: CSSNumberish(250.0)
	})
	assert event.interface_ == .animation_playback_event
	assert event.type_name() == 'finish'
	assert event.bubbles()
	assert event.timeline_time() == none
}
