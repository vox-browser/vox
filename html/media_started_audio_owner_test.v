module html

import dom
import math
import page

@[heap]
struct StartedAudioObservation {
mut:
	starts int
	pauses int
	events []string
}

fn started_audio_drain(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn started_audio_owner(ready MediaReadyState) !(&HTMLMediaElement, &page.Page) {
	url := dom.URL{ value: 'https://started-audio.example.test/' }
	mut document := parse_navigation_document('<audio id="player"></audio>', url, url.origin(), none)!
	owner := page.Page.create(1)!
	document.set_page(unsafe { &dom.Page(owner) })
	element := document.get_element_by_id('player') or { return error('missing audio') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing media owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{
			mime_type: 'video/mp4'
			duration: 20
			audio_tracks: [MediaTrackMetadata{ identifier: 1, name: 'Audio' }]
		}
	})
	media.set_source('/audio.mp4')
	media.load()!
	started_audio_drain(media)
	media.set_ready_state(ready)
	media.set_show_poster(false)
	started_audio_drain(media)
	assert media.audio_tracks().has_enabled_track() && media.paused()
	return media, owner
}

fn started_audio_client_states(owner &page.Page) []string {
	return owner.client().events.filter(it.name == 'change-audio-play-state').map(it.text)
}

fn test_waiting_playback_stays_silent_and_manager_hooks_precede_audible_notifications() {
	mut media, owner := started_audio_owner(.have_metadata)!
	document := media.document()?
	state := &StartedAudioObservation{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [media, document, owner, state] () {
			assert !media.paused() && !media.is_playing_audio() && !document.is_playing_audio()
			assert started_audio_client_states(owner) == []
			mut observation := unsafe { &StartedAudioObservation(state) }
			observation.starts++
		}
		pause: fn [media, document, owner, state] () {
			assert media.paused() && media.is_playing_audio() && document.is_playing_audio()
			assert started_audio_client_states(owner) == ['playing']
			mut observation := unsafe { &StartedAudioObservation(state) }
			observation.pauses++
		}
	})
	for name in ['playing', 'pause'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, media, document, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert media.paused() && !media.is_playing_audio() && !document.is_playing_audio()
				mut observation := unsafe { &StartedAudioObservation(state) }
				observation.events << name
				return dom.js_undefined()
			}
		})
	}
	promise := media.play()
	assert !media.paused() && !media.is_playing_audio() && !document.is_playing_audio()
	media.set_muted(true)
	media.set_muted(false)
	media.set_volume(0.5)!
	assert started_audio_client_states(owner) == [] && state.starts == 0
	started_audio_drain(media)
	assert promise.state() == .pending
	media.set_ready_state(.have_future_data)
	assert state.starts == 1 && media.is_playing_audio() && document.is_playing_audio()
	assert started_audio_client_states(owner) == ['playing']
	assert promise.state() == .pending && state.events == []
	media.pause()
	assert state.pauses == 1 && !media.is_playing_audio() && !document.is_playing_audio()
	assert started_audio_client_states(owner) == ['playing', 'paused']
	started_audio_drain(media)
	assert state.events == ['playing', 'pause'] && promise.state() == .fulfilled
	assert !document.is_playing_audio() && started_audio_client_states(owner) == ['playing', 'paused']
}

fn test_started_audio_balances_volume_mute_and_track_changes_without_duplicate_client_calls() {
	mut media, owner := started_audio_owner(.have_future_data)!
	document := media.document()?
	media.play()
	assert media.is_playing_audio() && document.is_playing_audio()
	media.set_muted(true)
	media.set_muted(true)
	assert !document.is_playing_audio()
	media.set_muted(false)
	media.set_volume(0)!
	media.set_volume(0)!
	assert !document.is_playing_audio()
	media.set_volume(0.5)!
	media.set_page_muted(true)
	assert !document.is_playing_audio()
	media.set_page_muted(false)
	mut track := media.audio_tracks().item(0)?
	track.set_enabled(false)
	track.set_enabled(false)
	assert !document.is_playing_audio()
	track.set_enabled(true)
	assert document.is_playing_audio()
	assert started_audio_client_states(owner) == ['playing', 'paused', 'playing', 'paused', 'playing', 'paused', 'playing', 'paused', 'playing']
	media.pause()
	media.set_paused(false)
	media.set_volume(1)!
	assert !document.is_playing_audio()
	assert started_audio_client_states(owner).len == 10
	media.notify_about_playing()
	assert document.is_playing_audio() && started_audio_client_states(owner).last() == 'playing'
	media.pause()
	started_audio_drain(media)
}

