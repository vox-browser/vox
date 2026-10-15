module html

import dom

@[heap]
struct ReadyAutoplayObservation {
mut:
	starts          int
	position        f64
	advance_on_play bool
	events          []string
	new_promise     ?&dom.Promise
}

fn ready_autoplay_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing readiness autoplay task') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('missing autoplay task document') }) == voidptr(media.document() or { panic('missing autoplay owner document') })
	return task
}

fn ready_autoplay_drain(media &HTMLMediaElement) {
	for _ in 0 .. 30 {
		if media.queued_media_task_ids_.len == 0 { return }
		ready_autoplay_take(media).execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn ready_autoplay_owner(kind string, buffered_end f64, autoplay bool) !(&HTMLMediaElement, &ReadyAutoplayObservation) {
	url := dom.URL{ value: 'https://ready-autoplay.example.test/' }
	attribute := if autoplay { ' autoplay' } else { '' }
	document := parse_navigation_document('<${kind} id="player"${attribute}></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing readiness autoplay player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing readiness autoplay owner') }
	seen := &ReadyAutoplayObservation{}
	media.set_fetch_hook(fn [buffered_end] (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: buffered_end }
	})
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [seen] () f64 { return seen.position }
		play: fn [media, seen] () {
			assert !media.paused() && !media.show_poster() && media.can_autoplay_
			assert !media.has_started_playback_ && media.pending_play_promises_.len == 0
			mut observation := unsafe { &ReadyAutoplayObservation(seen) }
			observation.starts++
			if observation.advance_on_play { observation.position = 7 }
		}
	})
	media.set_source('/movie.mp4')
	media.load()!
	ready_autoplay_drain(media)
	return media, seen
}

fn test_resource_autoplay_waits_for_enough_data_instead_of_starting_when_fetch_finishes() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	for kind in ['audio', 'video'] {
		for buffered_end in [0.0, 2.0] {
			mut media, seen := ready_autoplay_owner(kind, buffered_end, true)!
			defer {
				media.remove_queued_media_element_tasks()
				media.finish_delaying_load_event()
				media.finalize()
			}
			assert media.ready_state() == if buffered_end == 0 { MediaReadyState.have_metadata } else { MediaReadyState.have_future_data }
			assert media.network_state() == .idle && media.paused() && media.show_poster()
			assert seen.starts == 0 && media.can_autoplay_ && media.pending_play_promises_.len == 0
			assert media.event_count('play') == 0 && media.event_count('playing') == 0
			media.buffered_.clear()
			media.buffered_.add_range(0, 8)
			media.playback_has_future_data_ = true
			media.update_ready_state()
			assert media.ready_state() == .have_enough_data && !media.paused() && !media.show_poster()
			assert seen.starts == 1 && media.can_autoplay_ && media.pending_play_promises_.len == 0
			ready_autoplay_drain(media)
			assert media.event_count('play') == 1 && media.event_count('playing') == 1
			assert media.event_count('canplaythrough') == 1 && media.event_count('waiting') == 0
			assert media.play_range_start_ == none
		}
	}
}

