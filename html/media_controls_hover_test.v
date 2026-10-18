module html

import dom

@[heap]
struct HoverControlsProbe {
mut:
	outside_events int
}

fn hover_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing hover controls task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn hover_controls_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://hover-controls.example/'}
	mut document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing hover owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing hover media model') }
	mut controls := MediaControls.create(media)
	if kind == 'video' {
		media.set_ready_state(.have_enough_data)
		media.on_video_track_added(MediaTrackMetadata{identifier: 1, pixel_width: 320, pixel_height: 180})
		media.set_show_poster(false)
		controls.update_placeholder_visibility()
	}
	hover_controls_drain(media)
	return document, media, controls
}

fn hover_controls_send(target &dom.EventTarget, name string, handled bool) {
	// Source's no-argument hover callbacks accept ordinary Event instances too.
	event := dom.Event.create(name, dom.EventInit{cancelable: true})
	assert target.dispatch_event(event) == !handled
	assert event.default_prevented() == handled
}

fn hover_controls_assert_visible(controls &MediaControls, visible bool) {
	mut bar := controls.dom_.control_bar or { panic('Missing control bar') }
	assert controls.visible == visible && bar.class_list().contains('visible') == visible
	assert bar.class_list().contains('controls')
}

fn test_media_controls_bar_groups_widgets_and_preserves_unrelated_visibility_classes() {
	for kind in ['video', 'audio'] {
		mut document, media, mut controls := hover_controls_owner(kind)!
		defer { controls.remove_event_listeners(); document.finalize() }
		container := controls.dom_.container or { panic('Missing controls container') }
		mut bar := controls.dom_.control_bar or { panic('Missing control bar') }
		assert bar.is_html_element() && bar.local_name() == 'div' && bar.document() == document
		assert (bar.as_node().parent() or { panic('Missing control bar parent') }) == container.as_node()
		for widget in [controls.dom_.play_pause_icon, controls.dom_.timeline_track, controls.dom_.timestamp_element,
			controls.dom_.volume_area, controls.dom_.volume_fill, controls.dom_.mute_button, controls.dom_.fullscreen_icon] {
			element := widget or { panic('Missing bar widget') }
			assert (element.as_node().parent() or { panic('Missing widget parent') }) == bar.as_node()
		}
		if placeholder := controls.dom_.placeholder_circle {
			assert (placeholder.as_node().parent() or { panic('Missing placeholder parent') }) == container.as_node()
		}
		mut classes := bar.class_list()
		classes.add(['retained'])!
		hover_controls_assert_visible(controls, true)
		controls.hide_controls()
		hover_controls_assert_visible(controls, false)
		controls.show_controls()
		hover_controls_assert_visible(controls, true)
		assert classes.contains('retained') && media.current_src() == '' && media.paused()
	}
}

fn test_video_hover_events_follow_media_and_bar_targets_without_hiding_on_bar_exit() {
	mut document, media, mut controls := hover_controls_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	bar := controls.dom_.control_bar or { panic('Missing bar') }
	bar_target := unsafe { &dom.EventTarget(bar.as_node()) }
	assert controls.registered_event_listeners_.len == 18
	for name in ['mouseenter', 'mousemove', 'mouseleave'] {
		assert controls.registered_event_listeners_.filter(it.target == media.event_target() && it.event_name == name).len == 1
	}
	for name in ['mouseenter', 'mouseleave'] {
		assert controls.registered_event_listeners_.filter(it.target == bar_target && it.event_name == name).len == 1
	}
	controls.hide_controls()
	hover_controls_send(media.event_target(), 'mouseenter', true)
	hover_controls_assert_visible(controls, true)
	hover_controls_send(media.event_target(), 'mouseleave', true)
	hover_controls_assert_visible(controls, false)
	hover_controls_send(media.event_target(), 'mousemove', true)
	hover_controls_assert_visible(controls, true)
	hover_controls_send(bar_target, 'mouseenter', true)
	assert controls.hovering_controls
	hover_controls_send(media.event_target(), 'mouseleave', true)
	hover_controls_assert_visible(controls, true)
	hover_controls_send(bar_target, 'mouseleave', true)
	assert !controls.hovering_controls
	hover_controls_assert_visible(controls, true)
	hover_controls_send(media.event_target(), 'mouseleave', true)
	hover_controls_assert_visible(controls, false)
	assert media.paused() && media.current_playback_position() == 0
}

