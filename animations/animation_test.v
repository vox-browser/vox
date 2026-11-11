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
	assert (animation.current_time_at(TimeValue.milliseconds(100)) or { panic('missing current time') }).value == 150
	numberish := animation.current_time_for_bindings().value or {
		assert false
		return
	}
	assert numberish is f64
	assert !animation.pending_for_bindings()
	assert animation.ready_for_bindings().result().object_data == voidptr(animation)

	animation.hold_time_ = TimeValue.milliseconds(40)
	assert (animation.current_time_at(none) or { panic('missing held current time') }).value == 40
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

fn test_animation_constructor_is_infallible() {
	timeline := AnimationTimeline.new()
	animation := Animation.construct_impl(none, timeline)
	assert (animation.timeline_ or { panic('missing constructor timeline') }) == timeline
}

fn test_finished_binding_synchronizes_an_observed_skipped_animation() {
	mut timeline := new_document_timeline(none, 0, 0)
	timeline.set_document_active(true)
	mut effect := KeyframeEffect.create()
	effect.AnimationEffect.update_timing(OptionalEffectTiming{
		duration: IterationDuration(10.0)
	})!
	mut animation := Animation.create(effect.as_animation_effect(), timeline)
	effect.set_is_compositor_driven(true)
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

fn test_animation_effect_replacement_moves_target_association() {
	document := dom.Document.create(dom.url_about_blank())
	first_target := document.create_element('div')!
	second_target := document.create_element('div')!
	mut first_effect := KeyframeEffect.create()
	first_effect.set_target(first_target)
	mut second_effect := KeyframeEffect.create()
	second_effect.set_target(second_target)
	mut animation := Animation.create(first_effect.as_animation_effect(), none)

	mut first_animatable := Animatable.new(first_target)
	assert first_animatable.associated_animations_in_composite_order() == [animation]
	first_effect.set_is_compositor_driven(true)
	second_effect.set_is_compositor_driven(true)
	animation.set_effect(second_effect.as_animation_effect())
	assert !first_animatable.has_associated_animations()
	mut second_animatable := Animatable.new(second_target)
	assert second_animatable.associated_animations_in_composite_order() == [animation]
	assert first_effect.associated_animation_ == none
	assert second_effect.associated_animation_ != none
	assert !first_effect.is_compositor_driven()
	assert !second_effect.is_compositor_driven()
}

fn test_animation_replace_state_moves_target_and_timeline_associations() {
	document := dom.Document.create(dom.url_about_blank())
	target := document.create_element('div')!
	mut effect := KeyframeEffect.create()
	effect.set_target(target)
	mut timeline := AnimationTimeline.new()
	mut animation := Animation.create(effect.as_animation_effect(), timeline)
	mut animatable := Animatable.new(target)
	assert animatable.has_associated_animations()
	assert timeline.associated_animations_.len == 1

	animation.set_replace_state(.removed)
	assert !animatable.has_associated_animations()
	assert timeline.associated_animations_.len == 0
	animation.set_replace_state(.persisted)
	assert animatable.associated_animations_in_composite_order() == [animation]
	assert timeline.associated_animations_ == [animation]
}

fn test_animation_css_cancellation_disassociates_until_replayed() {
	document := dom.Document.create(dom.url_about_blank())
	target := document.create_element('div')!
	mut effect := KeyframeEffect.create()
	effect.set_target(target)
	mut animation := Animation.create(effect.as_animation_effect(), none)
	mut animatable := Animatable.new(target)
	assert animatable.has_associated_animations()

	animation.schedule_disassociation_from_target_after_css_cancellation()
	assert animation.css_cancellation_disassociation_pending()
	animation.disassociate_from_target_after_css_cancellation()
	assert !animation.css_cancellation_disassociation_pending()
	assert !animatable.has_associated_animations()
	animation.play_an_animation(true)!
	assert animatable.associated_animations_in_composite_order() == [animation]
}

fn test_animation_provisional_effect_can_be_discarded_without_target_exposure() {
	mut animation := Animation.create(none, none)
	mut effect := AnimationEffect.new()
	animation.set_provisional_effect(effect)
	installed_effect := animation.effect_ or { panic('missing provisional effect') }
	assert installed_effect == effect
	associated := effect.associated_animation_ or { panic('missing association') }
	assert associated == animation

	animation.discard_provisional_effect()
	assert animation.effect_ == none
	assert effect.associated_animation_ == none
}

fn test_animation_recovers_relevant_settings_from_its_timeline_document() {
	mut document := dom.Document.create(dom.url_about_blank())
	_ := html.WindowModel.create_top_level(document, none, 'animation-global')!
	mut timeline := new_document_timeline(document, 0, 0)
	timeline.set_document_active(true)
	animation := Animation.create(none, timeline)
	settings := animation.relevant_settings_object() or { panic('missing settings') }
	assert settings == unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	explicit_animation := Animation.create_with_environment(settings, none, none)
	assert (explicit_animation.relevant_settings_object() or { panic('missing explicit settings') }) == settings
	global_object := animation.relevant_global_object() or { panic('missing global') }
	assert global_object == settings.global_object()
	global_impl := animation.relevant_global_impl() or { panic('missing global implementation') }
	assert global_impl == global_object
	assert Animation.effect_offset() == uint(__offsetof(Animation, effect_))
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