fn test_ready_autoplay_queues_owned_readiness_before_play_and_keeps_a_later_explicit_promise_separate() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	for kind in ['audio', 'video'] {
		mut media, seen := ready_autoplay_owner(kind, 0, false)!
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		mut observation := unsafe { &ReadyAutoplayObservation(seen) }
		observation.position = 3
		observation.advance_on_play = true
		media.set_autoplay(true)
		for name in ['loadeddata', 'canplay', 'canplaythrough', 'timeupdate', 'play', 'playing'] {
			media.set_on_event(name, &dom.CallbackType{
				handle_event: fn [name, media, seen] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
					mut result := unsafe { &ReadyAutoplayObservation(seen) }
					result.events << name
					assert !media.paused() && !media.show_poster() && media.ready_state() == .have_enough_data
					assert voidptr(event.target() or { panic('missing autoplay event target') }) == voidptr(media.event_target())
					assert voidptr(current or { panic('missing autoplay current target') }) == voidptr(media.event_target())
					assert event.is_trusted() && !event.bubbles() && !event.cancelable()
					if name == 'canplaythrough' {
						assert media.can_autoplay_ && media.pending_play_promises_.len == 0
						mut owner := unsafe { &HTMLMediaElement(media) }
						result.new_promise = owner.play()
					}
					if name == 'playing' {
						assert media.current_time() == 3
						assert (result.new_promise or { panic('missing later explicit promise') }).state() == .pending
					}
					return dom.js_undefined()
				}
			})
		}
		media.set_ready_state(.have_enough_data)
		assert seen.starts == 1 && seen.position == 7 && media.has_started_playback_
		assert !media.paused() && media.can_autoplay_ && media.pending_play_promises_.len == 0
		assert media.play_range_start_ == none && seen.new_promise == none
		assert seen.events == [] && media.queued_media_task_ids_.len == 6
		mut loop := main_thread_event_loop()
		loop.perform_a_microtask_checkpoint()
		assert seen.events == []
		for name in ['loadeddata', 'canplay', 'canplaythrough', 'timeupdate', 'play', 'playing'] {
			ready_autoplay_take(media).execute()
			assert seen.events.last() == name
		}
		promise := seen.new_promise or { panic('missing explicit listener promise') }
		assert promise.state() == .pending && media.queued_media_task_ids_.len == 1
		ready_autoplay_take(media).execute()
		assert promise.state() == .fulfilled && promise.result().is_undefined()
		assert seen.starts == 1 && media.queued_media_task_ids_.len == 0
		assert seen.events == ['loadeddata', 'canplay', 'canplaythrough', 'timeupdate', 'play', 'playing']
	}
}

fn test_ready_autoplay_gates_and_same_state_refreshes_do_not_create_a_new_start() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	for kind in ['audio', 'video'] {
		for gate in ['allowed', 'policy', 'sandbox', 'can-autoplay', 'attribute', 'adapter',
			'empty-network', 'already-playing'] {
			policy.set_policy(.allow_audio_and_video, [])
			mut media, seen := ready_autoplay_owner(kind, 0, false)!
			defer {
				media.remove_queued_media_element_tasks()
				media.finish_delaying_load_event()
				media.finalize()
			}
			media.set_ready_state(.have_future_data)
			ready_autoplay_drain(media)
			media.set_autoplay(gate != 'attribute')
			mut document := media.document()?
			match gate {
				'policy' { policy.set_policy(.block_audio_and_video, []) }
				'sandbox' { document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features)) }
				'can-autoplay' { media.can_autoplay_ = false }
				'adapter' { media.allow_autoplay_ = false }
				'empty-network' { media.network_state_ = .empty }
				'already-playing' { media.set_paused(false) }
				else {}
			}
			media.set_ready_state(.have_enough_data)
			assert seen.starts == if gate == 'allowed' { 1 } else { 0 }
			assert media.paused() == (gate !in ['allowed', 'already-playing'])
			ready_autoplay_drain(media)
			assert media.event_count('play') == if gate == 'allowed' { 1 } else { 0 }
			assert media.event_count('playing') == if gate == 'allowed' { 1 } else { 0 }
			if gate != 'allowed' {
				policy.set_policy(.allow_audio_and_video, [])
				document.set_active_sandboxing_flag_bits(0)
				media.network_state_ = .idle
				media.can_autoplay_ = true
				media.allow_autoplay_ = true
				media.set_autoplay(true)
				media.set_paused(true)
			}
			media.set_ready_state(.have_enough_data)
			assert seen.starts == if gate == 'allowed' { 1 } else { 0 }
			assert media.queued_media_task_ids_.len == 0
			if gate != 'allowed' {
				media.set_ready_state(.have_future_data)
				media.set_ready_state(.have_enough_data)
				assert !media.paused() && seen.starts == 1
				ready_autoplay_drain(media)
				assert media.event_count('play') == 1 && media.event_count('playing') == 1
			}
			assert media.can_autoplay_ && media.pending_play_promises_.len == 0
		}
	}
}