fn test_video_hover_leave_obeys_live_placeholder_and_scrubbing_guards() {
	mut document, mut media, mut controls := hover_controls_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	for state in [MediaControlsScrubbing.while_paused, .while_playing] {
		controls.scrubbing_timeline = state
		hover_controls_send(media.event_target(), 'mouseleave', true)
		hover_controls_assert_visible(controls, true)
	}
	controls.scrubbing_timeline = .no
	controls.scrubbing_volume = true
	hover_controls_send(media.event_target(), 'mouseleave', true)
	hover_controls_assert_visible(controls, true)
	controls.scrubbing_volume = false
	media.set_show_poster(true)
	assert controls.should_show_placeholder()
	hover_controls_send(media.event_target(), 'mouseleave', true)
	hover_controls_assert_visible(controls, true)
	media.set_current_playback_position(1)
	assert media.show_poster() && !controls.should_show_placeholder()
	hover_controls_send(media.event_target(), 'mouseleave', true)
	hover_controls_assert_visible(controls, false)
	controls.show_controls()
	media.set_ready_state(.have_nothing)
	hover_controls_send(media.event_target(), 'mouseleave', true)
	hover_controls_assert_visible(controls, true)
	hover_controls_drain(media)
}

fn test_hover_cleanup_preserves_other_listeners_and_skips_audio_or_missing_control_bars() {
	mut document, media, mut controls := hover_controls_owner('video')!
	defer { document.finalize() }
	bar := controls.dom_.control_bar or { panic('Missing bar') }
	probe := &HoverControlsProbe{}
	outside := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe, media] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert (event.target() or { panic('Missing owner event target') }) == media.event_target()
			assert (current or { panic('Missing current owner') }) == media.event_target()
			mut seen := unsafe { &HoverControlsProbe(probe) }
			seen.outside_events++
			return dom.js_undefined()
		}
	})
	media.event_target().add_event_listener_without_options('mouseenter', outside)
	defer { media.event_target().remove_event_listener_without_options('mouseenter', outside) }
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
	controls.hide_controls()
	hover_controls_send(media.event_target(), 'mouseenter', false)
	hover_controls_send(unsafe { &dom.EventTarget(bar.as_node()) }, 'mouseenter', false)
	hover_controls_assert_visible(controls, false)
	assert probe.outside_events == 1 && !controls.hovering_controls
	mut audio_document, audio, mut audio_controls := hover_controls_owner('audio')!
	defer { audio_controls.remove_event_listeners(); audio_document.finalize() }
	assert audio_controls.registered_event_listeners_.len == 13
	hover_controls_send(audio.event_target(), 'mouseleave', false)
	hover_controls_assert_visible(audio_controls, true)
	mut ownerless := HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-hover.example/'})
	mut adapter := MediaControls.create(ownerless)
	defer { adapter.remove_event_listeners() }
	assert adapter.dom_.control_bar == none && adapter.registered_event_listeners_.len == 13
	hover_controls_send(ownerless.event_target(), 'mouseenter', false)
	mut owned := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	root := owned.attach_a_user_agent_shadow_root(.named)
	foreign_media := html_media_element_for_dom_element(owned)?
	mut preserving := MediaControls.create(foreign_media)
	defer { preserving.remove_event_listeners() }
	assert owned.shadow_root()? == root && preserving.dom_.control_bar == none
	assert unsafe { &dom.Node(root) }.children_as_vector().len == 0
	assert preserving.registered_event_listeners_.len == 13
	hover_controls_send(foreign_media.event_target(), 'mouseenter', false)
}
