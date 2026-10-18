module html

import dom

@[heap]
struct UserPlayProbe {
mut:
	starts int
	pauses int
	fetches int
	events []string
}

fn user_play_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing user play task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn user_play_owner(kind string, prepared bool) !(&dom.Document, &HTMLMediaElement, &MediaControls, &UserPlayProbe) {
	url := dom.URL{value: 'https://user-play.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing media owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing media model') }
	if prepared {
		media.set_duration(60)
		media.set_ready_state(.have_enough_data)
		media.network_state_ = .idle
		media.seekable_.add_range(0, 60)
		media.on_audio_track_added(MediaTrackMetadata{identifier: 1})
		if kind == 'video' {
			media.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180})
		}
		media.set_show_poster(false)
	}
	probe := &UserPlayProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [probe] () {
			mut state := unsafe { &UserPlayProbe(probe) }
			state.starts++
		}
		pause: fn [probe] () {
			mut state := unsafe { &UserPlayProbe(probe) }
			state.pauses++
		}
	})
	controls := MediaControls.create(media)
	user_play_drain(media)
	target := media.event_target()
	for name in ['play', 'playing', 'pause', 'waiting'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [probe, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert (event.target() or { panic('Missing event target') }) == target
				assert (current or { panic('Missing current target') }) == target
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				mut state := unsafe { &UserPlayProbe(probe) }
				state.events << event.type_name()
				return dom.js_undefined()
			}
		})
	}
	return document, media, controls, probe
}

fn user_play_cleanup(mut controls MediaControls) {
	controls.remove_event_listeners()
	if mut timer := controls.hover_timer_ { timer.stop() }
}

fn user_play_space(media &HTMLMediaElement) {
	event := dom.KeyboardEvent.construct_impl('keydown', dom.KeyboardEventInit{
		key_code: u32(dom.KeyCode.space)
		cancelable: true
	}) or { panic(err) }
	base := unsafe { &dom.Event(event) }
	assert !base.is_trusted()
	assert !media.event_target().dispatch_event(base) && base.default_prevented()
}

fn test_controls_user_play_runs_internal_steps_without_granting_public_play_permission() {
	mut policy := AutoplaySettings.the()
	previous := policy.policy()
	allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous, allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	for kind in ['audio', 'video'] {
		mut document, mut media, mut controls, probe := user_play_owner(kind, true)!
		defer { user_play_cleanup(mut controls); document.finalize() }
		native := document.get_window()?
		assert !native.has_sticky_activation() && !media.is_allowed_to_play()
		denied := media.play()
		assert denied.state() == .rejected && media.paused()
		exception := denied.result().as_webidl_value()!.dom_exception_?
		assert exception.name() == 'NotAllowedError'
		assert media.toggle_playback().state() == .rejected && media.paused()
		assert probe.starts == 0 && probe.events == [] && media.pending_play_promises_.len == 0
		controls.toggle_playback()
		assert !media.paused() && probe.starts == 1 && controls.play_icon_is_pause
		assert probe.events == [] && media.pending_play_promises_.len == 0
		assert !native.has_sticky_activation() && !media.is_allowed_to_play()
		user_play_drain(media)
		assert probe.events == ['play', 'playing'] && controls.request_animation_frame_id_ != 0
		controls.toggle_playback()
		assert media.paused() && probe.pauses == 1 && !controls.play_icon_is_pause
		user_play_drain(media)
		assert probe.events == ['play', 'playing', 'pause']
		assert media.play().state() == .rejected && media.paused()
		assert !native.has_sticky_activation() && media.pending_play_promises_.len == 0
	}
}

