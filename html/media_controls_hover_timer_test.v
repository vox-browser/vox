module html

import dom
import platform
import time

fn timed_controls_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://timed-controls.example/'}
	mut document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing media owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing media model') }
	mut controls := MediaControls.create(media)
	if kind == 'video' {
		media.set_ready_state(.have_enough_data)
		media.on_video_track_added(MediaTrackMetadata{identifier: 1, pixel_width: 320, pixel_height: 180})
		media.set_show_poster(false)
		controls.update_placeholder_visibility()
	}
	return document, media, controls
}

fn timed_controls_visible(controls &MediaControls, expected bool) {
	mut bar := controls.dom_.control_bar or { panic('Missing control bar') }
	assert controls.visible == expected
	assert bar.class_list().contains('visible') == expected
	assert bar.class_list().contains('controls')
}

fn timed_controls_cleanup(mut controls MediaControls) {
	if mut timer := controls.hover_timer_ { timer.stop() }
	controls.remove_event_listeners()
}

fn test_controls_show_restarts_one_second_timer_and_successful_hide_releases_it() {
	mut document, media, mut controls := timed_controls_owner('video')!
	defer { timed_controls_cleanup(mut controls); document.finalize() }
	mut bar := controls.dom_.control_bar or { panic('Missing bar') }
	mut classes := bar.class_list()
	classes.add(['retained'])!
	mut timer := controls.hover_timer_ or { panic('Missing initial hover timer') }
	assert timer.is_single_shot() && timer.interval() == 1000
	assert timer.is_active() && timer.has_activity_root()
	timer.stop()
	controls.show_controls()
	assert (controls.hover_timer_ or { panic('Missing restarted timer') }) == timer
	assert timer.is_active() && timer.has_activity_root()
	for name in ['mouseenter', 'mousemove'] {
		assert !media.event_target().dispatch_event(dom.Event.create(name, dom.EventInit{cancelable: true}))
		assert (controls.hover_timer_ or { panic('Missing hover timer') }) == timer
	}
	timer.fire()
	timed_controls_visible(controls, false)
	assert controls.hover_timer_ == none && !timer.is_active() && !timer.has_activity_root()
	assert classes.contains('retained')
	controls.show_controls()
	mut next := controls.hover_timer_ or { panic('Missing new hover timer') }
	assert next != timer && next.is_active()
	// Immediate mouseleave must unregister the pending timeout before dropping it.
	assert !media.event_target().dispatch_event(dom.Event.create('mouseleave', dom.EventInit{cancelable: true}))
	assert controls.hover_timer_ == none && !next.is_active() && !next.has_activity_root()
	controls.show_controls()
	next.fire()
	timed_controls_visible(controls, true)
}

fn test_hover_timeout_preserves_scrubbing_hover_and_live_placeholder_guards() {
	mut document, mut media, mut controls := timed_controls_owner('video')!
	defer { timed_controls_cleanup(mut controls); document.finalize() }
	for guard in 0 .. 5 {
		controls.scrubbing_timeline = match guard {
			0 { MediaControlsScrubbing.while_paused }
			1 { MediaControlsScrubbing.while_playing }
			else { MediaControlsScrubbing.no }
		}
		controls.scrubbing_volume = guard == 2
		controls.hovering_controls = guard == 3
		media.set_show_poster(guard == 4)
		controls.show_controls()
		mut timer := controls.hover_timer_ or { panic('Missing guarded timer') }
		timer.fire()
		timed_controls_visible(controls, true)
		assert (controls.hover_timer_ or { panic('Guard dropped timer') }) == timer
		assert !timer.is_active() && !timer.has_activity_root()
		controls.scrubbing_timeline = .no
		controls.scrubbing_volume = false
		controls.hovering_controls = false
		// The hide predicate must inspect the live representation, not its cache.
		if guard == 4 { media.set_current_playback_position(1) }
		assert !controls.should_show_placeholder()
		controls.show_controls()
		assert (controls.hover_timer_ or { panic('Missing reused timer') }) == timer
		assert timer.is_active() && timer.has_activity_root()
		timer.fire()
		timed_controls_visible(controls, false)
		assert controls.hover_timer_ == none
	}
}

fn test_bar_exit_restarts_the_inactive_guarded_timer_before_delayed_hide() {
	mut document, media, mut controls := timed_controls_owner('video')!
	defer { timed_controls_cleanup(mut controls); document.finalize() }
	bar := controls.dom_.control_bar or { panic('Missing bar') }
	target := unsafe { &dom.EventTarget(bar.as_node()) }
	assert !target.dispatch_event(dom.Event.create('mouseenter', dom.EventInit{cancelable: true}))
	assert controls.hovering_controls
	mut timer := controls.hover_timer_ or { panic('Missing timer') }
	assert !media.event_target().dispatch_event(dom.Event.create('mouseleave', dom.EventInit{cancelable: true}))
	assert timer.is_active() // A guarded direct hide leaves the pending deadline alone.
	timer.fire()
	timed_controls_visible(controls, true)
	assert !timer.is_active()
	assert !target.dispatch_event(dom.Event.create('mouseleave', dom.EventInit{cancelable: true}))
	assert !controls.hovering_controls && timer.is_active()
	assert (controls.hover_timer_ or { panic('Missing restarted bar timer') }) == timer
	timed_controls_visible(controls, true)
	timer.fire()
	timed_controls_visible(controls, false)
	assert controls.hover_timer_ == none
}

fn test_audio_controls_receive_native_timeout_and_missing_bars_keep_numeric_adapter() {
	mut document, media, mut controls := timed_controls_owner('audio')!
	defer { timed_controls_cleanup(mut controls); document.finalize() }
	assert controls.dom_.placeholder_circle == none && media.paused()
	mut timer := controls.hover_timer_ or { panic('Missing audio hover timer') }
	assert timer.interval() == 1000 && timer.is_single_shot()
	assert platform.native_timer_scheduling_available()
	deadline := time.sys_mono_now() + i64(4 * time.second)
	for controls.visible && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
	}
	timed_controls_visible(controls, false)
	assert controls.hover_timer_ == none && !timer.is_active() && !timer.has_activity_root()
	mut ownerless := HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-timer.example/'})
	mut adapter := MediaControls.create(ownerless)
	defer { adapter.remove_event_listeners() }
	assert adapter.dom_.control_bar == none && adapter.hover_timer_ == none
	adapter.hide_controls()
	assert !adapter.visible
	adapter.show_controls()
	assert adapter.visible && adapter.hover_timer_ == none
	mut owned := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	root := owned.attach_a_user_agent_shadow_root(.named)
	foreign_media := html_media_element_for_dom_element(owned)?
	mut preserving := MediaControls.create(foreign_media)
	defer { preserving.remove_event_listeners() }
	assert owned.shadow_root()? == root
	assert preserving.dom_.control_bar == none && preserving.hover_timer_ == none
}
