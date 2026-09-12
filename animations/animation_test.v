module animations

import dom
import html

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
	assert animation.ready().result().object_data == voidptr(animation)

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
	assert animation.finished().result().object_data == voidptr(animation)
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

fn test_animation_current_time_at_and_binding_helpers() {
	mut timeline := AnimationTimeline.new()
	timeline.set_current_time(TimeValue.milliseconds(100))
	mut animation := Animation.create(none, timeline)
	animation.start_time_ = TimeValue.milliseconds(25)
	animation.playback_rate_ = 2
	assert animation.current_time_at(TimeValue.milliseconds(100))!.value == 150
	numberish := animation.current_time_for_bindings().value or {
		assert false
		return
	}
	assert numberish is f64
	assert !animation.pending_for_bindings()
	assert animation.ready_for_bindings().result().object_data == voidptr(animation)

	animation.hold_time_ = TimeValue.milliseconds(40)
	assert animation.current_time_at(none)!.value == 40
	assert animation.play_state_at(TimeValue.milliseconds(0)) == .finished
}

fn test_construct_animation_selects_default_only_for_omitted_timeline() {
	default_timeline := AnimationTimeline.new()
	explicit_timeline := AnimationTimeline.new()
	omitted := construct_animation(none, none, default_timeline, 1)
	explicit := construct_animation(none, explicit_timeline, default_timeline, 2)
	explicit_null := construct_animation(none, none, default_timeline, 2)
	assert (omitted.timeline_ or { panic('missing default timeline') }) == default_timeline
	assert (explicit.timeline_ or { panic('missing explicit timeline') }) == explicit_timeline
	assert explicit_null.timeline_ == none
}

fn test_finished_binding_synchronizes_an_observed_skipped_animation() {
	mut timeline := new_document_timeline(none, 0, 0)
	timeline.set_document_active(true)
	mut effect := KeyframeEffect.create()
	effect.AnimationEffect.update_timing(OptionalEffectTiming{
		duration: IterationDuration(10.0)
	})!
	effect.set_is_compositor_driven(true)
	mut animation := Animation.create(effect.as_animation_effect(), timeline)
	animation.start_time_ = TimeValue.milliseconds(0)
	assert animation.play_state() == .running
	assert animation.finished().state() == .pending

	timeline.monotonic_timestamp_offset_ -= 100
	mut event_loop := html.main_thread_event_loop()
	event_loop.process()
	promise := animation.finished_for_bindings()
	assert promise.state() == .fulfilled
	assert promise.result().object_data == voidptr(animation)
	assert animation.is_finished()
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
