module html

import dom

@[heap]
struct PlayClickProbe {
mut:
	starts int
	pauses int
	outside int
}

fn play_click_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing play click task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn play_click_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls, &PlayClickProbe) {
	url := dom.URL{value: 'https://play-click.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing play click owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing play click model') }
	media.set_duration(60)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.seekable_.add_range(0, 60)
	media.on_audio_track_added(MediaTrackMetadata{identifier: 1})
	if kind == 'video' {
		media.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180})
	}
	media.set_show_poster(false)
	probe := &PlayClickProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [probe] () {
			mut state := unsafe { &PlayClickProbe(probe) }
			state.starts++
		}
		pause: fn [probe] () {
			mut state := unsafe { &PlayClickProbe(probe) }
			state.pauses++
		}
	})
	controls := MediaControls.create(media)
	play_click_drain(media)
	return document, media, controls, probe
}

fn play_click_cleanup(mut controls MediaControls) {
	controls.remove_event_listeners()
	if mut timer := controls.hover_timer_ { timer.stop() }
}

fn play_click_send(element &dom.Element, cancelable bool, bubbles bool, handled bool) {
	event := dom.Event.construct_impl('click', dom.EventInit{cancelable: cancelable, bubbles: bubbles}) or { panic(err) }
	assert !event.is_trusted()
	assert unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event) == !(handled && cancelable)
	assert event.default_prevented() == (handled && cancelable)
}

fn test_play_button_click_uses_user_play_for_audio_and_video_and_retains_the_icon() {
	mut policy := AutoplaySettings.the()
	previous := policy.policy()
	allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous, allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	for kind in ['audio', 'video'] {
		mut document, mut media, mut controls, probe := play_click_owner(kind)!
		defer { play_click_cleanup(mut controls); document.finalize() }
		mut button := controls.dom_.play_button?
		icon := controls.dom_.play_pause_icon?
		assert button.is_html_element() && button.local_name() == 'button'
		assert button.class_list().contains('control-button') && button.class_list().contains('play-pause-button')
		assert (icon.as_node().parent() or { panic('Missing icon parent') }) == button.as_node()
		target := unsafe { &dom.EventTarget(button.as_node()) }
		assert controls.registered_event_listeners_.filter(it.target == target && it.event_name == 'click').len == 1
		assert media.play().state() == .rejected && media.paused()
		controls.hide_controls()
		assert !controls.visible && controls.hover_timer_ == none
		play_click_send(button, true, false, true)
		assert !media.paused() && probe.starts == 1 && controls.play_icon_is_pause && controls.visible
		assert media.pending_play_promises_.len == 0 && media.event_count('play') == 0
		play_click_drain(media)
		assert media.event_count('play') == 1 && media.event_count('playing') == 1
		// Source's no-argument listener also handles a non-cancelable ordinary Event.
		play_click_send(button, false, false, true)
		assert media.paused() && probe.pauses == 1 && !controls.play_icon_is_pause
		play_click_drain(media)
		assert media.event_count('pause') == 1 && controls.dom_.play_pause_icon? == icon
		assert !document.get_window()?.has_sticky_activation() && media.play().state() == .rejected
	}
}

