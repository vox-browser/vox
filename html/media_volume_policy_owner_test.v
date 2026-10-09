module html

import dom
import page

@[heap]
struct VolumePolicyObservation {
mut:
	fetches int
	hooks []string
	events []string
	pending []bool
	position f64 = 2
}

fn volume_policy_owner(kind string, address string) !(&HTMLMediaElement, &VolumePolicyObservation) {
	url := dom.URL{ value: address }
	document := parse_navigation_document('<${kind} id="player"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing media owner') }
	state := &VolumePolicyObservation{}
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut seen := unsafe { &VolumePolicyObservation(state) }
		seen.fetches++
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/pending.mp4')
	return media, state
}

fn volume_policy_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing volume policy task') }
}

fn volume_policy_drain(media &HTMLMediaElement) {
	for media.queued_media_task_ids_.len > 0 { volume_policy_take(media).execute() }
}

fn volume_policy_load(mut media HTMLMediaElement) ! {
	media.load()!
	volume_policy_drain(media)
	media.set_show_poster(false)
}

fn test_becoming_audible_pauses_both_owners_before_volume_update_and_defers_ordered_rejection() {
	mut policy := AutoplaySettings.the()
	old_policy := policy.policy_
	old_allowlist := policy.allowlist_.clone()
	defer { policy.policy_ = old_policy; policy.allowlist_ = old_allowlist }
	policy.set_policy(.block_audio, [])
	for kind in ['audio', 'video'] {
		for change in ['unmute', 'volume'] {
			mut media, state := volume_policy_owner(kind, 'https://volume-policy.example.test/')!
			if change == 'unmute' { media.set_muted(true) } else { media.set_volume(0)! }
			volume_policy_load(mut media)!
			media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
				current_time: fn [state] () f64 { return state.position }
			})
			media.set_official_playback_position(2)
			first := media.play()
			second := media.play()
			volume_policy_drain(media)
			assert !media.paused() && first.state() == .pending && second.state() == .pending
			media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
				current_time: fn [state] () f64 { return state.position }
				pause: fn [state] () {
					mut seen := unsafe { &VolumePolicyObservation(state) }
					seen.hooks << 'pause'
				}
				set_volume: fn [state, media] (value f64) {
					mut seen := unsafe { &VolumePolicyObservation(state) }
					seen.hooks << 'volume:${value}:${media.paused()}'
				}
			})
			target := media.event_target()
			for name in ['volumechange', 'timeupdate', 'pause'] {
				media.set_on_event(name, &dom.CallbackType{
					handle_event: fn [name, media, state, first, second, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
						mut seen := unsafe { &VolumePolicyObservation(state) }
						seen.events << name
						seen.pending << (first.state() == .pending && second.state() == .pending)
						assert media.paused()
						assert voidptr(event.target() or { panic('missing target') }) == voidptr(target)
						assert voidptr(current or { panic('missing current target') }) == voidptr(target)
						assert event.is_trusted() && !event.bubbles() && !event.cancelable()
						return dom.js_undefined()
					}
				})
			}
			mut clock := unsafe { &VolumePolicyObservation(state) }
			clock.position = 6
			// Deliver the clock sample before manually executing owner tasks.
			media.set_official_playback_position(6)
			if change == 'unmute' { media.set_muted(false) } else { media.set_volume(0.5)! }
			assert media.paused() && media.pending_play_promises_.len == 0
			assert !media.can_autoplay_ && media.current_time() == 6
			assert media.played().start(0)! == 2 && media.played().end(0)! == 6
			assert state.hooks == ['pause', 'volume:${media.volume()}:true']
			assert state.events == [] && state.fetches == 1 && media.queued_media_task_ids_.len == 2
			mut loop := main_thread_event_loop()
			loop.perform_a_microtask_checkpoint()
			assert state.events == [] && first.state() == .pending
			volume_task := volume_policy_take(media)
			assert voidptr(volume_task.document()?) == voidptr(media.document()?)
			assert volume_task.source() == media.media_element_event_task_source()
			volume_task.execute()
			assert state.events == ['volumechange'] && first.state() == .pending
			pause_task := volume_policy_take(media)
			assert voidptr(pause_task.document()?) == voidptr(media.document()?)
			assert pause_task.source() == media.media_element_event_task_source()
			pause_task.execute()
			assert state.events == ['volumechange', 'timeupdate', 'pause'] && state.pending == [true, true, true]
			assert first.state() == .rejected && second.state() == .rejected
			first_exception := first.result().as_webidl_value()!.dom_exception_?
			second_exception := second.result().as_webidl_value()!.dom_exception_?
			assert voidptr(first_exception) == voidptr(second_exception)
			assert first_exception.name() == 'AbortError' && first_exception.code() == 20
			assert first_exception.message() == 'Media playback was paused'
			assert media.queued_media_task_ids_.len == 0
		}
	}
}