fn test_ready_autoplay_reads_the_adopted_documents_policy_and_sandbox() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	for kind in ['audio', 'video'] {
		policy.set_policy(.block_audio_and_video, ['https://ready-autoplay.example.test/'])
		mut media, seen := ready_autoplay_owner(kind, 0, false)!
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		media.set_ready_state(.have_future_data)
		ready_autoplay_drain(media)
		media.set_autoplay(true)
		mut original := media.document()?
		assert media.is_allowed_to_play()
		url := dom.URL{ value: 'https://adopted-ready-autoplay.example.test/' }
		mut document := parse_navigation_document('<body></body>', url, url.origin(), none)!
		document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
		document.adopt_node(original.get_element_by_id('player')?.as_node())
		assert voidptr(media.document()?) == voidptr(document)
		assert !media.is_allowed_to_play() && !media.is_eligible_for_autoplay()
		media.set_ready_state(.have_enough_data)
		ready_autoplay_drain(media)
		assert media.paused() && seen.starts == 0 && media.event_count('play') == 0
		document.set_active_sandboxing_flag_bits(0)
		media.set_ready_state(.have_future_data)
		media.set_ready_state(.have_enough_data)
		ready_autoplay_drain(media)
		assert media.is_eligible_for_autoplay() && !media.is_allowed_to_play()
		assert media.paused() && seen.starts == 0 && media.event_count('playing') == 0
		original.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
		policy.set_policy(.block_audio_and_video, ['https://adopted-ready-autoplay.example.test/'])
		media.set_ready_state(.have_future_data)
		media.set_ready_state(.have_enough_data)
		assert !media.paused() && seen.starts == 1 && media.can_autoplay_
		ready_autoplay_drain(media)
		assert media.event_count('play') == 1 && media.event_count('playing') == 1
	}
}

fn test_ready_autoplay_timeupdate_depends_on_poster_and_queued_playing_survives_a_listener_pause() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	for kind in ['audio', 'video'] {
		for poster in [false, true] {
			mut media, seen := ready_autoplay_owner(kind, 0, false)!
			defer {
				media.remove_queued_media_element_tasks()
				media.finish_delaying_load_event()
				media.finalize()
			}
			media.set_show_poster(poster)
			media.set_autoplay(true)
			for name in ['loadeddata', 'canplay', 'canplaythrough', 'timeupdate', 'play', 'playing', 'pause'] {
				media.set_on_event(name, &dom.CallbackType{
					handle_event: fn [name, media, seen] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
						mut observation := unsafe { &ReadyAutoplayObservation(seen) }
						observation.events << name
						if name == 'loadeddata' {
							assert !media.paused() && media.can_autoplay_ && seen.starts == 1
							mut owner := unsafe { &HTMLMediaElement(media) }
							owner.pause()
							assert owner.paused() && !owner.can_autoplay_
						} else {
							assert media.paused()
							assert seen.starts == 1
						}
						return dom.js_undefined()
					}
				})
			}
			media.set_ready_state(.have_enough_data)
			assert !media.paused() && !media.show_poster() && media.can_autoplay_
			assert seen.starts == 1 && seen.events == [] && media.pending_play_promises_.len == 0
			assert media.queued_media_task_ids_.len == if poster { 6 } else { 5 }
			ready_autoplay_drain(media)
			expected := if poster {
				['loadeddata', 'canplay', 'canplaythrough', 'timeupdate', 'play', 'playing', 'timeupdate', 'pause']
			} else {
				['loadeddata', 'canplay', 'canplaythrough', 'play', 'playing', 'timeupdate', 'pause']
			}
			assert seen.events == expected && media.paused() && !media.can_autoplay_
			assert media.event_count('play') == 1 && media.event_count('playing') == 1
			assert media.event_count('pause') == 1 && media.event_count('timeupdate') == if poster { 2 } else { 1 }
			assert seen.starts == 1 && !media.has_started_playback_ && media.pending_play_promises_.len == 0
		}
	}
}