fn test_play_click_bubbles_from_icons_and_video_placeholder_without_toggling_the_control_bar() {
	mut document, media, mut controls, probe := play_click_owner('video')!
	defer { play_click_cleanup(mut controls); document.finalize() }
	mut button := controls.dom_.play_button?
	icon := controls.dom_.play_pause_icon?
	overlay := controls.dom_.video_overlay?
	placeholder := controls.dom_.placeholder_circle?
	bar := controls.dom_.control_bar?
	container := controls.dom_.container?
	assert (placeholder.as_node().parent() or { panic('Missing placeholder parent') }) == overlay.as_node()
	assert (overlay.as_node().parent() or { panic('Missing overlay parent') }) == container.as_node()
	assert (bar.as_node().parent() or { panic('Missing bar parent') }) == container.as_node()
	assert overlay != bar && overlay != container
	button.set_attribute_value('disabled', '')
	html_element_click(unsafe { &dom.HTMLElement(button) })
	assert media.paused() && probe.starts == 0
	button.remove_attribute('disabled')
	play_click_send(icon, true, true, true)
	assert !media.paused() && probe.starts == 1 && probe.pauses == 0
	play_click_drain(media)
	play_click_send(placeholder, true, true, true)
	assert media.paused() && probe.starts == 1 && probe.pauses == 1
	play_click_drain(media)
	for part in [bar, controls.dom_.timestamp_element?, container] {
		play_click_send(part, true, true, false)
		assert media.paused() && probe.starts == 1 && probe.pauses == 1
	}
	// The speaker's sibling click must not bubble into a video play handler.
	play_click_send(controls.dom_.mute_button?, true, true, true)
	assert media.muted() && media.paused() && probe.starts == 1
	html_element_click(unsafe { &dom.HTMLElement(button) })
	assert !media.paused() && probe.starts == 2
	play_click_drain(media)
	play_click_send(overlay, true, false, true)
	assert media.paused() && probe.pauses == 2
	play_click_drain(media)
}

fn test_play_click_scrubbing_guards_and_cleanup_preserve_unrelated_listeners() {
	mut document, media, mut controls, probe := play_click_owner('video')!
	defer { play_click_cleanup(mut controls); document.finalize() }
	button := controls.dom_.play_button?
	overlay := controls.dom_.video_overlay?
	controls.hide_controls()
	for phase in [MediaControlsScrubbing.while_paused, .while_playing] {
		controls.scrubbing_timeline = phase
		for part in [button, overlay] {
			play_click_send(part, true, true, true)
			assert media.paused() && probe.starts == 0 && probe.pauses == 0
			assert !controls.visible && controls.hover_timer_ == none
			assert media.queued_media_task_ids_.len == 0 && media.pending_play_promises_.len == 0
		}
	}
	controls.scrubbing_timeline = .no
	target := unsafe { &dom.EventTarget(button.as_node()) }
	outside := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &PlayClickProbe(probe) }
			state.outside++
			return dom.js_undefined()
		}
	})
	target.add_event_listener_without_options('click', outside)
	defer { target.remove_event_listener_without_options('click', outside) }
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
	play_click_send(button, true, true, false)
	play_click_send(overlay, true, true, false)
	assert media.paused() && probe.starts == 0 && probe.outside == 1 && !controls.visible
}

fn test_play_click_follows_adoption_and_has_no_video_overlay_on_audio_or_missing_widgets() {
	mut first, first_media, mut controls, first_probe := play_click_owner('video')!
	mut second, second_media, mut other, second_probe := play_click_owner('audio')!
	defer {
		play_click_cleanup(mut controls)
		play_click_cleanup(mut other)
		first.finalize()
		second.finalize()
	}
	owner := first.get_element_by_id('player')?
	second.adopt_node(owner.as_node())
	button := controls.dom_.play_button?
	overlay := controls.dom_.video_overlay?
	assert button.document() == second && overlay.document() == second && first_media.document()? == second
	play_click_send(button, true, true, true)
	assert !first_media.paused() && second_media.paused() && first_probe.starts == 1 && second_probe.starts == 0
	play_click_drain(first_media)
	play_click_send(overlay, true, true, true)
	play_click_drain(first_media)
	assert first_media.paused() && first_probe.pauses == 1
	assert other.dom_.play_button != none && other.dom_.video_overlay == none
	mut ownerless := MediaControls.create(HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-play.example/'}))
	defer { ownerless.remove_event_listeners() }
	assert ownerless.dom_.play_button == none && ownerless.dom_.video_overlay == none
	assert ownerless.registered_event_listeners_.len == 13
	mut element := second.create_element('video')!
	root := element.attach_a_user_agent_shadow_root(.named)
	mut preserving := MediaControls.create(html_media_element_for_dom_element(element)?)
	defer { preserving.remove_event_listeners() }
	assert element.shadow_root()? == root && preserving.dom_.play_button == none && preserving.dom_.video_overlay == none
	assert preserving.registered_event_listeners_.len == 13
}