fn test_blocked_change_on_a_paused_empty_owner_disables_autoplay_without_selecting_a_resource() {
	mut policy := AutoplaySettings.the()
	old_policy := policy.policy_
	old_allowlist := policy.allowlist_.clone()
	defer { policy.policy_ = old_policy; policy.allowlist_ = old_allowlist }
	policy.set_policy(.block_audio_and_video, [])
	for kind in ['audio', 'video'] {
		mut media, state := volume_policy_owner(kind, 'https://paused-volume.example.test/')!
		assert media.can_autoplay_ && media.network_state() == .empty
		media.set_muted(true)
		assert !media.can_autoplay_ && media.paused() && media.network_state() == .empty
		assert state.fetches == 0 && media.queued_media_task_ids_.len == 1
		media.set_volume(0)!
		assert state.fetches == 0 && media.queued_media_task_ids_.len == 2
		volume_policy_drain(media)
		assert media.event_count('volumechange') == 2
		assert media.event_count('timeupdate') == 0 && media.event_count('pause') == 0
	}
}

fn test_allowing_policy_origin_or_consumed_sticky_activation_keeps_changed_media_playing() {
	mut policy := AutoplaySettings.the()
	old_policy := policy.policy_
	old_allowlist := policy.allowlist_.clone()
	defer { policy.policy_ = old_policy; policy.allowlist_ = old_allowlist }
	for permission in ['policy', 'origin', 'sticky'] {
		policy.set_policy(.allow_audio_and_video, [])
		mut media, _ := volume_policy_owner('video', 'https://allowed-volume.example.test/')!
		volume_policy_load(mut media)!
		promise := media.play()
		volume_policy_drain(media)
		if permission == 'origin' {
			policy.set_policy(.block_audio_and_video, ['https://allowed-volume.example.test'])
		} else if permission == 'sticky' {
			policy.set_policy(.block_audio_and_video, [])
			mut native := media.document()?.get_window()?
			native.set_last_activation_timestamp(0)
			mut window := unsafe { &WindowModel(native) }
			window.consume_user_activation()
			assert native.has_sticky_activation() && !native.has_transient_activation()
		}
		media.set_volume(0.5)!
		media.set_muted(true)
		media.set_muted(false)
		volume_policy_drain(media)
		assert !media.paused() && promise.state() == .pending && media.pending_play_promises_.len == 1
		assert media.event_count('volumechange') == 3 && media.event_count('pause') == 0
		media.pause_element()
		volume_policy_drain(media)
	}
}

fn test_page_unmute_and_unchanged_or_invalid_values_do_not_run_the_policy_pause_steps() {
	mut policy := AutoplaySettings.the()
	old_policy := policy.policy_
	old_allowlist := policy.allowlist_.clone()
	defer { policy.policy_ = old_policy; policy.allowlist_ = old_allowlist }
	policy.set_policy(.block_audio, [])
	mut owner := page.Page.create(1)!
	owner.set_page_mute_state(.muted)
	mut media, state := volume_policy_owner('audio', 'https://page-volume-policy.example.test/')!
	mut document := media.document()?
	document.set_page(unsafe { &dom.Page(owner) })
	volume_policy_load(mut media)!
	promise := media.play()
	volume_policy_drain(media)
	media.set_volume(0.5)!
	volume_policy_drain(media)
	assert !media.paused() && media.effective_media_volume() == 0
	owner.set_page_mute_state(.unmuted)
	assert !media.paused() && !media.is_allowed_to_play() && media.effective_media_volume() == 0.5
	assert media.queued_media_task_ids_.len == 0 && promise.state() == .pending
	media.set_volume(0.5)!
	media.set_muted(false)
	mut rejected := false
	media.set_volume(2) or { rejected = true }
	assert rejected && media.volume() == 0.5
	assert !media.paused() && media.queued_media_task_ids_.len == 0 && state.fetches == 1
	media.set_volume(0.75)!
	assert media.paused() && media.queued_media_task_ids_.len == 2
	volume_policy_drain(media)
	assert promise.state() == .rejected && media.event_count('volumechange') == 2
}

fn test_adopted_volume_change_uses_the_new_document_and_not_the_old_sticky_window() {
	mut policy := AutoplaySettings.the()
	old_policy := policy.policy_
	old_allowlist := policy.allowlist_.clone()
	defer { policy.policy_ = old_policy; policy.allowlist_ = old_allowlist }
	policy.set_policy(.block_audio, [])
	mut media, _ := volume_policy_owner('audio', 'https://old-volume-policy.example.test/')!
	old_document := media.document()?
	mut old_window := old_document.get_window()?
	old_window.set_last_activation_timestamp(0)
	url := dom.URL{ value: 'https://adopted-volume-policy.example.test/' }
	mut document := parse_navigation_document('<body></body>', url, url.origin(), none)!
	document.adopt_node(old_document.get_element_by_id('player')?.as_node())
	media.set_muted(true)
	volume_policy_load(mut media)!
	promise := media.play()
	volume_policy_drain(media)
	assert !media.paused() && !document.get_window()?.has_sticky_activation()
	media.set_muted(false)
	assert media.paused() && promise.state() == .pending
	task := volume_policy_take(media)
	assert voidptr(task.document()?) == voidptr(document)
	task.execute()
	volume_policy_drain(media)
	assert promise.state() == .rejected && media.event_count('pause') == 1
}
