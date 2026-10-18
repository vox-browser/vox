module html

import dom

fn play_pause_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing play/pause controls task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn play_pause_controls_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://play-pause-controls.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing play/pause owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing play/pause media') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	controls := MediaControls.create(media)
	play_pause_controls_drain(media)
	mut window := document.get_window() or { return error('Missing play/pause Window') }
	window.set_last_activation_timestamp(dom.current_high_resolution_time(window))
	assert window.has_sticky_activation()
	return document, media, controls
}

fn play_pause_controls_assert(controls &MediaControls, playing bool) {
	assert controls.play_icon_is_pause == playing
	mut icon := controls.dom_.play_pause_icon or { panic('Missing play/pause icon') }
	assert icon.class_list().contains('playing') == playing
	assert icon.class_list().contains('retained') && icon.class_list().contains('custom-icon')
}

fn test_play_pause_controls_preserve_other_tokens_through_actual_playback_and_queued_events() {
	for kind in ['video', 'audio'] {
		mut document, media, mut controls := play_pause_controls_owner(kind)!
		defer { controls.remove_event_listeners(); document.finalize() }
		mut icon := controls.dom_.play_pause_icon?
		mut classes := icon.class_list()
		classes.add(['retained', 'custom-icon'])!
		play_pause_controls_assert(controls, false)
		controls.toggle_playback()
		assert !media.paused()
		play_pause_controls_assert(controls, true)
		play_pause_controls_drain(media)
		play_pause_controls_assert(controls, true)
		controls.toggle_playback()
		assert media.paused()
		play_pause_controls_drain(media)
		play_pause_controls_assert(controls, false)
		// Source only owns the playing token; it does not restore unrelated tokens.
		classes.remove(['play-pause-icon'])!
		controls.update_play_pause_icon()
		assert !classes.contains('play-pause-icon')
		play_pause_controls_assert(controls, false)
	}
}

fn test_play_pause_controls_scrub_state_overrides_the_backend_pause_state_without_losing_tokens() {
	for phase in [MediaControlsScrubbing.while_paused, .while_playing] {
		mut document, mut media, mut controls := play_pause_controls_owner('video')!
		defer { controls.remove_event_listeners(); document.finalize() }
		mut icon := controls.dom_.play_pause_icon?
		mut classes := icon.class_list()
		classes.add(['retained', 'custom-icon'])!
		controls.scrubbing_timeline = phase
		controls.update_play_pause_icon()
		play_pause_controls_assert(controls, phase == .while_playing)
		_ = media.play()
		play_pause_controls_drain(media)
		play_pause_controls_assert(controls, phase == .while_playing)
		media.pause()
		play_pause_controls_drain(media)
		play_pause_controls_assert(controls, phase == .while_playing)
		controls.scrubbing_timeline = .no
		controls.update_play_pause_icon()
		play_pause_controls_assert(controls, false)
	}
}

fn test_play_pause_controls_remove_their_listener_and_explicit_refresh_preserves_the_existing_icon() {
	mut document, mut media, mut controls := play_pause_controls_owner('audio')!
	defer { controls.remove_event_listeners(); document.finalize() }
	mut icon := controls.dom_.play_pause_icon?
	mut classes := icon.class_list()
	classes.add(['retained', 'custom-icon'])!
	_ = media.play()
	play_pause_controls_drain(media)
	play_pause_controls_assert(controls, true)
	controls.remove_event_listeners()
	media.pause()
	play_pause_controls_drain(media)
	play_pause_controls_assert(controls, true)
	controls.update_play_pause_icon()
	assert (controls.dom_.play_pause_icon or { panic('Missing retained icon') }) == icon
	play_pause_controls_assert(controls, false)
}

fn test_play_pause_controls_keep_the_existing_ownerless_numeric_adapter() {
	mut media := HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-play-pause.example/'})
	mut controls := MediaControls.create(media)
	defer { controls.remove_event_listeners() }
	assert controls.dom_.play_pause_icon == none && media.paused()
	controls.scrubbing_timeline = .while_playing
	controls.update_play_pause_icon()
	assert controls.play_icon_is_pause && media.paused()
	controls.scrubbing_timeline = .while_paused
	controls.update_play_pause_icon()
	assert !controls.play_icon_is_pause && media.paused()
	controls.scrubbing_timeline = .no
	controls.update_play_pause_icon()
	assert !controls.play_icon_is_pause
}