fn test_pause_hook_reentrant_volume_update_reports_the_stop_only_once() {
	mut media, owner := started_audio_owner(.have_future_data)!
	document := media.document()?
	media.play()
	assert document.is_playing_audio()
	state := &StartedAudioObservation{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		pause: fn [media, document, state] () {
			assert media.paused() && media.is_playing_audio() && document.is_playing_audio()
			mut observation := unsafe { &StartedAudioObservation(state) }
			observation.pauses++
			mut player := unsafe { &HTMLMediaElement(media) }
			player.set_muted(true)
			assert !document.is_playing_audio()
		}
	})
	media.pause()
	media.pause()
	media.set_muted(false)
	assert state.pauses == 1 && !document.is_playing_audio()
	assert started_audio_client_states(owner) == ['playing', 'paused']
	started_audio_drain(media)
}

fn test_resource_failure_removes_audibility_without_synthesizing_pause() {
	mut media, owner := started_audio_owner(.have_future_data)!
	document := media.document()?
	media.play()
	assert document.is_playing_audio()
	media.handle_media_source_failure([], 'unsupported resource')
	assert !media.paused() && media.audio_tracks().length() == 0
	assert !media.is_playing_audio() && !document.is_playing_audio()
	assert started_audio_client_states(owner) == ['playing', 'paused']
	// Source forget-tracks leaves the started state intact; a new enabled track
	// re-evaluates it without an invented second manager start.
	media.on_audio_track_added(MediaTrackMetadata{ identifier: 2, name: 'Replacement' })
	assert document.is_playing_audio()
	assert started_audio_client_states(owner) == ['playing', 'paused', 'playing']
	media.pause()
	started_audio_drain(media)
}

fn test_actual_media_start_and_pause_realign_hidden_document_timers() {
	mut media, owner := started_audio_owner(.have_metadata)!
	mut document := media.document()?
	window := unsafe { &WindowModel(document.get_window()?) }
	mut scope := window.window_or_worker_global_scope()
	scope.set_hidden_document_timer_wake_up_interval(1_000)
	scope.set_hidden_document_intensive_timer_throttling(60_000, 1_000, 1_000)
	document.update_the_visibility_state(.hidden)
	grace := scope.intensive_timer_grace_deadline_ms_
	id := scope.set_timeout(timer_source_handler(''), 25, [])
	media.play()
	waiting := scope.active_timers_[id] or { panic('missing waiting timer') }
	assert !document.is_playing_audio()
	assert math.fmod(waiting.due_time_ms - scope.hidden_timer_grid_origin_ms(), 1_000) == 0
	media.set_ready_state(.have_future_data)
	audible := scope.active_timers_[id] or { panic('missing audible timer') }
	assert document.is_playing_audio() && audible.due_time_ms == audible.deadline_ms
	media.pause()
	silent := scope.active_timers_[id] or { panic('missing silent timer') }
	assert !document.is_playing_audio()
	assert math.fmod(silent.due_time_ms - scope.hidden_timer_grid_origin_ms(), 1_000) == 0
	assert scope.intensive_timer_grace_deadline_ms_ == grace
	assert started_audio_client_states(owner) == ['playing', 'paused']
	scope.clear_timeout(id)
	started_audio_drain(media)
}

fn test_waiting_media_notifies_the_adopting_page_and_audible_adoption_transfers_document_state() {
	mut media, first_owner := started_audio_owner(.have_metadata)!
	mut first := media.document()?
	// Keep the element disconnected so adoption does not invoke removed_from's
	// independent pause algorithm.
	element := first.get_element_by_id('player')?
	mut node := element.as_node()
	node.remove(false)
	started_audio_drain(media)
	media.play()
	assert !first.is_playing_audio() && started_audio_client_states(first_owner) == []
	url := dom.URL{ value: 'https://adopted-audio.example.test/' }
	mut second := parse_navigation_document('', url, url.origin(), none)!
	second_owner := page.Page.create(1)!
	second.set_page(unsafe { &dom.Page(second_owner) })
	second.adopt_node(element.as_node())
	media.set_ready_state(.have_future_data)
	assert !first.is_playing_audio() && second.is_playing_audio()
	assert started_audio_client_states(first_owner) == []
	assert started_audio_client_states(second_owner) == ['playing']
	first.adopt_node(element.as_node())
	assert first.is_playing_audio() && !second.is_playing_audio()
	assert started_audio_client_states(first_owner) == []
	assert started_audio_client_states(second_owner) == ['playing']
	media.pause()
	assert !first.is_playing_audio() && !second.is_playing_audio()
	assert started_audio_client_states(first_owner) == ['paused']
	assert started_audio_client_states(second_owner) == ['playing']
	started_audio_drain(media)
}