fn test_controls_space_uses_user_play_and_both_scrubbing_guards_prevent_all_actions() {
	mut policy := AutoplaySettings.the()
	previous := policy.policy()
	allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous, allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	for kind in ['video', 'audio'] {
		mut document, media, mut controls, probe := user_play_owner(kind, true)!
		defer { user_play_cleanup(mut controls); document.finalize() }
		controls.hide_controls()
		assert !controls.visible && controls.hover_timer_ == none
		for phase in [MediaControlsScrubbing.while_paused, .while_playing] {
			controls.scrubbing_timeline = phase
			user_play_space(media)
			assert media.paused() && probe.starts == 0 && probe.pauses == 0
			assert !controls.visible && controls.hover_timer_ == none
			assert probe.events == [] && media.queued_media_task_ids_.len == 0
		}
		controls.scrubbing_timeline = .no
		user_play_space(media)
		assert !media.paused() && probe.starts == 1 && controls.visible
		assert media.pending_play_promises_.len == 0
		user_play_drain(media)
		user_play_space(media)
		assert media.paused() && probe.pauses == 1
		user_play_drain(media)
		assert probe.events == ['play', 'playing', 'pause']
		assert !document.get_window()?.has_sticky_activation()
	}
}

fn test_user_play_resume_does_not_add_a_promise_or_resolve_a_paused_public_batch() {
	mut policy := AutoplaySettings.the()
	previous := policy.policy()
	allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous, allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut document, mut media, mut controls, probe := user_play_owner('audio', true)!
	defer { user_play_cleanup(mut controls); document.finalize() }
	media.set_ready_state(.have_current_data)
	user_play_drain(media)
	pending := media.play()
	assert pending.state() == .pending && media.pending_play_promises_.len == 1
	assert !media.paused() && probe.starts == 0
	policy.set_policy(.block_audio_and_video, [])
	controls.toggle_playback() // Pause captures the old promise for queued rejection.
	assert media.paused() && pending.state() == .pending && media.pending_play_promises_.len == 0
	controls.toggle_playback() // The user entry resumes without creating a new play promise.
	assert !media.paused() && pending.state() == .pending && media.pending_play_promises_.len == 0
	user_play_drain(media)
	assert pending.state() == .rejected
	exception := pending.result().as_webidl_value()!.dom_exception_?
	assert exception.name() == 'AbortError'
	assert probe.events == ['play', 'waiting', 'pause', 'play', 'waiting']
	assert probe.starts == 0 && probe.pauses == 1
	media.set_ready_state(.have_enough_data)
	user_play_drain(media)
	assert probe.starts == 1 && probe.events.last() == 'playing'
	assert pending.state() == .rejected && media.pending_play_promises_.len == 0
}

fn test_user_play_promotes_actual_preload_none_selection_without_marking_it_as_explicit_load() {
	mut policy := AutoplaySettings.the()
	previous := policy.policy()
	allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous, allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	for kind in ['audio', 'video'] {
		mut document, mut media, mut controls, probe := user_play_owner(kind, false)!
		defer { user_play_cleanup(mut controls); document.finalize() }
		media.set_fetch_hook(fn [probe] (url dom.URL, offset u64) !MediaResourceResponse {
			assert url.value == 'https://user-play.example/movie.mp4' && offset == 0
			mut state := unsafe { &UserPlayProbe(probe) }
			state.fetches++
			return MediaResourceResponse{mime_type: 'video/mp4', duration: 60, buffered_end: 60}
		})
		media.set_source('/movie.mp4')
		media.select_resource()!
		assert probe.fetches == 0 && media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		assert media.paused() && media.ready_state() == .have_nothing
		assert media.play().state() == .rejected && probe.fetches == 0
		controls.toggle_playback()
		assert probe.fetches == 1 && !media.paused() && media.ready_state() == .have_enough_data
		assert !media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		assert !media.current_resource_selection_is_explicit_ && media.pending_play_promises_.len == 0
		user_play_drain(media)
		assert media.event_count('play') == 1 && media.event_count('playing') == 1
		assert probe.starts == 1 && !document.get_window()?.has_sticky_activation()
		controls.toggle_playback()
		user_play_drain(media)
		assert media.paused() && probe.fetches == 1 && media.event_count('pause') == 1
	}
}
